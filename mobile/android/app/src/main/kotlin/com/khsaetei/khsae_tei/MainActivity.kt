package com.khsaetei.khsae_tei

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "khsae_tei/multicast_lock"
    private var lock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            // Android drops incoming multicast (mDNS) packets over WiFi by default
            // to save power; a MulticastLock is required to receive them at all.
            when (call.method) {
                "acquire" -> {
                    if (lock == null) {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        lock = wifi.createMulticastLock("khsae_tei_mdns").apply { setReferenceCounted(true) }
                    }
                    lock?.acquire()
                    result.success(null)
                }
                "release" -> {
                    lock?.let { if (it.isHeld) it.release() }
                    result.success(null)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    // Without this, OEM battery managers (Samsung especially,
                    // confirmed by testing) throttle the background service
                    // regardless of the foreground-service notification.
                    val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
                    if (!powerManager.isIgnoringBatteryOptimizations(applicationContext.packageName)) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${applicationContext.packageName}")
                        }
                        startActivity(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
