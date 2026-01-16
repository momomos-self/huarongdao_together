import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PermissionService {
  static const MethodChannel _channel = MethodChannel('huarongdao.p2p/permissions');

  /// 通过原生方法请求网络/位置权限（Android）
  /// 获取权限后返回 true，否则返回 false 或弹出引导
  static Future<bool> requestNetworkPermissions(BuildContext context) async {
    // On Windows desktop we do not require runtime network discovery permissions.
    // Allow play immediately to avoid blocking UI with platform permission dialogs.
    if (Platform.isWindows) return true;
    try {
      // 尝试调用原生方法检查并请求权限
      final dynamic result = await _channel.invokeMethod('checkAndRequestNetworkPermissions');
      if (result == true) return true;
    } on PlatformException catch (e) {
      debugPrint("Permission request failed: ${e.message}");
    }

    // 如果未获得权限，且 context 仍然有效，则显示对话框
    if (context.mounted) {
      final bool? goToSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('需要网络发现权限'),
          content: const Text('为了在同一局域网内发现并连接对手，应用需要位置或附近设备权限。请点击“去设置”手动开启权限。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );

      if (goToSettings == true) {
        try {
          await _channel.invokeMethod('openAppSettings');
        } on PlatformException catch (e) {
          debugPrint("Could not open settings: ${e.message}");
        }
      }
    }

    return false;
  }

  /// 请求访问相册/图片权限（Android）。返回 true 表示已授权。
  static Future<bool> requestPhotoPermissions(BuildContext context) async {
    try {
      final dynamic result = await _channel.invokeMethod('checkAndRequestPhotoPermissions');
      if (result == true) return true;
    } on PlatformException catch (e) {
      debugPrint("Photo permission request failed: ${e.message}");
    }

    if (context.mounted) {
      final bool? goToSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('需要相册权限'),
          content: const Text('为了使用图片拼图模式，应用需要访问相册的权限。请点击“去设置”手动开启权限。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('去设置')),
          ],
        ),
      );

      if (goToSettings == true) {
        try {
          await _channel.invokeMethod('openAppSettings');
        } on PlatformException catch (e) {
          debugPrint("Could not open settings: ${e.message}");
        }
      }
    }

    return false;
  }
}

