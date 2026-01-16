import "package:flutter/material.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:provider/provider.dart";
import "core/constants.dart";
import "models/record.dart";
import "pages/home_page.dart";
import "provider/game_provider.dart";
import "provider/socket_provider.dart";
import "provider/local_server_provider.dart";
import "provider/local_client_provider.dart";
import "services/permission_service.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  Hive.registerAdapter(GameRecordAdapter());
  await Hive.openBox<GameRecord>(AppConstants.recordBox);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => SocketProvider()),
        ChangeNotifierProvider(create: (_) => LocalServerProvider()),
        ChangeNotifierProvider(create: (_) => LocalClientProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PermissionGate(),
    );
  }
}

class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ensurePermissions();
  }

  Future<void> _ensurePermissions() async {
    final granted = await PermissionService.requestNetworkPermissions(context);
    if (mounted) {
      setState(() {
        _ready = granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text('需要网络权限以启用局域网对战'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _ensurePermissions(),
                child: const Text('点击重试或请求权限'),
              ),
            ],
          ),
        ),
      );
    }

    return const HomePage();
  }
}
