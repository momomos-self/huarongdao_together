package com.example.huarongdao_together

import android.content.Context
import android.net.wifi.WifiManager
import android.Manifest
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
	private var multicastLock: WifiManager.MulticastLock? = null
	private val CHANNEL = "huarongdao.p2p/multicast"
	private val PERM_CHANNEL = "huarongdao.p2p/permissions"
	private val REQUEST_CODE_PERMISSIONS = 1001
	private var pendingPermResult: MethodChannel.Result? = null
	private var pendingPermissions: Array<String> = arrayOf()

	override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"acquireMulticastLock" -> {
					acquireMulticastLock()
					result.success(true)
				}
				"releaseMulticastLock" -> {
					releaseMulticastLock()
					result.success(true)
				}
				else -> result.notImplemented()
			}
		}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERM_CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"checkAndRequestNetworkPermissions" -> {
					val permissions = mutableListOf<String>()
					
					// 根据用户要求和 Android 版本动态构建权限列表
					if (android.os.Build.VERSION.SDK_INT >= 33) { // Android 13 (TIRAMISU)
						permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
					}
					
					permissions.add(Manifest.permission.ACCESS_WIFI_STATE)
					permissions.add(Manifest.permission.ACCESS_NETWORK_STATE)
					permissions.add(Manifest.permission.INTERNET)

					if (android.os.Build.VERSION.SDK_INT <= 32) { // Android 12L (S_V2) 及以下
						permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
						permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
					}
					
					checkAndRequestPermissions(permissions.toTypedArray(), result)
				}
				"checkAndRequestPhotoPermissions" -> {
					val permissions = mutableListOf<String>()
					if (android.os.Build.VERSION.SDK_INT >= 33) {
						permissions.add(Manifest.permission.READ_MEDIA_IMAGES)
					} else {
						permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
					}
					checkAndRequestPermissions(permissions.toTypedArray(), result)
				}
				"openAppSettings" -> {
					openAppSettings()
					result.success(true)
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun checkAndRequestPermissions(perms: Array<String>, result: MethodChannel.Result) {
		// 如果已存在挂起结果，拒绝新请求
		if (pendingPermResult != null) {
			result.error("busy", "permission request already in progress", null)
			return
		}
		val notGranted = perms.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
		Log.d("HuarongP2P", "checkAndRequestPermissions: requested=${perms.joinToString()} notGranted=${notGranted.joinToString()}")
		if (notGranted.isEmpty()) {
			Log.d("HuarongP2P", "All permissions already granted")
			result.success(true)
			return
		}
		pendingPermResult = result
		pendingPermissions = perms
		ActivityCompat.requestPermissions(this, perms, REQUEST_CODE_PERMISSIONS)
	}

	override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode == REQUEST_CODE_PERMISSIONS) {
			val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
			Log.d("HuarongP2P", "onRequestPermissionsResult: granted=$granted results=${grantResults.joinToString()}")
			pendingPermResult?.success(granted)
			pendingPermResult = null
			pendingPermissions = arrayOf()
		}
	}

	private fun openAppSettings() {
		try {
			val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
			val uri = android.net.Uri.fromParts("package", packageName, null)
			intent.data = uri
			startActivity(intent)
		} catch (e: Exception) {
			// ignore
		}
	}

	private fun acquireMulticastLock() {
		val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
		if (multicastLock == null) {
			multicastLock = wifi.createMulticastLock("huarongdao_multicast")
			multicastLock?.setReferenceCounted(true)
			multicastLock?.acquire()
			Log.d("HuarongP2P", "MulticastLock acquired")
		}
	}

	private fun releaseMulticastLock() {
		multicastLock?.let {
			if (it.isHeld) it.release()
			Log.d("HuarongP2P", "MulticastLock released")
			multicastLock = null
		}
	}
}
