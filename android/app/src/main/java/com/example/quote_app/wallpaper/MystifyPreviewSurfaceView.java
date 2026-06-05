package com.example.quote_app.wallpaper;

import android.content.Context;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

/**
 * Native in-app preview for the Touch/Mystify wallpaper.
 *
 * This view intentionally reuses the same OpenGL renderer thread used by the
 * live wallpaper service. The previous Flutter CustomPainter preview could look
 * very different from the real wallpaper; this SurfaceView makes the settings
 * page preview and the applied wallpaper share the same rendering path.
 */
public final class MystifyPreviewSurfaceView extends SurfaceView implements SurfaceHolder.Callback {
    private IntimacyMystifyWallpaperService.GLRenderThread renderThread;
    private boolean released = false;

    public MystifyPreviewSurfaceView(Context context) {
        super(context);
        setFocusable(false);
        setFocusableInTouchMode(false);
        getHolder().addCallback(this);
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        if (released) return;
        stopRenderer();
        renderThread = new IntimacyMystifyWallpaperService.GLRenderThread(getContext().getApplicationContext(), holder, true);
        renderThread.setVisible(true);
        int w = Math.max(2, getWidth());
        int h = Math.max(2, getHeight());
        renderThread.resize(w, h);
        renderThread.start();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        if (renderThread != null) renderThread.resize(width, height);
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        stopRenderer();
    }

    @Override
    protected void onDetachedFromWindow() {
        release();
        super.onDetachedFromWindow();
    }

    public void release() {
        released = true;
        stopRenderer();
        try { getHolder().removeCallback(this); } catch (Throwable ignored) {}
    }

    private void stopRenderer() {
        if (renderThread != null) {
            renderThread.requestStop();
            renderThread = null;
        }
    }
}
