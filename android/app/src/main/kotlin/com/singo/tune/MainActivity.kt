package com.singo.tune

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.singo.tune/custom_notif"
        )
        CustomMusicNotif.channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val title = call.argument<String>("title") ?: "Singo Tune"
                    val artist = call.argument<String>("artist") ?: ""
                    val art = call.argument<String>("art")
                    val playing = call.argument<Boolean>("playing") ?: false
                    CustomMusicNotif.show(this, title, artist, art, playing)
                    result.success(null)
                }
                "hide" -> {
                    CustomMusicNotif.hide(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
