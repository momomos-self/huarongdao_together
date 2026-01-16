# Huarongdao Together

一个用 Flutter 实现的华容道益智多人竞速小游戏，支持单机、基于服务器的对战（可接入后端）以及局域网（LAN）本地 C/S 联机模式。
重点：本仓库集成了一个稳定的局域网 C/S 方案（以开热点/局域网中的一台设备作为服务端），适用于没有公网/后端环境的本地联机场景。
注意：本游戏用于腾讯菁英班作业，不用于商业用途

## 目录概览（重要文件）
 - `lib/main.dart`：程序入口，Provider 注册与路由。
 - `lib/pages/room_page.dart`：联机大厅、创建/连接房间与局域网控制界面。
 - `lib/pages/multi_game_page.dart`：多人对战页（显示双方状态、处理消息与胜负判定）。
 - `lib/pages/game_page.dart`：单人游戏逻辑与界面。
 - `lib/provider/local_server_provider.dart`：局域网服务端实现（ServerSocket），负责接收客户端消息并广播。
 - `lib/provider/local_client_provider.dart`：局域网客户端实现（Socket），负责连接服务端并收发 JSON 消息。
 - `lib/provider/socket_provider.dart`：原有的 Socket.IO 后端适配器（仍保留以支持远端后端）。
 - `pubspec.yaml`：依赖与资源声明。

## 核心功能简述
 - 单机/本地游戏：支持图片模式与数字模式，可保存记录（Hive）。
 - 后端对战（可选）：可通过 Node.js 后端与 socket.io 做多人对战（保留接口）。
 - 局域网（LAN）本地 C/S 对战：当无法使用公网后端时，可在一台设备上启动本地服务（端口默认 8888），其他设备输入该 IP 连接并进入对战。
## LAN C/S 设计说明

设计目标：在没有公网服务器或在移动热点环境下，使用一种可靠、简单的局域网联机方式：一台设备作为服务端（Host），其它设备作为客户端（Client）。
实现要点：
 - 服务端：使用 `ServerSocket` 监听端口（`LocalServerProvider`）。保存已连接客户端列表、解析 JSON 行协议，并向所有客户端广播消息。提供 `sendToAll(msg, exclude: socket)`，支持排除来源以避免回显。
 - 客户端：使用 `Socket.connect`（`LocalClientProvider`），发送 JSON 行（每条消息以换行分隔），并注册回调处理来自服务端的消息。
 - 消息格式（JSON）：
	 - `{'type':'join_request', 'roomId': '...', 'name':'clientName'}` 客户端请求加入
	 - `{'type':'join_accept', 'roomId':'...'}` 服务端确认加入
	- `{'type':'status', 'time':'1.2', 'steps': 10}` 周期性发送玩家状态
	- `{'type':'move', 'index': 5}` 移动同步（可用于回放或回放校验）
	- `{'type':'finish', 'time':'12.3', 'steps': 80}` 玩家完成
	- `{'type':'result', 'winner':'host'|'client', 'winnerTime':..., 'winnerSteps':...}` 主机决定并广播最终胜利结果

工作流（高层）：
 1. 主机在 `RoomPage` 点击“创建本地房间”并启动服务（显示本机 IP:port）。
 2. 客户端在 `RoomPage` 输入主机 IP 并点击“连接”。服务端自动记录客户端信息并回送 `join_accept`。
 3. 主机点击“开始游戏”后，主机本地 `GameProvider.startGame(...)`，并通过 `sendStart()` 广播 `start` 给客户端（包含 `size` 与 `layout`）。
 4. 游戏过程中，双方周期性发送 `status`，服务端将客户端 `status` 转发给其他客户端并更新主机 UI（主机负责聚合/展示）。为避免客户端看到自己发送的回显，服务端在转发时会排除消息来源（`exclude`）。
 5. 任一方完成后发送 `finish`。主机作为权威端决定胜者（等候短时窗口或等待双方完成），然后广播 `result` 给所有客户端，页面显示胜负对话。

优点：简单可靠、对移动热点友好，不依赖外部服务器或 NAT 穿透。
限制：受局域网/热点环境影响（防火墙、Android 热点 IP 变化、平台网络权限）。

## 快速上手（开发环境）

前提：已安装 Flutter SDK、Android SDK / Xcode（按需）。
1. 克隆仓库：

```bash
git clone <repo-url>
cd huarongdao_together
flutter pub get
```

2. 运行（调试）：
 - Windows：`flutter run -d windows`
 - Android（设备/模拟器）：`flutter run -d <deviceId>`
 - iOS（需要 macOS + Xcode）：`flutter run -d <deviceId>`
3. 打包发布（示例 Android）：

```bash
flutter build apk --release --split-per-abi
```

## 局域网联机
 - 设备 A（主机）：打开 App → 对战大厅 → 开启「局域网」切换 → 点击“创建本地房间 (作为服务端)” → 记下界面上显示的本机 IP（例如 192.168.43.1）
 - 设备 B（客户端）：打开 App → 对战大厅 → 开启「局域网」切换 → 在“连接到主机”输入框填写主机 IP → 点击“连接” → 客户端会发送 `join_request` 并等待 `join_accept`
 - 主机在连接后点击“开始游戏” → 主机与客户端应分别进入游戏并开始同步状态与步数；完成后主机会广播 `result` 并展示胜负。
常见问题排查：
 - 无法连接：检查目标 IP 是否正确（热点一般会使用 192.168.43.1 或 192.168.0.1 等），并确认防火墙允许端口 8888（Windows 防火墙、Android 热点）。
 - Android 权限：部分 Android 版本对本地网络/热点有权限或策略限制，需允许应用网络权限。开发时可在 `permission_service.dart` 做条件处理（项目中已为 Windows 做了判定）。
 - 消息不显示或抖动：服务端已实现排除来源转发，若仍出现回显/抖动，请开启 Debug 日志（下一节提供命令）并检查发送/接收的 JSON 内容。
