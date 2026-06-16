package com.saigonphantomlabs.base

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val wifiChannel = "com.saigonphantomlabs.base/wifi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRssi" -> result.success(currentRssi())
                    "getWifiInfo" -> result.success(currentWifiInfo())
                    else -> result.notImplemented()
                }
            }
    }

    /** RSSI hiện tại (dBm) hoặc null nếu không lấy được / không phải WiFi. */
    private fun currentRssi(): Int? {
        return try {
            val wifi = applicationContext
                .getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            val rssi = wifi.connectionInfo?.rssi ?: return null
            // RSSI hợp lệ là số âm (vd -45). 0 hoặc dương = không có kết nối WiFi.
            if (rssi >= 0) null else rssi
        } catch (e: Exception) {
            null
        }
    }

    /** RSSI + tần số (MHz) + link speed (Mbps). Field nào lỗi → null. */
    private fun currentWifiInfo(): Map<String, Any?> {
        return try {
            val wifi = applicationContext
                .getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            val info = wifi.connectionInfo
            @Suppress("DEPRECATION")
            val rssi = info?.rssi
            @Suppress("DEPRECATION")
            val freq = info?.frequency // MHz (API 21+)
            @Suppress("DEPRECATION")
            val linkSpeed = info?.linkSpeed // Mbps
            mapOf(
                "rssi" to (if (rssi != null && rssi < 0) rssi else null),
                "frequencyMhz" to (if (freq != null && freq > 0) freq else null),
                "linkSpeedMbps" to (if (linkSpeed != null && linkSpeed > 0) linkSpeed else null),
            )
        } catch (e: Exception) {
            emptyMap()
        }
    }
}
