package com.ethiopianreligious.reader.ethiopian_reader

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/// Blocks screenshots and screen recording for the reader surface (DRM).
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
    }
}
