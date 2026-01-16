const express = require("express");
const http = require("http");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: { origin: "*" }
});

const rooms = new Map();

// Helper to cleanup any rooms a socket is in
function cleanupSocketRooms(socket) {
    for (const [id, room] of rooms.entries()) {
        if (room.players.includes(socket.id)) {
            socket.to(id).emit("opponentDisconnected");
            socket.leave(id);
            rooms.delete(id);
            console.log(`Cleanup: Room ${id} deleted because player ${socket.id} left/disconnected.`);
        }
    }
    broadcastRooms();
}

io.on("connection", (socket) => {
    console.log("User connected:", socket.id);

    socket.on("createRoom", (data) => {
        cleanupSocketRooms(socket);
        const { password, isPublic } = data || {};
        const roomId = Math.random().toString(36).substring(2, 6).toUpperCase();
        socket.join(roomId);
        rooms.set(roomId, {
            id: roomId,
            players: [socket.id],
            status: "waiting",
            layout: null,
            password: password || null,
            isPublic: isPublic !== false
        });
        socket.emit("roomCreated", { roomId, players: [socket.id] });
        broadcastRooms();
        console.log(`Room created: ${roomId} (Pass: ${password || "None"})`);
    });

    socket.on("getRooms", () => {
        sendRoomList(socket);
    });

    socket.on("joinRoom", (data) => {
        cleanupSocketRooms(socket);
        // Handle both simple ID and object with password
        const roomId = typeof data === "string" ? data : data.roomId;
        const password = data.password;
        console.log(`Join attempt: socket=${socket.id} -> room=${roomId}`);
        
        const room = rooms.get(roomId);
        if (!room) {
            console.log(`Join failed: room ${roomId} not found`);
            return socket.emit("error", "未找到房间");
        }
        if (room.players.includes(socket.id)) {
            console.log(`Join ignored: socket ${socket.id} already in room ${roomId}`);
            // send current player list back to this socket
            return socket.emit("playerJoined", { roomId, players: room.players });
        }
        if (room.players.length >= 2) {
            console.log(`Join failed: room ${roomId} is full`);
            return socket.emit("error", "房间已满");
        }
        if (room.status !== "waiting") {
            console.log(`Join failed: room ${roomId} already started`);
            return socket.emit("error", "游戏已开始");
        }
        if (room.password && room.password !== password) {
            console.log(`Join failed: wrong password for room ${roomId}`);
            return socket.emit("error", "密码错误");
        }

        // All checks passed -> add player
        room.players.push(socket.id);
        socket.join(roomId);
        io.to(roomId).emit("playerJoined", { roomId, players: room.players });
        console.log(`Join success: socket ${socket.id} joined room ${roomId}`);
        broadcastRooms();
    });

    socket.on("startGame", (data) => {
        const { roomId, layout, size } = data;
        const room = rooms.get(roomId);
        if (room) {
            room.status = "playing";
            room.layout = layout;
            io.to(roomId).emit("gameStarted", { layout, size });
            broadcastRooms();
        }
    });

    socket.on("updateStatus", (data) => {
        const { roomId, time, steps } = data;
        socket.to(roomId).emit("opponentUpdate", { time, steps });
    });

    socket.on("finishGame", (data) => {
        const { roomId, time, steps } = data;
        const room = rooms.get(roomId);
        if (room) {
            io.to(roomId).emit("gameEnded", { winnerId: socket.id, winnerTime: time, winnerSteps: steps });
            room.status = "finished";
            broadcastRooms();
        }
    });

    socket.on("leaveRoom", (data) => {
        // If client provided a roomId, prefer deleting that specific room
        try {
            const roomId = data && data.roomId;
            if (roomId && rooms.has(roomId)) {
                const room = rooms.get(roomId);
                // notify other players in the room
                socket.to(roomId).emit("opponentDisconnected");
                // remove socket from room and delete the room record
                socket.leave(roomId);
                rooms.delete(roomId);
                console.log(`LeaveRoom: Room ${roomId} deleted on request by ${socket.id}`);
                broadcastRooms();
                return;
            }
        } catch (e) {
            console.error('leaveRoom error handling explicit roomId', e);
        }

        // Fallback: cleanup any rooms this socket may be in
        cleanupSocketRooms(socket);
    });

    socket.on("disconnect", () => {
        cleanupSocketRooms(socket);
    });
});

function sendRoomList(target) {
    const list = Array.from(rooms.values())
        .filter(r => r.status === "waiting" && r.isPublic)
        .map(r => ({ id: r.id, playerCount: r.players.length, hasPassword: !!r.password }));
    target.emit("roomList", list);
}

function broadcastRooms() {
    const list = Array.from(rooms.values())
        .filter(r => r.status === "waiting" && r.isPublic)
        .map(r => ({ id: r.id, playerCount: r.players.length, hasPassword: !!r.password }));
    io.emit("roomList", list);
    console.log('Broadcast rooms:', list.map(r => r.id));
}

const PORT = 3000;
server.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
});
