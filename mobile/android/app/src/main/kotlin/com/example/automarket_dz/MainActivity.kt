package com.example.automarket_dz

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "automarket_dz/notifications"
	private val notificationChannelId = "chat_messages"
	private val notificationPermissionRequestCode = 7091

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
				when (call.method) {
					"showNotification" -> {
						val title = call.argument<String>("title") ?: "رسالة جديدة"
						val body = call.argument<String>("body") ?: "لديك رسالة جديدة"
						val shown = showNotification(title, body)
						result.success(shown)
					}

					"requestNotificationPermission" -> {
						val granted = requestNotificationPermissionIfNeeded()
						result.success(granted)
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun requestNotificationPermissionIfNeeded(): Boolean {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
			return true
		}

		val granted = ContextCompat.checkSelfPermission(
			this,
			Manifest.permission.POST_NOTIFICATIONS
		) == PackageManager.PERMISSION_GRANTED

		if (!granted) {
			requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequestCode)
			return false
		}

		return true
	}

	private fun showNotification(title: String, body: String): Boolean {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			val granted = ContextCompat.checkSelfPermission(
				this,
				Manifest.permission.POST_NOTIFICATIONS
			) == PackageManager.PERMISSION_GRANTED
			if (!granted) {
				return false
			}
		}

		val notificationManager =
			getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			val channel = NotificationChannel(
				notificationChannelId,
				"Chat Messages",
				NotificationManager.IMPORTANCE_HIGH
			)
			channel.description = "Notifications for incoming chat messages"
			notificationManager.createNotificationChannel(channel)
		}

		val notification = NotificationCompat.Builder(this, notificationChannelId)
			.setSmallIcon(R.mipmap.ic_launcher)
			.setContentTitle(title)
			.setContentText(body)
			.setStyle(NotificationCompat.BigTextStyle().bigText(body))
			.setPriority(NotificationCompat.PRIORITY_HIGH)
			.setAutoCancel(true)
			.build()

		val notificationId = (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
		notificationManager.notify(notificationId, notification)

		return true
	}
}
