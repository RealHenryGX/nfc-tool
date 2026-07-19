package com.songoku.nfctool.nfc_tool

import android.app.NotificationChannel
import android.app.NotificationManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.AlarmClock
import android.provider.CalendarContract
import android.provider.MediaStore
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.util.Base64
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "NfcToolbox"
    }

    private val isDebuggable: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    private val channelName = "com.songoku.nfctool/platform"
    private var torchOn = false
    private var tts: TextToSpeech? = null
    private var pendingResult: MethodChannel.Result? = null
    private val pickReq = 4101
    private val saveReq = 4102
    private var saveBytesPending: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (isDebuggable) {
                    Log.d(TAG, "channel ← ${call.method}")
                }
                when (call.method) {
                    "batteryLevel" -> {
                        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        result.success(mapOf("ok" to true, "level" to level))
                    }
                    "wifiEnabled" -> {
                        @Suppress("DEPRECATION")
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        result.success(mapOf("ok" to true, "enabled" to wifi.isWifiEnabled))
                    }
                    "runTask" -> {
                        val kind = call.argument<String>("kind") ?: ""
                        @Suppress("UNCHECKED_CAST")
                        val params = (call.argument<Map<String, Any?>>("params") ?: emptyMap())
                        try {
                            val message = runTask(kind, params)
                            result.success(mapOf("ok" to true, "message" to message))
                        } catch (e: Exception) {
                            result.success(mapOf("ok" to false, "error" to (e.message ?: "error")))
                        }
                    }
                    "listLaunchableApps" -> {
                        val pm = packageManager
                        val main = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
                        val apps = pm.queryIntentActivities(main, 0)
                            .map {
                                mapOf(
                                    "label" to it.loadLabel(pm).toString(),
                                    "packageName" to it.activityInfo.packageName,
                                )
                            }
                            .sortedBy { it["label"]?.toString()?.lowercase() }
                        result.success(mapOf("ok" to true, "apps" to apps))
                    }
                    "pickBytes" -> {
                        pendingResult = result
                        val mime = call.argument<String>("mime") ?: "*/*"
                        val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mime
                        }
                        startActivityForResult(i, pickReq)
                    }
                    "saveBytes" -> {
                        val b64 = call.argument<String>("base64") ?: ""
                        val filename = call.argument<String>("filename") ?: "nfc_dump.bin"
                        saveBytesPending = Base64.decode(b64, Base64.DEFAULT)
                        pendingResult = result
                        val i = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, filename)
                        }
                        startActivityForResult(i, saveReq)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val res = pendingResult ?: return
        pendingResult = null
        if (resultCode != RESULT_OK || data?.data == null) {
            res.success(mapOf("ok" to false, "error" to "cancelled"))
            return
        }
        try {
            when (requestCode) {
                pickReq -> {
                    val bytes = contentResolver.openInputStream(data.data!!)?.use { it.readBytes() }
                        ?: ByteArray(0)
                    res.success(
                        mapOf(
                            "ok" to true,
                            "base64" to Base64.encodeToString(bytes, Base64.NO_WRAP),
                            "uri" to data.data.toString(),
                        ),
                    )
                }
                saveReq -> {
                    val bytes = saveBytesPending ?: ByteArray(0)
                    contentResolver.openOutputStream(data.data!!)!!.use { it.write(bytes) }
                    saveBytesPending = null
                    res.success(mapOf("ok" to true, "uri" to data.data.toString()))
                }
                else -> res.success(mapOf("ok" to false, "error" to "unknown request"))
            }
        } catch (e: Exception) {
            res.success(mapOf("ok" to false, "error" to (e.message ?: "io error")))
        }
    }

    private fun runTask(kind: String, params: Map<String, Any?>): String {
        return when (kind) {
            "wifi_state" -> toggleWifi(params["enabled"] as? Boolean)
            "wifi_network", "forgot_wifi" -> {
                startActivity(Intent(Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened Wi-Fi settings"
            }
            "hotspot_state" -> {
                startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened wireless settings (hotspot)"
            }
            "bluetooth_state" -> toggleBluetooth(params["enabled"] as? Boolean)
            "bluetooth_discoverable" -> {
                val i = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE)
                i.putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 120)
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(i)
                "Requested BT discoverable"
            }
            "bluetooth_connect", "bluetooth_disconnect", "bluetooth_unpair" -> btDeviceAction(kind, params["mac"]?.toString())
            "nfc_state" -> {
                startActivity(Intent(Settings.ACTION_NFC_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened NFC settings"
            }
            "plane_state" -> {
                startActivity(Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened airplane settings"
            }
            "mobile_data" -> {
                startActivity(Intent(Settings.ACTION_DATA_ROAMING_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened mobile data settings"
            }
            "gps_state" -> {
                startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened location settings"
            }
            "sound_mode" -> setSoundMode(params["mode"]?.toString() ?: "normal")
            "volume" -> setVolume(params)
            "brightness" -> setBrightness(params)
            "adaptive_brightness", "brightness_mode", "display_timeout", "auto_rotate" -> {
                startActivity(Intent(Settings.ACTION_DISPLAY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened display settings"
            }
            "flashlight" -> toggleTorch(params["enabled"] as? Boolean)
            "zen_mode", "notification_light" -> {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened notification policy settings"
            }
            "expand_notifications" -> expandNotifications()
            "launch_app" -> launchApp(params["packageName"]?.toString())
            "app_details" -> {
                val pkg = params["packageName"]?.toString() ?: packageName
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                "Opened app details"
            }
            "uninstall_app" -> {
                val pkg = params["packageName"]?.toString() ?: return "package required"
                startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Uninstall intent sent"
            }
            "kill_app", "kill_app_root", "enable_app", "disable_app" -> {
                val pkg = params["packageName"]?.toString() ?: packageName
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                "Opened app details (force-stop/enable/disable manually; root not exposed)"
            }
            "open_file" -> {
                val path = params["path"]?.toString() ?: return "path required"
                startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse(path), "*/*").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Open file intent"
            }
            "send_intent" -> sendCustomIntent(params)
            "toolbox" -> {
                startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened system settings"
            }
            "power_saving" -> {
                startActivity(Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened battery saver"
            }
            "timezone" -> {
                startActivity(Intent(Settings.ACTION_DATE_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened date/time settings"
            }
            "alarm_set", "alarm_in" -> {
                val i = Intent(AlarmClock.ACTION_SET_ALARM)
                params["hour"]?.toString()?.toIntOrNull()?.let { i.putExtra(AlarmClock.EXTRA_HOUR, it) }
                params["minute"]?.toString()?.toIntOrNull()?.let { i.putExtra(AlarmClock.EXTRA_MINUTES, it) }
                params["message"]?.toString()?.let { i.putExtra(AlarmClock.EXTRA_MESSAGE, it) }
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(i)
                "Alarm intent sent"
            }
            "timer_set" -> {
                val secs = params["seconds"]?.toString()?.toIntOrNull() ?: 60
                val i = Intent(AlarmClock.ACTION_SET_TIMER)
                i.putExtra(AlarmClock.EXTRA_LENGTH, secs)
                i.putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(i)
                "Timer intent sent"
            }
            "tts" -> speak(params["text"]?.toString() ?: "")
            "speak_time" -> speak(java.text.SimpleDateFormat("HH:mm", Locale.getDefault()).format(java.util.Date()))
            "vibrate" -> vibratePattern(longArrayOf(0, 200, 100, 200))
            "morse" -> morseVibrate(params["text"]?.toString() ?: "")
            "media_control" -> mediaControl(params["action"]?.toString() ?: "toggle")
            "play_sound" -> playTone()
            "speaker_state" -> {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val on = params["enabled"] as? Boolean ?: !am.isSpeakerphoneOn
                @Suppress("DEPRECATION")
                am.isSpeakerphoneOn = on
                "Speakerphone $on"
            }
            "notification_alert" -> postNotification(params["title"]?.toString() ?: "NFC Toolbox", params["body"]?.toString() ?: "Task alert")
            "wear_notification" -> postNotification(params["title"]?.toString() ?: "Wear", params["body"]?.toString() ?: "NFC task")
            "screenshot" -> {
                startActivity(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened camera (screenshot API restricted)"
            }
            "start_rec_mic" -> {
                startActivity(Intent(MediaStore.Audio.Media.RECORD_SOUND_ACTION).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened sound recorder"
            }
            "insert_event" -> {
                val i = Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
                params["title"]?.toString()?.let { i.putExtra(CalendarContract.Events.TITLE, it) }
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(i)
                "Calendar insert intent"
            }
            "change_wallpaper" -> {
                startActivity(Intent(Intent.ACTION_SET_WALLPAPER).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Wallpaper picker opened"
            }
            "print_image" -> {
                startActivity(Intent(Settings.ACTION_PRINT_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened print settings"
            }
            "multi_window", "car_mode", "driving_mode", "blocking_mode", "sleep_timer" -> {
                startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Opened settings for $kind"
            }
            "run_shortcut", "tasker" -> {
                val action = params["action"]?.toString() ?: "net.dinglisch.android.tasker.ACTION_TASK"
                startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                "Broadcast/intent $action"
            }
            else -> "Unsupported native task: $kind"
        }
    }

    @Suppress("DEPRECATION")
    private fun btDeviceAction(kind: String, mac: String?): String {
        if (mac.isNullOrBlank()) return "mac required"
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return "No Bluetooth"
        return try {
            val device: BluetoothDevice = adapter.getRemoteDevice(mac.uppercase())
            when (kind) {
                "bluetooth_connect" -> {
                    val m = device.javaClass.getMethod("createBond")
                    m.invoke(device)
                    "Bond/connect requested for $mac"
                }
                "bluetooth_unpair" -> {
                    val m = device.javaClass.getMethod("removeBond")
                    m.invoke(device)
                    "Unpair requested for $mac"
                }
                else -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    "Opened BT settings (disconnect)"
                }
            }
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            "BT action failed (${e.message}); opened settings"
        }
    }

    private fun expandNotifications(): String {
        return try {
            @Suppress("WrongConstant")
            val statusBarService = getSystemService("statusbar")
            val statusBarManager = Class.forName("android.app.StatusBarManager")
            val method = statusBarManager.getMethod("expandNotificationsPanel")
            method.invoke(statusBarService)
            "Expanded notifications"
        } catch (e: Exception) {
            "Cannot expand notifications: ${e.message}"
        }
    }

    private fun speak(text: String): String {
        if (text.isBlank()) return "text required"
        if (tts == null) {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    tts?.language = Locale.getDefault()
                    tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())
                }
            }
        } else {
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())
        }
        return "Speaking"
    }

    private fun vibratePattern(pattern: LongArray): String {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
        return "Vibrated"
    }

    private fun morseVibrate(text: String): String {
        val map = mapOf(
            'a' to ".-", 'b' to "-...", 'c' to "-.-.", 'd' to "-..", 'e' to ".",
            'f' to "..-.", 'g' to "--.", 'h' to "....", 'i' to "..", 'j' to ".---",
            'k' to "-.-", 'l' to ".-..", 'm' to "--", 'n' to "-.", 'o' to "---",
            'p' to ".--.", 'q' to "--.-", 'r' to ".-.", 's' to "...", 't' to "-",
            'u' to "..-", 'v' to "...-", 'w' to ".--", 'x' to "-..-", 'y' to "-.--",
            'z' to "--..", ' ' to " ",
        )
        val unit = 80L
        val pattern = mutableListOf(0L)
        for (ch in text.lowercase()) {
            val code = map[ch] ?: continue
            for (symbol in code) {
                when (symbol) {
                    '.' -> { pattern.add(unit); pattern.add(unit) }
                    '-' -> { pattern.add(unit * 3); pattern.add(unit) }
                    ' ' -> pattern.add(unit * 3)
                }
            }
            pattern.add(unit * 2)
        }
        return vibratePattern(pattern.toLongArray())
    }

    private fun mediaControl(action: String): String {
        val key = when (action.lowercase()) {
            "play", "pause", "toggle" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
            "prev", "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            "stop" -> KeyEvent.KEYCODE_MEDIA_STOP
            else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
        }
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, key))
        am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, key))
        return "Media $action"
    }

    private fun playTone(): String {
        val tg = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
        tg.startTone(ToneGenerator.TONE_PROP_BEEP, 300)
        Handler(Looper.getMainLooper()).postDelayed({ tg.release() }, 400)
        return "Played tone"
    }

    private fun postNotification(title: String, body: String): String {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "nfc_toolbox_tasks"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "NFC Tasks", NotificationManager.IMPORTANCE_DEFAULT),
            )
        }
        val n = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()
        nm.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), n)
        return "Notification posted"
    }

    @Suppress("DEPRECATION")
    private fun toggleWifi(enabled: Boolean?): String {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val target = enabled ?: !wifi.isWifiEnabled
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startActivity(Intent(Settings.Panel.ACTION_WIFI).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            "Opened Wi-Fi panel (Android 10+ restriction)"
        } else {
            wifi.isWifiEnabled = target
            "Wi-Fi set to $target"
        }
    }

    @Suppress("DEPRECATION")
    private fun toggleBluetooth(enabled: Boolean?): String {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: return "Bluetooth adapter missing"
        val target = enabled ?: !adapter.isEnabled
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            "Opened Bluetooth settings (toggle restricted)"
        } else {
            if (target) adapter.enable() else adapter.disable()
            "Bluetooth set to $target"
        }
    }

    private fun setSoundMode(mode: String): String {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        when (mode.lowercase()) {
            "silent" -> am.ringerMode = AudioManager.RINGER_MODE_SILENT
            "vibrate" -> am.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            else -> am.ringerMode = AudioManager.RINGER_MODE_NORMAL
        }
        return "Sound mode: $mode"
    }

    private fun setVolume(params: Map<String, Any?>): String {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val stream = when (params["stream"]?.toString()) {
            "ring" -> AudioManager.STREAM_RING
            "alarm" -> AudioManager.STREAM_ALARM
            "notif" -> AudioManager.STREAM_NOTIFICATION
            else -> AudioManager.STREAM_MUSIC
        }
        val max = am.getStreamMaxVolume(stream)
        val pct = (params["percent"]?.toString()?.toIntOrNull() ?: 50).coerceIn(0, 100)
        val value = (max * pct) / 100
        am.setStreamVolume(stream, value, 0)
        return "Volume $pct% on stream"
    }

    private fun setBrightness(params: Map<String, Any?>): String {
        val pct = (params["percent"]?.toString()?.toIntOrNull() ?: 50).coerceIn(1, 100)
        return try {
            Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, (pct * 255) / 100)
            val lp = window.attributes
            lp.screenBrightness = pct / 100f
            window.attributes = lp
            "Brightness $pct%"
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_DISPLAY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            "Need WRITE_SETTINGS; opened display settings (${e.message})"
        }
    }

    private fun toggleTorch(enabled: Boolean?): String {
        val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = cm.cameraIdList.firstOrNull() ?: return "No camera"
        val target = enabled ?: !torchOn
        cm.setTorchMode(id, target)
        torchOn = target
        return "Flashlight $target"
    }

    private fun launchApp(pkg: String?): String {
        if (pkg.isNullOrBlank()) return "packageName required"
        val launch = packageManager.getLaunchIntentForPackage(pkg)
            ?: return "App not installed: $pkg"
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launch)
        return "Launched $pkg"
    }

    private fun sendCustomIntent(params: Map<String, Any?>): String {
        val action = params["action"]?.toString() ?: return "action required"
        val i = Intent(action)
        params["data"]?.toString()?.let { i.data = Uri.parse(it) }
        params["packageName"]?.toString()?.let { i.setPackage(it) }
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(i)
        return "Intent $action sent"
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}
