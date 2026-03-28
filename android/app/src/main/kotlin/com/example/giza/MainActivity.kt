package com.example.giza

import android.os.Bundle
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // Make sure this string matches EXACTLY in your Flutter code
    private val CHANNEL = "com.example.giza/ytdlp"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize Python as soon as the app starts
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val py = Python.getInstance().getModule("yt_backend")

            when (call.method) {
                "downloadAudio" -> {
                    val url = call.argument<String>("url")
                    val path = call.argument<String>("path")
                    val id = call.argument<String>("id")
                    
                    // Run this in a background thread so it doesn't freeze the UI
                    Thread {
                        try {
                            val outputPath = py.callAttr("download_audio", url, path, id).toString()
                            runOnUiThread { result.success(outputPath) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DOWNLOAD_FAILED", e.message, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}