package com.example.giza
import android.os.Bundle
import com.chaquo.python.PyException
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.giza.app/youtube"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }
        val py      = Python.getInstance()
        val backend = py.getModule("yt_backend")
        
        // Ensure cacheDir exists and is used for streaming
        val streamFile = File(this.cacheDir, "yt_stream.m4a")

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "getStreamUrl" -> {
                        val url = call.argument<String>("url") ?: return@setMethodCallHandler result.error("ERR", "URL null", null)
                        val streamPath = streamFile.absolutePath

                        // Run stream_audio in a background thread and pass the writable path
                        Thread {
                            try {
                                backend.callAttr("stream_audio", url, streamPath)
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }.start()

                        // Return the path immediately to Flutter
                        result.success(streamPath)
                    }

                    "downloadAudio" -> {
                        val url      = call.argument<String>("url") ?: return@setMethodCallHandler result.error("ERR", "URL null", null)
                        val saveDir  = call.argument<String>("saveDir") ?: return@setMethodCallHandler result.error("ERR", "Dir null", null)
                        val videoId  = call.argument<String>("videoId") ?: return@setMethodCallHandler result.error("ERR", "ID null", null)

                        File(saveDir).mkdirs()
                        Thread {
                            try {
                                val path = backend.callAttr("download_audio", url, saveDir, videoId).toString()
                                runOnUiThread { result.success(path) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("ERR", e.message, null) }
                            }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }
}