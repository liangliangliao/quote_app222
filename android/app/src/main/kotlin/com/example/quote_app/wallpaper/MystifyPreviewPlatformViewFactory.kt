package com.example.quote_app.wallpaper

import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MystifyPreviewPlatformViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return MystifyPreviewPlatformView(context)
    }
}

private class MystifyPreviewPlatformView(context: Context) : PlatformView {
    private val previewView = MystifyPreviewSurfaceView(context)
    override fun getView(): View = previewView
    override fun dispose() {
        previewView.release()
    }
}
