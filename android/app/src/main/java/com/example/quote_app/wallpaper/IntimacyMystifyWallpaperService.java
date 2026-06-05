package com.example.quote_app.wallpaper;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.OnSharedPreferenceChangeListener;
import android.graphics.Color;
import android.graphics.RectF;
import android.opengl.GLES20;
import android.os.SystemClock;
import android.service.wallpaper.WallpaperService;
import android.view.SurfaceHolder;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.Random;

import javax.microedition.khronos.egl.EGL10;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.egl.EGLContext;
import javax.microedition.khronos.egl.EGLDisplay;
import javax.microedition.khronos.egl.EGLSurface;

/**
 * 发现之旅/触摸：Mystify 亲密艺术动态壁纸。
 *
 * V8 解决三个核心问题：
 * 1) 底层从 Canvas/Bitmap 升级为 OpenGL ES + FBO ping-pong 残影。
 *    真正采用“每帧即时绘制当前随机线条，上一帧只靠 FBO 残影衰减保留”的 Mystify 逻辑。
 * 2) 引入全屏 Stroke Event Generator：每条线从手机可见屏幕任意位置、任意边缘、任意角落、任意两点即时生成，
 *    并用热区采样器避免长期集中在一小块区域。
 * 3) 增加 phosphor decay、加色混合、扇形光网、纤维丝带、点线喷洒与棱镜余影，
 *    对齐参考视频里“黑场中彩色光迹生成、折叠、拖尾、淡出”的观感。
 * 5) V28 新增艺术导演：花瓣钩弧、叶片藤蔓、电子纱扇、银白折刃、菱形框片、长弓光桥等母型轮换，
 *    避免所有点线组成近似同一形状，也减少无组织散乱感。
 * 6) V29 新增“反重复生命系统”：母型冷却记忆、低差异黄金采样、非周期相位、深层变体、
 *    水母触须/星云涡旋/折纸光片/星座碎链，让长期播放更难出现雷同画面。
 * 7) V30 从“点线网状”升级为“雕塑形态”：液态光泡、羽翼、花冠、丝绸幕、能量环、晶体光片。
 * 8) V31 把余韵阶段升级为深蓝水域气泡；V32 去除大圆盘和旧小残泡，改为中心爆散的透明彩膜气泡。
 * 9) V33 进一步把气泡做成水晶薄膜：蓝色水域背景、透明折射感、随机爆散；同时在余韵/新周期做 FBO 清洁，避免旧线条留下脏痕。
 * 10) V34 把“释放”阶段从普通圆形脉冲升级为抽象能量爆发：白金光心、粗大放射光束、暖金/橙红辉光、
 *     高速碎光粒子洪流与短暂满屏白化；只借鉴爆发节奏与光效层次，不复制参考视频中的角色、武器或道具。
 * 11) V35 继续强化释放阶段的“突然颤抖 + 强刺激爆光 + 扫屏光柱 + 碎光洪流”：
 *     通过高频错位重影、短促白化、宽幅冲击楔面、斜切扫光和更密的抽象碎片，增强视频中先抖动再爆发的冲击。
 * 12) V36 把释放开头改为更短、更快、更剧烈的硬震颤；同时余韵气泡改为无 FBO 拖尾的逐帧水晶泡，
 *     避免移动时出现筒状重影/残影，只保留透明膜边、白色高光与轻微折射。
 * 13) V37 把释放震颤升级为“硬震屏错位”：按真实秒数驱动 0.5 秒可见强震窗口，加入全屏白闪、
 *     斜向撕裂光带、核心多重错帧和大幅跳变偏移，让肉眼明确看到先剧烈颤动再爆发。
 * 14) V38 根据用户参考视频/桌面截图，把主体形体从“线条/点网”升级为“单体丝绸刃翼”：
 *     大面积半透明弧面、单侧厚翼、另一侧薄刃、尖端收束、白色切边、绿色/紫色光晕与细密等高线肋纹。
 *     大形体优先，细线只做边缘高光，不再让画面主要由细网格/点阵构成.
 * 15) V40 根据用户截图反馈，只重做“主体阶段”的形体生成与绘制：
 *     移除贯穿屏幕的粗直白带/灰白大宽面，改为参考视频里的局部彩色丝绸/蝠翼光膜、弯曲尖端和贴面细密肋纹。
 *     释放阶段和余韵阶段保持 V38 现有逻辑不变。
 * 16) V41 继续细化主体形体：从“沿中心线加宽的飘带”改为“单侧扇形薄膜/折叠光幕”。
 *     宽面从屏幕边缘/暗处展开，沿弯曲折脊收束到尖钩；肋纹贴着膜面汇聚，白光只保留为短折脊/尖端高光。
 *     仍只作用于分离、吸引、同步、临界主体阶段；释放和余韵阶段绘制函数保持不动。
 * 17) V57 根据用户反馈，把主体阶段改为“现场作画式”实时生成：
 *     当前画面由移动笔尖和短时间历史轨迹共同生成，历史长度逐渐增长，膜面、折脊、外缘、肋线每帧连续变化。
 *     重点解决完整主体直接出现、形体切换不够丝滑、缺少逐笔绘画过程的问题；释放和余韵阶段保持不动。
 * 18) V58 根据标准视频文字画像继续深度改造主体阶段：
 *     不再只画完整历史轮廓，而是按“光笔正在黑场作画”的方式，把新鲜笔尖、湿润外缘、透明膜面、
 *     细密肋线、短回声和颜色流动绑定在同一个时间窗口内。每段膜面/线条都按年龄分段衰减，
 *     让形体看起来是一笔一笔被画出、展开、扭转、收束、消散，而不是完整物体平移或换形。
 * 19) V59 按“光笔画出会呼吸的透明生命体”重新校正主体阶段：
 *     取消厚实带状主体，改为笔尖推进 + 中段开膜 + 喉口扇骨 + 细密流线 + 极短湿迹回声。
 *     膜面只是低透明承托，主体显形主要依靠外缘高光、折脊、肋线和随笔尖年龄衰减的颜色流动。
 * 20) V60 新增“审美导演 / 美感约束”主体系统：
 *     笔尖轨迹不再直接随机，而是由若干书法式样条候选生成、评分、择优；用曲率、纵横比、弯折节奏、
 *     自交风险、宽度分布来过滤丑形。膜面改成沿主脊线生长，肋线改为贴膜短骨与局部喉口扇骨混合，
 *     避免三角纸片、尾部打结、完整厚带和机械漂移。
 * 21) V61 新增“美学骨架锁定 / 大形体光膜”主体系统：
 *     不再让审美评分只挑出一条细弧线，而是先从精选书法光膜母型库中抽取优雅骨架，再用评分过滤。
 *     宽度包络改为黄金胸腔式开膜，主体中段形成可欣赏的透明翼幕/水母伞/折扇肋线；头尾仍保持笔尖
 *     推进与湿迹收束。每一帧都需要同时具备主骨架、负空间、透明膜面、细密肋线和局部高光.
 * 22) V62 立刻修复：主体阶段改为“吸引点光弦网 / 流线场生成器”。
 * 23) V63 修复：去掉硬边界 clamp，放大流线场，加入推进式笔尖与持续流场运动。
 *     由动态喉口、几十条等距弧形光线、负空间、透视压缩、颜色沿线流动和极淡透明膜面共同构成主体。
 *     线条主导，膜面辅助，彻底避免闭合叶片/布片轮廓；保留笔尖推进、短历史残影和实时呼吸变形。
 * 24) V64 修复：把主体从“画完后轻微呼吸”改成“全程滚动写入的活体光弦网”。
 * 25) V65 修复：增强“朝屏幕随机游走 + 形体持续千变万化”，用滚动书写相位替代一次性 reveal。
 *     当前帧只绘制随笔尖推进移动的时间窗口，旧窗口由短 FBO 湿迹保留并淡出；主脊线/喉口/旋涡/展开角持续重构，
 *     让画面始终处在写出、开膜、卷曲、收束、再生长的过程里，同时放大主体舞台和可见运动幅度。
 * 25) V88 把触摸主体阶段改为“单支光笔连续作画”：每段手势只绘制当前笔尖附近的新鲜轨迹，
 *     上一段终点无缝接下一段起点，持续画出长线、弧、环、扇骨、膜片、折线等不同形体；
 *     已画痕迹由 FBO 残影渐渐消失，更接近“笔在纸上画出并退隐”的动态过程。
 * 26) V89 继续强化为“单笔万象”：新增 23 种抽象笔势库、Catmull-Rom 连续骨架、端点零斜率形变、
 *     段落交接缝柔化与风格化调色，让同一支光笔能持续画出千变万化且过渡丝滑的艺术形状。
 * 27) V90 根据用户实机黑屏截图和参考视频重做主体书写节奏：
 *     开场显形改用真实秒级淡入，避免天级周期的 3% 淡入造成长时间黑屏；
 *     光笔改为“书写—停笔—余痕淡出—再落笔”的呼吸节奏，不再无休止连续划线；
 *     每笔完整 reveal 当前艺术形体，并在笔迹周围生成扇翼、花瓣、开放环、晶体切面、星链、光幕肋纹等结构。
 * 4) 保留天级宏观周期：分离最大，吸引/同步主要，临界较少，释放/余韵最少；所有比例和 1～365 天周期可配置.
 *
 * 动画只以抽象线条关系表达分离、吸引、同步、临界、释放、余韵，不出现任何具象身体或露骨画面。
 */
public class IntimacyMystifyWallpaperService extends WallpaperService {
    public static final String PREFS = "intimacy_mystify_wallpaper";

    @Override
    public Engine onCreateEngine() {
        return new MystifyEngine();
    }

    final class MystifyEngine extends Engine {
        private GLRenderThread renderThread;
        private boolean visible = false;

        @Override
        public void onSurfaceCreated(SurfaceHolder holder) {
            super.onSurfaceCreated(holder);
            ensureThread(holder);
        }

        @Override
        public void onSurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            super.onSurfaceChanged(holder, format, width, height);
            if (renderThread != null) renderThread.resize(width, height);
        }

        @Override
        public void onVisibilityChanged(boolean visible) {
            this.visible = visible;
            if (renderThread != null) renderThread.setVisible(visible);
        }

        @Override
        public void onOffsetsChanged(float xOffset, float yOffset, float xOffsetStep, float yOffsetStep,
                                     int xPixelOffset, int yPixelOffset) {
            super.onOffsetsChanged(xOffset, yOffset, xOffsetStep, yOffsetStep, xPixelOffset, yPixelOffset);
            if (renderThread != null) renderThread.setWallpaperOffsets(xOffset, yOffset);
        }

        @Override
        public void onSurfaceDestroyed(SurfaceHolder holder) {
            super.onSurfaceDestroyed(holder);
            if (renderThread != null) {
                renderThread.requestStop();
                renderThread = null;
            }
        }

        @Override
        public void onDestroy() {
            if (renderThread != null) {
                renderThread.requestStop();
                renderThread = null;
            }
            super.onDestroy();
        }

        private void ensureThread(SurfaceHolder holder) {
            if (renderThread == null) {
                renderThread = new GLRenderThread(getApplicationContext(), holder, isPreview());
                renderThread.setVisible(visible);
                renderThread.start();
            }
        }
    }

    static final class GLRenderThread extends Thread {
        private static final int EGL_CONTEXT_CLIENT_VERSION = 0x3098;
        private static final int EGL_OPENGL_ES2_BIT = 4;
        private static final int GRID_COLS = 6;
        private static final int GRID_ROWS = 10;

        private final Context context;
        private final SurfaceHolder holder;
        private final boolean enginePreview;
        private final SharedPreferences prefs;
        private final OnSharedPreferenceChangeListener prefListener;
        private volatile boolean configDirty = true;
        private String visualConfigSignature = "";
        private static final int MOTIF_COUNT = 18;
        private final Random random = new Random();
        private final ArrayList<StrokeEvent> strokes = new ArrayList<>();
        private final int[] spawnHeat = new int[GRID_COLS * GRID_ROWS];
        // V29：短期形态记忆。不是禁止重复，而是让最近出现过的母型降权，避免几分钟内
        // 反复看到同一种“线条整体轮廓”。
        private final int[] motifCooldown = new int[MOTIF_COUNT];
        private int artSpawnIndex = 0;

        private volatile boolean running = true;
        private volatile boolean visible = false;
        private volatile int requestedWidth = 1;
        private volatile int requestedHeight = 1;
        private volatile boolean resizePending = true;

        private int width = 1;
        private int height = 1;
        private int spawnCounter = 0;

        private EGL10 egl;
        private EGLDisplay eglDisplay;
        private EGLConfig eglConfig;
        private EGLContext eglContext;
        private EGLSurface eglSurface;

        private int textureProgram = 0;
        private int colorProgram = 0;
        private int[] fbo = new int[]{0, 0};
        private int[] tex = new int[]{0, 0};
        private int readIndex = 0;
        private int writeIndex = 1;
        private boolean fboReady = false;

        private Config cfg = new Config();
        private long lastConfigRead = 0L;
        private long startMs = SystemClock.elapsedRealtime();
        private float nextSpawnSec = 0f;
        private float nextHardClearSec = 8f;
        private long cycleStartWallMs = 0L;
        private float cycleDurationSec = 86400f;
        private float cycleCriticalStartSec = 0f;
        private float cycleReleaseStartSec = 0f;
        private float cycleReleaseDurationSec = 12f;
        private float cycleAfterglowDurationSec = 24f;
        private float cycleCriticalDurationSec = 60f;
        private float lastVisualSec = -1f;
        // V176 笔尖轨迹缓冲（环形数组，存最近 TRAIL_CAP 帧的笔尖位置+属性）
        private static final int TRAIL_CAP = 300;
        private final float[] trailX    = new float[TRAIL_CAP];
        private final float[] trailY    = new float[TRAIL_CAP];
        private final float[] trailR    = new float[TRAIL_CAP]; // 红
        private final float[] trailG    = new float[TRAIL_CAP]; // 绿
        private final float[] trailB    = new float[TRAIL_CAP]; // 蓝
        private final float[] trailW    = new float[TRAIL_CAP]; // 线宽
        private final float[] trailA    = new float[TRAIL_CAP]; // alpha
        private int   trailHead  = 0;   // 下一个写入位置
        private int   trailSize  = 0;   // 当前有效帧数
        private int   trailGesture = -1; // 上次写入时的 gesture（gesture变时清空）
        private String cycleSignature = "";
        private float pulseX = 0.5f;
        private float pulseY = 0.5f;
        private boolean releasePulseArmed = true;
        // V33：余韵气泡每一轮都使用新的随机种子；阶段切换时清理 FBO，避免上一阶段线条在桌面上留下灰黑痕迹。
        private int afterglowSeed = random.nextInt();
        private int releaseSeed = random.nextInt();
        private String lastPhaseName = "";
        private int cachedAestheticEpisode = Integer.MIN_VALUE;
        private int cachedAestheticGesture = 0;
        private float wallpaperXOffset = 0.5f;
        private float wallpaperYOffset = 0.5f;

        GLRenderThread(Context context, SurfaceHolder holder, boolean enginePreview) {
            super("IntimacyMystifyGLRendererV90ReferencePenArtWithPauses");
            this.context = context.getApplicationContext();
            this.holder = holder;
            this.enginePreview = enginePreview;
            this.prefs = this.context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
            this.prefListener = new OnSharedPreferenceChangeListener() {
                @Override public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
                    configDirty = true;
                }
            };
            this.prefs.registerOnSharedPreferenceChangeListener(this.prefListener);
            readConfig(true);
        }

        void setVisible(boolean visible) { this.visible = visible; }
        void requestStop() { running = false; interrupt(); }
        void resize(int w, int h) {
            if (w > 0 && h > 0) {
                requestedWidth = w;
                requestedHeight = h;
                resizePending = true;
            }
        }

        void setWallpaperOffsets(float xOffset, float yOffset) {
            wallpaperXOffset = clamp(xOffset, 0f, 1f);
            wallpaperYOffset = clamp(yOffset, 0f, 1f);
        }

        @Override
        public void run() {
            if (!initEgl()) return;
            try {
                initGlObjects();
                long last = SystemClock.elapsedRealtime();
                while (running) {
                    if (!visible) {
                        sleepQuiet(120);
                        last = SystemClock.elapsedRealtime();
                        continue;
                    }
                    long now = SystemClock.elapsedRealtime();
                    float dt = clamp((now - last) / 1000f, 0.001f, 0.055f);
                    last = now;
                    if (configDirty || now - lastConfigRead > 3000L) readConfig(false);
                    if (resizePending || !fboReady) {
                        applyResize();
                    }
                    renderFrame(now, dt);
                    egl.eglSwapBuffers(eglDisplay, eglSurface);
                    sleepQuiet(cfg.powerSave ? 38 : 18);
                }
            } catch (Throwable ignored) {
            } finally {
                try { prefs.unregisterOnSharedPreferenceChangeListener(prefListener); } catch (Throwable ignored) {}
                releaseGl();
            }
        }

        private boolean initEgl() {
            try {
                egl = (EGL10) EGLContext.getEGL();
                eglDisplay = egl.eglGetDisplay(EGL10.EGL_DEFAULT_DISPLAY);
                if (eglDisplay == EGL10.EGL_NO_DISPLAY) return false;
                int[] version = new int[2];
                if (!egl.eglInitialize(eglDisplay, version)) return false;
                int[] configAttrs = new int[]{
                        EGL10.EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                        EGL10.EGL_RED_SIZE, 8,
                        EGL10.EGL_GREEN_SIZE, 8,
                        EGL10.EGL_BLUE_SIZE, 8,
                        EGL10.EGL_ALPHA_SIZE, 8,
                        EGL10.EGL_DEPTH_SIZE, 0,
                        EGL10.EGL_STENCIL_SIZE, 0,
                        EGL10.EGL_NONE
                };
                EGLConfig[] configs = new EGLConfig[1];
                int[] num = new int[1];
                if (!egl.eglChooseConfig(eglDisplay, configAttrs, configs, 1, num) || num[0] <= 0) return false;
                eglConfig = configs[0];
                int[] ctxAttrs = new int[]{EGL_CONTEXT_CLIENT_VERSION, 2, EGL10.EGL_NONE};
                eglContext = egl.eglCreateContext(eglDisplay, eglConfig, EGL10.EGL_NO_CONTEXT, ctxAttrs);
                if (eglContext == EGL10.EGL_NO_CONTEXT) return false;
                eglSurface = egl.eglCreateWindowSurface(eglDisplay, eglConfig, holder, null);
                if (eglSurface == null || eglSurface == EGL10.EGL_NO_SURFACE) return false;
                return egl.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext);
            } catch (Throwable ignored) {
                return false;
            }
        }

        private void initGlObjects() {
            textureProgram = createProgram(TEXTURE_VERTEX, TEXTURE_FRAGMENT);
            colorProgram = createProgram(COLOR_VERTEX, COLOR_FRAGMENT);
            GLES20.glDisable(GLES20.GL_DEPTH_TEST);
            GLES20.glDisable(GLES20.GL_CULL_FACE);
            GLES20.glClearColor(0f, 0f, 0f, 1f);
            applyResize();
        }

        private void applyResize() {
            resizePending = false;
            width = Math.max(2, requestedWidth);
            height = Math.max(2, requestedHeight);
            GLES20.glViewport(0, 0, width, height);
            recreateFbos(width, height);
            strokes.clear();
            resetSpawnHeat();
            nextSpawnSec = 0f;
            nextHardClearSec = 6f + random.nextFloat() * 12f;
            afterglowSeed = random.nextInt();
            lastPhaseName = "";
            startMs = SystemClock.elapsedRealtime();
        }

        private void recreateFbos(int w, int h) {
            deleteFbos();
            GLES20.glGenTextures(2, tex, 0);
            GLES20.glGenFramebuffers(2, fbo, 0);
            for (int i = 0; i < 2; i++) {
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex[i]);
                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
                GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
                GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, w, h, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null);
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo[i]);
                GLES20.glFramebufferTexture2D(GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0, GLES20.GL_TEXTURE_2D, tex[i], 0);
                GLES20.glViewport(0, 0, w, h);
                GLES20.glClearColor(0f, 0f, 0f, 1f);
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
            }
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0);
            readIndex = 0;
            writeIndex = 1;
            fboReady = true;
        }

        private void renderFrame(long nowMs, float dt) {
            if (!fboReady) return;
            ensureCycleState(false);

            // V25：新增“调试循环模式”。
            // debugLoopEnabled 会同时作用于 App 原生预览和真实桌面/锁屏动态壁纸，
            // 按分钟把一次完整过程无限循环，专门用于验证阶段比例和短阶段持续时间是否生效。
            // previewAccelerated 仍只作用于系统/应用预览，不影响正式壁纸。
            boolean useDebugLoop = cfg.debugLoopEnabled;
            boolean useAcceleratedPreview = !useDebugLoop && enginePreview && cfg.previewAccelerated;
            float durationSec = useDebugLoop
                    ? Math.max(60f, cfg.debugCycleMinutes * 60f)
                    : (useAcceleratedPreview ? Math.max(30f, cfg.previewCycleMinutes * 60f) : Math.max(1f, cycleDurationSec));

            float sec;
            if (useDebugLoop) {
                float raw = (SystemClock.elapsedRealtime() - startMs) / 1000f;
                sec = raw % durationSec;
            } else if (useAcceleratedPreview) {
                // 单次预览：只跑一次完整过程，不循环释放/余韵。
                float raw = (SystemClock.elapsedRealtime() - startMs) / 1000f;
                sec = Math.min(raw, Math.max(0.001f, durationSec - 0.001f));
            } else {
                sec = currentCycleElapsedSec();
                if (sec >= cycleDurationSec) {
                    beginNewCycle(System.currentTimeMillis());
                    sec = 0f;
                }
            }

            if (lastVisualSec >= 0f && sec + 0.20f < lastVisualSec) {
                // 只处理真实周期重置或配置变更造成的时间回退；演示模式不再循环。
                nextSpawnSec = 0f;
                nextHardClearSec = 6f + random.nextFloat() * 12f;
                strokes.clear();
                resetSpawnHeat();
                clearFbos();
                releasePulseArmed = true;
                afterglowSeed = random.nextInt();
                releaseSeed = random.nextInt();
                lastPhaseName = "";
            }
            lastVisualSec = sec;
            CyclePlan plan = (useDebugLoop || useAcceleratedPreview) ? previewPlan(durationSec) : storedCyclePlan(durationSec);
            Phase phase = Phase.of(sec, durationSec, cfg, plan);
            if (!phase.name.equals(lastPhaseName)) {
                String previousPhase = lastPhaseName;
                // V34：进入释放时重置释放特效种子，并洗掉前段过多线条，让释放画面像一次干净、强烈的能量爆发。
                if (phase.name.equals("释放")) {
                    releaseSeed = random.nextInt();
                    resetSpawnHeat();
                    clearFbos();
                }
                // 进入余韵时立即清空释放阶段的大形体残影，让气泡层从干净黑/蓝水域中出现。
                if (phase.name.equals("余韵") && cfg.bubbles) {
                    strokes.clear();
                    resetSpawnHeat();
                    clearFbos();
                    afterglowSeed = random.nextInt();
                    nextSpawnSec = sec + 9999f;
                }
                // 余韵结束后也清一次，避免透明泡泡/旧光迹在桌面上留下截图里那种灰黑网状痕迹。
                if (phase.name.equals("分离") && "余韵".equals(previousPhase)) {
                    strokes.clear();
                    resetSpawnHeat();
                    clearFbos();
                    nextSpawnSec = sec + 0.10f;
                }
                lastPhaseName = phase.name;
            }
            float rawLocal = clamp((sec - phase.start) / Math.max(0.001f, phase.end - phase.start), 0f, 1f);
            float local = smooth(rawLocal);
            float release = phase.name.equals("释放") ? (float)Math.sin(local * Math.PI) : 0f;
            float after = phase.name.equals("余韵") ? local : 0f;
            float intensity = clamp(phase.intensity * (0.74f + 0.52f * cfg.intimacy), 0f, 1.30f);
            float tension = clamp(phase.tension * (0.72f + 0.56f * cfg.intimacy), 0f, 1.35f);

            if (!phase.name.equals("释放")) releasePulseArmed = true;
            if (phase.name.equals("释放") && releasePulseArmed) {
                float[] p = pickLeastUsedPoint(false);
                pulseX = p[0] / Math.max(1f, width);
                pulseY = p[1] / Math.max(1f, height);
                releaseSeed = random.nextInt();
                releasePulseArmed = false;
            }

            boolean observedVideoSubjectPhase = !phase.name.equals("释放") && !phase.name.equals("余韵");
            if (observedVideoSubjectPhase) {
                // V47：主体阶段完全改为逐帧程序化视频薄膜，不再继续生成/更新旧 Mystify 光迹。
                // 这样可以根除用户截图中仍然出现的粗白斜带、黄带交叉、巨大灰白扇面和多主体叠加。
                strokes.clear();
            } else {
                if (sec >= nextSpawnSec && !(phase.name.equals("余韵") && cfg.bubbles)) spawnAccordingToPhase(phase, sec);
                updateStrokes(sec, dt, phase, intensity, tension, release);
            }

            // Windows Mystify 的“离开”不是突然清除，也不是对象死亡，而是上一帧缓慢被黑场吞没。
            // 因此这里不再定时 hard clear，只做 FBO 反馈衰减；trail 越高，背影越慢消失。
            // V17：Windows Mystify 的背影是“慢慢被黑场吞没”，不是快速衰亡。
            // 这里提高最低残留，让尾部能在头部继续游走时同步、缓慢、淡淡退场。
            float fade = lerp(0.940f, 0.985f, cfg.trail);
            if (phase.name.equals("余韵") && cfg.bubbles) {
                // V36：气泡不是依靠 FBO 拖尾移动。每帧先清空旧帧，再绘制当前透明泡，
                // 彻底避免截图中那种随运动拉成长筒的重影/残影。
                fade = 0.0f;
            } else if (phase.name.equals("余韵")) {
                fade = Math.min(fade, 0.955f);
            } else if (!phase.name.equals("释放")) {
                // V103：主体阶段继续保留 FBO 残影美感，但要避免旧主体在下一次换位时仍然被重复凸显。
                // 因此改为按“当前笔势周期”动态调低残留：停顿期与换笔前后衰减更快。
                fade = Math.min(fade, subjectPhaseFeedbackFade(sec));
            }
            if (phase.name.equals("释放")) fade = Math.min(fade, lerp(0.780f, 0.900f, cfg.trail));
            if (cfg.powerSave) fade = Math.min(fade, 0.955f);

            // 1) FBO 残影：把上一帧纹理衰减写入新 FBO。
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo[writeIndex]);
            GLES20.glViewport(0, 0, width, height);
            GLES20.glDisable(GLES20.GL_BLEND);
            GLES20.glClearColor(0f, 0f, 0f, 1f);
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
            drawTexture(tex[readIndex], fade);

            // 2) 即时绘制当前随机线条。旧线条历史不由对象保存，只由 FBO 残影留下。
            GLES20.glEnable(GLES20.GL_BLEND);
            GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE);
            if (observedVideoSubjectPhase) {
                drawObservedVideoMembrane(sec, rawLocal, phase, intensity, tension);
            } else if (!(phase.name.equals("余韵") && cfg.bubbles) && !(phase.name.equals("释放") && local > 0.16f)) {
                drawAllStrokes(phase, intensity, tension, release, after);
            }
            if (phase.name.equals("释放")) drawReleaseEruption(rawLocal, release, phase);
            drawAfterglowBubbleAquarium(sec, after, phase);
            GLES20.glDisable(GLES20.GL_BLEND);

            // 3) 输出到真实壁纸 Surface。
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0);
            GLES20.glViewport(0, 0, width, height);
            GLES20.glClearColor(0f, 0f, 0f, 1f);
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
            drawTexture(tex[writeIndex], 1f);

            int tmp = readIndex;
            readIndex = writeIndex;
            writeIndex = tmp;
        }

        private void spawnAccordingToPhase(Phase phase, float sec) {
            decayArtMemory();
            artSpawnIndex++;

            // V43：参考视频的主体不是两片大色带相互穿插，而是黑场中“一片主膜 + 极少量暗回声”。
            // 因此只在主体阶段（分离/吸引/同步/临界）改成单主体生成；释放与余韵继续走下面的旧逻辑。
            boolean videoSubjectPhase = !phase.name.equals("释放") && !phase.name.equals("余韵");
            if (videoSubjectPhase) {
                while (strokes.size() > 0) strokes.remove(0);
                int actor = phase.name.equals("分离") ? 1 : 2;
                StrokeEvent subject = createStroke(phase, random.nextBoolean() ? -1 : 1, false, actor);
                subject.relation = phase.name.equals("临界") ? 0.14f : (phase.name.equals("同步") ? 0.08f : 0.02f);
                strokes.add(subject);

                float base;
                if (phase.name.equals("分离")) base = 20.0f + random.nextFloat() * 26.0f;
                else if (phase.name.equals("吸引")) base = 15.0f + random.nextFloat() * 18.0f;
                else if (phase.name.equals("同步")) base = 10.0f + random.nextFloat() * 14.0f;
                else base = 7.0f + random.nextFloat() * 9.0f;
                float densityScale = lerp(1.40f, 0.78f, cfg.strokeDensity);
                if (cfg.powerSave) densityScale *= 1.35f;
                nextSpawnSec = sec + base * lerp(1.05f, 0.74f, cfg.randomness) * densityScale;
                return;
            }

            // V26：性交意蕴不再只靠“单条光迹”隐喻，而是默认同时保留两个不同主体：
            // A：冷色、较细、较锋利，像主动追寻的轨迹；
            // B：暖色、较柔、点线喷洒更丰富，像被吸引并回应的轨迹。
            // 两者在“分离”阶段远离且互不牵引，在“吸引/同步”阶段逐渐同频，
            // 在“临界/释放”阶段短暂向共同能量场聚拢，余韵后再回到分离。
            int maxStrokes = cfg.powerSave ? 2 : 2;
            if (phase.name.equals("临界") && !cfg.powerSave && cfg.strokeDensity > 0.55f) maxStrokes = 4;
            while (strokes.size() > maxStrokes) strokes.remove(0);

            // V30：扇面网格只作为少数回声出现，不再让整屏偏“细线网状”。
            boolean fanA = random.nextFloat() < phase.fanChance * (0.025f + cfg.randomness * 0.055f);
            boolean fanB = random.nextFloat() < phase.fanChance * (0.045f + cfg.randomness * 0.085f);
            if (phase.name.equals("分离")) { fanA = false; fanB = false; }
            if (phase.name.equals("余韵")) { fanA = false; fanB = false; }

            StrokeEvent a = createStroke(phase, -1, fanA, 1);
            StrokeEvent b = createStroke(phase, 1, fanB, 2);
            tuneActorPairForPhase(a, b, phase);
            strokes.add(a);
            strokes.add(b);

            float base;
            // 两个主体始终可见，但出生间隔仍保持克制，避免画面变成杂乱线团。
            if (phase.name.equals("分离")) base = 14.0f + random.nextFloat() * 26.0f;
            else if (phase.name.equals("吸引")) base = 7.0f + random.nextFloat() * 14.0f;
            else if (phase.name.equals("同步")) base = 4.5f + random.nextFloat() * 10.0f;
            else if (phase.name.equals("临界")) base = 2.0f + random.nextFloat() * 3.8f;
            else if (phase.name.equals("释放")) base = 6.5f + random.nextFloat() * 10.0f;
            else base = 13.0f + random.nextFloat() * 24.0f;
            float densityScale = lerp(1.55f, 0.58f, cfg.strokeDensity);
            if (cfg.powerSave) densityScale *= 1.40f;
            nextSpawnSec = sec + base * lerp(1.08f, 0.68f, cfg.randomness) * densityScale;
        }

        private void tuneActorPairForPhase(StrokeEvent a, StrokeEvent b, Phase phase) {
            a.partner = b;
            b.partner = a;
            if (phase.name.equals("分离")) {
                a.relation = 0f;
                b.relation = 0f;
                a.attractX = width * (0.12f + random.nextFloat() * 0.20f);
                b.attractX = width * (0.68f + random.nextFloat() * 0.20f);
                a.attractY = height * (0.18f + random.nextFloat() * 0.64f);
                b.attractY = height * (0.18f + random.nextFloat() * 0.64f);
                return;
            }
            float commonX = width * (0.32f + random.nextFloat() * 0.36f);
            float commonY = height * (0.26f + random.nextFloat() * 0.48f);
            if (phase.name.equals("吸引")) {
                a.relation = 0.18f;
                b.relation = 0.18f;
                a.attractX = lerp(a.attractX, commonX, 0.42f);
                a.attractY = lerp(a.attractY, commonY, 0.42f);
                b.attractX = lerp(b.attractX, commonX, 0.42f);
                b.attractY = lerp(b.attractY, commonY, 0.42f);
            } else if (phase.name.equals("同步")) {
                a.relation = 0.58f;
                b.relation = 0.58f;
                b.seed = a.seed + 0.18f + random.nextFloat() * 0.26f;
                b.speed = lerp(b.speed, a.speed, 0.72f);
                a.attractX = b.attractX = commonX;
                a.attractY = b.attractY = commonY;
            } else if (phase.name.equals("临界") || phase.name.equals("释放")) {
                a.relation = 0.92f;
                b.relation = 0.92f;
                b.seed = a.seed + 0.06f + random.nextFloat() * 0.12f;
                b.speed = lerp(b.speed, a.speed, 0.86f);
                a.attractX = b.attractX = commonX;
                a.attractY = b.attractY = commonY;
                a.widthScale *= 1.10f;
                b.widthScale *= 1.16f;
            } else { // 余韵
                a.relation = 0.08f;
                b.relation = 0.08f;
                a.attractX = lerp(a.attractX, commonX, 0.18f);
                a.attractY = lerp(a.attractY, commonY, 0.18f);
                b.attractX = lerp(b.attractX, commonX, 0.18f);
                b.attractY = lerp(b.attractY, commonY, 0.18f);
            }
        }


        private void decayArtMemory() {
            for (int i = 0; i < motifCooldown.length; i++) {
                motifCooldown[i] = Math.max(0, motifCooldown[i] - 1);
            }
        }

        private void rememberMotif(int motif) {
            if (motif < 0 || motif >= motifCooldown.length) return;
            motifCooldown[motif] = Math.max(motifCooldown[motif], 4);
            int neighborA = Math.max(0, motif - 1);
            int neighborB = Math.min(motifCooldown.length - 1, motif + 1);
            motifCooldown[neighborA] = Math.max(motifCooldown[neighborA], 1);
            motifCooldown[neighborB] = Math.max(motifCooldown[neighborB], 1);
        }

        private int chooseArtMotif(Phase phase, int actor) {
            float[] w = motifWeightsForPhase(phase.name);
            // V30：优先选择有完整轮廓的大形体，降低“电子纱扇/星座碎链”这类细网比例。
            // 12 liquid pod, 13 wing, 14 blossom, 15 silk sheet, 16 orbit halo, 17 crystal shard.
            if (actor == 1) {
                w[3] *= 1.15f;   // silver blade
                w[10] *= 0.92f;  // origami sheet
                w[13] *= 1.35f;  // wing
                w[15] *= 1.22f;  // silk sheet
                w[17] *= 1.32f;  // crystal shard
                w[2] *= 0.42f;   // less fan lattice
                w[11] *= 0.34f;  // less dot chain
            } else if (actor == 2) {
                w[4] *= 1.05f;   // petal hook
                w[6] *= 0.95f;   // vine
                w[12] *= 1.45f;  // liquid pod
                w[14] *= 1.58f;  // blossom
                w[16] *= 1.26f;  // orbit halo
                w[2] *= 0.35f;
                w[11] *= 0.28f;
            }

            // V29/V30：非周期“天气”。不同天气推动不同雕塑形态，而不是反复刷同一种曲线。
            float t = (SystemClock.elapsedRealtime() - startMs) / 1000f;
            float weatherA = 0.5f + 0.5f * (float)Math.sin(t * 0.0173f + artSpawnIndex * 0.618f);
            float weatherB = 0.5f + 0.5f * (float)Math.sin(t * 0.0117f + artSpawnIndex * 1.4142f + 2.1f);
            float weatherC = 0.5f + 0.5f * (float)Math.sin(t * 0.0079f + artSpawnIndex * 1.7320f + 4.7f);
            w[8] *= 0.66f + weatherB * 0.78f;
            w[9] *= 0.62f + weatherC * 0.92f;
            w[12] *= 0.70f + weatherA * 1.35f;
            w[13] *= 0.72f + weatherB * 1.22f;
            w[14] *= 0.68f + weatherC * 1.38f;
            w[15] *= 0.74f + (1f - weatherA) * 1.20f;
            w[16] *= 0.72f + (1f - weatherB) * 1.26f;
            w[17] *= 0.76f + (1f - weatherC) * 1.18f;
            w[2] *= 0.25f + weatherA * 0.18f;
            w[11] *= 0.20f + weatherB * 0.16f;
            // V33：整体更偏“有形状的生命体/光膜/花瓣/晶体”，减少奇怪细线和网状语言。
            for (int i = 0; i < 12; i++) w[i] *= 0.82f;
            for (int i = 12; i <= 17; i++) w[i] *= 1.28f;

            // V41：只修正“主体阶段”的形体。
            // 之前 V38 只是提高视频母型权重，仍会混入旧银白刃/大灰面，并且 13/15/17 本身会生成贯穿屏幕的白色斜带。
            // 这里在分离/吸引/同步/临界阶段锁定为参考视频主体：单侧折叠膜面 + 宽端裁切 + 弯曲尖端 + 贴面肋纹。
            // 释放阶段和余韵阶段不在这里强改，保持现有释放爆发与余韵气泡逻辑不变。
            if (!phase.name.equals("释放") && !phase.name.equals("余韵")) {
                float bladeBias = phase.name.equals("分离") ? 1.00f
                        : (phase.name.equals("吸引") ? 1.10f
                        : (phase.name.equals("同步") ? 1.18f
                        : (phase.name.equals("临界") ? 1.26f : 1.00f)));
                for (int i = 0; i < w.length; i++) w[i] = 0f;
                // V44：主体阶段锁定为“视频单片卷曲薄膜”。13/17 只作为同一膜面的窄态/尖钩态，避免多形体拼贴和大色带交叉。
                w[13] = phase.name.equals("分离") ? 0.30f * bladeBias : 0.12f * bladeBias;
                w[15] = 1.00f * bladeBias;
                w[17] = phase.name.equals("临界") ? 0.16f * bladeBias : 0.05f * bladeBias;
            } else {
                float bladeBias = phase.name.equals("释放") ? 1.38f : 1.08f;
                w[13] *= 1.95f * bladeBias;
                w[15] *= 2.28f * bladeBias;
                w[17] *= 1.82f * bladeBias;
                w[12] *= 0.54f;
                w[14] *= 0.46f;
                w[16] *= 0.62f;
                w[2] *= 0.22f;
                w[11] *= 0.24f;
            }

            // 反重复冷却：最近出现过的母型降权。雕塑类也参与冷却，防止连续看到同一类大形体。
            for (int i = 0; i < w.length; i++) {
                w[i] *= 1f / (1f + motifCooldown[i] * (isSculpturalMotif(i) ? 0.72f : 0.58f));
                if (cfg.powerSave && (i == 8 || i == 9 || i == 11 || i == 14 || i == 16)) w[i] *= 0.68f;
            }

            int motif = weightedMotif(w);
            rememberMotif(motif);
            return motif;
        }

        private float[] motifWeightsForPhase(String phaseName) {
            // 0 comet arc, 1 veil ribbon, 2 electronic fan, 3 silver blade,
            // 4 petal hook, 5 prism polygon, 6 falling leaf, 7 long bridge,
            // 8 jellyfish tendril, 9 nebula coil, 10 origami sheet, 11 constellation chain,
            // 12 liquid pod, 13 luminous wing, 14 blossom crown, 15 silk banner,
            // 16 orbit halo, 17 crystal shard.
            if (phaseName.equals("分离")) {
                return new float[]{1.08f, 0.74f, 0.06f, 0.98f, 0.20f, 0.34f, 0.82f, 1.02f, 0.38f, 0.30f, 0.52f, 0.18f, 0.62f, 1.05f, 0.28f, 0.96f, 0.52f, 0.92f};
            }
            if (phaseName.equals("吸引")) {
                return new float[]{0.60f, 0.95f, 0.12f, 0.38f, 0.86f, 0.46f, 0.92f, 0.42f, 0.74f, 0.54f, 0.46f, 0.12f, 1.24f, 1.12f, 1.42f, 1.05f, 0.78f, 0.52f};
            }
            if (phaseName.equals("同步")) {
                return new float[]{0.34f, 0.86f, 0.30f, 0.48f, 0.72f, 0.58f, 0.44f, 0.32f, 0.50f, 0.64f, 0.72f, 0.16f, 1.06f, 1.30f, 1.20f, 1.34f, 1.18f, 0.76f};
            }
            if (phaseName.equals("临界")) {
                return new float[]{0.22f, 0.56f, 0.28f, 1.02f, 0.56f, 0.62f, 0.24f, 0.48f, 0.42f, 0.76f, 0.92f, 0.20f, 1.22f, 1.18f, 1.06f, 1.28f, 1.46f, 1.32f};
            }
            if (phaseName.equals("释放")) {
                return new float[]{0.24f, 0.40f, 0.22f, 1.14f, 0.32f, 0.46f, 0.22f, 0.94f, 0.34f, 0.72f, 0.88f, 0.22f, 1.48f, 1.06f, 0.86f, 0.92f, 1.70f, 1.46f};
            }
            return new float[]{0.86f, 0.62f, 0.08f, 0.74f, 0.28f, 0.26f, 0.92f, 0.68f, 0.42f, 0.28f, 0.38f, 0.14f, 0.94f, 0.72f, 0.74f, 0.86f, 0.78f, 0.66f};
        }

        private boolean isSculpturalMotif(int motif) {
            return motif >= 12 && motif <= 17;
        }

        private int weightedMotif(float[] w) {
            float total = 0f;
            for (float v : w) total += Math.max(0f, v);
            if (total <= 0.0001f) return random.nextInt(Math.max(1, w.length));
            float r = random.nextFloat() * total;
            for (int i = 0; i < w.length; i++) {
                r -= Math.max(0f, w[i]);
                if (r <= 0f) return i;
            }
            return w.length - 1;
        }

        private int motifControlCount(int motif) {
            switch (motif) {
                case 2: return 6 + random.nextInt(3);   // fan shell
                case 3: return 3 + random.nextInt(2);   // blade shard
                case 4: return 5 + random.nextInt(2);   // petal hook
                case 5: return 5;                       // prism polygon
                case 6: return 5 + random.nextInt(2);   // leaf/vine
                case 7: return 4 + random.nextInt(2);   // long bridge
                case 8: return 6 + random.nextInt(3);   // jellyfish tendril
                case 9: return 6 + random.nextInt(3);   // nebula coil
                case 10: return 5 + random.nextInt(2);  // origami sheet
                case 11: return 4 + random.nextInt(4);  // constellation chain
                case 12: return 5 + random.nextInt(3);  // liquid pod
                case 13: return 5 + random.nextInt(3);  // luminous wing
                case 14: return 6 + random.nextInt(3);  // blossom crown
                case 15: return 5 + random.nextInt(3);  // silk banner
                case 16: return 5 + random.nextInt(3);  // orbit halo
                case 17: return 4 + random.nextInt(3);  // crystal shard
                default: return 4 + random.nextInt(3);
            }
        }

        private StrokeEvent createStroke(Phase phase, int side, boolean fan, int actor) {
            int motif = chooseArtMotif(phase, actor);
            int count = motifControlCount(motif);
            StrokeEvent s = new StrokeEvent(count);
            s.actor = actor;
            s.motif = motif;
            s.motifStrength = 0.72f + random.nextFloat() * 0.70f;
            s.variant = random.nextInt(100000);
            s.flowA = 0.65f + random.nextFloat() * 1.70f;
            s.flowB = 0.35f + random.nextFloat() * 1.45f;
            s.flowC = random.nextBoolean() ? 1f : -1f;
            s.asymmetry = -1f + random.nextFloat() * 2f;
            // V15：生命周期表示“一笔光迹从起笔到尾部完全滑出”的飞行时间。
            // 不是整条线慢慢死亡；真正的尾部退场由移动窗口 + FBO 慢衰减共同完成。
            s.life = 2.8f + random.nextFloat() * (4.2f + cfg.randomness * 2.8f);
            if (phase.name.equals("分离")) s.life *= 1.25f;
            if (phase.name.equals("吸引")) s.life *= 1.10f;
            if (phase.name.equals("同步")) s.life *= 0.95f;
            if (phase.name.equals("临界")) s.life *= 0.72f;
            if (phase.name.equals("释放")) s.life *= 0.45f;
            // V18：不再允许出现截图中那种“残缺的短小点线”。
            // 一个笔触从可见开始就必须具备足够长度，像 Windows/Ribbons 那种完整的一笔光迹，
            // 而不是小虫子或短残片。
            s.visibleWindow = 0.32f + random.nextFloat() * 0.24f;
            if (phase.name.equals("分离")) s.visibleWindow *= 0.92f;
            if (phase.name.equals("同步")) s.visibleWindow *= 1.10f;
            if (phase.name.equals("临界")) s.visibleWindow *= 1.18f;
            if (phase.name.equals("释放")) s.visibleWindow *= 1.24f;
            s.headLead = 0.06f + random.nextFloat() * 0.13f;
            s.seed = random.nextFloat() * (float)Math.PI * 2f;
            s.widthScale = 0.54f + random.nextFloat() * 0.72f;
            s.speed = Math.min(width, height) * (0.82f + random.nextFloat() * (0.90f + cfg.randomness * 0.55f));
            s.turn = 0.06f + random.nextFloat() * (0.20f + cfg.randomness * 0.18f);
            s.relation = phase.relation;
            s.fan = fan || motif == 2;
            s.fanLines = s.fan ? 4 + random.nextInt(8) : 0;
            s.fanGapPx = Math.min(width, height) * (0.003f + random.nextFloat() * 0.009f);
            int[] colors = palette(cfg.style);
            if (actor == 1) {
                // 主动追寻者：冷色、锋利、较直、点线更克制。
                s.colorA = colors[0];
                s.colorB = random.nextFloat() < 0.62f ? colors[1] : Color.WHITE;
                s.widthScale *= 0.82f;
                s.turn *= 0.68f;
                s.visibleWindow *= 0.94f;
                s.fan = false;
                s.fanLines = 0;
            } else if (actor == 2) {
                // 回应者：暖色、柔和、点线喷洒更丰富。
                s.colorA = colors[2];
                s.colorB = random.nextFloat() < 0.58f ? colors[3] : Color.WHITE;
                s.widthScale *= 1.10f;
                s.turn *= 1.18f;
                s.visibleWindow *= 1.05f;
                if (!phase.name.equals("分离") && random.nextFloat() < 0.035f + cfg.randomness * 0.055f) {
                    s.fan = true;
                    s.fanLines = 2 + random.nextInt(2);
                }
            } else {
                s.colorA = pickColor(colors);
                s.colorB = random.nextFloat() < 0.20f ? Color.WHITE : pickColor(colors);
            }
            boolean v41SubjectPhase = !phase.name.equals("释放") && !phase.name.equals("余韵");
            // V28：不同母型有不同的运动气质，避免“所有线条长得一样”。
            if (s.motif == 2) { // electronic fan / shell
                s.fan = true;
                s.fanLines = Math.max(s.fanLines, 7 + random.nextInt(8));
                s.visibleWindow *= 1.18f;
                s.widthScale *= 0.92f;
                s.turn *= 0.78f;
            } else if (s.motif == 3) { // silver blade
                s.widthScale *= 0.72f;
                s.turn *= 0.48f;
                s.visibleWindow *= 0.92f;
                s.colorA = Color.WHITE;
            } else if (s.motif == 4) { // petal hook
                s.widthScale *= 1.12f;
                s.turn *= 1.35f;
                s.visibleWindow *= 1.10f;
            } else if (s.motif == 5) { // prism polygon
                s.widthScale *= 0.86f;
                s.turn *= 0.58f;
                s.visibleWindow *= 0.96f;
            } else if (s.motif == 6) { // falling leaf / vine
                s.widthScale *= 1.04f;
                s.turn *= 1.16f;
            } else if (s.motif == 7) { // long bridge arc
                s.visibleWindow *= 1.22f;
                s.turn *= 0.62f;
            } else if (s.motif == 8) { // jellyfish tendril / water grass
                s.widthScale *= 0.94f;
                s.turn *= 1.42f;
                s.visibleWindow *= 1.18f;
            } else if (s.motif == 9) { // nebula coil / smoke spiral
                s.widthScale *= 1.06f;
                s.turn *= 1.08f;
                s.visibleWindow *= 1.12f;
            } else if (s.motif == 10) { // origami light sheet
                s.widthScale *= 0.92f;
                s.turn *= 0.74f;
                s.visibleWindow *= 1.08f;
                if (random.nextFloat() < 0.42f) { s.fan = true; s.fanLines = Math.max(s.fanLines, 5 + random.nextInt(5)); }
            } else if (s.motif == 11) { // constellation broken chain
                s.widthScale *= 0.56f;
                s.turn *= 0.86f;
                s.visibleWindow *= 0.86f;
            } else if (s.motif == 12) { // liquid light pod: rounded glowing body
                s.widthScale *= 1.85f;
                s.turn *= 0.62f;
                s.visibleWindow *= 1.22f;
                s.fan = false;
                s.fanLines = 0;
            } else if (s.motif == 13) { // video wing
                if (v41SubjectPhase) {
                    // V44：主体阶段只让宽度服务于边缘/肋线，不再把整条轨迹放大成白色彩带。
                    s.widthScale *= 0.82f;
                    s.turn *= 0.18f;
                    s.visibleWindow = Math.max(s.visibleWindow * 1.18f, 0.56f);
                    s.life *= 1.18f;
                } else {
                    // 释放/余韵保持 V38 既有参数。
                    s.widthScale *= 2.36f;
                    s.turn *= 0.36f;
                    s.visibleWindow *= 1.52f;
                    s.life *= 1.14f;
                }
                s.fan = false;
                s.fanLines = 0;
            } else if (s.motif == 14) { // blossom crown: petal cluster
                s.widthScale *= 1.72f;
                s.turn *= 0.84f;
                s.visibleWindow *= 1.20f;
                s.fan = false;
                s.fanLines = 0;
            } else if (s.motif == 15) { // silk banner / main video subject
                if (v41SubjectPhase) {
                    // V44：主膜面靠自定义 profile 展开，baseWidth 只留给极细折脊。
                    s.widthScale *= 0.90f;
                    s.turn *= 0.18f;
                    s.visibleWindow = Math.max(s.visibleWindow * 1.22f, 0.62f);
                    s.life *= 1.22f;
                } else {
                    // 释放/余韵保持 V38 既有参数。
                    s.widthScale *= 2.78f;
                    s.turn *= 0.38f;
                    s.visibleWindow *= 1.64f;
                    s.life *= 1.18f;
                }
                s.fan = false;
                s.fanLines = 0;
            } else if (s.motif == 16) { // orbit halo: luminous ring / crescent
                s.widthScale *= 1.34f;
                s.turn *= 0.66f;
                s.visibleWindow *= 1.12f;
                s.fan = false;
                s.fanLines = 0;
            } else if (s.motif == 17) { // crystal edge / shard
                if (v41SubjectPhase) {
                    s.widthScale *= 0.62f;
                    s.turn *= 0.15f;
                    s.visibleWindow = Math.max(s.visibleWindow * 1.10f, 0.50f);
                    s.life *= 1.12f;
                } else {
                    // 释放/余韵保持 V38 既有参数。
                    s.widthScale *= 1.84f;
                    s.turn *= 0.30f;
                    s.visibleWindow *= 1.24f;
                    s.life *= 1.08f;
                }
                s.fan = false;
                s.fanLines = 0;
            }

            if (s.motif == 13 || s.motif == 15 || s.motif == 17) {
                if (v41SubjectPhase) {
                    // V43：主体阶段限制在参考视频常见的绿/紫/青色族，移除黄色/橙色宽带。
                    int v = Math.floorMod(s.variant, 6);
                    if (v == 0) { s.colorA = 0xFF20F05A; s.colorB = 0xFF7C3AED; }
                    else if (v == 1) { s.colorA = 0xFF2EE67A; s.colorB = 0xFFB000FF; }
                    else if (v == 2) { s.colorA = 0xFF16D977; s.colorB = 0xFF3EEBFF; }
                    else if (v == 3) { s.colorA = 0xFF7C3AED; s.colorB = 0xFF23F06D; }
                    else if (v == 4) { s.colorA = 0xFF39FF74; s.colorB = 0xFF3EEBFF; }
                    else { s.colorA = 0xFF22C55E; s.colorB = 0xFFA855F7; }
                    s.asymmetry = (strokeHash(s, 17, 1181) < 0.5f ? -1f : 1f) * (0.86f + strokeHash(s, 19, 1187) * 0.42f);
                } else {
                    // 释放/余韵保持 V38 的色相族。
                    int v = Math.floorMod(s.variant, 5);
                    if (v == 0) { s.colorA = 0xFF22C55E; s.colorB = 0xFFA78BFA; }
                    else if (v == 1) { s.colorA = 0xFF7C3AED; s.colorB = 0xFFE5E7EB; }
                    else if (v == 2) { s.colorA = 0xFF34D399; s.colorB = 0xFFECFEFF; }
                    else if (v == 3) { s.colorA = 0xFFC4B5FD; s.colorB = 0xFFFFFFFF; }
                    else { s.colorA = 0xFF4ADE80; s.colorB = 0xFF60A5FA; }
                    s.asymmetry = (strokeHash(s, 17, 1181) < 0.5f ? -1f : 1f) * (0.72f + strokeHash(s, 19, 1187) * 0.52f);
                }
            }

            s.bounds = fullScreenBounds();
            initStrokeFromAnyVisiblePosition(s, side, phase);
            return s;
        }

        private RectF fullScreenBounds() {
            float padX = width * lerp(0.08f, 0.22f, cfg.fullScreenCoverage);
            float padY = height * lerp(0.08f, 0.22f, cfg.fullScreenCoverage);
            return new RectF(-padX, -padY, width + padX, height + padY);
        }

        private void initStrokeFromAnyVisiblePosition(StrokeEvent s, int side, Phase phase) {
            if (initStrokeByArtMotif(s, side, phase)) return;
            // 这一步是 V8 的重点：控制点直接从全屏可见坐标系生成，而不是从中心曲线移动出来。
            // 热区采样保证长期覆盖整块手机屏幕。
            int mode = random.nextInt(100);
            float x0, y0, x1, y1;
            if (mode < 30) {
                float[] p0 = randomEdgePoint(side);
                float[] p1 = pickLeastUsedPoint(false);
                x0 = p0[0]; y0 = p0[1]; x1 = p1[0]; y1 = p1[1];
            } else if (mode < 72) {
                float[] p0 = pickLeastUsedPoint(false);
                float[] p1 = pickLeastUsedPoint(true);
                x0 = p0[0]; y0 = p0[1]; x1 = p1[0]; y1 = p1[1];
                float minDist = Math.min(width, height) * 0.36f;
                int guard = 0;
                while (distance(x0, y0, x1, y1) < minDist && guard++ < 10) {
                    p1 = pickLeastUsedPoint(true);
                    x1 = p1[0]; y1 = p1[1];
                }
            } else {
                float[] p0 = randomCornerOrDiagonalStart();
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                x0 = p0[0]; y0 = p0[1]; x1 = p1[0]; y1 = p1[1];
            }

            markSpawnHeat(x0, y0);
            markSpawnHeat(x1, y1);

            // 以“从某处喷洒/飞掠到另一处”的长势能曲线生成控制点。
            // 不再围绕一个小中心随意弯曲，避免像蚯蚓；每次都是一段有方向、有起笔、有收笔的 Mystify 光迹。
            float angle = (float)Math.atan2(y1 - y0, x1 - x0) + (random.nextFloat() - 0.5f) * (0.12f + cfg.randomness * 0.30f);
            float length = Math.max(Math.min(width, height) * 0.42f, distance(x0, y0, x1, y1));
            float perp = Math.min(width, height) * (0.045f + random.nextFloat() * (0.12f + cfg.randomness * 0.06f));
            float bendSign = random.nextBoolean() ? 1f : -1f;
            float phaseOffset = random.nextFloat() * (float)Math.PI * 2f;
            float coherentV = s.speed * (0.72f + random.nextFloat() * 0.70f);
            for (int i = 0; i < s.count; i++) {
                float u = i / Math.max(1f, (s.count - 1f));
                float baseX = lerp(x0, x1, u);
                float baseY = lerp(y0, y1, u);
                float broadArc = (float)Math.sin(u * Math.PI) * perp * bendSign;
                float fineArc = (float)Math.sin(u * Math.PI * 2f + phaseOffset) * perp * 0.22f;
                float curve = broadArc + fineArc;
                s.x[i] = baseX - (float)Math.sin(angle) * curve;
                s.y[i] = baseY + (float)Math.cos(angle) * curve;
                float sideDrift = (i - (s.count - 1) * 0.5f) / Math.max(1f, (s.count - 1f));
                s.vx[i] = (float)Math.cos(angle) * coherentV - (float)Math.sin(angle) * coherentV * sideDrift * 0.055f;
                s.vy[i] = (float)Math.sin(angle) * coherentV + (float)Math.cos(angle) * coherentV * sideDrift * 0.055f;
                markSpawnHeat(s.x[i], s.y[i]);
            }
            s.attractX = lerp(0f, width, random.nextFloat());
            s.attractY = lerp(0f, height, random.nextFloat());
        }


        private boolean initVideoSilkBladeSubject(StrokeEvent s, int side, int motif, Phase phase) {
            // V44：根据视频逐帧重新抽象主体骨架：不是横竖交叉的宽彩带，也不是居中白脊，
            // 而是一条弯曲折脊牵引的单侧卷曲薄膜。它从黑场局部浮出，宽肩逐渐展开，末端收成细钩/细茎。
            float minDim = Math.max(1f, Math.min(width, height));
            float spanBase = phase.name.equals("分离") ? 0.30f
                    : (phase.name.equals("吸引") ? 0.34f
                    : (phase.name.equals("同步") ? 0.40f
                    : (phase.name.equals("临界") ? 0.46f : 0.36f)));
            float span = minDim * (spanBase + 0.12f * strokeHash(s, 11, 1401));
            if (motif == 13) span *= 0.86f;
            if (motif == 17) span *= 0.76f;

            float safeL = width * 0.14f;
            float safeR = width * 0.86f;
            float safeT = height * 0.18f;
            float safeB = height * 0.82f;

            int pose = Math.floorMod(s.variant, 7);
            float jitter = (strokeHash(s, 17, 1407) - 0.5f) * 0.50f;
            float angle;
            if (phase.name.equals("分离")) {
                angle = (pose % 2 == 0 ? 0.04f : (float)Math.PI - 0.04f) + jitter * 0.62f;       // 细 S 线横向漂移
            } else if (phase.name.equals("吸引")) {
                angle = (pose % 3 == 0 ? 0.22f : (pose % 3 == 1 ? -0.22f : 2.70f)) + jitter * 0.70f;
            } else if (phase.name.equals("同步")) {
                angle = (pose % 2 == 0 ? -0.86f : 2.28f) + jitter * 0.58f;                        // 紫色月牙/卷帘
            } else if (phase.name.equals("临界")) {
                angle = (pose % 2 == 0 ? -1.18f : 2.04f) + jitter * 0.52f;                        // 绿膜+细茎
            } else {
                angle = (pose < 3 ? 0.18f : (pose < 5 ? -0.92f : 2.20f)) + jitter;
            }
            float tx = (float)Math.cos(angle);
            float ty = (float)Math.sin(angle);
            float nx = -ty;
            float ny = tx;
            float sideSign = s.asymmetry == 0f ? (strokeHash(s, 53, 1421) < 0.5f ? -1f : 1f) : (s.asymmetry < 0f ? -1f : 1f);

            // 只让少数宽端被画面裁切；大多数主体保持局部悬浮，避免再次出现贯穿桌面的长白/黄带。
            float cx = lerp(safeL, safeR, strokeHash(s, 23, 1427));
            float cy = lerp(safeT, safeB, strokeHash(s, 29, 1429));
            boolean croppedShoulder = strokeHash(s, 31, 1433) < (phase.name.equals("临界") ? 0.42f : 0.26f);
            float tailX = cx - tx * span * 0.56f - nx * sideSign * span * 0.10f;
            float tailY = cy - ty * span * 0.56f - ny * sideSign * span * 0.10f;
            float tipX = cx + tx * span * 0.44f + nx * sideSign * span * 0.05f;
            float tipY = cy + ty * span * 0.44f + ny * sideSign * span * 0.05f;
            if (croppedShoulder) {
                float edgePad = minDim * (0.03f + 0.07f * strokeHash(s, 37, 1439));
                if (Math.abs(tx) > Math.abs(ty)) tailX = tx > 0f ? -edgePad : width + edgePad;
                else tailY = ty > 0f ? -edgePad : height + edgePad;
                tipX = tailX + tx * span;
                tipY = tailY + ty * span;
            }

            float curveAmp = minDim * (0.060f + 0.092f * strokeHash(s, 41, 1447)) * sideSign;
            if (phase.name.equals("分离")) curveAmp *= 0.74f;
            if (phase.name.equals("临界")) curveAmp *= 1.10f;
            float counter = minDim * (0.018f + 0.040f * strokeHash(s, 43, 1451)) * -sideSign;
            float hookAmp = minDim * (0.050f + 0.068f * strokeHash(s, 47, 1453)) * -sideSign;
            float speed = s.speed * (0.10f + 0.075f * strokeHash(s, 59, 1459));

            for (int i = 0; i < s.count; i++) {
                float u = i / Math.max(1f, s.count - 1f);
                float su = smooth(u);
                float alongX = lerp(tailX, tipX, su);
                float alongY = lerp(tailY, tipY, su);
                float mainBend = (float)Math.sin(su * Math.PI) * curveAmp;
                float sBend = (float)Math.sin(su * Math.PI * 2.0f + s.seed * 0.37f) * counter * (0.25f + 0.75f * (float)Math.sin(su * Math.PI));
                float hook = (float)Math.pow(clamp((su - 0.70f) / 0.30f, 0f, 1f), 1.45f) * hookAmp;
                float shoulderFold = (float)Math.pow(1f - su, 2.35f) * curveAmp * 0.15f;
                float curl = mainBend + sBend + hook - shoulderFold;
                s.x[i] = alongX + nx * curl;
                s.y[i] = alongY + ny * curl;

                float tangentBoost = 0.36f + 0.34f * su;
                float normalDrift = speed * (0.006f + 0.014f * strokeHash(s, 71 + i, 1469)) * sideSign * (1.0f - su);
                s.vx[i] = tx * speed * tangentBoost + nx * normalDrift;
                s.vy[i] = ty * speed * tangentBoost + ny * normalDrift;
                markSpawnHeat(s.x[i], s.y[i]);
            }
            s.attractX = lerp(tailX, tipX, 0.68f) + nx * curveAmp * 0.18f;
            s.attractY = lerp(tailY, tipY, 0.68f) + ny * curveAmp * 0.18f;
            s.bounds = new RectF(-width * 0.22f, -height * 0.22f, width * 1.22f, height * 1.22f);
            return true;
        }


        
private boolean initStrokeByArtMotif(StrokeEvent s, int side, Phase phase) {
            float minDim = Math.max(1f, Math.min(width, height));
            int motif = s.motif;
            if (motif == 1 || motif == 0) return false;
            if (motif == 13 || motif == 15 || motif == 17) return initVideoSilkBladeSubject(s, side, motif, phase);

            if (motif == 2) { // electronic fan / shell: hidden pivot + gradually opening ribs
                float[] pivot = pickLeastUsedPoint(false);
                float base = random.nextFloat() * (float)Math.PI * 2f;
                float sweep = (0.75f + random.nextFloat() * 1.35f) * (random.nextBoolean() ? 1f : -1f);
                float squash = 0.62f + random.nextFloat() * 0.34f;
                float speed = s.speed * (0.36f + random.nextFloat() * 0.35f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float su = smooth(u);
                    float rr = minDim * (0.038f + 0.36f * su) * s.motifStrength;
                    float ang = base + sweep * su;
                    s.x[i] = pivot[0] + (float)Math.cos(ang) * rr;
                    s.y[i] = pivot[1] + (float)Math.sin(ang) * rr * squash;
                    float tangent = ang + (sweep >= 0f ? 1f : -1f) * (float)Math.PI * 0.5f;
                    s.vx[i] = (float)Math.cos(tangent) * speed * (0.45f + u);
                    s.vy[i] = (float)Math.sin(tangent) * speed * squash * (0.45f + u);
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = pivot[0];
                s.attractY = pivot[1];
                return true;
            }

            if (motif == 3) { // silver blade: straight diagonal energy with one sharp crease
                float[] p0 = randomEdgePoint(side);
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                float dx = p1[0] - p0[0];
                float dy = p1[1] - p0[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 1f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float crease = (random.nextFloat() - 0.5f) * minDim * (0.16f + cfg.randomness * 0.16f);
                float speed = s.speed * (0.82f + random.nextFloat() * 0.45f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float blade = (float)Math.sin(Math.PI * u) * crease;
                    s.x[i] = lerp(p0[0], p1[0], u) + nx * blade;
                    s.y[i] = lerp(p0[1], p1[1], u) + ny * blade;
                    s.vx[i] = dx / len * speed + nx * (i - (s.count - 1) * 0.5f) * speed * 0.035f;
                    s.vy[i] = dy / len * speed + ny * (i - (s.count - 1) * 0.5f) * speed * 0.035f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = lerp(p0[0], p1[0], 0.55f);
                s.attractY = lerp(p0[1], p1[1], 0.55f);
                return true;
            }

            if (motif == 4) { // petal hook: vertical stem curling into a flower-like head
                float[] c = pickLeastUsedPoint(false);
                float base = random.nextFloat() * (float)Math.PI * 2f;
                float sweep = (1.18f + random.nextFloat() * 1.64f) * (random.nextBoolean() ? 1f : -1f);
                float speed = s.speed * (0.42f + random.nextFloat() * 0.35f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float rr = minDim * (0.045f + 0.22f * (float)Math.pow(u, 0.72f)) * s.motifStrength;
                    float ang = base + sweep * u * u;
                    float stem = minDim * 0.11f * (0.5f - u);
                    float sx = (float)Math.cos(base + Math.PI * 0.5f) * stem;
                    float sy = (float)Math.sin(base + Math.PI * 0.5f) * stem;
                    s.x[i] = c[0] + sx + (float)Math.cos(ang) * rr;
                    s.y[i] = c[1] + sy + (float)Math.sin(ang) * rr * (0.58f + random.nextFloat() * 0.24f);
                    float tangent = ang + (sweep >= 0f ? 1f : -1f) * (float)Math.PI * 0.5f;
                    s.vx[i] = (float)Math.cos(tangent) * speed * (0.54f + u * 0.35f);
                    s.vy[i] = (float)Math.sin(tangent) * speed * (0.54f + u * 0.35f);
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = c[0];
                s.attractY = c[1];
                return true;
            }

            if (motif == 5) { // prism polygon: diamond/square frame briefly turning in darkness
                float[] c = pickLeastUsedPoint(false);
                float radius = minDim * (0.10f + random.nextFloat() * 0.22f) * s.motifStrength;
                float rot = random.nextFloat() * (float)Math.PI * 2f;
                float[][] corners = new float[][]{
                        {(float)Math.cos(rot) * radius, (float)Math.sin(rot) * radius * 0.72f},
                        {(float)Math.cos(rot + Math.PI * 0.5f) * radius * 0.72f, (float)Math.sin(rot + Math.PI * 0.5f) * radius},
                        {(float)Math.cos(rot + Math.PI) * radius, (float)Math.sin(rot + Math.PI) * radius * 0.72f},
                        {(float)Math.cos(rot + Math.PI * 1.5f) * radius * 0.72f, (float)Math.sin(rot + Math.PI * 1.5f) * radius},
                        {(float)Math.cos(rot) * radius, (float)Math.sin(rot) * radius * 0.72f}
                };
                float drift = s.speed * (0.28f + random.nextFloat() * 0.26f);
                float moveAng = rot + (random.nextBoolean() ? 1f : -1f) * (float)Math.PI * 0.35f;
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    int seg = Math.min(3, (int)(u * 4f));
                    float local = u * 4f - seg;
                    s.x[i] = c[0] + lerp(corners[seg][0], corners[seg + 1][0], local);
                    s.y[i] = c[1] + lerp(corners[seg][1], corners[seg + 1][1], local);
                    s.vx[i] = (float)Math.cos(moveAng) * drift + (float)Math.cos(rot + i) * drift * 0.08f;
                    s.vy[i] = (float)Math.sin(moveAng) * drift + (float)Math.sin(rot + i) * drift * 0.08f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = c[0];
                s.attractY = c[1];
                return true;
            }

            if (motif == 6) { // falling leaf / vine: slender soft S curve
                float[] p0 = pickLeastUsedPoint(false);
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                float dx = p1[0] - p0[0];
                float dy = p1[1] - p0[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 1f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float amp = minDim * (0.055f + random.nextFloat() * 0.11f) * s.motifStrength;
                float speed = s.speed * (0.46f + random.nextFloat() * 0.32f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float leaf = (float)Math.sin(Math.PI * u) * amp + (float)Math.sin(Math.PI * 2f * u) * amp * 0.28f;
                    s.x[i] = lerp(p0[0], p1[0], u) + nx * leaf;
                    s.y[i] = lerp(p0[1], p1[1], u) + ny * leaf;
                    s.vx[i] = dx / len * speed + nx * speed * (0.10f - u * 0.06f);
                    s.vy[i] = dy / len * speed + ny * speed * (0.06f + u * 0.05f);
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = lerp(p0[0], p1[0], 0.60f);
                s.attractY = lerp(p0[1], p1[1], 0.60f);
                return true;
            }

            if (motif == 7) { // long bridge arc: wide magenta/green bow spanning the black field
                float[] p0 = randomCornerOrDiagonalStart();
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                float dx = p1[0] - p0[0];
                float dy = p1[1] - p0[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 1f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float amp = minDim * (0.09f + random.nextFloat() * 0.20f) * (random.nextBoolean() ? 1f : -1f);
                float speed = s.speed * (0.58f + random.nextFloat() * 0.40f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float arc = (float)Math.sin(Math.PI * u) * amp;
                    s.x[i] = lerp(p0[0], p1[0], u) + nx * arc;
                    s.y[i] = lerp(p0[1], p1[1], u) + ny * arc;
                    s.vx[i] = dx / len * speed;
                    s.vy[i] = dy / len * speed;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = lerp(p0[0], p1[0], 0.50f);
                s.attractY = lerp(p0[1], p1[1], 0.50f);
                return true;
            }

            if (motif == 8) { // jellyfish tendril: many-control soft hanging curve with a drifting head
                float[] c = pickLeastUsedPoint(false);
                float base = random.nextFloat() * (float)Math.PI * 2f;
                float sweep = (0.55f + random.nextFloat() * 0.85f) * (random.nextBoolean() ? 1f : -1f);
                float len = minDim * (0.22f + random.nextFloat() * 0.28f) * s.motifStrength;
                float speed = s.speed * (0.34f + random.nextFloat() * 0.26f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float droop = len * (u - 0.5f);
                    float wave = (float)Math.sin(u * Math.PI * 1.7f + s.seed) * minDim * (0.045f + random.nextFloat() * 0.030f);
                    float ang = base + sweep * u;
                    float tx = (float)Math.cos(base) * droop + (float)Math.cos(ang + Math.PI * 0.5f) * wave;
                    float ty = (float)Math.sin(base) * droop + (float)Math.sin(ang + Math.PI * 0.5f) * wave;
                    s.x[i] = c[0] + tx;
                    s.y[i] = c[1] + ty;
                    s.vx[i] = (float)Math.cos(base + 0.22f * s.flowC) * speed + (float)Math.cos(ang) * speed * 0.12f;
                    s.vy[i] = (float)Math.sin(base + 0.22f * s.flowC) * speed + (float)Math.sin(ang) * speed * 0.12f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = c[0];
                s.attractY = c[1];
                return true;
            }

            if (motif == 9) { // nebula coil: open spiral, not a closed circle
                float[] c = pickLeastUsedPoint(false);
                float base = random.nextFloat() * (float)Math.PI * 2f;
                float handed = random.nextBoolean() ? 1f : -1f;
                float radius = minDim * (0.035f + random.nextFloat() * 0.075f);
                float grow = minDim * (0.16f + random.nextFloat() * 0.23f) * s.motifStrength;
                float drift = s.speed * (0.28f + random.nextFloat() * 0.26f);
                float move = base + handed * (float)Math.PI * 0.35f;
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float rr = radius + grow * smooth(u);
                    float a = base + handed * (0.75f + 2.15f * u + 0.30f * (float)Math.sin(u * Math.PI));
                    s.x[i] = c[0] + (float)Math.cos(a) * rr;
                    s.y[i] = c[1] + (float)Math.sin(a) * rr * (0.62f + random.nextFloat() * 0.18f);
                    s.vx[i] = (float)Math.cos(move) * drift + (float)Math.cos(a + Math.PI * 0.5f) * drift * 0.18f;
                    s.vy[i] = (float)Math.sin(move) * drift + (float)Math.sin(a + Math.PI * 0.5f) * drift * 0.18f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = c[0];
                s.attractY = c[1];
                return true;
            }

            if (motif == 10) { // origami sheet: folded luminous paper, two creases
                float[] p0 = randomEdgePoint(side);
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                float dx = p1[0] - p0[0];
                float dy = p1[1] - p0[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 1f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float fold = minDim * (0.060f + random.nextFloat() * 0.16f) * (random.nextBoolean() ? 1f : -1f);
                float speed = s.speed * (0.52f + random.nextFloat() * 0.34f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float kink = ((u < 0.48f ? u / 0.48f : (1f - u) / 0.52f));
                    float zig = (i % 2 == 0 ? -0.45f : 0.45f) * fold * (0.25f + 0.75f * (float)Math.sin(Math.PI * u));
                    s.x[i] = lerp(p0[0], p1[0], u) + nx * (fold * kink + zig);
                    s.y[i] = lerp(p0[1], p1[1], u) + ny * (fold * kink + zig);
                    s.vx[i] = dx / len * speed + nx * speed * (i - (s.count - 1) * 0.5f) * 0.025f;
                    s.vy[i] = dy / len * speed + ny * speed * (i - (s.count - 1) * 0.5f) * 0.025f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = lerp(p0[0], p1[0], 0.52f);
                s.attractY = lerp(p0[1], p1[1], 0.52f);
                return true;
            }

            if (motif == 12) { // liquid pod: slow oval body with inner drift, not a point cloud
                float[] c = pickLeastUsedPoint(false);
                float base = random.nextFloat() * (float)Math.PI * 2f;
                float rx = minDim * (0.11f + random.nextFloat() * 0.18f) * s.motifStrength;
                float ry = rx * (0.52f + random.nextFloat() * 0.36f);
                float drift = s.speed * (0.24f + random.nextFloat() * 0.22f);
                float move = base + (random.nextBoolean() ? 1f : -1f) * (float)Math.PI * 0.28f;
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float a = base + (u - 0.5f) * (1.45f + random.nextFloat() * 1.05f);
                    float breathe = 0.82f + 0.18f * (float)Math.sin(u * Math.PI);
                    s.x[i] = c[0] + (float)Math.cos(a) * rx * breathe;
                    s.y[i] = c[1] + (float)Math.sin(a) * ry * breathe;
                    s.vx[i] = (float)Math.cos(move) * drift + (float)Math.cos(a + Math.PI * 0.5f) * drift * 0.10f;
                    s.vy[i] = (float)Math.sin(move) * drift + (float)Math.sin(a + Math.PI * 0.5f) * drift * 0.10f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = c[0];
                s.attractY = c[1];
                return true;
            }

            if (motif == 13) { // luminous wing: broad asymmetric wing crossing the black field
                float[] p0 = randomEdgePoint(side);
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                float dx = p1[0] - p0[0];
                float dy = p1[1] - p0[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 1f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float amp = minDim * (0.12f + random.nextFloat() * 0.22f) * (random.nextBoolean() ? 1f : -1f);
                float speed = s.speed * (0.42f + random.nextFloat() * 0.30f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float lift = (float)Math.sin(Math.PI * u) * amp;
                    float secondary = (float)Math.sin(Math.PI * 2f * u + s.seed) * amp * 0.16f;
                    s.x[i] = lerp(p0[0], p1[0], u) + nx * (lift + secondary);
                    s.y[i] = lerp(p0[1], p1[1], u) + ny * (lift + secondary);
                    s.vx[i] = dx / len * speed + nx * speed * (0.06f - u * 0.04f);
                    s.vy[i] = dy / len * speed + ny * speed * (0.05f + u * 0.03f);
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = lerp(p0[0], p1[0], 0.48f);
                s.attractY = lerp(p0[1], p1[1], 0.48f);
                return true;
            }

            if (motif == 14) { // blossom crown: looped petal arc around a soft center
                float[] c = pickLeastUsedPoint(false);
                float base = random.nextFloat() * (float)Math.PI * 2f;
                float radius = minDim * (0.08f + random.nextFloat() * 0.15f) * s.motifStrength;
                float petals = 3f + random.nextInt(4);
                float drift = s.speed * (0.25f + random.nextFloat() * 0.24f);
                float move = base + (float)Math.PI * 0.42f;
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float a = base + u * (float)Math.PI * 1.65f;
                    float flower = radius * (0.66f + 0.34f * (float)Math.sin(petals * a));
                    s.x[i] = c[0] + (float)Math.cos(a) * flower;
                    s.y[i] = c[1] + (float)Math.sin(a) * flower * (0.70f + random.nextFloat() * 0.18f);
                    s.vx[i] = (float)Math.cos(move) * drift + (float)Math.cos(a + Math.PI * 0.5f) * drift * 0.12f;
                    s.vy[i] = (float)Math.sin(move) * drift + (float)Math.sin(a + Math.PI * 0.5f) * drift * 0.12f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = c[0];
                s.attractY = c[1];
                return true;
            }

            if (motif == 15) { // silk banner: broad flowing sheet, intentionally not a mesh
                float[] p0 = randomCornerOrDiagonalStart();
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                float dx = p1[0] - p0[0];
                float dy = p1[1] - p0[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 1f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float amp = minDim * (0.06f + random.nextFloat() * 0.12f) * (random.nextBoolean() ? 1f : -1f);
                float speed = s.speed * (0.34f + random.nextFloat() * 0.28f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float wave = (float)Math.sin(Math.PI * u) * amp + (float)Math.sin(Math.PI * 3f * u + s.seed) * amp * 0.20f;
                    s.x[i] = lerp(p0[0], p1[0], u) + nx * wave;
                    s.y[i] = lerp(p0[1], p1[1], u) + ny * wave;
                    s.vx[i] = dx / len * speed + nx * speed * 0.035f * (0.5f - u);
                    s.vy[i] = dy / len * speed + ny * speed * 0.035f * (0.5f - u);
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = lerp(p0[0], p1[0], 0.52f);
                s.attractY = lerp(p0[1], p1[1], 0.52f);
                return true;
            }

            if (motif == 16) { // orbit halo: crescent/ring body, not random dots
                float[] c = pickLeastUsedPoint(false);
                float base = random.nextFloat() * (float)Math.PI * 2f;
                float sweep = (1.55f + random.nextFloat() * 1.25f) * (random.nextBoolean() ? 1f : -1f);
                float rx = minDim * (0.13f + random.nextFloat() * 0.20f) * s.motifStrength;
                float ry = rx * (0.48f + random.nextFloat() * 0.38f);
                float drift = s.speed * (0.22f + random.nextFloat() * 0.20f);
                float move = base + (random.nextBoolean() ? 1f : -1f) * (float)Math.PI * 0.30f;
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float a = base + sweep * u;
                    s.x[i] = c[0] + (float)Math.cos(a) * rx;
                    s.y[i] = c[1] + (float)Math.sin(a) * ry;
                    s.vx[i] = (float)Math.cos(move) * drift + (float)Math.cos(a + Math.PI * 0.5f) * drift * 0.08f;
                    s.vy[i] = (float)Math.sin(move) * drift + (float)Math.sin(a + Math.PI * 0.5f) * drift * 0.08f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = c[0];
                s.attractY = c[1];
                return true;
            }

            if (motif == 17) { // crystal shard: moving faceted luminous plate
                float[] p0 = randomEdgePoint(side);
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                float dx = p1[0] - p0[0];
                float dy = p1[1] - p0[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 1f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float speed = s.speed * (0.58f + random.nextFloat() * 0.34f);
                float shard = minDim * (0.09f + random.nextFloat() * 0.16f) * (random.nextBoolean() ? 1f : -1f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float angular = (i % 2 == 0 ? -0.55f : 0.70f) * shard * (0.35f + 0.65f * (float)Math.sin(Math.PI * u));
                    s.x[i] = lerp(p0[0], p1[0], u) + nx * angular;
                    s.y[i] = lerp(p0[1], p1[1], u) + ny * angular;
                    s.vx[i] = dx / len * speed + nx * speed * (i - (s.count - 1) * 0.5f) * 0.030f;
                    s.vy[i] = dy / len * speed + ny * speed * (i - (s.count - 1) * 0.5f) * 0.030f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = lerp(p0[0], p1[0], 0.50f);
                s.attractY = lerp(p0[1], p1[1], 0.50f);
                return true;
            }

            if (motif == 11) { // constellation chain: sparse angular path with glowing nodes
                float[] p0 = pickLeastUsedPoint(false);
                float[] p1 = randomOppositeLongPoint(p0[0], p0[1]);
                float dx = p1[0] - p0[0];
                float dy = p1[1] - p0[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 1f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float speed = s.speed * (0.45f + random.nextFloat() * 0.34f);
                for (int i = 0; i < s.count; i++) {
                    float u = i / Math.max(1f, s.count - 1f);
                    float step = (random.nextFloat() - 0.5f) * minDim * (0.07f + cfg.randomness * 0.06f);
                    s.x[i] = lerp(p0[0], p1[0], u) + nx * step;
                    s.y[i] = lerp(p0[1], p1[1], u) + ny * step;
                    s.vx[i] = dx / len * speed + nx * speed * (random.nextFloat() - 0.5f) * 0.08f;
                    s.vy[i] = dy / len * speed + ny * speed * (random.nextFloat() - 0.5f) * 0.08f;
                    markSpawnHeat(s.x[i], s.y[i]);
                }
                s.attractX = lerp(p0[0], p1[0], 0.50f);
                s.attractY = lerp(p0[1], p1[1], 0.50f);
                return true;
            }
            return false;
        }

        private float[] randomEdgePoint(int side) {
            int edge = random.nextInt(4);
            if (side < 0) edge = random.nextBoolean() ? 0 : 2;
            if (side > 0) edge = random.nextBoolean() ? 1 : 3;
            float oX = width * (0.02f + random.nextFloat() * 0.18f);
            float oY = height * (0.02f + random.nextFloat() * 0.18f);
            switch (edge) {
                case 0: return new float[]{-oX, random.nextFloat() * height};
                case 1: return new float[]{width + oX, random.nextFloat() * height};
                case 2: return new float[]{random.nextFloat() * width, -oY};
                default: return new float[]{random.nextFloat() * width, height + oY};
            }
        }

        private float[] randomCornerOrDiagonalStart() {
            float oX = width * (0.04f + random.nextFloat() * 0.20f);
            float oY = height * (0.04f + random.nextFloat() * 0.20f);
            switch (random.nextInt(4)) {
                case 0: return new float[]{-oX, -oY};
                case 1: return new float[]{width + oX, -oY};
                case 2: return new float[]{width + oX, height + oY};
                default: return new float[]{-oX, height + oY};
            }
        }

        private float[] randomOppositeLongPoint(float x0, float y0) {
            float x = x0 < width * 0.5f ? width * (0.55f + random.nextFloat() * 0.65f) : -width * (0.05f + random.nextFloat() * 0.55f);
            float y = y0 < height * 0.5f ? height * (0.48f + random.nextFloat() * 0.72f) : -height * (0.04f + random.nextFloat() * 0.60f);
            return new float[]{x, y};
        }

        private float[] pickLeastUsedPoint(boolean farPreference) {
            // V29：热区采样 + 黄金比例低差异采样混合。热区避免局部重复，黄金序列避免
            // 伪随机长期形成可见簇团，使出生点更像“永远换位置的星图”。
            int best = 0;
            int bestScore = Integer.MAX_VALUE;
            int samples = 10 + random.nextInt(12);
            for (int i = 0; i < samples; i++) {
                int idx = random.nextInt(GRID_COLS * GRID_ROWS);
                int score = spawnHeat[idx] + random.nextInt(4);
                if (score < bestScore) { bestScore = score; best = idx; }
            }
            int col = best % GRID_COLS;
            int row = best / GRID_COLS;
            float cw = width / (float)GRID_COLS;
            float ch = height / (float)GRID_ROWS;
            float heatX = col * cw + random.nextFloat() * cw;
            float heatY = row * ch + random.nextFloat() * ch;

            float phi = 0.61803398875f;
            float psi = 0.754877666f;
            float gx = fract(0.13f + (artSpawnIndex + spawnCounter * 0.37f) * phi + random.nextFloat() * 0.037f);
            float gy = fract(0.71f + (artSpawnIndex + spawnCounter * 0.41f) * psi + random.nextFloat() * 0.037f);
            float goldX = lerp(-width * 0.06f, width * 1.06f, gx);
            float goldY = lerp(-height * 0.06f, height * 1.06f, gy);

            float mix = 0.38f + random.nextFloat() * 0.28f;
            float x = lerp(heatX, goldX, mix);
            float y = lerp(heatY, goldY, mix);
            if (farPreference && random.nextFloat() < 0.40f) {
                x = width - x + (random.nextFloat() - 0.5f) * cw;
                y = height - y + (random.nextFloat() - 0.5f) * ch;
            }
            x = clamp(x, -width * 0.10f, width * 1.10f);
            y = clamp(y, -height * 0.10f, height * 1.10f);
            markSpawnHeat(x, y);
            return new float[]{x, y};
        }

        private void markSpawnHeat(float x, float y) {
            int col = clampInt((int)(clamp(x, 0f, Math.max(1, width - 1)) / Math.max(1f, width) * GRID_COLS), 0, GRID_COLS - 1);
            int row = clampInt((int)(clamp(y, 0f, Math.max(1, height - 1)) / Math.max(1f, height) * GRID_ROWS), 0, GRID_ROWS - 1);
            int idx = row * GRID_COLS + col;
            spawnHeat[idx] = Math.min(100000, spawnHeat[idx] + 4);
            spawnCounter++;
            if (spawnCounter % 36 == 0) {
                for (int i = 0; i < spawnHeat.length; i++) spawnHeat[i] = Math.max(0, spawnHeat[i] - 1);
            }
        }

        private void resetSpawnHeat() {
            for (int i = 0; i < spawnHeat.length; i++) spawnHeat[i] = 0;
            spawnCounter = 0;
        }

        private void updateStrokes(float sec, float dt, Phase phase, float intensity, float tension, float release) {
            Iterator<StrokeEvent> it = strokes.iterator();
            while (it.hasNext()) {
                StrokeEvent s = it.next();
                s.age += dt;
                if (s.age > s.life) {
                    it.remove();
                    continue;
                }
                updateStroke(s, sec, dt, phase, intensity, tension, release);
            }
        }

        private void updateStroke(StrokeEvent s, float sec, float dt, Phase phase, float intensity, float tension, float release) {
            float relationPull = s.relation * (0.00018f + 0.00036f * cfg.intimacy) * (0.5f + tension);
            if (phase.name.equals("分离")) relationPull = 0f;
            if (phase.name.equals("吸引")) relationPull *= 0.22f;
            if (phase.name.equals("临界")) relationPull *= 1.55f;

            s.attractX += Math.sin(sec * (0.024f + s.turn * 0.009f) + s.seed) * width * 0.012f * dt;
            s.attractY += Math.cos(sec * (0.021f + s.turn * 0.008f) + s.seed) * height * 0.012f * dt;
            s.attractX = clamp(s.attractX, -width * 0.14f, width * 1.14f);
            s.attractY = clamp(s.attractY, -height * 0.14f, height * 1.14f);

            for (int i = 0; i < s.count; i++) {
                float wobble = (float)Math.sin(sec * (0.8f + s.turn * s.flowA) + s.seed + i * (1.05f + 0.18f * s.flowB));
                float wobble2 = (float)Math.cos(sec * (0.72f + s.turn * 0.76f * s.flowB) + s.seed * 1.37f + i * 1.67f);
                float eddy = (float)Math.sin(sec * (0.19f + 0.031f * s.flowA) + s.seed * 2.31f + i * 2.414f);
                // V29：非周期小流场。控制点仍保持整体势能，但每一类母型拥有不同“呼吸”，
                // 避免长期播放时所有线都像同一条曲线换皮。
                float motifFlow = isSculpturalMotif(s.motif) ? 0.56f : ((s.motif == 8 || s.motif == 9) ? 1.22f : (s.motif == 3 || s.motif == 10 ? 0.72f : 1.0f));
                s.vx[i] += (wobble + eddy * 0.42f * s.flowC) * s.speed * s.turn * motifFlow * (0.030f + cfg.randomness * 0.052f) * dt;
                s.vy[i] += (wobble2 - eddy * 0.36f * s.flowC) * s.speed * s.turn * motifFlow * (0.030f + cfg.randomness * 0.052f) * dt;
                s.vx[i] += (s.attractX - s.x[i]) * relationPull * 60f * dt;
                s.vy[i] += (s.attractY - s.y[i]) * relationPull * 60f * dt;
                if (release > 0f) {
                    s.vx[i] += (s.attractX - s.x[i]) * release * 0.016f;
                    s.vy[i] += (s.attractY - s.y[i]) * release * 0.016f;
                }
                s.x[i] += s.vx[i] * dt;
                s.y[i] += s.vy[i] * dt;
                s.vx[i] *= 0.998f;
                s.vy[i] *= 0.998f;
                bounce(s, i);
            }
        }

        private void bounce(StrokeEvent s, int i) {
            RectF b = s.bounds;
            if (s.x[i] < b.left) { s.x[i] = b.left; s.vx[i] = Math.abs(s.vx[i]) * (0.82f + random.nextFloat()*0.22f); }
            if (s.x[i] > b.right) { s.x[i] = b.right; s.vx[i] = -Math.abs(s.vx[i]) * (0.82f + random.nextFloat()*0.22f); }
            if (s.y[i] < b.top) { s.y[i] = b.top; s.vy[i] = Math.abs(s.vy[i]) * (0.82f + random.nextFloat()*0.22f); }
            if (s.y[i] > b.bottom) { s.y[i] = b.bottom; s.vy[i] = -Math.abs(s.vy[i]) * (0.82f + random.nextFloat()*0.22f); }
        }

        private void drawAllStrokes(Phase phase, float intensity, float tension, float release, float after) {
            for (int i = 0; i < strokes.size(); i++) {
                StrokeEvent s = strokes.get(i);
                drawStroke(s, phase, intensity, tension, release, after);
            }
        }

        private void drawStroke(StrokeEvent s, Phase phase, float intensity, float tension, float release, float after) {
            // V17：真正做“头部游走显现 + 尾部同步缓慢消失”。
            // 不再只画当前一段，也不让整条笔触整体衰老；而是把同一条光迹按时间切成多层。
            // 每层都是过去某个瞬间的可见窗口：越靠近头部越亮，越靠尾部越淡。
            // FBO 再继续保留更旧的尾迹，形成 Windows Mystify 那种“后会有期”的淡出背影。
            float progress = clamp(s.age / Math.max(0.001f, s.life), 0f, 1f);
            float born = smooth(Math.min(1f, s.age / Math.max(0.001f, s.life * 0.08f)));
            if (born <= 0.015f) return;

            ArrayList<float[]> all = sampleStroke(s);
            if (all.size() < 2) return;

            int ca = s.colorA;
            int cb = s.colorB;
            float baseWidth = lerp(0.52f, 3.20f, cfg.ribbonWidth) * s.widthScale * (0.64f + intensity * 0.58f + release * 0.32f);
            float[] c1 = color4(ca, 1f);
            float[] c2 = color4(cb, 1f);
            float[] mix = new float[]{(c1[0]+c2[0])*0.5f, (c1[1]+c2[1])*0.5f, (c1[2]+c2[2])*0.5f, 1f};

            // 过去的窗口层数。trail 越长，尾巴越柔和、越慢退场。
            int layers = cfg.powerSave ? 7 : (10 + (int)(cfg.trail * 18f));
            float step = lerp(0.018f, 0.010f, cfg.trail);
            for (int layer = layers; layer >= 0; layer--) {
                float p = progress - layer * step;
                if (p <= -0.08f || p >= 1.18f) continue;
                ArrayList<float[]> pts = visibleSegmentAt(all, s, p);
                if (pts.size() < 2) continue;

                float depth = layer / Math.max(1f, (float)layers);
                float afterStroke = phase.name.equals("余韵") && cfg.bubbles
                        ? (0.12f * (1f - 0.42f * after))
                        : (1f - after * 0.55f);
                float layerAlpha = born * (float)Math.pow(1f - depth, 2.15f) * afterStroke;
                if (layer == 0) layerAlpha *= 1.14f;
                if (layerAlpha <= 0.006f) continue;

                drawStrokeLayer(s, pts, phase, baseWidth, mix, layerAlpha, intensity, tension, release, layer == 0);
            }
        }

        private void drawStrokeLayer(StrokeEvent s, ArrayList<float[]> pts, Phase phase, float baseWidth,
                                     float[] mix, float alpha, float intensity, float tension, float release, boolean headLayer) {
            if (pts.size() < 2 || alpha <= 0.004f) return;
            boolean sculptural = isSculpturalMotif(s.motif);
            if (s.fan && headLayer && (s.motif == 2 || s.motif == 5)) {
                float nx = (float)Math.cos(s.seed + Math.PI / 2f);
                float ny = (float)Math.sin(s.seed + Math.PI / 2f);
                for (int k = s.fanLines; k >= 1; k--) {
                    float off = (k - s.fanLines * 0.5f) * s.fanGapPx * (0.70f + intensity);
                    drawTaperedStrip(offsetPoints(pts, nx * off, ny * off), baseWidth * 0.16f, mix[0], mix[1], mix[2], alpha * (0.010f + intensity * 0.018f));
                }
            }

            // V30：雕塑形态优先以“面/体/片/环”出现；纤维与点线只保留给非雕塑轨迹。
            if (!sculptural) {
                drawFiberVeil(s, pts, baseWidth, mix[0], mix[1], mix[2], alpha, intensity, tension, release, headLayer);
            }
            // 扇形光网降级为少数专属母型，不再每条线都展开网状肋纹。
            if ((s.motif == 2 && (headLayer || s.fan)) || (s.motif == 5 && headLayer && tension > 0.38f)) {
                drawMystifyFanLattice(s, pts, phase, baseWidth, mix[0], mix[1], mix[2], alpha * 0.82f, intensity, tension, release);
            }
            drawArtMotifAccent(s, pts, phase, baseWidth, mix[0], mix[1], mix[2], alpha, intensity, tension, release, headLayer);

            float actorFace = s.actor == 1 ? 0.86f : (s.actor == 2 ? 1.14f : 1.0f);
            float actorLine = s.actor == 1 ? 0.92f : (s.actor == 2 ? 1.08f : 1.0f);
            if (sculptural) {
                if (s.motif == 13 || s.motif == 15 || s.motif == 17) {
                    // V43：主体面已由单侧折叠膜面绘制；这里只保留极暗骨架，不再补彩色粗带。
                    drawTaperedStrip(pts, Math.max(0.08f, baseWidth * actorLine * 0.010f), mix[0], mix[1], mix[2], alpha * (0.006f + intensity * 0.003f));
                } else {
                    drawTaperedStrip(pts, baseWidth * actorFace * (10.5f + tension * 2.2f), mix[0], mix[1], mix[2], alpha * (0.020f + intensity * 0.026f + release * 0.034f));
                    drawTaperedStrip(pts, baseWidth * actorLine * (1.10f + tension * 0.22f), mix[0], mix[1], mix[2], alpha * (0.105f + intensity * 0.075f + release * 0.050f));
                }
            } else {
                // 面：宽而极淡，构成参考图里“喷洒在黑纸上”的半透明羽化面。
                drawTaperedStrip(pts, baseWidth * actorFace * (6.2f + tension * 1.4f), mix[0], mix[1], mix[2], alpha * (0.008f + intensity * 0.015f + release * 0.024f));
                // 线：主光带，仍然克制，避免蚯蚓感。
                drawTaperedStrip(pts, baseWidth * actorLine * (1.95f + tension * 0.42f), mix[0], mix[1], mix[2], alpha * (0.040f + intensity * 0.048f + release * 0.034f));
                drawTaperedStrip(pts, baseWidth * actorLine * (0.64f + tension * 0.12f), mix[0], mix[1], mix[2], alpha * (0.17f + intensity * 0.12f + release * 0.060f));
            }
            if (headLayer && !sculptural && s.motif != 11) drawActorHeadCluster(s, pts, baseWidth, mix[0], mix[1], mix[2], alpha, intensity, tension, release);

            // 点线喷洒只作为少量纹理；雕塑类、扇面和星座链不再继续喷点，避免“网状/散点”主导。
            if (!sculptural && s.motif != 2 && s.motif != 11 && (headLayer || alpha > 0.105f)) {
                drawPointLineSpray(s, pts, phase, baseWidth, mix[0], mix[1], mix[2], alpha * 0.58f, intensity, tension, release);
            }
            // 核心亮线：视频主体只保留几乎不可见的折脊暗示；真正的亮尖已在 drawVideoSilkBladeSubject 末端局部绘制。
            if (s.motif == 13 || s.motif == 15 || s.motif == 17) {
                drawTaperedStrip(pts, Math.max(0.08f, baseWidth * 0.004f), 0.62f, 1.00f, 0.86f, alpha * (0.004f + intensity * 0.002f));
            } else {
                drawTaperedStrip(pts, Math.max(0.30f, baseWidth * (sculptural ? 0.050f : 0.075f)), 1f, 1f, 1f, alpha * (sculptural ? 0.24f : 0.34f + intensity * 0.17f));
            }
        }

        private void drawMystifyFanLattice(StrokeEvent s, ArrayList<float[]> pts, Phase phase, float baseWidth,
                                        float r, float g, float b, float alpha, float intensity,
                                        float tension, float release) {
            if (pts.size() < 5 || alpha <= 0.004f) return;
            boolean motifFan = s.motif == 2 || s.motif == 5 || s.motif == 10;
            boolean phaseAllows = phase.name.equals("同步") || phase.name.equals("临界") || phase.name.equals("释放") || motifFan;
            float chance = (s.fan || motifFan ? 1.0f : 0.10f + cfg.randomness * 0.18f + tension * 0.18f);
            if (!phaseAllows && !s.fan) return;
            if (!s.fan && !motifFan && strokeHash(s, 0, 881) > chance) return;

            float[] first = pts.get(0);
            float[] last = pts.get(pts.size() - 1);
            float dx = last[0] - first[0];
            float dy = last[1] - first[1];
            float len = (float)Math.sqrt(dx * dx + dy * dy);
            if (len < 0.001f) return;
            float tx = dx / len;
            float ty = dy / len;
            float nx = -ty;
            float ny = tx;

            int ribs = s.fan ? Math.max(5, s.fanLines + 4) : 5 + (int)(cfg.randomness * 7f + tension * 4f);
            if (phase.name.equals("临界")) ribs += 3;
            if (phase.name.equals("释放")) ribs += 1;
            ribs = Math.min(18, Math.max(4, ribs));
            float spread = baseWidth * (5.8f + cfg.randomness * 4.8f + tension * 5.2f + release * 4.2f);
            float originBias = strokeHash(s, 1, 883) < 0.5f ? 0f : 1f;
            for (int j = 0; j < ribs; j++) {
                float jj = ribs == 1 ? 0f : (j / (float)(ribs - 1));
                float centered = (jj - 0.5f) * 2f;
                float hash = strokeHash(s, j, 887);
                float off = centered * spread * (0.55f + hash * 0.55f);
                float phaseShift = (strokeHash(s, j, 889) - 0.5f) * baseWidth * (1.2f + tension);
                ArrayList<float[]> rib = new ArrayList<>(pts.size());
                for (int i = 0; i < pts.size(); i++) {
                    float u = i / Math.max(1f, pts.size() - 1f);
                    float fanGrow = originBias < 0.5f ? smooth(u) : smooth(1f - u);
                    float feather = (float)Math.sin(Math.PI * clamp(u, 0f, 1f));
                    float shimmer = (float)Math.sin(u * Math.PI * 2.0f + s.seed * 1.7f + j * 0.41f)
                            * baseWidth * (0.35f + tension * 0.25f) * feather;
                    float[] p = pts.get(i);
                    rib.add(new float[]{
                            p[0] + nx * (off * fanGrow + shimmer) + tx * phaseShift * feather,
                            p[1] + ny * (off * fanGrow + shimmer) + ty * phaseShift * feather
                    });
                }
                float ribWidth = Math.max(0.22f, baseWidth * (0.040f + strokeHash(s, j, 891) * 0.060f));
                float ribAlpha = alpha * (0.020f + intensity * 0.026f + release * 0.030f) * (0.55f + hash * 0.70f);
                drawTaperedStrip(rib, ribWidth, r, g, b, ribAlpha);
            }

            // 扇面内增加极淡的横向折线，形成“电子纱/贝壳肋纹”的网感。
            int cross = Math.min(6, Math.max(2, ribs / 3));
            for (int k = 1; k <= cross; k++) {
                float u = k / (float)(cross + 1);
                int idx = clampInt((int)(u * (pts.size() - 1)), 1, pts.size() - 2);
                float[] p = pts.get(idx);
                float span = spread * (0.22f + 0.52f * (originBias < 0.5f ? smooth(u) : smooth(1f - u)));
                ArrayList<float[]> crossPts = new ArrayList<>(2);
                crossPts.add(new float[]{p[0] - nx * span, p[1] - ny * span});
                crossPts.add(new float[]{p[0] + nx * span, p[1] + ny * span});
                drawTaperedStrip(crossPts, Math.max(0.18f, baseWidth * 0.025f), r, g, b,
                        alpha * (0.008f + intensity * 0.014f + release * 0.012f));
            }
        }


        private void drawAsymmetricRibbon(ArrayList<float[]> pts, float leftMax, float rightMax,
                                           float r, float g, float b, float a, float power) {
            if (pts.size() < 2 || a <= 0.001f) return;
            int n = pts.size();
            float[] verts = new float[n * 2 * 2];
            int vi = 0;
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float profile = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), power);
                float[] prev = pts.get(Math.max(0, i - 1));
                float[] next = pts.get(Math.min(n - 1, i + 1));
                float dx = next[0] - prev[0];
                float dy = next[1] - prev[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float x = pts.get(i)[0];
                float y = pts.get(i)[1];
                putNdc(verts, vi, x + nx * leftMax * profile, y + ny * leftMax * profile); vi += 2;
                putNdc(verts, vi, x - nx * rightMax * profile, y - ny * rightMax * profile); vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_STRIP, r, g, b, a);
        }


        private void drawRuledSurface(ArrayList<float[]> inner, ArrayList<float[]> outer,
                                      float r, float g, float b, float a) {
            if (inner.size() < 2 || outer.size() < 2 || a <= 0.001f) return;
            int n = Math.min(inner.size(), outer.size());
            float[] verts = new float[n * 2 * 2];
            int vi = 0;
            for (int i = 0; i < n; i++) {
                float[] p0 = inner.get(i);
                float[] p1 = outer.get(i);
                putNdc(verts, vi, p0[0], p0[1]); vi += 2;
                putNdc(verts, vi, p1[0], p1[1]); vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_STRIP, r, g, b, a);
        }

        private void drawEllipse(float cx, float cy, float rx, float ry, float rot, float r, float g, float b, float a, int segments) {
            if (a <= 0f || rx <= 0f || ry <= 0f) return;
            float[] verts = new float[(segments + 2) * 2];
            putNdc(verts, 0, cx, cy);
            float co = (float)Math.cos(rot);
            float si = (float)Math.sin(rot);
            int vi = 2;
            for (int i = 0; i <= segments; i++) {
                float ang = i / (float)segments * (float)Math.PI * 2f;
                float x = (float)Math.cos(ang) * rx;
                float y = (float)Math.sin(ang) * ry;
                putNdc(verts, vi, cx + x * co - y * si, cy + x * si + y * co);
                vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_FAN, r, g, b, a);
        }

        private void drawArcStrip(float cx, float cy, float radius, float widthPx, float startAng, float sweep,
                                  float r, float g, float b, float a, int segments) {
            if (a <= 0f || radius <= 0f || widthPx <= 0f || segments < 2) return;
            float[] verts = new float[(segments + 1) * 2 * 2];
            int vi = 0;
            for (int i = 0; i <= segments; i++) {
                float u = i / (float)segments;
                float ang = startAng + sweep * u;
                float co = (float)Math.cos(ang);
                float si = (float)Math.sin(ang);
                float fade = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.35f);
                float outer = radius + widthPx * (0.35f + 0.65f * fade);
                float inner = Math.max(0f, radius - widthPx * (0.35f + 0.65f * fade));
                putNdc(verts, vi, cx + co * outer, cy + si * outer); vi += 2;
                putNdc(verts, vi, cx + co * inner, cy + si * inner); vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_STRIP, r, g, b, a);
        }

        private void drawFilledPolygon(ArrayList<float[]> poly, float r, float g, float b, float a) {
            if (poly.size() < 3 || a <= 0.001f) return;
            float[] verts = new float[poly.size() * 2];
            int vi = 0;
            for (int i = 0; i < poly.size(); i++) {
                float[] p = poly.get(i);
                putNdc(verts, vi, p[0], p[1]);
                vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_FAN, r, g, b, a);
        }



        private void drawObservedVideoMembrane(float sec, float local, Phase phase, float intensity, float tension) {
            // V89：把主体阶段从“每帧重绘一个已经存在的主体”改为“单支光笔正在持续作画”。
            // 一段手势先像笔在纸上画出长线，随后终点接起点连续画出弧线、环、扇骨、丝膜、折线等形体；
            // 已经画过的痕迹不再被反复重绘，只交给 FBO 残影逐渐消失，因此肉眼能看到“画出 → 延展 → 淡去”。
            drawContinuousPenDrawingSubject(sec, local, phase, intensity, tension);
        }

        private float continuousPenBaseDrawForFade() {
            // V108：把一次“创作”拉长成连续过程，避免几秒一次随机跳位造成“东一下西一下”。
            return lerp(11.20f, 7.60f, clamp(cfg.randomness, 0f, 1f)) * (cfg.powerSave ? 1.08f : 1.0f);
        }

        private float continuousPenBasePauseForFade() {
            // V108：几乎取消停顿，旧痕只靠 FBO 退去，不再做完成态展示。
            return lerp(0.12f, 0.00f, clamp(cfg.randomness, 0f, 1f));
        }

        private float subjectPhaseFeedbackFade(float drawSec) {
            // V173：完全重写 fade 曲线，支持"从无到有"的历史积累。
            //
            // 原版 fade 最高 0.875（@60fps → 1秒后历史仅剩3%），历史根本来不及积累。
            // 新版按 raw 进度分三段：
            //   积累期（0→0.70）：fade=0.972~0.978，历史缓慢积累，形成从无到有的轨迹面
            //   鼎盛期（0.70→0.82）：fade=0.960~0.972，历史层最丰富，形体最完整
            //   消散期（0.82→1.00）：fade=0.820→0.650，旧痕迹快速消散，形成"先画先消失"
            //   停顿期（slot>drawBudget）：fade=0.550，快速清场，为下一个 gesture 准备
            float baseDraw  = continuousPenBaseDrawForFade();
            float basePause = continuousPenBasePauseForFade();
            float period    = Math.max(3.0f, baseDraw + basePause);
            float liveSec   = drawSec + 0.86f;
            int   gesture   = Math.max(0, (int)Math.floor(liveSec / period));
            float slot      = liveSec - gesture * period;
            float drawBudget = baseDraw * (0.975f + 0.04f * stableHash01(gesture, 8987));
            drawBudget = clamp(drawBudget, period * 0.955f, period * 0.998f);

            // 停顿期：快速清场（为下一个 gesture 的"从无到有"让出干净黑场）
            if (slot >= drawBudget) {
                float restRaw = clamp((slot - drawBudget) / Math.max(0.001f, period - drawBudget), 0f, 1f);
                return cfg.powerSave ? 0.520f : lerp(0.550f, 0.620f, cfg.trail) - 0.060f * restRaw;
            }

            float raw = clamp(slot / Math.max(0.001f, drawBudget), 0f, 1f);

            // 积累期：高 fade，让每帧画的线条缓慢积累，形成"从一笔到丰满形体"
            float accumulate = smoother(clamp(raw / 0.70f, 0f, 1f));        // 0→1 在 0~70%
            float dissolve   = smoother(clamp((raw - 0.78f) / 0.22f, 0f, 1f)); // 0→1 在 78~100%

            // fade 曲线：积累期高（0.974），消散期低（0.820→0.640）
            // V176d：trail粒子靠FBO留存，需要较高fade
            // 积累期高fade → 轨迹留住慢慢积累；消散期降低 → 旧痕迹自然消亡
            float fadeAccum    = cfg.powerSave ? 0.950f : lerp(0.960f, 0.972f, cfg.trail);
            float fadePeak     = cfg.powerSave ? 0.942f : lerp(0.952f, 0.965f, cfg.trail);
            float fadeDissolve = cfg.powerSave ? 0.720f : lerp(0.740f, 0.800f, cfg.trail);

            float f = lerp(fadeAccum, fadePeak, accumulate);
            f = lerp(f, fadeDissolve, dissolve);

            return clamp(f, 0.52f, 0.975f);
        }

        private void drawContinuousPenDrawingSubject(float drawSec, float local, Phase phase, float intensity, float tension) {
            // ══════════════════════════════════════════════════════════════════
            // V181：20种曲线（10种3D投影）+ 立体渲染（阴影+高光管）
            //
            // 立体感来源：
            //   ① 阴影层：轨迹整体偏移一段距离+变暗变宽，模拟光照投影
            //   ② 高光线：中轴极细亮线，模拟玻璃管反光
            //   ③ 3D曲线（类型10~19）：环面纽结/3D李萨如/球面曲线等，
            //      经过随机旋转的摄像机投影到屏幕，摄像机缓慢旋转产生动态立体感
            //
            // 20种曲线类型：
            //   0~9  : 2D（李萨如/玫瑰/Spirograph/自由曲线）
            //  10~19 : 3D投影（环面纽结(2,3)/(3,5)/(2,5)/随机 + 三叶结 + 3D李萨如×2
            //           + Viviani曲线 + 球面曲线 + 3D自由叠加）
            // ══════════════════════════════════════════════════════════════════
            if (drawSec < 0f) return;
            float W = Math.max(1f, width), H = Math.max(1f, height);
            float minDim = Math.min(W, H);
            float liveSec = drawSec + 0.86f; // 与 subjectPhaseFeedbackFade 保持一致

            // ── 繁星星空 ──
            int starCount = cfg.powerSave ? 80 : 180;
            int starSeed  = (int)(liveSec / 90f);
            for (int i = 0; i < starCount; i++) {
                float sx  = stableHash01(starSeed*600+i, 31001)*W;
                float sy  = stableHash01(starSeed*600+i, 31003)*H;
                float szr = stableHash01(starSeed*600+i, 31005);
                float starR = szr<0.72f ? (0.35f+0.50f*szr/0.72f)
                            : szr<0.94f ? (1.0f+1.5f*(szr-0.72f)/0.22f)
                            : (2.8f+2.5f*(szr-0.94f)/0.06f);
                float twFreq = 0.25f+1.8f*stableHash01(starSeed*600+i,31007);
                float twinkle= 0.55f+0.45f*(float)Math.sin(liveSec*twFreq*6.28f
                              +stableHash01(starSeed*600+i,31009)*6.28f);
                boolean warm = stableHash01(starSeed*600+i,31011)<0.12f;
                float sHue   = warm ? 0.10f+0.06f*stableHash01(starSeed*600+i,31013)
                                    : 0.58f+0.08f*stableHash01(starSeed*600+i,31015);
                float[] sRgb = hsvToRgb(sHue, warm?0.55f:0.18f+0.20f*stableHash01(starSeed*600+i,31017), 1f);
                float sA = 0.016f*twinkle*(szr>0.94f?2.8f:1f);
                drawEllipse(sx,sy,starR,starR,0f,sRgb[0],sRgb[1],sRgb[2],sA,4);
                if(szr>0.94f) drawEllipse(sx,sy,starR*3.2f,starR*3.2f,0f,sRgb[0],sRgb[1],sRgb[2],sA*0.14f,5);
            }

            // ── 时间轴（与 subjectPhaseFeedbackFade 完全对齐，避免FBO被意外清空）──
            float baseDraw  = lerp(11.20f,7.60f,clamp(cfg.randomness,0f,1f))*(cfg.powerSave?1.08f:1.0f);
            float basePause = lerp(0.12f,0.00f,clamp(cfg.randomness,0f,1f));
            float period    = Math.max(3.0f, baseDraw+basePause);
            int   gesture   = Math.max(0,(int)Math.floor(liveSec/period));
            float slot      = liveSec-gesture*period;
            float budget    = baseDraw*(0.975f+0.04f*stableHash01(gesture,8987));
            budget = clamp(budget, period*0.955f, period*0.998f);
            if(slot>=budget) return;
            float raw=clamp(slot/budget,0f,1f);
            if(raw>0.97f) return;
            if(gesture!=trailGesture){trailHead=0;trailSize=0;trailGesture=gesture;}

            // ── 阶段包络 ──
            float phaseIn =smoother(clamp((drawSec-phase.start)/1.5f,0f,1f));
            float phaseOut=smoother(clamp((phase.end-drawSec)/1.8f,0f,1f));
            float stageA  =phaseIn*phaseOut*(1.4f+0.5f*clamp(phase.intensity*(0.74f+0.52f*cfg.intimacy),0f,1.3f));
            if(stageA<0.01f) return;

            // ── gesture 基因（15个随机维度，保证每次唯一）──
            int   g         = gesture;
            int   artMode   = (int)(stableHash01(g,25001)*8);
            float hueBase   = stableHash01(g,25003);
            float hueSpd    = 0.006f+0.012f*stableHash01(g,25005);
            int   curveType = (int)(stableHash01(g,27001)*20); // 0~19
            boolean is3D    = (curveType >= 10);
            // 摄像机（3D曲线用，缓慢旋转产生动态立体感）
            float camYaw    = stableHash01(g,28001)*6.2831853f + liveSec*0.013f;
            float camPitch  = (0.22f+0.40f*stableHash01(g,28003))*(float)Math.PI;
            float cy=(float)Math.cos(camYaw), sy_=(float)Math.sin(camYaw);
            float cp=(float)Math.cos(camPitch), sp=(float)Math.sin(camPitch);
            // 光源方向（决定阴影方向，每个gesture不同）
            float lightAng  = stableHash01(g,28051)*6.2831853f;
            float shadowLen = 0f; // 后续用lw计算

            // ── 节奏 ──
            float rSlow=0.5f+0.5f*(float)Math.sin(liveSec*(0.05f+0.04f*stableHash01(g,25011))*6.28f+stableHash01(g,25013)*6.28f);
            float rMid =0.5f+0.5f*(float)Math.sin(liveSec*(0.18f+0.22f*stableHash01(g,25021))*6.28f+stableHash01(g,25023)*6.28f);
            float rFast=0.5f+0.5f*(float)Math.sin(liveSec*(1.20f+1.50f*stableHash01(g,25031))*6.28f+stableHash01(g,25033)*6.28f);
            float rhythm=rSlow*0.60f+rMid*0.28f+rFast*0.12f;

            // ── 频率：trail窗口内完成0.8~1.4个图形 ──
            float trailSec    = TRAIL_CAP/60f;
            float fBase       = (0.80f+0.60f*stableHash01(g,27003))/trailSec
                              * (0.85f+0.30f*stableHash01(g,27005));
            float theta=liveSec*fBase*6.2831853f;
            float phX=stableHash01(g,27011)*6.28f, phY=stableHash01(g,27013)*6.28f, phZ=stableHash01(g,27014)*6.28f;
            float ampX=0.78f+0.18f*stableHash01(g,27015), ampY=0.72f+0.22f*stableHash01(g,27017);
            float rotA=stableHash01(g,27019)*6.28f;
            float crA=(float)Math.cos(rotA), srA=(float)Math.sin(rotA);

            // ── 计算笔尖（rawX,rawY 均在[-1,1]）──
            float rawX=0f, rawY=0f;
            switch(curveType) {
                // ─── 2D曲线（0~9）───
                case 0: rawX=ampX*(float)Math.sin(theta+phX); rawY=ampY*(float)Math.sin(theta+phY+(float)Math.PI*0.5f); break;
                case 1: rawX=ampX*(float)Math.sin(theta+phX); rawY=ampY*(float)Math.sin(2f*theta+phY); break;
                case 2: rawX=ampX*(float)Math.sin(theta+phX); rawY=ampY*(float)Math.sin(theta*1.5f+phY); break;
                case 3:{int k=3;float r=ampX*(float)Math.cos(k*theta+phX);rawX=r*(float)Math.cos(theta);rawY=r*(float)Math.sin(theta);break;}
                case 4:{int k2=2+(int)(stableHash01(g,27031)*4);float r2=ampY*(float)Math.sin(k2*theta+phY);rawX=r2*(float)Math.cos(theta);rawY=r2*(float)Math.sin(theta);break;}
                case 5:{float R=0.55f+0.25f*stableHash01(g,27041),rr=0.12f+0.20f*stableHash01(g,27043),d=0.15f+0.30f*stableHash01(g,27045),rt=(R-rr)/Math.max(0.01f,rr);rawX=ampX*((R-rr)*(float)Math.cos(theta)+d*(float)Math.cos(rt*theta+phX));rawY=ampY*((R-rr)*(float)Math.sin(theta)-d*(float)Math.sin(rt*theta+phY));break;}
                case 6:{float R2=0.60f+0.20f*stableHash01(g,27051),rr2=0.06f+0.12f*stableHash01(g,27053),d2=0.35f+0.45f*stableHash01(g,27055),rt2=(R2+rr2)/Math.max(0.01f,rr2);rawX=ampX*((R2+rr2)*(float)Math.cos(theta)-d2*(float)Math.cos(rt2*theta+phX));rawY=ampY*((R2+rr2)*(float)Math.sin(theta)-d2*(float)Math.sin(rt2*theta+phY));break;}
                case 7:{float R3=0.50f+0.30f*stableHash01(g,27061),rr3=0.08f+0.18f*stableHash01(g,27063),d3=0.20f+0.40f*stableHash01(g,27065),irr=1.4142f+0.30f*stableHash01(g,27067);rawX=ampX*((R3-rr3)*(float)Math.cos(theta)+d3*(float)Math.cos(irr*theta+phX));rawY=ampY*((R3-rr3)*(float)Math.sin(theta)-d3*(float)Math.sin(irr*theta+phY));break;}
                case 8:{float a8=0.35f+0.45f*stableHash01(g,27071),b8=0.25f+0.55f*stableHash01(g,27073);rawX=ampX*(float)Math.sin(theta+phX)*(float)Math.cos(a8*theta);rawY=ampY*(float)Math.sin(theta+phY)*(float)Math.cos(b8*theta);break;}
                case 9:{float fY9=fBase*(1.618f+0.20f*stableHash01(g,27081)),fX9=fBase*(1.414f+0.20f*stableHash01(g,27083)),wA=0.60f+0.25f*stableHash01(g,27085),wB=1f-wA;rawX=ampX*(wA*(float)Math.sin(theta+phX)+wB*(float)Math.sin(fX9*liveSec*6.28f+phX*1.3f));rawY=ampY*(wA*(float)Math.sin(fY9*liveSec*6.28f+phY)+wB*(float)Math.sin(fBase*1.5f*liveSec*6.28f+phY*0.8f));break;}

                // ─── 3D曲线（10~19，经摄像机投影）───
                default:{
                    float x3=0f,y3=0f,z3=0f;
                    switch(curveType){
                        case 10:{// 环面纽结 (2,3) 三叶结
                            float R=0.70f,r=0.30f+0.15f*stableHash01(g,29001);
                            x3=(R+r*(float)Math.cos(3*theta))*(float)Math.cos(2*theta);
                            y3=(R+r*(float)Math.cos(3*theta))*(float)Math.sin(2*theta);
                            z3=r*(float)Math.sin(3*theta);
                            float n=R+r; x3/=n;y3/=n;z3/=n; break;}
                        case 11:{// 环面纽结 (3,5)
                            float R=0.65f,r=0.30f+0.10f*stableHash01(g,29011);
                            x3=(R+r*(float)Math.cos(5*theta))*(float)Math.cos(3*theta);
                            y3=(R+r*(float)Math.cos(5*theta))*(float)Math.sin(3*theta);
                            z3=r*(float)Math.sin(5*theta);
                            float n=R+r; x3/=n;y3/=n;z3/=n; break;}
                        case 12:{// 环面纽结 (2,5) 五叶结
                            float R=0.68f,r=0.28f+0.12f*stableHash01(g,29021);
                            x3=(R+r*(float)Math.cos(5*theta))*(float)Math.cos(2*theta);
                            y3=(R+r*(float)Math.cos(5*theta))*(float)Math.sin(2*theta);
                            z3=r*(float)Math.sin(5*theta);
                            float n=R+r; x3/=n;y3/=n;z3/=n; break;}
                        case 13:{// 环面纽结 (p,q) 随机
                            int pp=2+(int)(stableHash01(g,29031)*3), qq=pp*2+1+(int)(stableHash01(g,29033)*2);
                            float R=0.62f,r=0.28f+0.15f*stableHash01(g,29035);
                            x3=(R+r*(float)Math.cos(qq*theta))*(float)Math.cos(pp*theta);
                            y3=(R+r*(float)Math.cos(qq*theta))*(float)Math.sin(pp*theta);
                            z3=r*(float)Math.sin(qq*theta);
                            float n=R+r; x3/=n;y3/=n;z3/=n; break;}
                        case 14:{// 经典三叶结
                            float sc=1f/3f;
                            x3=sc*((float)Math.sin(theta)+2f*(float)Math.sin(2*theta));
                            y3=sc*((float)Math.cos(theta)-2f*(float)Math.cos(2*theta));
                            z3=-sc*(float)Math.sin(3*theta);
                            break;}
                        case 15:{// 8字结（Figure-eight knot）
                            float sc=1f/4f;
                            x3=sc*(2f+(float)Math.cos(2*theta))*(float)Math.cos(3*theta);
                            y3=sc*(2f+(float)Math.cos(2*theta))*(float)Math.sin(3*theta);
                            z3=sc*(float)Math.sin(4*theta);
                            break;}
                        case 16:{// 3D李萨如箱 a:b:c=1:2:3
                            float av=1f,bv=2f+stableHash01(g,29061),cv=3f+stableHash01(g,29063);
                            x3=ampX*(float)Math.sin(av*theta+phX);
                            y3=ampY*(float)Math.sin(bv*theta+phY);
                            z3=0.85f*(float)Math.sin(cv*theta+phZ);
                            break;}
                        case 17:{// 3D李萨如（随机整数比）
                            float av2=1f+(int)(stableHash01(g,29071)*3),bv2=1f+(int)(stableHash01(g,29073)*4),cv2=1f+(int)(stableHash01(g,29075)*5);
                            x3=ampX*(float)Math.sin(av2*theta+phX);
                            y3=ampY*(float)Math.sin(bv2*theta+phY);
                            z3=0.80f*(float)Math.sin(cv2*theta+phZ);
                            break;}
                        case 18:{// Viviani曲线（球与柱面交线）
                            x3=0.5f*(1f+(float)Math.cos(theta));
                            y3=0.5f*(float)Math.sin(theta);
                            z3=(float)Math.sin(theta*0.5f+phZ);
                            x3=x3*2f-1f; // 映射到[-1,1]
                            break;}
                        default:{// 球面李萨如
                            float atheta=theta,bphi=theta*(1.618f+0.30f*stableHash01(g,29091));
                            x3=(float)Math.sin(atheta)*(float)Math.cos(bphi);
                            y3=(float)Math.sin(atheta)*(float)Math.sin(bphi);
                            z3=(float)Math.cos(atheta);
                            break;}
                    }
                    // 摄像机投影（缓慢旋转产生动态立体感）
                    float xr2=x3*cy-z3*sy_;
                    float yr2=y3*cp-(x3*sy_+z3*cy)*sp;
                    rawX=xr2; rawY=yr2;
                    break;}
            }
            // 全局旋转+屏幕映射
            float rX=rawX*crA-rawY*srA, rY=rawX*srA+rawY*crA;
            float padX=W*0.07f, padY=H*0.07f;
            float tipX=clamp(W*0.5f+rX*(W*0.5f-padX), padX, W-padX);
            float tipY=clamp(H*0.5f+rY*(H*0.5f-padY), padY, H-padY);

            // ── 生命包络 ──
            float birthA=smoother(clamp(raw/0.05f,0f,1f));
            float deathA=1f-smoother(clamp((raw-0.82f)/0.18f,0f,1f));
            float lifeA=birthA*deathA*stageA;
            if(lifeA<0.005f) return;

            // ── 笔画属性 ──
            float hue=fract(hueBase+liveSec*hueSpd);
            float sat=0.68f+0.28f*rhythm;
            float peakEnv=(float)Math.pow(Math.sin(Math.PI*Math.min(raw/0.82f,1f)),0.4f);
            float lwBase=minDim*(0.0048f+0.0028f*cfg.ribbonWidth);
            float lwScale;
            switch(artMode){case 1:lwScale=2.0f+1.5f*(1f-rhythm);break;case 2:lwScale=3.2f+2.0f*rSlow;break;case 6:lwScale=1.4f+4.5f*(1f-rhythm);break;default:lwScale=1.0f+0.7f*(1f-rhythm);break;}
            float lw=Math.max(1.5f,lwBase*lwScale*(0.55f+0.45f*peakEnv));
            float val=0.82f+0.14f*peakEnv+0.06f*rFast;
            float[] rgb=hsvToRgb(hue,sat,val);
            rgb[0]=Math.max(rgb[0],0.25f);rgb[1]=Math.max(rgb[1],0.55f);rgb[2]=Math.max(rgb[2],0.65f);

            // ── 写入轨迹缓冲 ──
            int wi=trailHead%TRAIL_CAP;
            trailX[wi]=tipX;trailY[wi]=tipY;
            trailR[wi]=rgb[0];trailG[wi]=rgb[1];trailB[wi]=rgb[2];
            trailW[wi]=lw;trailA[wi]=lifeA;
            trailHead++;if(trailSize<TRAIL_CAP)trailSize++;
            if(trailSize<2) return;

            // ── 构建路径 ──
            int total=trailSize;
            int tSt=(trailHead-total+TRAIL_CAP*2)%TRAIL_CAP;
            ArrayList<float[]> path=new ArrayList<>(total);
            for(int i=0;i<total;i++){
                int idx=(tSt+i)%TRAIL_CAP;
                path.add(new float[]{trailX[idx],trailY[idx]});
            }

            // ══════════════════════════════════════════════════════════════════
            // 立体渲染三层：① 阴影 → ② 主体(artMode) → ③ 高光管
            // ══════════════════════════════════════════════════════════════════

            // ── ① 阴影层（偏色暗版，黑底上可见；产生空间漂浮感）──
            shadowLen = lw*(0.60f+0.35f*stableHash01(g,28053));
            float sdx=(float)Math.cos(lightAng)*shadowLen, sdy=(float)Math.sin(lightAng)*shadowLen;
            ArrayList<float[]> shadowPath=new ArrayList<>(total);
            for(float[] p:path) shadowPath.add(new float[]{p[0]+sdx,p[1]+sdy});
            // 阴影颜色：主色调偏移+大幅压暗（黑底上用深色而非纯黑）
            float[] shRgb=hsvToRgb(fract(hue+0.18f), sat*0.55f, val*0.28f);
            drawAgeFadedStrip(shadowPath, lw*1.55f, shRgb[0],shRgb[1],shRgb[2], lifeA*0.55f, 1.0f, 0.003f);

            // ── ② 主体（按 artMode）──
            switch(artMode){
                case 0:
                    drawAgeFadedStrip(path,lw,rgb[0],rgb[1],rgb[2],lifeA*0.90f,1.12f,0.02f);
                    break;
                case 1:{
                    drawAgeFadedStrip(path,lw,rgb[0],rgb[1],rgb[2],lifeA*0.85f,1.06f,0.02f);
                    float[]ec=hsvToRgb(fract(hue+0.08f),sat*0.40f,1f);
                    drawAgeFadedStrip(path,lw*0.12f,ec[0],ec[1],ec[2],lifeA*0.55f,1.28f,0.35f);
                    break;}
                case 2:
                    drawAgeFadedStrip(path,lw*2.6f,rgb[0],rgb[1],rgb[2],lifeA*0.18f,1.0f,0.005f);
                    drawAgeFadedStrip(path,lw,rgb[0],rgb[1],rgb[2],lifeA*0.65f,1.08f,0.02f);
                    break;
                case 3:{
                    drawAgeFadedStrip(path,lw*1.1f,rgb[0],rgb[1],rgb[2],lifeA*0.95f,1.18f,0.005f);
                    float[]gc=hsvToRgb(fract(hue+0.12f),sat*0.30f,1f);
                    drawAgeFadedStrip(path,lw*2.8f,gc[0],gc[1],gc[2],lifeA*0.16f,1.0f,0.001f);
                    break;}
                case 4:{
                    float vOff=lw*0.75f;
                    ArrayList<float[]>p1=new ArrayList<>(total),p2=new ArrayList<>(total);
                    for(int i=0;i<total;i++){
                        float[]cur=path.get(i),prv=path.get(Math.max(0,i-1)),nxt=path.get(Math.min(total-1,i+1));
                        float dx=nxt[0]-prv[0],dy=nxt[1]-prv[1],dl=(float)Math.sqrt(dx*dx+dy*dy);
                        if(dl<0.1f){p1.add(cur);p2.add(cur);continue;}
                        float nx2=-dy/dl,ny2=dx/dl;
                        p1.add(new float[]{cur[0]+nx2*vOff,cur[1]+ny2*vOff});
                        p2.add(new float[]{cur[0]-nx2*vOff,cur[1]-ny2*vOff});
                    }
                    float[]v1=hsvToRgb(fract(hue+0.07f),sat*0.75f,val);
                    float[]v2=hsvToRgb(fract(hue-0.07f),sat*0.75f,val);
                    drawAgeFadedStrip(p1,lw*0.50f,v1[0],v1[1],v1[2],lifeA*0.75f,1.08f,0.02f);
                    drawAgeFadedStrip(p2,lw*0.50f,v2[0],v2[1],v2[2],lifeA*0.68f,1.08f,0.02f);
                    break;}
                case 5:
                    drawAgeFadedStrip(path,lw*0.65f,rgb[0],rgb[1],rgb[2],lifeA*0.80f,1.08f,0.02f);
                    for(int p2=0;p2<Math.min(6,total);p2++){
                        float[]pt=path.get(total-1-p2);float pA=lifeA*(1f-p2*0.15f);
                        for(int pk=0;pk<5;pk++){
                            float pa=pk/5f*6.28f+liveSec*0.7f+p2*0.35f;
                            float[]pr=hsvToRgb(fract(hue+pk*0.09f),sat*0.80f,val);
                            drawEllipse(pt[0]+(float)Math.cos(pa)*lw*0.75f,pt[1]+(float)Math.sin(pa)*lw*0.75f,lw*0.26f,lw*0.10f,pa,pr[0],pr[1],pr[2],pA*0.52f,4);
                        }
                    }
                    break;
                case 6:{
                    int step=Math.max(1,total/25);
                    for(int i=0;i<total-step;i+=step){
                        ArrayList<float[]>seg=new ArrayList<>(step+2);
                        for(int j=i;j<=Math.min(i+step,total-1);j++) seg.add(path.get(j));
                        float cur2=0f;
                        if(i>0&&i+step<total){float[]pm=path.get(i-1),pc=path.get(i),pn=path.get(Math.min(i+step,total-1));float d1x=pc[0]-pm[0],d1y=pc[1]-pm[1],d2x=pn[0]-pc[0],d2y=pn[1]-pc[1],l1=(float)Math.sqrt(d1x*d1x+d1y*d1y),l2=(float)Math.sqrt(d2x*d2x+d2y*d2y);if(l1>0.5f&&l2>0.5f)cur2=1f-clamp((d1x*d2x+d1y*d2y)/(l1*l2),-1f,1f);}
                        drawAgeFadedStrip(seg,Math.max(0.8f,lw*(0.25f+1.8f*cur2)),rgb[0],rgb[1],rgb[2],lifeA*(float)Math.pow((i+1f)/total,0.7f)*(0.45f+0.45f*cur2),1.05f,0.20f);
                    }
                    break;}
                default:{
                    drawAgeFadedStrip(path,lw*0.60f,rgb[0],rgb[1],rgb[2],lifeA*0.75f,1.08f,0.02f);
                    int sStep=Math.max(1,total/18);
                    for(int i=0;i<total;i+=sStep){
                        float[]pt=path.get(i);
                        float[]sr=hsvToRgb(fract(hue+stableHash01(g+i,25403)*0.30f),sat*0.60f,1f);
                        float sAng=stableHash01(g+i,25401)*6.28f,sDst=lw*(0.4f+0.7f*stableHash01(g+i,25405));
                        drawEllipse(pt[0]+(float)Math.cos(sAng)*sDst,pt[1]+(float)Math.sin(sAng)*sDst,lw*0.26f,lw*0.26f,0f,sr[0],sr[1],sr[2],lifeA*(float)Math.pow((i+1f)/total,1.2f)*0.52f,4);
                    }
                    break;}
            }

            // ── ③ 高光管（玻璃管反光感，让立体感更明显）──
            drawAgeFadedStrip(path, lw*0.10f, 1f,1f,1f, lifeA*0.78f, 1.45f, 0.32f);
        }



        private void drawCoherentFlowCreation(ArrayList<float[]> stroke, int gesture, int motif, float raw, float progress,
                                              float minDim, float drawSec, float seedA, float seedB, float seedC,
                                              float[] mid, float[] cyan, float[] hot, float alpha) {
            int n = stroke.size();
            if (n < 5 || alpha <= 0.001f) return;

            // V139：按“看得懂的连续创作过程”重构。
            // 这版先暂停多副本、多网状和后补完整主体，改为一个短句从种子点向两端缓慢生长，
            // 光弦在生长的同时持续变形、留下残影并逐渐消失。
            drawWindows7MystifyGenerativeCreation(stroke, gesture, raw, progress, minDim, drawSec, seedA, seedB, seedC, mid, cyan, hot, alpha);
        }

        private void drawWindows7MystifyGenerativeCreation(ArrayList<float[]> sourceStroke, int gesture, float raw, float progress,
                                                            float minDim, float drawSec, float seedA, float seedB, float seedC,
                                                            float[] mid, float[] cyan, float[] hot, float alpha) {
            // V146：根据 V145 实拍反馈重构。
            // 实拍里仍像“爬行类动物”：根因是仍然把一条连续脊线当作主体，
            // 再给它加宽、加膜、加肋线。视觉上自然会变成“身躯在爬”。
            // 这一版先跳过旧的蛇形主体算法，改成“多个短笔触事件”的自由画笔：
            // 一段短句内会依次出现线、扇、网、丝带、花瓣等不同笔触，
            // 每个笔触自己生长、展开、淡去，不再由一条身体拖着全场移动。
            if (drawSec >= -999999f) {
                drawFreeArtistScreensaverBrush(gesture, raw, progress, minDim, drawSec, seedA, seedB, seedC, mid, cyan, hot, alpha);
                return;
            }
            int strings = 1;
            int trails = cfg.powerSave ? 3 : 5;
            float globalSpeed = mystifySpeed(drawSec, gesture, seedA);
            float baseGap = (0.34f + 0.10f * stableHash01(gesture, 14003)) * lerp(1.28f, 0.96f, globalSpeed);
            float lineWidth = Math.max(0.42f, minDim * (0.00165f + 0.00120f * cfg.ribbonWidth));
            for (int s = 0; s < strings; s++) {
                int sg = gesture * 37 + s * 2003 + 14107;
                float life = generativeStringLife(drawSec, sg, s);
                float stringAlpha = alpha * life * (s == 0 ? 1.0f : 0.28f);
                if (stringAlpha <= alpha * 0.014f) continue;
                float localGap = baseGap * (0.82f + 0.34f * stableHash01(sg, 14011));
                for (int k = trails - 1; k >= 0; k--) {
                    float age = k / Math.max(1f, trails - 1f);
                    float remain = 1f - age;
                    float phraseDuration = generativePhraseDuration(sg);
                    float localCreativeTime = clamp(raw, 0f, 0.999f) * phraseDuration;
                    float time = localCreativeTime - k * localGap - s * 0.10f;
                    if (time < 0f) continue;
                    ArrayList<float[]> curve = buildGenerativeMystifyCurve(sg, time, minDim, seedA + s * 0.17f, seedB + s * 0.31f, seedC + s * 0.53f,
                            cfg.powerSave ? 78 : 132);
                    if (curve.size() < 5) continue;
                    float phraseLife = generativePhraseLife(time, sg);
                    float reveal = generativePhraseReveal(time, sg);
                    ArrayList<ArrayList<float[]>> visibleSegments = generativeCreationSegments(curve, reveal, sg, time);
                    if (visibleSegments.isEmpty()) continue;
                    float a = stringAlpha * phraseLife;
                    if (a <= 0.001f) continue;
                    float hue = fract(0.58f + sg * 0.027f + time * 0.037f - age * 0.075f + 0.050f * generativePhrasePulse(time, sg));
                    float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, remain, k == 0);
                    float width = lineWidth * (s == 0 ? 1.0f : 0.70f) * (0.72f + 0.42f * generativePhrasePulse(time, sg));
                    if (k == 0) {
                        drawGenerativeGrowingFormSegments(visibleSegments, minDim, sg, time, color, cyan, hot, a, width);
                        drawGenerativeSegmentTips(visibleSegments, minDim, sg, time, color, hot, a, width);
                    } else {
                        // 旧笔痕：跟随当时已经画到的位置，只画窄而淡的时间切片，
                        // 让先画内容按节奏缓慢消失，而不是等整段完成后一起消失。
                        float processBand = smoother(clamp(remain / 0.88f, 0f, 1f));
                        float trailAlpha = a * (0.010f + 0.060f * processBand * processBand) * (0.80f + 0.20f * generativePhrasePulse(time, sg));
                        drawGenerativeTrailSegments(visibleSegments, width * (0.34f + 0.34f * remain), color, trailAlpha);
                    }
                }
            }
        }

        private void drawFreeArtistScreensaverBrush(int gesture, float raw, float progress,
                                                        float minDim, float drawSec, float seedA, float seedB, float seedC,
                                                        float[] mid, float[] cyan, float[] hot, float alpha) {
            // V147：彻底切断“连续脊线 + 两侧膜面 + 肋线”的身体结构。
            // 参考 Flurry / Flux / Fieldlines 等开源艺术屏保的思路：
            // 画面由独立的短笔触事件、场线事件、扇形事件和光点爆发组成；
            // 没有一条贯穿全场的身体，也不再画附着在身体两侧的膜和肋线。
            drawPureImprovisationScreensaverBrush(gesture, raw, progress, minDim, drawSec, seedA, seedB, seedC, mid, cyan, hot, alpha);
        }

        private void drawPureImprovisationScreensaverBrush(int gesture, float raw, float progress,
                                                            float minDim, float drawSec, float seedA, float seedB, float seedC,
                                                            float[] mid, float[] cyan, float[] hot, float alpha) {
            // V153：彻底把“画笔主路径”改成流场式生成笔刷。
            // V152 仍会被看成一条主线，因为它本质上还是用中心曲线承载形态。
            // V153 参考 Flurry / Flux / Fieldlines / Solarwinds 一类开源艺术屏保的生成思想：
            // 一个统一创作场中不断出生、运动、转向、淡出的光粒笔迹组成主体；
            // 形态从粒子运动场中生长出来，而不是先画好线条、扇形、网状模板再替换展示。
            drawFlowFieldArtistCreationV153(gesture, raw, minDim, drawSec, seedA, seedB, seedC, mid, cyan, hot, alpha);
        }

        private void drawFlowFieldArtistCreationV153(int gesture, float raw, float minDim, float drawSec,
                                                     float seedA, float seedB, float seedC,
                                                     float[] mid, float[] cyan, float[] hot, float alpha) {
            // V163：继续对照参考视频修正 V162。
            // V162 虽已变成控制点光弦，但仍有三个偏差：
            // 1) 控制点仍像“家族模板”插值；2) 宽面用填充 surface，容易像预制形体；
            // 3) 可见窗口过长，容易一次性呈现太多已完成形状。
            // V163 改为“细轮廓光弦 + 极淡同源时间切片 + 较短绘制窗口”，
            // 让主体更接近参考视频里的清晰、克制、持续生成的光短句。
            // V168：Windows Mystify 式多形体轮换 + 逐段渐隐。
            drawV168MystifyPolymorphCreation(gesture, raw, minDim, drawSec, seedA, seedB, seedC, mid, cyan, hot, alpha);
        }

        // =====================================================================
        // V172：真正的 Mystify"从无到有"——每帧只画当前一条线，FBO 自然累积历史
        //
        // 核心认知修正（来自阅读引擎主循环）：
        //
        //   引擎每帧调用本函数时，raw 是当前时刻的进度（0→1 匀速推进）。
        //   FBO 的 fade（≈0.96~0.98）每帧保留上一帧画面的 96~98%。
        //   因此：历史不需要在本函数内手动重画！
        //   只需每帧画"当前时刻的一条线"，FBO 就会自动把所有历史线条
        //   像墨迹一样留在画面上并缓慢消散——这正是 Mystify 的真实机制。
        //
        // 正确的"从无到有"实现：
        //   raw=0.00：Wire 刚刚诞生，笔尖在起点，只有一个光点
        //   raw=0.05：Wire 开始移动，画出第一段细线，FBO 留住这段线
        //   raw=0.20：Wire 继续运动，形体开始展开，FBO 上累积了20%的轨迹
        //   raw=0.50：形体进入鼎盛，FBO 上有完整的历史尾迹，颜色丰富
        //   raw=0.80：FBO 的 fade 开始让旧痕迹消散，先画的部分先消失
        //   raw=1.00：Wire 停止，只剩最后画的线条在 FBO 上慢慢消散
        //
        // "呼吸"感的实现：
        //   线宽随正弦函数脉动（粗→细→粗），产生"吸气-呼气"节奏
        //   颜色随 raw 沿彩虹流动，历史尾迹自然形成彩虹渐变
        //   速度随呼吸调制：快时 Wire 移动快（线条稀疏），慢时密集（实体感）
        //
        // 高随机性：
        //   每个 gesture 用种子决定 Corner 数（3~6）、速度、颜色方案、呼吸频率
        //   同一 gesture 内曲线形体由 Corner 弹跳有机产生，绝不重复
        // =====================================================================
        private void drawV168MystifyPolymorphCreation(int gesture, float raw, float minDim, float drawSec,
                                                      float seedA, float seedB, float seedC,
                                                      float[] mid, float[] cyan, float[] hot, float alpha) {
            if (alpha <= 0.002f) return;
            // raw 是当前帧的进度（0→1），每帧只绘制"此刻的状态"
            // FBO 负责保留历史——不在本函数内画历史层！
            float t = clamp(raw, 0f, 0.999f);

            // ══════════════════════════════════════════════════════
            // 每个 gesture 的独特基因（由 gesture 种子决定，每次完全不同）
            // ══════════════════════════════════════════════════════
            int g = gesture;
            int   cornerCount   = 3 + (int)(stableHash01(g, 22001) * 4);   // 3~6 个顶点
            int   wireCount     = stableHash01(g, 22003) > 0.60f ? 2 : 1;  // 1~2 条 Wire
            float speedBase     = 0.14f + 0.36f * stableHash01(g, 22005);  // 速度基因
            float breathFreq    = 1.5f  + 3.0f  * stableHash01(g, 22007);  // 呼吸频率
            float breathDepth   = 0.25f + 0.55f * stableHash01(g, 22009);  // 呼吸深度
            int   colorScheme   = (int)(stableHash01(g, 22011) * 8);       // 颜色方案

            // ── 呼吸函数：sin 调制速度和线宽 ──
            float breathPhase = t * breathFreq * (float)Math.PI * 2f
                    + stableHash01(g, 22013) * (float)Math.PI * 2f;
            float breath = 0.5f + 0.5f * (float)Math.sin(breathPhase); // [0,1]
            // 速度倍率：吸气时快（形体伸展），呼气时慢（线条密集，实体感增强）
            float speedMult = 1f - breathDepth * (1f - breath);

            // ── 整体生命包络（控制每帧本条线的 alpha）──
            // 诞生：前 6% 从 0 淡入（FBO 上会自然积累出"从无到有"的感觉）
            float birthEnv = smoother(clamp(t / 0.06f, 0f, 1f));
            // 消亡：最后 15% 淡出（FBO fade 会让旧线条先消散，产生"先画先消失"）
            float deathEnv = 1f - smoother(clamp((t - 0.85f) / 0.15f, 0f, 1f));
            float lifeEnv  = birthEnv * deathEnv;
            if (lifeEnv <= 0.003f) return;

            // ── 线宽：随呼吸脉动，随生命进度略微变化 ──
            // 鼎盛期（t≈0.5）最粗，两端细——产生"从细线生长到宽体再收束"的感觉
            float peakWidth = (float)Math.sin(Math.PI * t); // 0→1→0
            float lineWidth = Math.max(0.5f, minDim * (
                    0.0014f                              // 基础宽度
                    + 0.0012f * cfg.ribbonWidth          // 用户设置
                    + 0.0010f * peakWidth                // 鼎盛期加粗
                    + 0.0008f * breath));                // 呼吸脉动

            int samples = cfg.powerSave ? 60 : 100;

            // ══════════════════════════════════════════════════════
            // 绘制当前帧的 Wire 线条（只画此刻，不画历史）
            // ══════════════════════════════════════════════════════
            for (int wire = 0; wire < wireCount; wire++) {
                float hue0 = v171BaseHue(g, colorScheme, wire);
                // 颜色随 raw 沿彩虹流动（FBO 历史自然形成彩虹尾迹）
                float hue = fract(hue0 + t * 0.12f);
                float[] col = v171ColorFromScheme(hue, colorScheme, mid, cyan, hot, true);
                // 保证在黑底上足够亮
                col[0] = Math.max(col[0], 0.30f);
                col[1] = Math.max(col[1], 0.65f);
                col[2] = Math.max(col[2], 0.78f);

                // 构建当前时刻的 Wire 曲线
                ArrayList<float[]> curve = buildV171WireCurve(
                        g, wire, t, cornerCount, speedBase * speedMult, samples);
                if (curve.size() < 4) continue;

                float effectiveAlpha = alpha * lifeEnv;

                // 主线条（每帧只画这一条）
                drawAgeFadedStrip(curve, Math.max(0.28f, lineWidth),
                        col[0], col[1], col[2],
                        effectiveAlpha,
                        1.08f,   // 中段亮度增益
                        0.50f);  // 头尾最低亮度比例

                // 白色中轴高光（模拟霓虹光管中心线）
                drawAgeFadedStrip(curve, Math.max(0.10f, lineWidth * 0.040f),
                        0.88f, 0.95f, 1.00f,
                        effectiveAlpha * 0.52f,
                        1.18f, 0.82f);

                // ── 笔尖光点：跟随 Wire 当前运动前端 ──
                // 诞生初期（t<0.08）光点最显眼（这是"第一笔落下"的星火）
                // 之后逐渐压暗（主体已经展开，笔尖只是引导）
                float tipBirth = smoother(clamp(t / 0.08f, 0f, 1f));
                // 消亡末期光点也消失
                float tipDeath = 1f - smoother(clamp((t - 0.80f) / 0.20f, 0f, 1f));
                float tipAlpha = alpha * tipBirth * tipDeath
                        * (t < 0.08f ? 1.0f : (0.55f + 0.35f * (1f - t * 0.6f)));

                if (tipAlpha > 0.015f && !curve.isEmpty()) {
                    // Wire 的"活动顶点"：取曲线末端作为笔尖
                    float[] tipPt = curve.get(curve.size() - 1);
                    float tipR = Math.max(1.0f, minDim * (
                            0.0025f
                            + 0.0020f * (t < 0.06f ? 1f : breath))); // 诞生时光点最大
                    drawEllipse(tipPt[0], tipPt[1], tipR, tipR * 0.38f,
                            t * 6.2831853f, // 随时间旋转
                            hot[0], hot[1], hot[2], tipAlpha, 10);

                    // 诞生阶段：额外的光晕（暗示即将展开的能量）
                    if (t < 0.10f) {
                        float haloAlpha = tipAlpha * (1f - t / 0.10f) * 0.22f;
                        drawEllipse(tipPt[0], tipPt[1], tipR * 3.8f, tipR * 2.0f,
                                t * 3.14159f, col[0], col[1], col[2], haloAlpha, 8);
                    }

                    // 鼎盛期：Wire 的首端也亮起（两个端点同时发光，像 Mystify 的顶点）
                    if (t > 0.25f && t < 0.80f) {
                        float[] headPt = curve.get(0);
                        float headR = tipR * (0.5f + 0.4f * breath);
                        drawEllipse(headPt[0], headPt[1], headR, headR * 0.38f,
                                t * 4.18879f,
                                col[0], col[1], col[2], tipAlpha * 0.60f, 8);
                    }
                }
            }
        }

        // buildV171WireCurve、v171BaseHue、v171ColorFromScheme 保持不变（V171 已定义）

        /** 保留废弃函数签名 */
        private void drawV169MystifyConnectors(ArrayList<float[]> cur, ArrayList<float[]> prev,
                                               float[] color, float alpha, float lineW) {}
        private void drawV169OrganicRibs(ArrayList<float[]> pts, float[] color, float alpha, float lineW) {}
        private ArrayList<float[]> buildV170WireCurve(int g, int wire, float local, int samples) {
            return buildV171WireCurve(g, wire, local, 4, 0.30f, samples);
        }
        // =====================================================================
        // V172 结束
        // =====================================================================

        /**
         * V171/V172 辅助：构建 Wire 曲线（带速度调制的弹跳控制点 + Catmull-Rom 插值）
         */
        private ArrayList<float[]> buildV171WireCurve(int g, int wire, float local,
                                                       int cornerCount, float speed, int samples) {
            float mx = width * 0.06f, my = height * 0.08f;
            float sw = width - 2f * mx, sh = height - 2f * my;

            float[][] corners = new float[cornerCount][2];
            for (int c = 0; c < cornerCount; c++) {
                int si = g * 3001 + wire * 1301 + c * 701 + 21201;
                float x0 = stableHash01(si, 21211);
                float y0 = stableHash01(si, 21213);
                // 各 Corner 速度不同——这是形体持续有机变形的根本原因
                float vx = speed * (0.55f + 0.90f * stableHash01(si, 21217));
                float vy = speed * (0.50f + 0.95f * stableHash01(si, 21219));
                float phx = stableHash01(si, 21223);
                float phy = stableHash01(si, 21227);
                // 主弹跳：|sin| 模拟屏幕边缘反弹
                float bx = Math.abs((float)Math.sin((float)Math.PI * (x0 + vx * local + phx)));
                float by = Math.abs((float)Math.sin((float)Math.PI * (y0 + vy * local + phy)));
                // 第二谐波叠加（更有机的运动感）
                float vx2 = speed * (0.22f + 0.35f * stableHash01(si, 21231));
                float vy2 = speed * (0.20f + 0.38f * stableHash01(si, 21233));
                float bx2 = Math.abs((float)Math.sin((float)Math.PI * (x0*1.5f + vx2*local + phx*0.8f)));
                float by2 = Math.abs((float)Math.sin((float)Math.PI * (y0*1.5f + vy2*local + phy*0.8f)));
                // 低频漂移（整体缓慢游弋感）
                float driftX = 0.06f * (float)Math.sin(local * 0.8f + stableHash01(si,21235)*6.28f);
                float driftY = 0.06f * (float)Math.sin(local * 0.7f + stableHash01(si,21237)*6.28f);
                bx = clamp(bx*0.68f + bx2*0.32f + driftX, 0f, 1f);
                by = clamp(by*0.68f + by2*0.32f + driftY, 0f, 1f);
                corners[c][0] = mx + bx * sw;
                corners[c][1] = my + by * sh;
            }
            // Catmull-Rom 样条插值
            ArrayList<float[]> out = new ArrayList<>(samples);
            int n = cornerCount;
            for (int s = 0; s < samples; s++) {
                float q   = s / Math.max(1f, samples - 1f);
                float pos = q * (n - 1f);
                int   i1  = clampInt((int)pos, 0, n-1);
                float tt  = pos - i1;
                int   i0  = clampInt(i1-1, 0, n-1);
                int   i2  = clampInt(i1+1, 0, n-1);
                int   i3  = clampInt(i1+2, 0, n-1);
                float t2  = tt*tt, t3 = t2*tt;
                float x = 0.5f*((2*corners[i1][0])
                        +(-corners[i0][0]+corners[i2][0])*tt
                        +(2*corners[i0][0]-5*corners[i1][0]+4*corners[i2][0]-corners[i3][0])*t2
                        +(-corners[i0][0]+3*corners[i1][0]-3*corners[i2][0]+corners[i3][0])*t3);
                float y = 0.5f*((2*corners[i1][1])
                        +(-corners[i0][1]+corners[i2][1])*tt
                        +(2*corners[i0][1]-5*corners[i1][1]+4*corners[i2][1]-corners[i3][1])*t2
                        +(-corners[i0][1]+3*corners[i1][1]-3*corners[i2][1]+corners[i3][1])*t3);
                out.add(new float[]{x, y});
            }
            return out;
        }

        /** HSV → RGB 转换（h∈[0,1], s∈[0,1], v∈[0,1]） */
        private float[] hsvToRgb(float h, float s, float v) {
            h = fract(h) * 6f;
            int   i = (int)h;
            float f = h - i;
            float p = v * (1f - s);
            float q = v * (1f - s * f);
            float t = v * (1f - s * (1f - f));
            switch (i % 6) {
                case 0: return new float[]{v, t, p};
                case 1: return new float[]{q, v, p};
                case 2: return new float[]{p, v, t};
                case 3: return new float[]{p, q, v};
                case 4: return new float[]{t, p, v};
                default:return new float[]{v, p, q};
            }
        }

        /** V171/V172：8种颜色方案的基础色相（黄金比例低差异序列，每个gesture不同） */
        private float v171BaseHue(int g, int scheme, int wire) {
            float[] bases = {0.55f, 0.05f, 0.32f, 0.72f, 0.15f, 0.48f, 0.88f, 0.62f};
            float base = bases[scheme % 8];
            float wireOffset = wire == 0 ? 0f : (0.33f + 0.34f * stableHash01(g, 21301));
            return fract(base + wireOffset + g * 0.0618f);
        }

        /** V171/V172：8种颜色方案（冷蓝/暖橙/自然绿/紫/金/青白/玫瑰/彩虹） */
        private float[] v171ColorFromScheme(float hue, int scheme, float[] mid,
                                             float[] cyan, float[] hot, boolean brightest) {
            if (scheme == 7) {
                float[] c = mystifyPaletteFromHue(hue, mid, cyan, hot, 1.0f, brightest);
                c[0] = Math.max(c[0], 0.30f); c[1] = Math.max(c[1], 0.65f); c[2] = Math.max(c[2], 0.75f);
                return c;
            }
            float[][] ranges = {
                {0.55f, 0.12f}, {0.05f, 0.10f}, {0.32f, 0.10f}, {0.72f, 0.12f},
                {0.13f, 0.06f}, {0.50f, 0.08f}, {0.88f, 0.10f}
            };
            float[] r = ranges[scheme % 7];
            float mappedHue = fract(r[0] + (hue - 0.5f) * r[1] * 2f);
            float[] c = mystifyPaletteFromHue(mappedHue, mid, cyan, hot, 1.0f, brightest);
            float bright = brightest ? 1.0f : 0.80f;
            c[0] = Math.max(c[0]*bright, scheme==0 ? 0.20f : 0.30f);
            c[1] = Math.max(c[1]*bright, 0.60f);
            c[2] = Math.max(c[2]*bright, 0.70f);
            return c;
        }

        private void drawReferenceVideoTimePainterV166(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V167：修复 V166 在黑色背景下“几乎只剩一条暗线”的可见性问题。
            // V166 的分叉、场线、变身层大量被极低 alpha / 极细线宽压暗，导致真实壁纸上几乎看不见。
            // 本版保留单一主体，但提高主体亮度、线宽、旁路轮廓、变身场线与同源回声的可见度。
            float local = clamp(raw, 0f, 0.999f);
            float life = v166PhraseLife(local);
            if (life <= 0.002f) return;
            float mutation = v166MutationPulse(local, gesture);
            float head = v166Head(local, gesture, mutation);
            float tail = v166Tail(local, head, mutation);
            if (head <= tail + 0.016f) {
                float[] c = v166Center(gesture, local, minDim);
                drawEllipse(c[0], c[1], minDim * 0.0046f, minDim * 0.0018f, v166Angle(gesture, local),
                        hot[0], hot[1], hot[2], alpha * life * 0.170f, 18);
                return;
            }

            float[] center = v166Center(gesture, local, minDim);
            float scale = minDim * (0.43f + 0.20f * stableHash01(gesture, 16601)) * (1f + 0.12f * mutation);
            float angle = v166Angle(gesture, local);
            float camera = v166CameraFov(local, gesture, minDim);
            float hue = fract(0.50f + stableHash01(gesture, 16603) * 0.26f + local * (0.070f + 0.030f * mutation));
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 1.00f, true);
            // V167：黑色动态壁纸上，低饱和/低透明度的颜色会被背景吞掉。
            // 给主色设置最低亮度，避免“明明画了分叉/网纱，但肉眼只看见一条暗线”。
            color[0] = Math.max(color[0], 0.38f);
            color[1] = Math.max(color[1], 0.82f);
            color[2] = Math.max(color[2], 0.88f);

            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes; e >= 1; e--) {
                float oldLocal = local - e * (0.050f + 0.016f * mutation);
                if (oldLocal <= 0.020f) continue;
                float oldLife = v166PhraseLife(oldLocal);
                if (oldLife <= 0.004f) continue;
                float oldMutation = v166MutationPulse(oldLocal, gesture);
                float oldHead = v166Head(oldLocal, gesture, oldMutation);
                float oldTail = v166Tail(oldLocal, oldHead, oldMutation);
                if (oldHead <= oldTail + 0.018f) continue;
                float[] oc = v166Center(gesture, oldLocal, minDim);
                drawV166PolymorphicString(gesture, oldLocal, oldTail, oldHead, oc[0], oc[1],
                        v166Angle(gesture, oldLocal), scale, v166CameraFov(oldLocal, gesture, minDim),
                        color, cyan, hot, alpha * oldLife * (0.052f / e), true);
            }

            drawV166PolymorphicString(gesture, local, tail, head, center[0], center[1], angle, scale, camera,
                    color, cyan, hot, alpha * life * 1.75f, false);
            drawV166MutationBranches(gesture, local, tail, head, center[0], center[1], angle, scale, camera,
                    color, cyan, hot, alpha * life * 1.30f, mutation);
            drawV166BrushTip(gesture, local, head, center[0], center[1], angle, scale, camera, hot, alpha * life * 1.55f, mutation);
        }

        private float v166PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.004f) / 0.070f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.930f) / 0.070f, 0f, 1f));
            return appear * vanish;
        }

        private float v166MutationPulse(float local, int gesture) {
            // 五个变身节拍：每次不是换主体，而是同一光弦控制点发生一次拓扑重组。
            float base = 0.145f + 0.018f * stableHash01(gesture, 16611);
            float p0 = base;
            float p1 = 0.292f + 0.030f * stableHash01(gesture, 16613);
            float p2 = 0.455f + 0.035f * stableHash01(gesture, 16617);
            float p3 = 0.626f + 0.032f * stableHash01(gesture, 16619);
            float p4 = 0.785f + 0.025f * stableHash01(gesture, 16623);
            float b0 = v166PulseAt(local, p0, 0.040f);
            float b1 = v166PulseAt(local, p1, 0.050f);
            float b2 = v166PulseAt(local, p2, 0.055f);
            float b3 = v166PulseAt(local, p3, 0.052f);
            float b4 = v166PulseAt(local, p4, 0.046f);
            return clamp(Math.max(Math.max(b0, b1), Math.max(Math.max(b2, b3), b4)), 0f, 1f);
        }

        private float v166PulseAt(float x, float center, float radius) {
            float d = Math.abs(x - center) / Math.max(0.001f, radius);
            if (d >= 1f) return 0f;
            float v = 1f - d;
            return smoother(v);
        }

        private float v166Head(float local, int gesture, float mutation) {
            float raw = clamp((local - 0.006f) / 0.820f, 0f, 1f);
            float h = smoother(raw);
            // 变身节拍处头部有提笔、顿挫、再推进，体现“突然变化”而非匀速爬行。
            h += 0.038f * mutation * waveEnvelope(raw);
            h += 0.006f * (float)Math.sin(stableHash01(gesture, 16629) * 6.2831853f + local * 10.5f) * waveEnvelope(raw);
            return clamp(h, 0f, 1f);
        }

        private float v166Tail(float local, float head, float mutation) {
            float chase = smoother(clamp((local - 0.105f) / 0.585f, 0f, 1f));
            float window = lerp(0.62f, 0.34f, chase);
            window *= (1f - 0.12f * mutation);
            float dissolvePush = 0.060f * smoother(clamp((local - 0.805f) / 0.120f, 0f, 1f));
            return clamp(head - window + dissolvePush, 0f, Math.max(0f, head - 0.046f));
        }

        private float[] v166Center(int gesture, float local, float minDim) {
            float sx = stableHash01(gesture, 16631);
            float sy = stableHash01(gesture, 16637);
            float x = width * (0.18f + 0.62f * sx);
            float y = height * (0.20f + 0.50f * sy);
            float drift = minDim * 0.020f * waveEnvelope(local);
            float ph = stableHash01(gesture, 16641) * 6.2831853f;
            x += drift * (float)Math.sin(ph + local * 0.82f) + drift * 0.26f * (float)Math.sin(ph * 0.7f + local * 1.44f);
            y += drift * 0.58f * (float)Math.cos(ph * 0.8f + local * 0.74f);
            return new float[]{clamp(x, width * 0.14f, width * 0.86f), clamp(y, height * 0.18f, height * 0.76f)};
        }

        private float v166Angle(int gesture, float local) {
            float base = stableHash01(gesture, 16643) * 6.2831853f;
            float mutation = v166MutationPulse(local, gesture);
            return base
                    + 0.18f * (float)Math.sin(stableHash01(gesture, 16647) * 6.2831853f + local * 0.98f)
                    + 0.50f * mutation * (float)Math.sin(stableHash01(gesture, 16651) * 6.2831853f + local * 9.4f);
        }

        private float v166CameraFov(float local, int gesture, float minDim) {
            float mutation = v166MutationPulse(local, gesture);
            float f = 0.90f + 0.10f * (float)Math.sin(stableHash01(gesture, 16653) * 6.2831853f + local * 0.92f);
            f -= 0.13f * mutation;
            return minDim * clamp(f, 0.58f, 1.08f);
        }

        private void drawV166PolymorphicString(int gesture, float local, float tail, float head,
                                               float cx, float cy, float angle, float scale, float cameraFov,
                                               float[] color, float[] cyan, float[] hot, float alpha, boolean echo) {
            if (alpha <= 0.001f) return;
            int samples = cfg.powerSave ? 48 : 78;
            float minD = Math.max(1f, Math.min(width, height));
            float mutation = v166MutationPulse(local, gesture);
            float baseWidth = Math.max(0.32f, minD * (0.00145f + 0.00105f * cfg.ribbonWidth));
            int lanes = echo ? 1 : (cfg.powerSave ? 3 : (mutation > 0.34f ? 5 : 3));
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : lerp(-1f, 1f, i / Math.max(1f, lanes - 1f));
                if (lanes == 3 && i == 1) lane = 0f;
                ArrayList<float[]> line = buildV166ProjectedCurve(gesture, local, tail, head, lane,
                        cx, cy, angle, scale, cameraFov, samples);
                if (line.size() < 2) continue;
                float laneWeight = 1f - 0.60f * Math.abs(lane);
                float w = baseWidth * (echo ? 0.26f : (lane == 0f ? (1.28f + 0.36f * mutation) : (0.44f + 0.34f * mutation)));
                float a = alpha * (echo ? 0.070f : (lane == 0f ? 0.360f : 0.130f * (0.74f + mutation))) * laneWeight;
                drawAgeFadedStrip(line, Math.max(0.014f, w), color[0], color[1], color[2], a, 1.04f, echo ? 0.06f : 0.46f);
                if (!echo && lane == 0f) {
                    drawAgeFadedStrip(line, Math.max(0.012f, baseWidth * 0.060f),
                            0.94f, 1.00f, 1.00f, alpha * (0.092f + 0.052f * mutation), 1.08f, 0.70f);
                }
            }
            if (!echo && mutation > 0.56f) {
                drawV166MutationFieldThreads(gesture, local, tail, head, cx, cy, angle, scale, cameraFov,
                        color, cyan, alpha * 1.15f, samples);
            }
        }

        private ArrayList<float[]> buildV166ProjectedCurve(int gesture, float local, float tail, float head, float lane,
                                                           float cx, float cy, float angle, float scale, float cameraFov,
                                                           int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            int count = 8;
            float[][] ctl = new float[count][3];
            for (int i = 0; i < count; i++) {
                float u = i / Math.max(1f, count - 1f);
                ctl[i] = v166AutonomousControlPoint(gesture, local, u, lane, scale);
            }
            float mutation = v166MutationPulse(local, gesture);
            float yaw = angle + 0.070f * (float)Math.sin(local * 2.0f + stableHash01(gesture, 16655) * 6.2831853f);
            float roll = (0.15f + 0.24f * mutation) * (float)Math.sin(local * 1.55f + stableHash01(gesture, 16657) * 6.2831853f) * waveEnvelope(local);
            float pitch = (0.10f + 0.16f * mutation) * (float)Math.sin(local * 1.85f + stableHash01(gesture, 16659) * 6.2831853f) * waveEnvelope(local);
            for (int s = 0; s < samples; s++) {
                float q = s / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float pos = u * (count - 1f);
                int i1 = clampInt((int)Math.floor(pos), 0, count - 1);
                float t = smoother(pos - i1);
                int i0 = clampInt(i1 - 1, 0, count - 1);
                int i2 = clampInt(i1 + 1, 0, count - 1);
                int i3 = clampInt(i1 + 2, 0, count - 1);
                float[] p3 = catmullRomPoint3(ctl[i0], ctl[i1], ctl[i2], ctl[i3], t);
                float[] pr = projectMystify3dPoint(p3[0], p3[1], p3[2], yaw, roll, pitch, cameraFov);
                out.add(new float[]{cx + pr[0], cy + pr[1]});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private float[] v166AutonomousControlPoint(int gesture, float local, float u, float lane, float scale) {
            float style = local * (7.2f + 1.4f * stableHash01(gesture, 16661)) + u * (1.40f + 0.50f * stableHash01(gesture, 16663)) + stableHash01(gesture, 16665) * 4.0f;
            int step = (int)Math.floor(style);
            float f = fract(style);
            // 保持—突变—保持：不是一直匀速变，而是在过渡段突然显著变身。
            float mix = smoother(clamp((f - 0.26f) / 0.42f, 0f, 1f));
            int modeA = v166ModeForStep(gesture, step);
            int modeB = v166ModeForStep(gesture, step + 1);
            float[] a = v166ControlPointForMode(modeA, gesture, local, u, scale);
            float[] b = v166ControlPointForMode(modeB, gesture, local, u, scale);
            float mutation = v166MutationPulse(local, gesture);
            float mx = lerp(a[0], b[0], mix);
            float my = lerp(a[1], b[1], mix);
            float mz = lerp(a[2], b[2], mix);
            float env = waveEnvelope(u);
            float ph = stableHash01(gesture, 16667) * 6.2831853f;
            // 在变身节拍处增加非模板的即兴力场，使形态不是简单 modeA/modeB 展示。
            my += scale * mutation * env * 0.20f * (float)Math.sin(ph + local * 12.0f + u * 9.0f);
            mz += scale * mutation * env * 0.14f * (float)Math.cos(ph * 0.7f + local * 10.0f + u * 11.0f);
            my += lane * scale * (0.012f + 0.055f * env * (0.35f + mutation));
            return new float[]{mx, my, mz};
        }

        private int v166ModeForStep(int gesture, int step) {
            float r = fract(step * 0.6180339887f + stableHash01(gesture + step * 13, 16671) * 0.83f + stableHash01(gesture, 16673) * 0.29f);
            return clampInt((int)Math.floor(r * 12.0f), 0, 11);
        }

        private float[] v166ControlPointForMode(int mode, int gesture, float local, float u, float scale) {
            float t = u - 0.5f;
            float env = waveEnvelope(u);
            float ph0 = stableHash01(gesture + mode * 17, 16681) * 6.2831853f;
            float ph1 = stableHash01(gesture + mode * 19, 16683) * 6.2831853f;
            float x, y, z;
            switch (mode) {
                case 0: // 极简长弧
                    x = scale * t * 0.92f;
                    y = scale * (0.10f * (float)Math.sin(ph0 + u * 3.1415926f) + 0.18f * (float)Math.sin(Math.PI * u)) * env;
                    z = scale * 0.08f * (float)Math.cos(ph1 + u * 3.5f + local * 1.2f) * env;
                    break;
                case 1: // S 形书写
                    x = scale * t * 0.82f;
                    y = scale * (float)Math.sin(t * 6.2831853f + ph0 + local * 1.4f) * 0.34f * env;
                    z = scale * 0.10f * (float)Math.sin(u * 6.2831853f + ph1) * env;
                    break;
                case 2: // 扇形展开
                    x = scale * t * (0.52f + 0.55f * u);
                    y = scale * (t * 0.80f + 0.14f * (float)Math.sin(ph0 + u * 6.2831853f)) * env;
                    z = scale * (0.16f * (u - 0.5f) + 0.07f * (float)Math.sin(ph1 + local)) * env;
                    break;
                case 3: // 回环 / 半闭合空间弧
                    float theta = ph0 + u * (4.2f + 1.1f * (float)Math.sin(local * 1.3f));
                    x = scale * (0.34f * (float)Math.cos(theta) * env + t * 0.25f);
                    y = scale * (0.40f * (float)Math.sin(theta) * env);
                    z = scale * 0.20f * (float)Math.cos(theta + ph1) * env;
                    break;
                case 4: // 翼面 / 花瓣
                    x = scale * t * (0.72f + 0.18f * (float)Math.sin(ph0 + local));
                    y = scale * (0.50f * env * (1f - 0.25f * u) * (stableHash01(gesture, 16691) < 0.5f ? -1f : 1f)
                            + 0.08f * (float)Math.sin(ph1 + u * 5.0f)) * env;
                    z = scale * 0.12f * (float)Math.sin(ph0 + u * 4.0f + local) * env;
                    break;
                case 5: // 钩形回扫
                    x = scale * (t * 0.72f - 0.24f * (float)Math.pow(u, 1.8f));
                    y = scale * ((float)Math.pow(u, 1.55f) * 0.62f - 0.30f + 0.10f * (float)Math.sin(ph0 + u * 8.0f)) * env;
                    z = scale * 0.10f * (float)Math.cos(ph1 + u * 5.0f + local) * env;
                    break;
                case 6: // 波浪场线
                    x = scale * t * 0.86f;
                    y = scale * (0.30f * (float)Math.sin(ph0 + u * 12.566f + local * 2.0f) + 0.14f * (float)Math.sin(ph1 + u * 25.0f)) * env;
                    z = scale * 0.12f * (float)Math.sin(ph1 + u * 8.0f) * env;
                    break;
                case 7: // 喷泉式扩散
                    x = scale * t * (0.30f + 1.20f * u);
                    y = scale * (0.62f * (u - 0.16f) * (u - 0.16f) - 0.20f + 0.10f * (float)Math.sin(ph0 + u * 5.0f)) * env;
                    z = scale * (0.18f * (u - 0.5f) + 0.08f * (float)Math.sin(ph1 + local * 1.5f)) * env;
                    break;
                case 8: // 叶片 / split leaf
                    x = scale * t * (0.70f + 0.28f * env);
                    y = scale * (0.44f * env * (u < 0.55f ? -0.45f : 1.0f) + 0.16f * (float)Math.sin(ph0 + u * 4.0f)) * env;
                    z = scale * 0.14f * (float)Math.cos(ph1 + u * 4.5f + local) * env;
                    break;
                case 9: // 螺旋绞索
                    float th = ph0 + u * 13.0f + local * 2.4f;
                    x = scale * (t * 0.58f + 0.15f * (float)Math.cos(th) * env);
                    y = scale * (0.30f * (float)Math.sin(th) * env);
                    z = scale * (0.26f * (float)Math.cos(th + 1.2f) * env);
                    break;
                case 10: // 刀锋丝带
                    x = scale * t * (0.40f + 1.05f * u);
                    y = scale * (0.50f * env * (1f - u) + 0.08f * (float)Math.sin(ph0 + u * 6.0f)) * (stableHash01(gesture, 16695) < 0.5f ? -1f : 1f);
                    z = scale * 0.08f * (float)Math.sin(ph1 + u * 7.0f) * env;
                    break;
                default: // 星芒/突刺，但保持曲线插值
                    x = scale * t * (0.78f + 0.20f * (float)Math.sin(ph0 + u * 18.0f));
                    y = scale * (0.18f * (float)Math.sin(ph1 + u * 18.0f) + 0.38f * env * (u > 0.62f ? (u - 0.62f) * 2.6f : 0f));
                    z = scale * 0.18f * (float)Math.cos(ph0 + u * 10.0f + local) * env;
                    break;
            }
            return new float[]{x, y, z};
        }

        private void drawV166MutationFieldThreads(int gesture, float local, float tail, float head,
                                                  float cx, float cy, float angle, float scale, float cameraFov,
                                                  float[] color, float[] cyan, float alpha, int samples) {
            int count = cfg.powerSave ? 2 : 4;
            for (int i = 0; i < count; i++) {
                float lane = lerp(-0.82f, 0.82f, i / Math.max(1f, count - 1f));
                float t0 = clamp(tail + 0.06f + 0.065f * i, tail, head);
                float t1 = clamp(head - 0.030f * i, t0 + 0.02f, head);
                ArrayList<float[]> line = buildV166ProjectedCurve(gesture + 41 + i * 11, local - 0.011f * i,
                        t0, t1, lane, cx, cy, angle, scale, cameraFov, Math.max(12, samples / 2));
                if (line.size() >= 2) {
                    drawAgeFadedStrip(line, Math.max(0.18f, scale * 0.00055f), cyan[0], cyan[1], cyan[2], alpha * 0.115f, 1.00f, 0.34f);
                }
            }
        }

        private void drawV166MutationBranches(int gesture, float local, float tail, float head,
                                              float cx, float cy, float angle, float scale, float cameraFov,
                                              float[] color, float[] cyan, float[] hot, float alpha, float mutation) {
            if (mutation <= 0.12f || alpha <= 0.001f) return;
            ArrayList<float[]> main = buildV166ProjectedCurve(gesture, local, tail, head, 0f,
                    cx, cy, angle, scale, cameraFov, cfg.powerSave ? 42 : 68);
            if (main.size() < 5) return;
            int branches = cfg.powerSave ? 1 : (mutation > 0.62f ? 3 : 2);
            for (int b = 0; b < branches; b++) {
                float anchorU = clamp(head - 0.07f - 0.095f * b, tail + 0.045f, head - 0.012f);
                float idxF = (anchorU - tail) / Math.max(0.001f, head - tail) * (main.size() - 1);
                int idx = clampInt((int)idxF, 1, main.size() - 2);
                float[] p0 = main.get(idx);
                float[] pm = main.get(idx - 1);
                float[] pp = main.get(idx + 1);
                float dx = pp[0] - pm[0], dy = pp[1] - pm[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float tx = dx / dl, ty = dy / dl;
                float nx = -ty, ny = tx;
                float side = ((stableHash01(gesture + b * 17, 16697) < 0.5f) ? -1f : 1f);
                float len = scale * (0.10f + 0.18f * mutation) * (1f - 0.20f * b);
                float ctrlX = p0[0] + tx * len * 0.30f + nx * side * len * (0.36f + 0.20f * mutation);
                float ctrlY = p0[1] + ty * len * 0.30f + ny * side * len * (0.36f + 0.20f * mutation);
                float endX = p0[0] + tx * len * (0.48f + 0.12f * b) + nx * side * len * (0.90f + 0.22f * stableHash01(gesture, 16699 + b));
                float endY = p0[1] + ty * len * (0.48f + 0.12f * b) + ny * side * len * (0.90f + 0.22f * stableHash01(gesture, 16703 + b));
                ArrayList<float[]> branch = buildQuadraticCurve(p0[0], p0[1], ctrlX, ctrlY, endX, endY, cfg.powerSave ? 12 : 22);
                float a = alpha * (0.190f + 0.135f * mutation) * (1f - 0.22f * b);
                drawAgeFadedStrip(branch, Math.max(0.24f, scale * 0.00085f), cyan[0], cyan[1], cyan[2], a, 1.04f, 0.58f);
                drawAgeFadedStrip(branch, Math.max(0.13f, scale * 0.00036f), 0.96f, 1.00f, 1.00f, a * 0.60f, 1.08f, 0.78f);
                drawEllipse(endX, endY, Math.max(0.52f, scale * 0.0027f), Math.max(0.22f, scale * 0.0011f), angle,
                        hot[0], hot[1], hot[2], alpha * mutation * 0.120f, 12);
            }
        }

        private void drawV166BrushTip(int gesture, float local, float head,
                                      float cx, float cy, float angle, float scale, float cameraFov,
                                      float[] hot, float alpha, float mutation) {
            if (head <= 0.018f || alpha <= 0.001f) return;
            ArrayList<float[]> tipCurve = buildV166ProjectedCurve(gesture, local, Math.max(0f, head - 0.010f), head, 0f,
                    cx, cy, angle, scale, cameraFov, 5);
            if (tipCurve.isEmpty()) return;
            float[] p = tipCurve.get(tipCurve.size() - 1);
            float tipLife = 1f - smoother(clamp((local - 0.868f) / 0.10f, 0f, 1f));
            drawEllipse(p[0], p[1], Math.max(1.60f, scale * (0.0060f + 0.0038f * mutation)), Math.max(0.68f, scale * 0.0026f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * (0.150f + 0.082f * mutation), 18);
        }


        private void drawReferenceVideoTimePainterV165(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V165：针对“单一固定形状、缺少分叉/突变、缺少顿挫、运动不丝滑”的问题。
            // 保留 Windows/Mystify 式少量控制点光弦，但加入：
            // 1) beat pulse：有节奏的顿挫、加速、舒张；
            // 2) branch flare：从当前光弦局部突然分叉，但仍贴附于主弦，不是独立主体；
            // 3) mutation field：控制点在脉冲期间发生大幅拓扑扭转，形成重大变异；
            // 4) smooth-eased center/camera：中心与透视只做连续缓动，减少“寸步难行”的卡顿感。
            float local = clamp(raw, 0f, 0.999f);
            float life = v165PhraseLife(local);
            if (life <= 0.002f) return;
            float pulse = v165BeatPulse(local, gesture);
            float head = v165Head(local, gesture);
            float tail = v165Tail(local, head, pulse);
            if (head <= tail + 0.018f) {
                float[] c = v165Center(gesture, local, minDim);
                drawEllipse(c[0], c[1], minDim * 0.0042f, minDim * 0.0017f, v165Angle(gesture, local),
                        hot[0], hot[1], hot[2], alpha * life * 0.048f, 16);
                return;
            }

            float[] center = v165Center(gesture, local, minDim);
            float scale = minDim * (0.42f + 0.18f * stableHash01(gesture, 16501)) * (1f + 0.08f * pulse);
            float angle = v165Angle(gesture, local);
            float camera = v165CameraFov(local, gesture, minDim);
            float hue = fract(0.51f + stableHash01(gesture, 16503) * 0.24f + local * (0.048f + 0.020f * pulse));
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 1.00f, true);

            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes; e >= 1; e--) {
                float oldLocal = local - e * (0.060f + 0.020f * pulse);
                if (oldLocal <= 0.025f) continue;
                float oldLife = v165PhraseLife(oldLocal);
                if (oldLife <= 0.004f) continue;
                float oldPulse = v165BeatPulse(oldLocal, gesture);
                float oldHead = v165Head(oldLocal, gesture);
                float oldTail = v165Tail(oldLocal, oldHead, oldPulse);
                if (oldHead <= oldTail + 0.020f) continue;
                float[] oc = v165Center(gesture, oldLocal, minDim);
                drawV165AutonomousString(gesture, oldLocal, oldTail, oldHead, oc[0], oc[1],
                        v165Angle(gesture, oldLocal), scale, v165CameraFov(oldLocal, gesture, minDim),
                        color, cyan, hot, alpha * oldLife * (0.014f / e), true);
            }

            drawV165AutonomousString(gesture, local, tail, head, center[0], center[1], angle, scale, camera,
                    color, cyan, hot, alpha * life, false);
            drawV165BranchFlares(gesture, local, tail, head, center[0], center[1], angle, scale, camera,
                    color, cyan, hot, alpha * life, pulse);
            drawV165BrushTip(gesture, local, head, center[0], center[1], angle, scale, camera, hot, alpha * life);
        }

        private float v165PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.010f) / 0.115f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.885f) / 0.105f, 0f, 1f));
            return appear * vanish;
        }

        private float v165BeatPulse(float local, int gesture) {
            // 三个“顿挫点”：不是硬跳，而是快速蓄势、突然展开、柔和退回。
            float p0 = 0.20f + 0.045f * stableHash01(gesture, 16511);
            float p1 = 0.47f + 0.055f * stableHash01(gesture, 16513);
            float p2 = 0.72f + 0.050f * stableHash01(gesture, 16517);
            float b0 = v165PulseAt(local, p0, 0.055f);
            float b1 = v165PulseAt(local, p1, 0.070f);
            float b2 = v165PulseAt(local, p2, 0.060f);
            return clamp(Math.max(b0, Math.max(b1, b2)), 0f, 1f);
        }

        private float v165PulseAt(float x, float center, float radius) {
            float d = Math.abs(x - center) / Math.max(0.001f, radius);
            if (d >= 1f) return 0f;
            float v = 1f - d;
            return smoother(v);
        }

        private float v165Head(float local, int gesture) {
            float raw = clamp((local - 0.008f) / 0.812f, 0f, 1f);
            float pulse = v165BeatPulse(local, gesture);
            float h = smoother(raw);
            // 脉冲期间头部会“提笔一顿后快速探出”，体现顿挫，而不是匀速爬行。
            h += 0.030f * pulse * waveEnvelope(raw);
            h += 0.007f * (float)Math.sin(stableHash01(gesture, 16519) * 6.2831853f + local * 9.0f) * waveEnvelope(raw);
            return clamp(h, 0f, 1f);
        }

        private float v165Tail(float local, float head, float pulse) {
            float chase = smoother(clamp((local - 0.125f) / 0.600f, 0f, 1f));
            float window = lerp(0.50f, 0.24f, chase);
            // 顿挫时尾部略追近，让旧痕迹产生“收束/消失”节奏。
            window *= (1f - 0.18f * pulse);
            float dissolvePush = 0.090f * smoother(clamp((local - 0.735f) / 0.155f, 0f, 1f));
            return clamp(head - window + dissolvePush, 0f, Math.max(0f, head - 0.050f));
        }

        private float[] v165Center(int gesture, float local, float minDim) {
            float sx = stableHash01(gesture, 16521);
            float sy = stableHash01(gesture, 16523);
            float x = width * (0.18f + 0.62f * sx);
            float y = height * (0.20f + 0.50f * sy);
            float drift = minDim * 0.030f * waveEnvelope(local);
            float ph = stableHash01(gesture, 16525) * 6.2831853f;
            // 使用低频连续漂移，避免整体运动卡顿或寸步难行。
            x += drift * (float)Math.sin(ph + local * 1.20f) + drift * 0.36f * (float)Math.sin(ph * 0.7f + local * 2.05f);
            y += drift * 0.62f * (float)Math.cos(ph * 0.8f + local * 1.05f);
            return new float[]{clamp(x, width * 0.14f, width * 0.86f), clamp(y, height * 0.18f, height * 0.76f)};
        }

        private float v165Angle(int gesture, float local) {
            float base = stableHash01(gesture, 16527) * 6.2831853f;
            float pulse = v165BeatPulse(local, gesture);
            // 顿挫时角度有明显但平滑的转向，产生“突然重大变异”的来源之一。
            return base
                    + 0.22f * (float)Math.sin(stableHash01(gesture, 16529) * 6.2831853f + local * 1.35f)
                    + 0.38f * pulse * (float)Math.sin(stableHash01(gesture, 16531) * 6.2831853f + local * 8.0f);
        }

        private float v165CameraFov(float local, int gesture, float minDim) {
            float pulse = v165BeatPulse(local, gesture);
            float f = 0.88f + 0.12f * (float)Math.sin(stableHash01(gesture, 16533) * 6.2831853f + local * 1.28f);
            // 脉冲时略近，让突变有“扑面/开合”的屏保节奏。
            f -= 0.10f * pulse;
            return minDim * clamp(f, 0.62f, 1.10f);
        }

        private void drawV165AutonomousString(int gesture, float local, float tail, float head,
                                              float cx, float cy, float angle, float scale, float cameraFov,
                                              float[] color, float[] cyan, float[] hot, float alpha, boolean echo) {
            if (alpha <= 0.001f) return;
            int samples = cfg.powerSave ? 42 : 70;
            float minD = Math.max(1f, Math.min(width, height));
            float pulse = v165BeatPulse(local, gesture);
            float baseWidth = Math.max(0.09f, minD * (0.00070f + 0.00046f * cfg.ribbonWidth));
            float openness = v165ShapeOpenness(local, gesture);
            int lanes = echo ? 1 : (openness + pulse > 0.78f ? (cfg.powerSave ? 2 : 3) : 1);
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : lerp(-1f, 1f, i / Math.max(1f, lanes - 1f));
                if (lanes == 3 && i == 1) lane = 0f;
                ArrayList<float[]> line = buildV165ProjectedCurve(gesture, local, tail, head, lane,
                        cx, cy, angle, scale, cameraFov, samples);
                if (line.size() < 2) continue;
                float laneWeight = 1f - 0.56f * Math.abs(lane);
                float w = baseWidth * (echo ? 0.15f : (lane == 0f ? (0.62f + 0.18f * pulse) : 0.18f));
                float a = alpha * (echo ? 0.026f : (lane == 0f ? 0.126f : 0.030f * (openness + 0.6f * pulse))) * laneWeight;
                drawAgeFadedStrip(line, Math.max(0.014f, w), color[0], color[1], color[2], a, 1.04f, echo ? 0.06f : 0.42f);
                if (!echo && lane == 0f) {
                    drawAgeFadedStrip(line, Math.max(0.012f, baseWidth * 0.058f),
                            0.94f, 1.00f, 1.00f, alpha * (0.030f + 0.020f * pulse), 1.08f, 0.58f);
                }
            }
            if (!echo && openness > 0.74f) {
                drawV165SparseFieldThreads(gesture, local, tail, head, cx, cy, angle, scale, cameraFov,
                        color, cyan, alpha * 0.70f, samples);
            }
        }

        private ArrayList<float[]> buildV165ProjectedCurve(int gesture, float local, float tail, float head, float lane,
                                                           float cx, float cy, float angle, float scale, float cameraFov,
                                                           int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            int count = 7;
            float[][] ctl = new float[count][3];
            for (int i = 0; i < count; i++) {
                float u = i / Math.max(1f, count - 1f);
                ctl[i] = v165AutonomousControlPoint(gesture, local, u, lane, scale);
            }
            float pulse = v165BeatPulse(local, gesture);
            float yaw = angle + 0.080f * (float)Math.sin(local * 3.0f + stableHash01(gesture, 16535) * 6.2831853f);
            float roll = (0.17f + 0.18f * pulse) * (float)Math.sin(local * 1.95f + stableHash01(gesture, 16537) * 6.2831853f) * waveEnvelope(local);
            float pitch = (0.11f + 0.12f * pulse) * (float)Math.sin(local * 2.35f + stableHash01(gesture, 16539) * 6.2831853f) * waveEnvelope(local);
            for (int s = 0; s < samples; s++) {
                float q = s / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float pos = u * (count - 1f);
                int i1 = clampInt((int)Math.floor(pos), 0, count - 1);
                float t = smoother(pos - i1);
                int i0 = clampInt(i1 - 1, 0, count - 1);
                int i2 = clampInt(i1 + 1, 0, count - 1);
                int i3 = clampInt(i1 + 2, 0, count - 1);
                float[] p3 = catmullRomPoint3(ctl[i0], ctl[i1], ctl[i2], ctl[i3], t);
                float[] pr = projectMystify3dPoint(p3[0], p3[1], p3[2], yaw, roll, pitch, cameraFov);
                out.add(new float[]{cx + pr[0], cy + pr[1]});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private float[] v165AutonomousControlPoint(int gesture, float local, float u, float lane, float scale) {
            float env = waveEnvelope(u);
            float pulse = v165BeatPulse(local, gesture);
            float ph0 = stableHash01(gesture, 16541) * 6.2831853f;
            float ph1 = stableHash01(gesture, 16543) * 6.2831853f;
            float ph2 = stableHash01(gesture, 16545) * 6.2831853f;
            float curl = (float)Math.sin(ph0 + local * 2.00f) * 0.52f
                    + (float)Math.sin(ph1 + local * 4.20f + u * 2.6f) * 0.24f
                    + pulse * (float)Math.sin(ph2 + u * 7.1f + local * 10.0f) * 0.62f;
            float spread = smoother(clamp((float)Math.sin(ph1 + local * 2.65f) * 0.5f + 0.5f + 0.52f * pulse, 0f, 1f));
            float loop = smoother(clamp((float)Math.sin(ph2 + local * 2.25f + 0.7f) * 0.5f + 0.5f + 0.35f * pulse, 0f, 1f));
            float wing = smoother(clamp((float)Math.sin(ph0 * 0.6f + local * 1.62f + 1.4f) * 0.5f + 0.5f + 0.30f * pulse, 0f, 1f));
            float x = scale * (u - 0.5f) * (0.70f + 0.20f * wing + 0.12f * pulse * (float)Math.sin(u * 6.2831853f + ph1));
            float baseWave = (float)Math.sin(ph0 + u * 5.2f + local * 2.1f) * 0.18f;
            float sCurve = (float)Math.sin((u - 0.5f) * 3.1415926f) * curl * 0.36f;
            float fan = (u - 0.5f) * spread * (0.38f + 0.22f * pulse);
            float petal = (float)Math.sin(Math.PI * u) * (float)Math.sin(ph2 + local * 2.4f) * wing * (0.30f + 0.18f * pulse);
            float loopY = (float)Math.cos((u * 1.18f + local * 0.22f) * 6.2831853f + ph1) * loop * env * (0.20f + 0.18f * pulse);
            float split = pulse * env * (u > 0.60f ? (u - 0.60f) * 2.4f : 0f) * (stableHash01(gesture, 16547) < 0.5f ? -1f : 1f);
            float y = scale * (baseWave + sCurve + fan + petal + loopY + split * 0.22f) * env;
            y += lane * scale * (0.012f + 0.048f * env * (v165ShapeOpenness(local, gesture) + 0.45f * pulse));
            float z = scale * (0.11f * (float)Math.cos(ph2 + u * 3.8f + local * 1.9f) * env
                    + 0.10f * loop * (float)Math.sin(u * 6.2831853f + ph0 + local)
                    + 0.12f * pulse * env * (float)Math.sin(ph1 + u * 10.0f));
            return new float[]{x, y, z};
        }

        private float v165ShapeOpenness(float local, int gesture) {
            float a = stableHash01(gesture, 16549) * 6.2831853f;
            float v = 0.5f + 0.5f * (float)Math.sin(a + local * 2.55f);
            return smoother(v) * waveEnvelope(local);
        }

        private void drawV165SparseFieldThreads(int gesture, float local, float tail, float head,
                                                float cx, float cy, float angle, float scale, float cameraFov,
                                                float[] color, float[] cyan, float alpha, int samples) {
            int count = cfg.powerSave ? 2 : 3;
            for (int i = 0; i < count; i++) {
                float lane = lerp(-0.72f, 0.72f, i / Math.max(1f, count - 1f));
                float t0 = clamp(tail + 0.08f + 0.10f * i, tail, head);
                float t1 = clamp(head - 0.04f * i, t0 + 0.02f, head);
                ArrayList<float[]> line = buildV165ProjectedCurve(gesture + 31 + i * 7, local - 0.016f * i,
                        t0, t1, lane, cx, cy, angle, scale, cameraFov, Math.max(12, samples / 2));
                if (line.size() >= 2) {
                    drawAgeFadedStrip(line, Math.max(0.010f, scale * 0.00018f), cyan[0], cyan[1], cyan[2], alpha * 0.020f, 1.00f, 0.12f);
                }
            }
        }

        private void drawV165BranchFlares(int gesture, float local, float tail, float head,
                                          float cx, float cy, float angle, float scale, float cameraFov,
                                          float[] color, float[] cyan, float[] hot, float alpha, float pulse) {
            if (pulse <= 0.10f || alpha <= 0.001f) return;
            ArrayList<float[]> main = buildV165ProjectedCurve(gesture, local, tail, head, 0f,
                    cx, cy, angle, scale, cameraFov, cfg.powerSave ? 36 : 60);
            if (main.size() < 5) return;
            int branches = cfg.powerSave ? 1 : 2;
            for (int b = 0; b < branches; b++) {
                float anchorU = clamp(head - 0.10f - 0.13f * b, tail + 0.06f, head - 0.02f);
                float idxF = (anchorU - tail) / Math.max(0.001f, head - tail) * (main.size() - 1);
                int idx = clampInt((int)idxF, 1, main.size() - 2);
                float[] p0 = main.get(idx);
                float[] pm = main.get(idx - 1);
                float[] pp = main.get(idx + 1);
                float dx = pp[0] - pm[0], dy = pp[1] - pm[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float tx = dx / dl, ty = dy / dl;
                float nx = -ty, ny = tx;
                float side = ((stableHash01(gesture + b * 17, 16561) < 0.5f) ? -1f : 1f);
                float len = scale * (0.08f + 0.16f * pulse) * (1f - 0.20f * b);
                float ctrlX = p0[0] + tx * len * 0.34f + nx * side * len * 0.40f;
                float ctrlY = p0[1] + ty * len * 0.34f + ny * side * len * 0.40f;
                float endX = p0[0] + tx * len * (0.52f + 0.14f * b) + nx * side * len * (0.82f + 0.20f * stableHash01(gesture, 16563 + b));
                float endY = p0[1] + ty * len * (0.52f + 0.14f * b) + ny * side * len * (0.82f + 0.20f * stableHash01(gesture, 16567 + b));
                ArrayList<float[]> branch = buildQuadraticCurve(p0[0], p0[1], ctrlX, ctrlY, endX, endY, cfg.powerSave ? 12 : 22);
                float a = alpha * (0.055f + 0.050f * pulse) * (1f - 0.22f * b);
                drawAgeFadedStrip(branch, Math.max(0.018f, scale * 0.00055f), cyan[0], cyan[1], cyan[2], a, 1.04f, 0.48f);
                drawAgeFadedStrip(branch, Math.max(0.012f, scale * 0.00022f), 0.96f, 1.00f, 1.00f, a * 0.48f, 1.08f, 0.72f);
                drawEllipse(endX, endY, Math.max(0.52f, scale * 0.0028f), Math.max(0.22f, scale * 0.0012f), angle,
                        hot[0], hot[1], hot[2], alpha * pulse * 0.052f, 12);
            }
        }

        private void drawV165BrushTip(int gesture, float local, float head,
                                      float cx, float cy, float angle, float scale, float cameraFov,
                                      float[] hot, float alpha) {
            if (head <= 0.018f || alpha <= 0.001f) return;
            ArrayList<float[]> tipCurve = buildV165ProjectedCurve(gesture, local, Math.max(0f, head - 0.010f), head, 0f,
                    cx, cy, angle, scale, cameraFov, 5);
            if (tipCurve.isEmpty()) return;
            float[] p = tipCurve.get(tipCurve.size() - 1);
            float pulse = v165BeatPulse(local, gesture);
            float tipLife = 1f - smoother(clamp((local - 0.860f) / 0.11f, 0f, 1f));
            drawEllipse(p[0], p[1], Math.max(0.78f, scale * (0.0038f + 0.0020f * pulse)), Math.max(0.32f, scale * 0.0016f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * (0.050f + 0.040f * pulse), 16);
        }


        private void drawReferenceVideoTimePainterV164(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V164：对照参考视频再次修正 V163 的核心差距。
            // V163 仍然借用了 familyA/familyB 模板控制点，视觉上可能仍像“某个模板在变”。
            // V164 改成“自主控制点光弦”：控制点由连续变化的 curl/spread/loop/wing/field 系数驱动，
            // 不再从一个家族模板插值到另一个家族模板。这样更接近参考视频中“少数光弦在黑底中
            // 自己弯曲、呼吸、成熟、退隐”的时间绘画状态机。
            float local = clamp(raw, 0f, 0.999f);
            float life = v164PhraseLife(local);
            if (life <= 0.002f) return;
            float head = v164Head(local, gesture);
            float tail = v164Tail(local, head);
            if (head <= tail + 0.018f) {
                float[] c = v164Center(gesture, local, minDim);
                drawEllipse(c[0], c[1], minDim * 0.0032f, minDim * 0.0013f, v164Angle(gesture, local),
                        hot[0], hot[1], hot[2], alpha * life * 0.036f, 14);
                return;
            }

            float[] center = v164Center(gesture, local, minDim);
            float scale = minDim * (0.40f + 0.16f * stableHash01(gesture, 16401));
            float angle = v164Angle(gesture, local);
            float camera = v164CameraFov(local, gesture, minDim);
            float hue = fract(0.52f + stableHash01(gesture, 16403) * 0.20f + local * 0.036f);
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 0.98f, true);

            // 极淡同源时间切片：只留下“刚才的状态”，不复制完整主体，不叠成多个对象。
            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes; e >= 1; e--) {
                float oldLocal = local - e * 0.070f;
                if (oldLocal <= 0.025f) continue;
                float oldLife = v164PhraseLife(oldLocal);
                if (oldLife <= 0.004f) continue;
                float oldHead = v164Head(oldLocal, gesture);
                float oldTail = v164Tail(oldLocal, oldHead);
                if (oldHead <= oldTail + 0.020f) continue;
                float[] oc = v164Center(gesture, oldLocal, minDim);
                drawV164AutonomousString(gesture, oldLocal, oldTail, oldHead, oc[0], oc[1],
                        v164Angle(gesture, oldLocal), scale, v164CameraFov(oldLocal, gesture, minDim),
                        color, cyan, hot, alpha * oldLife * (0.018f / e), true);
            }

            drawV164AutonomousString(gesture, local, tail, head, center[0], center[1], angle, scale, camera,
                    color, cyan, hot, alpha * life, false);
            drawV164BrushTip(gesture, local, head, center[0], center[1], angle, scale, camera, hot, alpha * life);
        }

        private float v164PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.012f) / 0.125f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.870f) / 0.120f, 0f, 1f));
            return appear * vanish;
        }

        private float v164Head(float local, int gesture) {
            float raw = clamp((local - 0.010f) / 0.805f, 0f, 1f);
            float h = smoother(raw);
            h += 0.012f * (float)Math.sin(stableHash01(gesture, 16405) * 6.2831853f + local * 4.8f) * waveEnvelope(raw);
            return clamp(h, 0f, 1f);
        }

        private float v164Tail(float local, float head) {
            // 比 V163 稍长一点，避免只剩一小截线；但尾部仍会追赶，让先画内容逐渐消失。
            float chase = smoother(clamp((local - 0.150f) / 0.610f, 0f, 1f));
            float window = lerp(0.48f, 0.26f, chase);
            float dissolvePush = 0.075f * smoother(clamp((local - 0.735f) / 0.165f, 0f, 1f));
            return clamp(head - window + dissolvePush, 0f, Math.max(0f, head - 0.058f));
        }

        private float[] v164Center(int gesture, float local, float minDim) {
            // 参考视频大留白：每段短句有自己的构图中心，但同一段内部只轻微漂移。
            float x = width * (0.18f + 0.62f * stableHash01(gesture, 16407));
            float y = height * (0.20f + 0.50f * stableHash01(gesture, 16409));
            float drift = minDim * 0.016f * waveEnvelope(local);
            float ph = stableHash01(gesture, 16411) * 6.2831853f;
            x += drift * (float)Math.sin(ph + local * 0.90f);
            y += drift * 0.55f * (float)Math.cos(ph * 0.8f + local * 0.82f);
            return new float[]{clamp(x, width * 0.14f, width * 0.86f), clamp(y, height * 0.18f, height * 0.76f)};
        }

        private float v164Angle(int gesture, float local) {
            float base = stableHash01(gesture, 16413) * 6.2831853f;
            return base + 0.13f * (float)Math.sin(stableHash01(gesture, 16415) * 6.2831853f + local * 1.10f);
        }

        private float v164CameraFov(float local, int gesture, float minDim) {
            float f = 0.88f + 0.12f * (float)Math.sin(stableHash01(gesture, 16417) * 6.2831853f + local * 1.22f);
            return minDim * clamp(f, 0.68f, 1.08f);
        }

        private void drawV164AutonomousString(int gesture, float local, float tail, float head,
                                              float cx, float cy, float angle, float scale, float cameraFov,
                                              float[] color, float[] cyan, float[] hot, float alpha, boolean echo) {
            if (alpha <= 0.001f) return;
            int samples = cfg.powerSave ? 36 : 62;
            float minD = Math.max(1f, Math.min(width, height));
            float baseWidth = Math.max(0.08f, minD * (0.00062f + 0.00042f * cfg.ribbonWidth));
            float widen = v164ShapeOpenness(local, gesture);
            int lanes = echo ? 1 : (widen > 0.62f ? (cfg.powerSave ? 2 : 3) : 1);
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : lerp(-1f, 1f, i / Math.max(1f, lanes - 1f));
                if (lanes == 3 && i == 1) lane = 0f;
                ArrayList<float[]> line = buildV164ProjectedCurve(gesture, local, tail, head, lane,
                        cx, cy, angle, scale, cameraFov, samples);
                if (line.size() < 2) continue;
                float laneWeight = 1f - 0.58f * Math.abs(lane);
                float w = baseWidth * (echo ? 0.16f : (lane == 0f ? 0.55f : 0.17f));
                float a = alpha * (echo ? 0.032f : (lane == 0f ? 0.112f : 0.026f * widen)) * laneWeight;
                drawAgeFadedStrip(line, Math.max(0.014f, w), color[0], color[1], color[2], a, 1.04f, echo ? 0.08f : 0.40f);
                if (!echo && lane == 0f) {
                    drawAgeFadedStrip(line, Math.max(0.012f, baseWidth * 0.052f),
                            0.94f, 1.00f, 1.00f, alpha * 0.028f, 1.08f, 0.54f);
                }
            }
            // 只在“开放”时补极少几根内侧线，避免 V155/V154 的乱线团。
            if (!echo && widen > 0.72f) {
                drawV164SparseFieldThreads(gesture, local, tail, head, cx, cy, angle, scale, cameraFov,
                        color, cyan, alpha * 0.70f, samples);
            }
        }

        private ArrayList<float[]> buildV164ProjectedCurve(int gesture, float local, float tail, float head, float lane,
                                                           float cx, float cy, float angle, float scale, float cameraFov,
                                                           int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            int count = 7;
            float[][] ctl = new float[count][3];
            for (int i = 0; i < count; i++) {
                float u = i / Math.max(1f, count - 1f);
                ctl[i] = v164AutonomousControlPoint(gesture, local, u, lane, scale);
            }
            float yaw = angle + 0.055f * (float)Math.sin(local * 2.9f + stableHash01(gesture, 16419) * 6.2831853f);
            float roll = 0.16f * (float)Math.sin(local * 1.8f + stableHash01(gesture, 16421) * 6.2831853f) * waveEnvelope(local);
            float pitch = 0.11f * (float)Math.sin(local * 2.2f + stableHash01(gesture, 16423) * 6.2831853f) * waveEnvelope(local);
            for (int s = 0; s < samples; s++) {
                float q = s / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float pos = u * (count - 1f);
                int i1 = clampInt((int)Math.floor(pos), 0, count - 1);
                float t = smoother(pos - i1);
                int i0 = clampInt(i1 - 1, 0, count - 1);
                int i2 = clampInt(i1 + 1, 0, count - 1);
                int i3 = clampInt(i1 + 2, 0, count - 1);
                float[] p3 = catmullRomPoint3(ctl[i0], ctl[i1], ctl[i2], ctl[i3], t);
                float[] pr = projectMystify3dPoint(p3[0], p3[1], p3[2], yaw, roll, pitch, cameraFov);
                out.add(new float[]{cx + pr[0], cy + pr[1]});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private float[] v164AutonomousControlPoint(int gesture, float local, float u, float lane, float scale) {
            // 连续生成系数：不是离散 family 模板，而是几个形变力场按时间自然此消彼长。
            float env = waveEnvelope(u);
            float ph0 = stableHash01(gesture, 16431) * 6.2831853f;
            float ph1 = stableHash01(gesture, 16433) * 6.2831853f;
            float ph2 = stableHash01(gesture, 16435) * 6.2831853f;
            float curl = (float)Math.sin(ph0 + local * 2.10f) * 0.58f + (float)Math.sin(ph1 + local * 4.00f + u * 2.5f) * 0.24f;
            float spread = smoother(clamp((float)Math.sin(ph1 + local * 2.75f) * 0.5f + 0.5f, 0f, 1f));
            float loop = smoother(clamp((float)Math.sin(ph2 + local * 2.35f + 0.7f) * 0.5f + 0.5f, 0f, 1f));
            float wing = smoother(clamp((float)Math.sin(ph0 * 0.6f + local * 1.65f + 1.4f) * 0.5f + 0.5f, 0f, 1f));
            float x = scale * (u - 0.5f) * (0.72f + 0.20f * wing);
            float baseWave = (float)Math.sin(ph0 + u * 5.3f + local * 2.2f) * 0.20f;
            float sCurve = (float)Math.sin((u - 0.5f) * 3.1415926f) * curl * 0.36f;
            float fan = (u - 0.5f) * spread * 0.42f;
            float petal = (float)Math.sin(Math.PI * u) * (float)Math.sin(ph2 + local * 2.4f) * wing * 0.34f;
            float loopY = (float)Math.cos((u * 1.15f + local * 0.20f) * 6.2831853f + ph1) * loop * env * 0.24f;
            float y = scale * (baseWave + sCurve + fan + petal + loopY) * env;
            // lane 只做少量轮廓偏移，不再生成宽膜面。
            y += lane * scale * (0.010f + 0.045f * env * v164ShapeOpenness(local, gesture));
            float z = scale * (0.10f * (float)Math.cos(ph2 + u * 3.8f + local * 1.9f) * env
                    + 0.08f * loop * (float)Math.sin(u * 6.2831853f + ph0 + local));
            return new float[]{x, y, z};
        }

        private float v164ShapeOpenness(float local, int gesture) {
            float a = stableHash01(gesture, 16437) * 6.2831853f;
            float v = 0.5f + 0.5f * (float)Math.sin(a + local * 2.55f);
            return smoother(v) * waveEnvelope(local);
        }

        private void drawV164SparseFieldThreads(int gesture, float local, float tail, float head,
                                                float cx, float cy, float angle, float scale, float cameraFov,
                                                float[] color, float[] cyan, float alpha, int samples) {
            int count = cfg.powerSave ? 2 : 3;
            for (int i = 0; i < count; i++) {
                float lane = lerp(-0.75f, 0.75f, i / Math.max(1f, count - 1f));
                float t0 = clamp(tail + 0.08f + 0.10f * i, tail, head);
                float t1 = clamp(head - 0.04f * i, t0 + 0.02f, head);
                ArrayList<float[]> line = buildV164ProjectedCurve(gesture + 31 + i * 7, local - 0.016f * i,
                        t0, t1, lane, cx, cy, angle, scale, cameraFov, Math.max(12, samples / 2));
                if (line.size() >= 2) {
                    drawAgeFadedStrip(line, Math.max(0.010f, scale * 0.00018f), cyan[0], cyan[1], cyan[2], alpha * 0.020f, 1.00f, 0.12f);
                }
            }
        }

        private void drawV164BrushTip(int gesture, float local, float head,
                                      float cx, float cy, float angle, float scale, float cameraFov,
                                      float[] hot, float alpha) {
            if (head <= 0.018f || alpha <= 0.001f) return;
            ArrayList<float[]> tipCurve = buildV164ProjectedCurve(gesture, local, Math.max(0f, head - 0.010f), head, 0f,
                    cx, cy, angle, scale, cameraFov, 4);
            if (tipCurve.isEmpty()) return;
            float[] p = tipCurve.get(tipCurve.size() - 1);
            float tipLife = 1f - smoother(clamp((local - 0.850f) / 0.12f, 0f, 1f));
            drawEllipse(p[0], p[1], Math.max(0.72f, scale * 0.0038f), Math.max(0.30f, scale * 0.0016f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.048f, 16);
        }




        private void drawReferenceVideoTimePainterV163(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V163：把 V162 的“家族模板形体”进一步改成参考视频式“轮廓光弦状态机”。
            // 关键策略：
            // - 一个短句只保留一条主光弦，不再画填充面；
            // - 形体由 3D 控制点的慢速微运动和头部家族倾向共同决定；
            // - 只画少量平行轮廓线和极淡同源历史切片，避免线团、膜面、预制形状感；
            // - 可见窗口变短，让先画部分更快退隐，形成“正在画”的过程。
            float local = clamp(raw, 0f, 0.999f);
            float life = v163PhraseLife(local);
            if (life <= 0.002f) return;
            float head = v163Head(local, gesture);
            float tail = v163Tail(local, head);
            if (head <= tail + 0.018f) {
                float[] c = v163Center(gesture, local, minDim);
                drawEllipse(c[0], c[1], minDim * 0.0038f, minDim * 0.0015f, v163Angle(gesture, local),
                        hot[0], hot[1], hot[2], alpha * life * 0.040f, 14);
                return;
            }
            float[] center = v163Center(gesture, local, minDim);
            float scale = minDim * (0.44f + 0.12f * stableHash01(gesture, 16301));
            float angle = v163Angle(gesture, local);
            float camera = v163CameraFov(local, gesture, minDim);
            int familyA = v162Family(gesture, 0);
            int familyB = v162Family(gesture, 1);
            float hue = fract(0.54f + 0.16f * stableHash01(gesture, 16303) + local * 0.050f);
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 0.98f, true);

            // 极淡历史切片：只画同源轮廓，不画完整面，不生成第二主体。
            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes; e >= 1; e--) {
                float oldLocal = local - e * 0.060f;
                if (oldLocal <= 0.020f) continue;
                float oldLife = v163PhraseLife(oldLocal);
                if (oldLife <= 0.004f) continue;
                float oldHead = v163Head(oldLocal, gesture);
                float oldTail = v163Tail(oldLocal, oldHead);
                if (oldHead <= oldTail + 0.020f) continue;
                float[] oc = v163Center(gesture, oldLocal, minDim);
                drawV163ContourString(gesture, oldLocal, oldTail, oldHead, oc[0], oc[1],
                        v163Angle(gesture, oldLocal), scale, v163CameraFov(oldLocal, gesture, minDim),
                        familyA, familyB, color, cyan, hot, alpha * oldLife * (0.020f / e), true);
            }

            drawV163ContourString(gesture, local, tail, head, center[0], center[1], angle, scale, camera,
                    familyA, familyB, color, cyan, hot, alpha * life, false);
            drawV163BrushTip(gesture, local, head, center[0], center[1], angle, scale, camera,
                    familyA, familyB, hot, alpha * life);
        }

        private float v163PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.010f) / 0.145f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.875f) / 0.115f, 0f, 1f));
            return appear * vanish;
        }

        private float v163Head(float local, int gesture) {
            float raw = clamp((local - 0.012f) / 0.80f, 0f, 1f);
            float h = smoother(raw);
            h += 0.010f * (float)Math.sin(stableHash01(gesture, 16309) * 6.2831853f + local * 5.1f) * waveEnvelope(raw);
            return clamp(h, 0f, 1f);
        }

        private float v163Tail(float local, float head) {
            // 窗口比 V162 更短：参考视频里通常是一个正在生成的光短句，而不是完整大形体长期停留。
            float chase = smoother(clamp((local - 0.18f) / 0.56f, 0f, 1f));
            float window = lerp(0.42f, 0.22f, chase);
            float dissolvePush = 0.08f * smoother(clamp((local - 0.72f) / 0.16f, 0f, 1f));
            return clamp(head - window + dissolvePush, 0f, Math.max(0f, head - 0.052f));
        }

        private float[] v163Center(int gesture, float local, float minDim) {
            float x = width * (0.20f + 0.58f * stableHash01(gesture, 16311));
            float y = height * (0.22f + 0.48f * stableHash01(gesture, 16313));
            float drift = minDim * 0.018f * waveEnvelope(local);
            float ph = stableHash01(gesture, 16317) * 6.2831853f;
            x += drift * (float)Math.sin(ph + local * 1.05f);
            y += drift * 0.58f * (float)Math.cos(ph * 0.7f + local * 0.92f);
            return new float[]{clamp(x, width * 0.16f, width * 0.84f), clamp(y, height * 0.18f, height * 0.74f)};
        }

        private float v163Angle(int gesture, float local) {
            float base = stableHash01(gesture, 16319) * 6.2831853f;
            return base + 0.10f * (float)Math.sin(stableHash01(gesture, 16321) * 6.2831853f + local * 1.18f);
        }

        private float v163CameraFov(float local, int gesture, float minDim) {
            float f = 0.88f + 0.11f * (float)Math.sin(stableHash01(gesture, 16323) * 6.2831853f + local * 1.35f);
            return minDim * clamp(f, 0.68f, 1.06f);
        }

        private void drawV163ContourString(int gesture, float local, float tail, float head,
                                           float cx, float cy, float angle, float scale, float cameraFov,
                                           int familyA, int familyB, float[] color, float[] cyan, float[] hot,
                                           float alpha, boolean echo) {
            int samples = cfg.powerSave ? 34 : 58;
            float minD = Math.max(1f, Math.min(width, height));
            float baseWidth = Math.max(0.08f, minD * (0.00062f + 0.00042f * cfg.ribbonWidth));
            float maturity = smoother(clamp((local - 0.060f) / 0.34f, 0f, 1f));
            if (alpha <= 0.001f) return;

            int lanes = echo ? 1 : v163LaneCount(familyA, familyB, local);
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : lerp(-1f, 1f, i / Math.max(1f, lanes - 1f));
                if (lanes == 3 && i == 1) lane = 0f;
                ArrayList<float[]> line = buildV163ProjectedCurve(gesture, local, tail, head, lane,
                        cx, cy, angle, scale, cameraFov, familyA, familyB, samples);
                if (line.size() < 2) continue;
                float laneWeight = 1f - 0.55f * Math.abs(lane);
                float w = baseWidth * (echo ? 0.18f : (lane == 0f ? 0.54f : 0.20f));
                float a = alpha * (echo ? 0.035f : (lane == 0f ? 0.105f : 0.030f * maturity)) * laneWeight;
                drawAgeFadedStrip(line, Math.max(0.014f, w), color[0], color[1], color[2], a, 1.06f, echo ? 0.08f : 0.42f);
                if (!echo && lane == 0f) {
                    drawAgeFadedStrip(line, Math.max(0.012f, baseWidth * 0.055f),
                            0.94f, 1.00f, 1.00f, alpha * 0.030f, 1.10f, 0.55f);
                }
            }
        }

        private int v163LaneCount(int familyA, int familyB, float local) {
            float mix = smoother(clamp((local - 0.44f) / 0.36f, 0f, 1f));
            int f = mix < 0.5f ? familyA : familyB;
            if (f == 1 || f == 4 || f == 5) return cfg.powerSave ? 2 : 4;
            if (f == 2) return cfg.powerSave ? 2 : 3;
            return 1;
        }

        private ArrayList<float[]> buildV163ProjectedCurve(int gesture, float local, float tail, float head, float lane,
                                                           float cx, float cy, float angle, float scale, float cameraFov,
                                                           int familyA, int familyB, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            int count = 6;
            float[][] ctl = new float[count][3];
            for (int i = 0; i < count; i++) {
                float u = i / Math.max(1f, count - 1f);
                ctl[i] = v163ControlPoint(gesture, local, u, lane, scale, familyA, familyB);
            }
            float yaw = angle + 0.06f * (float)Math.sin(local * 3.2f + stableHash01(gesture, 16331) * 6.2831853f);
            float roll = 0.18f * (float)Math.sin(local * 2.0f + stableHash01(gesture, 16333) * 6.2831853f) * waveEnvelope(local);
            float pitch = 0.12f * (float)Math.sin(local * 2.5f + stableHash01(gesture, 16337) * 6.2831853f) * waveEnvelope(local);
            for (int s = 0; s < samples; s++) {
                float q = s / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float pos = u * (count - 1f);
                int i1 = clampInt((int)Math.floor(pos), 0, count - 1);
                float t = smoother(pos - i1);
                int i0 = clampInt(i1 - 1, 0, count - 1);
                int i2 = clampInt(i1 + 1, 0, count - 1);
                int i3 = clampInt(i1 + 2, 0, count - 1);
                float[] p3 = catmullRomPoint3(ctl[i0], ctl[i1], ctl[i2], ctl[i3], t);
                float[] pr = projectMystify3dPoint(p3[0], p3[1], p3[2], yaw, roll, pitch, cameraFov);
                out.add(new float[]{cx + pr[0], cy + pr[1]});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private float[] v163ControlPoint(int gesture, float local, float u, float lane, float scale, int familyA, int familyB) {
            // 不是整段突然换家族：尾部偏 familyA，头部逐渐偏 familyB，中段平滑过渡。
            float front = smoother(clamp((u - 0.45f) / 0.38f, 0f, 1f));
            float timeGate = smoother(clamp((local - 0.34f) / 0.38f, 0f, 1f));
            float mix = clamp(front * timeGate, 0f, 1f);
            float[] a = v162ControlPointForFamily(familyA, gesture, local, u, 0f, scale, local * 1.7f);
            float[] b = v162ControlPointForFamily(familyB, gesture + 13, local, u, 0f, scale, local * 1.7f + 0.5f);
            float env = waveEnvelope(u);
            float laneWidth = scale * (0.010f + 0.044f * env * v163FamilyWidth(familyA, familyB, mix, local));
            float micro = scale * 0.018f * env * (float)Math.sin(stableHash01(gesture, 16341) * 6.2831853f + u * 7.0f + local * 3.1f);
            float x = lerp(a[0], b[0], mix);
            float y = lerp(a[1], b[1], mix) + lane * laneWidth + micro;
            float z = lerp(a[2], b[2], mix) + scale * 0.035f * env * (float)Math.cos(stableHash01(gesture, 16343) * 6.2831853f + u * 4.2f + local * 2.0f);
            return new float[]{x, y, z};
        }

        private float v163FamilyWidth(int familyA, int familyB, float mix, float local) {
            float wa = (familyA == 1 || familyA == 2 || familyA == 4 || familyA == 5) ? 1f : 0.30f;
            float wb = (familyB == 1 || familyB == 2 || familyB == 4 || familyB == 5) ? 1f : 0.30f;
            return lerp(wa, wb, mix) * smoother(clamp((local - 0.08f) / 0.36f, 0f, 1f));
        }

        private void drawV163BrushTip(int gesture, float local, float head,
                                      float cx, float cy, float angle, float scale, float cameraFov,
                                      int familyA, int familyB, float[] hot, float alpha) {
            if (head <= 0.018f || alpha <= 0.001f) return;
            ArrayList<float[]> tipCurve = buildV163ProjectedCurve(gesture, local, Math.max(0f, head - 0.008f), head, 0f,
                    cx, cy, angle, scale, cameraFov, familyA, familyB, 3);
            if (tipCurve.isEmpty()) return;
            float[] p = tipCurve.get(tipCurve.size() - 1);
            float tipLife = 1f - smoother(clamp((local - 0.850f) / 0.12f, 0f, 1f));
            drawEllipse(p[0], p[1], Math.max(0.82f, scale * 0.0046f), Math.max(0.34f, scale * 0.0019f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.050f, 16);
        }

        private void drawReferenceVideoTimePainterV162(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V162：对照参考视频后继续修 V161 的最大差距：V161 已经是“控制点光弦”，
            // 但还是太像一条数学曲线。参考视频更像“同一条光弦在时间中生长、成熟、
            // 头部试探下一种形态，尾部保留旧形态并退隐”。
            // 因此 V162 使用：有序 3D 控制点 + 头部渐变家族 + 局部宽度/纹理成熟度 + 极淡同源回声。
            float local = clamp(raw, 0f, 0.999f);
            float life = v162PhraseLife(local);
            if (life <= 0.002f) return;
            float head = v162Head(local);
            float tail = v162Tail(local, head);
            if (head <= tail + 0.028f) {
                float[] c = v162Center(gesture, local, minDim);
                float a = v162Angle(gesture, local);
                drawEllipse(c[0], c[1], minDim * 0.0046f, minDim * 0.0020f, a,
                        hot[0], hot[1], hot[2], alpha * life * 0.045f, 18);
                return;
            }
            float[] center = v162Center(gesture, local, minDim);
            float scale = minDim * (0.47f + 0.15f * stableHash01(gesture, 16201));
            float angle = v162Angle(gesture, local);
            float camera = v162CameraFov(local, gesture, minDim);
            float shapeT = v162ShapeTime(gesture, local);
            int familyA = v162Family(gesture, 0);
            int familyB = v162Family(gesture, 1);
            float[] color = mystifyPaletteFromHue(fract(0.53f + 0.18f * stableHash01(gesture, 16203) + local * 0.065f), mid, cyan, hot, 0.97f, true);

            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes; e >= 1; e--) {
                float oldLocal = local - e * 0.070f;
                if (oldLocal <= 0.018f) continue;
                float oldLife = v162PhraseLife(oldLocal);
                float oldHead = v162Head(oldLocal);
                float oldTail = v162Tail(oldLocal, oldHead);
                if (oldLife <= 0.006f || oldHead <= oldTail + 0.032f) continue;
                float[] oc = v162Center(gesture, oldLocal, minDim);
                drawV162MorphingGlyph(gesture, oldLocal, oldTail, oldHead, oc[0], oc[1],
                        v162Angle(gesture, oldLocal), scale, v162CameraFov(oldLocal, gesture, minDim),
                        shapeT - e * 0.18f, familyA, familyB, color, cyan, hot,
                        alpha * oldLife * (0.020f / e), true);
            }

            drawV162MorphingGlyph(gesture, local, tail, head, center[0], center[1], angle,
                    scale, camera, shapeT, familyA, familyB, color, cyan, hot, alpha * life, false);
            drawV162Tip(gesture, local, head, center[0], center[1], angle, scale, camera, shapeT,
                    familyA, familyB, hot, alpha * life);
        }

        private float v162PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.012f) / 0.16f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.890f) / 0.105f, 0f, 1f));
            return appear * vanish;
        }

        private float v162Head(float local) {
            float raw = clamp((local - 0.014f) / 0.78f, 0f, 1f);
            float h = smoother(raw);
            h += 0.012f * (float)Math.sin(local * 6.2831853f * 1.35f + 0.5f) * waveEnvelope(raw);
            return clamp(h, 0f, 1f);
        }

        private float v162Tail(float local, float head) {
            float chase = smoother(clamp((local - 0.245f) / 0.54f, 0f, 1f));
            float window = 0.66f - 0.38f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.080f));
        }

        private float[] v162Center(int gesture, float local, float minDim) {
            float baseX = width * (0.18f + 0.60f * stableHash01(gesture, 16211));
            float baseY = height * (0.22f + 0.48f * stableHash01(gesture, 16213));
            float drift = minDim * 0.026f * waveEnvelope(local);
            float phase = stableHash01(gesture, 16217) * 6.2831853f;
            baseX += drift * (float)Math.sin(phase + local * 0.94f);
            baseY += drift * 0.58f * (float)Math.cos(phase * 0.7f + local * 0.86f);
            return new float[]{clamp(baseX, width * 0.14f, width * 0.86f), clamp(baseY, height * 0.17f, height * 0.76f)};
        }

        private float v162Angle(int gesture, float local) {
            float base = stableHash01(gesture, 16219) * 6.2831853f;
            return base + 0.13f * (float)Math.sin(stableHash01(gesture, 16221) * 6.2831853f + local * 1.25f)
                    + 0.035f * (float)Math.sin(local * 4.0f) * waveEnvelope(local);
        }

        private float v162CameraFov(float local, int gesture, float minDim) {
            float f = 0.86f + 0.16f * (float)Math.sin(stableHash01(gesture, 16223) * 6.2831853f + local * 1.5f)
                    + 0.05f * (float)Math.sin(stableHash01(gesture, 16229) * 6.2831853f + local * 3.8f) * waveEnvelope(local);
            return minDim * clamp(f, 0.62f, 1.10f);
        }

        private float v162ShapeTime(int gesture, float local) {
            return stableHash01(gesture, 16231) * 4.0f + local * (0.70f + 0.18f * stableHash01(gesture, 16233));
        }

        private int v162Family(int gesture, int offset) {
            return (int)Math.floor(stableHash01(gesture + offset * 977, 16241) * 6.0f) % 6;
        }

        private void drawV162MorphingGlyph(int gesture, float local, float tail, float head,
                                           float cx, float cy, float angle, float scale, float cameraFov,
                                           float shapeT, int familyA, int familyB,
                                           float[] color, float[] cyan, float[] hot, float alpha, boolean echo) {
            int samples = cfg.powerSave ? 36 : 64;
            ArrayList<float[]> core = buildV162ProjectedCurve(gesture, local, tail, head, 0f, cx, cy, angle, scale, cameraFov, shapeT, familyA, familyB, samples);
            if (core.size() < 2) return;
            float minD = Math.max(1f, Math.min(width, height));
            float baseWidth = Math.max(0.10f, minD * (0.00070f + 0.00052f * cfg.ribbonWidth));
            float maturity = smoother(clamp((local - 0.055f) / 0.36f, 0f, 1f)) * (1f - 0.12f * smoother(clamp((local - 0.84f) / 0.11f, 0f, 1f)));

            if (!echo && maturity > 0.16f) {
                ArrayList<float[]> left = buildV162ProjectedCurve(gesture, local, tail, head, -1f, cx, cy, angle, scale, cameraFov, shapeT, familyA, familyB, samples);
                ArrayList<float[]> right = buildV162ProjectedCurve(gesture, local, tail, head, 1f, cx, cy, angle, scale, cameraFov, shapeT, familyA, familyB, samples);
                float surfaceAlpha = alpha * (0.018f + 0.018f * v162WideFamilyAmount(familyA, familyB, local)) * maturity;
                drawRuledSurfaceAgeFaded(left, right, color[0], color[1], color[2], surfaceAlpha, 1.10f);
                drawAgeFadedStrip(left, Math.max(0.018f, baseWidth * 0.060f), color[0], color[1], color[2], alpha * 0.008f * maturity, 0.98f, 0.16f);
                drawAgeFadedStrip(right, Math.max(0.018f, baseWidth * 0.060f), hot[0], hot[1], hot[2], alpha * 0.007f * maturity, 0.98f, 0.14f);
            }

            drawAgeFadedStrip(core, Math.max(0.060f, baseWidth * (echo ? 0.18f : 0.48f)),
                    color[0], color[1], color[2], alpha * (echo ? 0.032f : 0.104f), 1.05f, echo ? 0.10f : 0.44f);
            if (!echo) {
                drawAgeFadedStrip(core, Math.max(0.018f, baseWidth * 0.065f),
                        0.94f, 1.00f, 1.00f, alpha * 0.034f, 1.10f, 0.58f);
                float filament = v162FilamentAmount(familyA, familyB, local) * maturity;
                if (filament > 0.10f) {
                    drawV162Filaments(gesture, local, tail, head, cx, cy, angle, scale, cameraFov, shapeT,
                            familyA, familyB, baseWidth, color, cyan, alpha * filament, samples);
                }
            }
        }

        private float v162WideFamilyAmount(int a, int b, float local) {
            float mix = smoother(clamp((local - 0.46f) / 0.30f, 0f, 1f));
            float va = (a == 1 || a == 2 || a == 4) ? 1f : 0.35f;
            float vb = (b == 1 || b == 2 || b == 4) ? 1f : 0.35f;
            return lerp(va, vb, mix);
        }

        private float v162FilamentAmount(int a, int b, float local) {
            float mix = smoother(clamp((local - 0.48f) / 0.28f, 0f, 1f));
            float va = (a == 1 || a == 4 || a == 5) ? 1f : 0.05f;
            float vb = (b == 1 || b == 4 || b == 5) ? 1f : 0.05f;
            return lerp(va, vb, mix);
        }

        private ArrayList<float[]> buildV162ProjectedCurve(int gesture, float local, float tail, float head, float lane,
                                                           float cx, float cy, float angle, float scale, float cameraFov,
                                                           float shapeT, int familyA, int familyB, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            int count = 7;
            float[][] ctl = new float[count][3];
            for (int i = 0; i < count; i++) {
                float u = i / Math.max(1f, count - 1f);
                ctl[i] = v162ControlPoint(gesture, local, u, lane, scale, shapeT, familyA, familyB);
            }
            float yaw = angle + 0.08f * (float)Math.sin(shapeT * 1.5f + stableHash01(gesture, 16261) * 6.2831853f);
            float roll = 0.22f * (float)Math.sin(shapeT * 1.05f + stableHash01(gesture, 16263) * 6.2831853f) * waveEnvelope(local);
            float pitch = 0.18f * (float)Math.sin(shapeT * 0.84f + stableHash01(gesture, 16267) * 6.2831853f) * waveEnvelope(local);
            for (int s = 0; s < samples; s++) {
                float q = s / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float pos = u * (count - 1f);
                int i1 = clampInt((int)Math.floor(pos), 0, count - 1);
                float t = smoother(pos - i1);
                int i0 = clampInt(i1 - 1, 0, count - 1);
                int i2 = clampInt(i1 + 1, 0, count - 1);
                int i3 = clampInt(i1 + 2, 0, count - 1);
                float[] p3 = catmullRomPoint3(ctl[i0], ctl[i1], ctl[i2], ctl[i3], t);
                float[] pr = projectMystify3dPoint(p3[0], p3[1], p3[2], yaw, roll, pitch, cameraFov);
                out.add(new float[]{cx + pr[0], cy + pr[1]});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private float[] v162ControlPoint(int gesture, float local, float u, float lane, float scale, float shapeT, int familyA, int familyB) {
            float headGate = smoother(clamp((local - 0.34f) / 0.36f, 0f, 1f));
            float front = smoother(clamp((u - 0.46f) / 0.34f, 0f, 1f));
            float mix = clamp(headGate * front, 0f, 1f);
            float[] a = v162ControlPointForFamily(familyA, gesture, local, u, lane, scale, shapeT);
            float[] b = v162ControlPointForFamily(familyB, gesture + 11, local, u, lane, scale, shapeT + 0.55f);
            return new float[]{lerp(a[0], b[0], mix), lerp(a[1], b[1], mix), lerp(a[2], b[2], mix)};
        }

        private float[] v162ControlPointForFamily(int family, int gesture, float local, float u, float lane, float scale, float t) {
            float env = waveEnvelope(u);
            float phase = stableHash01(gesture, 16271) * 6.2831853f;
            float x = scale * (u - 0.5f);
            float y = 0f;
            float z = 0f;
            switch (family) {
                case 0: // 极简长弧 / 书写丝带
                    x *= 0.72f;
                    y = scale * (0.055f * (float)Math.sin(u * 3.1415927f * 1.18f + phase * 0.30f)
                            + 0.035f * (float)Math.sin(u * 3.1415927f * 2.10f + t));
                    z = scale * 0.065f * (float)Math.cos(u * 3.1415927f * 1.35f + t + phase) * env;
                    break;
                case 1: // 叶片 / 场线扇面
                    x *= 0.60f + 0.10f * (float)Math.sin(t * 0.7f + phase);
                    y = scale * (0.22f * env * (u - 0.12f) + 0.045f * (float)Math.sin(u * 3.1415927f * 2.0f + t));
                    z = scale * 0.085f * (float)Math.cos(u * 3.1415927f * 1.1f + t) * env;
                    break;
                case 2: // 宽薄翼面
                    x *= 0.58f;
                    y = scale * (0.18f * (float)Math.sin(u * 3.1415927f) * (0.38f + u)
                            + 0.035f * (float)Math.sin(u * 3.1415927f * 2.4f + phase));
                    z = scale * 0.11f * (float)Math.sin(u * 3.1415927f * 1.2f + t) * env;
                    break;
                case 3: // 钩形 / 花瓣回扫
                    x = scale * ((u - 0.5f) * 0.56f + 0.14f * env * (float)Math.sin(phase + t * 0.5f));
                    y = scale * (0.20f * (float)Math.sin(u * 3.1415927f * 1.05f + 0.35f) * env - 0.13f * (u - 0.72f) * (u - 0.72f));
                    z = scale * 0.070f * (float)Math.cos(u * 3.1415927f * 1.6f + t) * env;
                    break;
                case 4: // 环形网纱 / 半闭合空间弧
                    x = scale * (0.30f * (float)Math.sin((u * 1.08f + 0.05f) * 2f * 3.1415927f + phase * 0.25f));
                    y = scale * (0.22f * (float)Math.cos((u * 1.02f + 0.10f) * 2f * 3.1415927f + phase * 0.25f) * (0.78f + 0.22f * env));
                    z = scale * 0.10f * (float)Math.sin(u * 2f * 3.1415927f + t) * env;
                    break;
                default: // 场线长束 / 羽化波束
                    x *= 0.70f;
                    y = scale * (0.12f * env + 0.12f * (u - 0.5f) * (u - 0.5f) + 0.035f * (float)Math.sin(u * 3.1415927f * 2.8f + t));
                    z = scale * 0.12f * (float)Math.cos(u * 3.1415927f * 1.8f + phase + t) * env;
                    break;
            }
            float laneOpen = lane * scale * (0.012f + 0.064f * env * (0.40f + 0.60f * v162WideFamilyAmount(family, family, local)));
            // 出生早期仍是细线；成熟后家族形态才展开，避免“预制图形直接出现”。
            float maturity = smoother(clamp((local - (0.026f + 0.50f * u)) / 0.32f, 0f, 1f));
            float seedX = scale * (u - 0.5f) * 0.50f;
            float seedY = scale * 0.020f * (float)Math.sin(u * 3.1415927f * 1.05f + phase * 0.2f) + lane * scale * 0.006f * env;
            return new float[]{lerp(seedX, x, maturity), lerp(seedY, y + laneOpen, maturity), z * maturity};
        }

        private void drawV162Filaments(int gesture, float local, float tail, float head,
                                       float cx, float cy, float angle, float scale, float cameraFov, float shapeT,
                                       int familyA, int familyB, float width, float[] color, float[] cyan, float alpha, int samples) {
            int lanes = cfg.powerSave ? 1 : 2;
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : (i == 0 ? -0.48f : 0.48f);
                ArrayList<float[]> line = buildV162ProjectedCurve(gesture, local, tail, head, lane, cx, cy, angle, scale, cameraFov, shapeT, familyA, familyB, Math.max(8, samples / 2));
                drawAgeFadedStrip(line, Math.max(0.016f, width * 0.044f), cyan[0], cyan[1], cyan[2], alpha * 0.010f, 0.98f, 0.13f);
            }
        }

        private void drawV162Tip(int gesture, float local, float head,
                                 float cx, float cy, float angle, float scale, float cameraFov, float shapeT,
                                 int familyA, int familyB, float[] hot, float alpha) {
            if (head <= 0.020f || alpha <= 0.001f) return;
            ArrayList<float[]> tipCurve = buildV162ProjectedCurve(gesture, local, Math.max(0f, head - 0.010f), head, 0f, cx, cy, angle, scale, cameraFov, shapeT, familyA, familyB, 3);
            if (tipCurve.isEmpty()) return;
            float[] p = tipCurve.get(tipCurve.size() - 1);
            float tipLife = 1f - smoother(clamp((local - 0.860f) / 0.10f, 0f, 1f));
            drawEllipse(p[0], p[1], Math.max(1.0f, scale * 0.0058f), Math.max(0.42f, scale * 0.0024f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.054f, 18);
        }

        private void drawReferenceVideoTimePainterV161(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V161：对照参考视频继续修 V160 的最大差距：V160 仍像“一个固定光形家族逐渐成熟”。
            // 参考视频更接近：少数 3D 控制点形成的光弦不断改变自身，当前切片清楚，旧切片淡退。
            // 因此这里不再直接使用 v159 的固定 family target，而是使用“运动控制点 + 透视 + 同源时间切片”。
            float local = clamp(raw, 0f, 0.999f);
            float life = v161PhraseLife(local);
            if (life <= 0.002f) return;
            float head = v161Head(local);
            float tail = v161Tail(local, head);
            if (head <= tail + 0.030f) {
                float[] c = v161Center(gesture, local, minDim);
                float a = v161Angle(gesture, local);
                drawEllipse(c[0], c[1], minDim * 0.0050f, minDim * 0.0022f, a,
                        hot[0], hot[1], hot[2], alpha * life * 0.052f, 18);
                return;
            }

            float[] center = v161Center(gesture, local, minDim);
            float scale = minDim * (0.50f + 0.14f * stableHash01(gesture, 16101));
            float angle = v161Angle(gesture, local);
            float camera = v161CameraFov(local, gesture, minDim);
            float shapeT = v161ShapeTime(gesture, local);
            float[] color = mystifyPaletteFromHue(fract(0.54f + 0.18f * stableHash01(gesture, 16103) + local * 0.075f), mid, cyan, hot, 0.97f, true);

            // 同源时间切片：只画 1~2 个非常淡的过去状态，避免多主体/分身，但补足参考视频的时间残影。
            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes; e >= 1; e--) {
                float oldLocal = local - e * 0.055f;
                if (oldLocal <= 0.018f) continue;
                float oldLife = v161PhraseLife(oldLocal);
                float oldHead = v161Head(oldLocal);
                float oldTail = v161Tail(oldLocal, oldHead);
                if (oldLife <= 0.006f || oldHead <= oldTail + 0.035f) continue;
                float[] oc = v161Center(gesture, oldLocal, minDim);
                drawV161ControlString(gesture, oldLocal, oldTail, oldHead, oc[0], oc[1],
                        v161Angle(gesture, oldLocal), scale, v161CameraFov(oldLocal, gesture, minDim),
                        shapeT - e * 0.16f, color, cyan, hot, alpha * oldLife * 0.030f / e, true);
            }

            drawV161ControlString(gesture, local, tail, head, center[0], center[1], angle, scale,
                    camera, shapeT, color, cyan, hot, alpha * life, false);
            drawV161Tip(gesture, local, head, center[0], center[1], angle, scale, camera, shapeT, hot, alpha * life);
        }

        private float v161PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.012f) / 0.18f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.865f) / 0.130f, 0f, 1f));
            return appear * vanish;
        }

        private float v161Head(float local) {
            float raw = clamp((local - 0.018f) / 0.76f, 0f, 1f);
            float h = smoother(raw);
            // 非匀速推进，慢时切片更密，快时切片更疏。
            h += 0.018f * (float)Math.sin(local * 6.2831853f * 1.65f + 0.4f) * waveEnvelope(raw);
            return clamp(h, 0f, 1f);
        }

        private float v161Tail(float local, float head) {
            // 尾部从中段开始追赶，保证“先画部分边画边消失”。
            float chase = smoother(clamp((local - 0.225f) / 0.56f, 0f, 1f));
            float window = 0.58f - 0.34f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.070f));
        }

        private float[] v161Center(int gesture, float local, float minDim) {
            float baseX = width * (0.20f + 0.58f * stableHash01(gesture, 16111));
            float baseY = height * (0.23f + 0.46f * stableHash01(gesture, 16113));
            // 参考视频主体不是僵在同一位置，但运动很克制，不能像动物爬行。
            float drift = minDim * 0.035f * waveEnvelope(local);
            float phase = stableHash01(gesture, 16117) * 6.2831853f;
            baseX += drift * (float)Math.sin(phase + local * 1.25f);
            baseY += drift * 0.65f * (float)Math.cos(phase * 0.7f + local * 1.08f);
            return new float[]{clamp(baseX, width * 0.16f, width * 0.84f), clamp(baseY, height * 0.18f, height * 0.74f)};
        }

        private float v161Angle(int gesture, float local) {
            float base = stableHash01(gesture, 16119) * 6.2831853f;
            return base + 0.16f * (float)Math.sin(stableHash01(gesture, 16121) * 6.2831853f + local * 1.8f)
                    + 0.05f * (float)Math.sin(local * 5.3f) * waveEnvelope(local);
        }

        private float v161CameraFov(float local, int gesture, float minDim) {
            float f = 0.82f + 0.20f * (float)Math.sin(stableHash01(gesture, 16123) * 6.2831853f + local * 2.0f)
                    + 0.08f * (float)Math.sin(stableHash01(gesture, 16129) * 6.2831853f + local * 5.0f) * waveEnvelope(local);
            return minDim * clamp(f, 0.55f, 1.16f);
        }

        private float v161ShapeTime(int gesture, float local) {
            // 控制点运动时间，慢速持续变形，但不是一段内快速乱切所有风格。
            return stableHash01(gesture, 16131) * 4.0f + local * (0.88f + 0.22f * stableHash01(gesture, 16133));
        }

        private void drawV161ControlString(int gesture, float local, float tail, float head,
                                           float cx, float cy, float angle, float scale, float cameraFov, float shapeT,
                                           float[] color, float[] cyan, float[] hot, float alpha, boolean echo) {
            int samples = cfg.powerSave ? 34 : 58;
            ArrayList<float[]> core = buildV161ProjectedCurve(gesture, local, tail, head, 0f, cx, cy, angle, scale, cameraFov, shapeT, samples);
            if (core.size() < 2) return;
            float minD = Math.max(1f, Math.min(width, height));
            float baseWidth = Math.max(0.12f, minD * (0.00075f + 0.00058f * cfg.ribbonWidth));
            float mature = smoother(clamp((local - 0.060f) / 0.34f, 0f, 1f)) * (1f - 0.10f * smoother(clamp((local - 0.82f) / 0.12f, 0f, 1f)));

            // 只有在当前切片成熟时才出现极薄翼面；回声不画面，只画淡线，避免乱团。
            if (!echo && mature > 0.20f) {
                ArrayList<float[]> left = buildV161ProjectedCurve(gesture, local, tail, head, -1f, cx, cy, angle, scale, cameraFov, shapeT, samples);
                ArrayList<float[]> right = buildV161ProjectedCurve(gesture, local, tail, head, 1f, cx, cy, angle, scale, cameraFov, shapeT, samples);
                drawRuledSurfaceAgeFaded(left, right, color[0], color[1], color[2], alpha * 0.024f * mature, 0.95f);
                drawAgeFadedStrip(left, Math.max(0.020f, baseWidth * 0.070f), color[0], color[1], color[2], alpha * 0.010f * mature, 0.94f, 0.18f);
                drawAgeFadedStrip(right, Math.max(0.020f, baseWidth * 0.070f), hot[0], hot[1], hot[2], alpha * 0.009f * mature, 0.94f, 0.16f);
            }

            drawAgeFadedStrip(core, Math.max(0.070f, baseWidth * (echo ? 0.22f : 0.55f)),
                    color[0], color[1], color[2], alpha * (echo ? 0.040f : 0.118f), 0.95f, echo ? 0.12f : 0.50f);
            if (!echo) {
                drawAgeFadedStrip(core, Math.max(0.020f, baseWidth * 0.080f),
                        0.94f, 1.00f, 1.00f, alpha * 0.046f, 0.98f, 0.72f);
                // 稀疏内线只在叶片/环纱倾向明显时出现，且贴合主形体。
                if (v161InteriorNeedle(gesture, local) > 0.48f && mature > 0.35f) {
                    drawV161InteriorFilaments(gesture, local, tail, head, cx, cy, angle, scale, cameraFov, shapeT,
                            baseWidth, color, cyan, alpha * mature, samples);
                }
            }
        }

        private float v161InteriorNeedle(int gesture, float local) {
            return 0.5f + 0.5f * (float)Math.sin(stableHash01(gesture, 16135) * 6.2831853f + local * 2.4f);
        }

        private ArrayList<float[]> buildV161ProjectedCurve(int gesture, float local, float tail, float head, float lane,
                                                           float cx, float cy, float angle, float scale, float cameraFov,
                                                           float shapeT, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            int count = 6;
            float[][] ctl = new float[count][3];
            for (int i = 0; i < count; i++) {
                float u = i / Math.max(1f, count - 1f);
                ctl[i] = v161ControlPoint(gesture, local, u, lane, scale, shapeT);
            }
            float yaw = angle + 0.10f * (float)Math.sin(shapeT * 1.7f + stableHash01(gesture, 16141) * 6.2831853f);
            float roll = 0.30f * (float)Math.sin(shapeT * 1.15f + stableHash01(gesture, 16143) * 6.2831853f) * waveEnvelope(local);
            float pitch = 0.24f * (float)Math.sin(shapeT * 0.92f + stableHash01(gesture, 16147) * 6.2831853f) * waveEnvelope(local);
            for (int s = 0; s < samples; s++) {
                float q = s / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float pos = u * (count - 1f);
                int i1 = clampInt((int)Math.floor(pos), 0, count - 1);
                float t = smoother(pos - i1);
                int i0 = clampInt(i1 - 1, 0, count - 1);
                int i2 = clampInt(i1 + 1, 0, count - 1);
                int i3 = clampInt(i1 + 2, 0, count - 1);
                float[] p3 = catmullRomPoint3(ctl[i0], ctl[i1], ctl[i2], ctl[i3], t);
                float[] pr = projectMystify3dPoint(p3[0], p3[1], p3[2], yaw, roll, pitch, cameraFov);
                out.add(new float[]{cx + pr[0], cy + pr[1]});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private float[] v161ControlPoint(int gesture, float local, float u, float lane, float scale, float shapeT) {
            float env = waveEnvelope(u);
            float phase = stableHash01(gesture, 16151) * 6.2831853f;
            float mode = 0.5f + 0.5f * (float)Math.sin(shapeT * 1.05f + stableHash01(gesture, 16153) * 6.2831853f);
            float wing = smoother(mode);
            float x = scale * (u - 0.50f) * (0.68f + 0.12f * (float)Math.sin(shapeT * 0.7f + phase));
            float yBase = scale * (0.085f * (float)Math.sin(u * 3.1415927f * (1.05f + 0.22f * wing) + phase * 0.23f)
                    + 0.038f * (float)Math.sin(u * 3.1415927f * (2.15f + 0.30f * wing) + shapeT));
            float fan = scale * (0.20f + 0.18f * wing) * env * (u - 0.18f) * (1f - 0.25f * u);
            float loop = scale * 0.12f * (float)Math.sin(2f * 3.1415927f * u + phase + shapeT * 0.8f) * env * (1f - wing);
            float laneOpen = lane * scale * (0.020f + 0.082f * env * (0.35f + 0.65f * wing));
            float y = yBase + fan + loop + laneOpen;
            float z = scale * (0.10f * (float)Math.cos(u * 3.1415927f * 1.4f + shapeT + phase) * env
                    + lane * 0.025f * env);
            // 新生头部更细，成熟中段更开放：但点位是连续运动，不是模板替换。
            float maturity = smoother(clamp((local - (0.020f + 0.54f * u)) / 0.34f, 0f, 1f));
            float seedX = scale * (u - 0.50f) * 0.56f;
            float seedY = scale * 0.025f * (float)Math.sin(u * 3.1415927f * 1.1f + phase * 0.2f) + lane * scale * 0.010f * env;
            return new float[]{lerp(seedX, x, maturity), lerp(seedY, y, maturity), z * maturity};
        }

        private void drawV161InteriorFilaments(int gesture, float local, float tail, float head,
                                               float cx, float cy, float angle, float scale, float cameraFov, float shapeT,
                                               float width, float[] color, float[] cyan, float alpha, int samples) {
            int lanes = cfg.powerSave ? 1 : 2;
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : (i == 0 ? -0.45f : 0.45f);
                ArrayList<float[]> line = buildV161ProjectedCurve(gesture, local, tail, head, lane, cx, cy, angle, scale, cameraFov, shapeT, Math.max(8, samples / 2));
                drawAgeFadedStrip(line, Math.max(0.018f, width * 0.050f), cyan[0], cyan[1], cyan[2], alpha * 0.010f, 0.94f, 0.14f);
            }
        }

        private void drawV161Tip(int gesture, float local, float head,
                                 float cx, float cy, float angle, float scale, float cameraFov, float shapeT,
                                 float[] hot, float alpha) {
            if (head <= 0.020f || alpha <= 0.001f) return;
            ArrayList<float[]> tipCurve = buildV161ProjectedCurve(gesture, local, Math.max(0f, head - 0.010f), head, 0f, cx, cy, angle, scale, cameraFov, shapeT, 3);
            if (tipCurve.isEmpty()) return;
            float[] p = tipCurve.get(tipCurve.size() - 1);
            float tipLife = 1f - smoother(clamp((local - 0.850f) / 0.11f, 0f, 1f));
            drawEllipse(p[0], p[1], Math.max(1.1f, scale * 0.0065f), Math.max(0.45f, scale * 0.0028f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.060f, 18);
        }

        private void drawReferenceVideoTimePainterV160(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V160：对照参考视频继续修正 V159 的重大差距。
            // V159 仍是“一段固定家族逐渐成熟”，像是在展示一个稳定 motif；参考视频更像：
            // 同一段光痕先从极简起笔开始，头部持续生成新笔法，旧部保持旧笔法并退隐，
            // 中间只有少量清楚光形，不堆叠、不复制、不把所有风格塞进同一瞬间。
            float local = clamp(raw, 0f, 0.999f);
            float life = v160PhraseLife(local);
            if (life <= 0.002f) return;
            float head = v160Head(local);
            float tail = v160Tail(local, head);
            if (head <= tail + 0.026f) {
                float[] center = v160PhraseCenter(gesture);
                float angle = v160PhraseAngle(gesture, local);
                drawEllipse(center[0], center[1], minDim * 0.0060f, minDim * 0.0025f,
                        angle, hot[0], hot[1], hot[2], alpha * life * 0.065f, 18);
                return;
            }
            float[] center = v160PhraseCenter(gesture);
            float scale = minDim * (0.55f + 0.12f * stableHash01(gesture, 16001));
            float angle = v160PhraseAngle(gesture, local);
            int familyA = v160FamilyA(gesture);
            int familyB = v160FamilyB(gesture, familyA);

            // 只保留一个极淡同源时间回声，表达“旧笔痕正在退隐”，避免再次出现多主体/复制感。
            float oldLocal = local - 0.085f;
            if (!cfg.powerSave && oldLocal > 0.030f) {
                float oldLife = v160PhraseLife(oldLocal);
                float oldHead = v160Head(oldLocal);
                float oldTail = v160Tail(oldLocal, oldHead);
                if (oldLife > 0.006f && oldHead > oldTail + 0.030f) {
                    drawV160MorphingGlyph(gesture, familyA, familyB, oldLocal, oldTail, oldHead,
                            center[0], center[1], v160PhraseAngle(gesture, oldLocal), scale,
                            mid, cyan, hot, alpha * oldLife * 0.030f, true);
                }
            }
            drawV160MorphingGlyph(gesture, familyA, familyB, local, tail, head,
                    center[0], center[1], angle, scale, mid, cyan, hot, alpha * life, false);
            drawV160Tip(gesture, familyA, familyB, local, head, center[0], center[1], angle, scale, hot, alpha * life);
        }

        private float v160PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.010f) / 0.16f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.870f) / 0.120f, 0f, 1f));
            return appear * vanish;
        }

        private float v160Head(float local) {
            // 参考视频不是匀速爬线：前段缓慢起笔，中段展开，后段收势。
            float h = smoother(clamp((local - 0.012f) / 0.74f, 0f, 1f));
            float pulse = 0.006f * (float)Math.sin(local * 6.2831853f * 1.25f) * waveEnvelope(h);
            return clamp(h + pulse, 0f, 1f);
        }

        private float v160Tail(float local, float head) {
            // 先画内容必须边画边淡去：尾部较早追赶，但保持一个可读的创作窗口。
            float chase = smoother(clamp((local - 0.205f) / 0.56f, 0f, 1f));
            float window = 0.62f - 0.36f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.060f));
        }

        private int v160FamilyA(int gesture) {
            return (int)Math.floor(stableHash01(gesture, 16011) * 6.0f) % 6;
        }

        private int v160FamilyB(int gesture, int familyA) {
            int jump = 1 + (int)Math.floor(stableHash01(gesture, 16013) * 5.0f);
            int b = (familyA + jump) % 6;
            if (b == familyA) b = (familyA + 2) % 6;
            return b;
        }

        private float[] v160PhraseCenter(int gesture) {
            // 保持大留白，但避免永远在同一个区域。
            float cx = width * (0.20f + 0.58f * stableHash01(gesture, 16017));
            float cy = height * (0.22f + 0.47f * stableHash01(gesture, 16019));
            return new float[]{clamp(cx, width * 0.17f, width * 0.83f), clamp(cy, height * 0.20f, height * 0.72f)};
        }

        private float v160PhraseAngle(int gesture, float local) {
            float base = stableHash01(gesture, 16023) * 6.2831853f;
            float breath = 0.075f * (float)Math.sin(stableHash01(gesture, 16029) * 6.2831853f + local * 2.05f);
            float settle = 0.030f * (float)Math.sin(stableHash01(gesture, 16031) * 6.2831853f + local * 4.10f) * waveEnvelope(local);
            return base + breath + settle;
        }

        private void drawV160MorphingGlyph(int gesture, int familyA, int familyB, float local, float tail, float head,
                                           float cx, float cy, float angle, float scale,
                                           float[] mid, float[] cyan, float[] hot, float alpha, boolean echo) {
            int samples = cfg.powerSave ? 36 : 64;
            ArrayList<float[]> core = buildV160Lane(gesture, familyA, familyB, local, tail, head, 0f, cx, cy, angle, scale, samples);
            if (core.size() < 2) return;
            float familyBlend = v160HeadFamilyBlend(local, head);
            float hue = fract(0.52f + stableHash01(gesture, 16037) * 0.30f + lerp(familyA, familyB, familyBlend) * 0.041f + local * 0.038f);
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 0.98f, true);
            float minD = Math.max(1f, Math.min(this.width, this.height));
            float baseWidth = Math.max(0.48f, minD * (0.00175f + 0.00075f * cfg.ribbonWidth));
            float mature = v160PhraseMaturity(local);

            // 主体本身生长成形，而不是靠两侧毛刺装饰。宽面只在成熟段轻轻出现。
            if (mature > 0.10f && !echo) {
                ArrayList<float[]> left = buildV160Lane(gesture, familyA, familyB, local, tail, head, -1f, cx, cy, angle, scale, samples);
                ArrayList<float[]> right = buildV160Lane(gesture, familyA, familyB, local, tail, head, 1f, cx, cy, angle, scale, samples);
                float surfaceAlpha = alpha * 0.030f * mature;
                drawRuledSurfaceAgeFaded(left, right, color[0], color[1], color[2], surfaceAlpha, 0.94f);
                drawAgeFadedStrip(left, Math.max(0.026f, baseWidth * 0.055f), color[0], color[1], color[2], alpha * 0.014f * mature, 0.92f, 0.18f);
                drawAgeFadedStrip(right, Math.max(0.026f, baseWidth * 0.055f), hot[0], hot[1], hot[2], alpha * 0.012f * mature, 0.92f, 0.16f);
            }

            drawAgeFadedStrip(core, Math.max(0.10f, baseWidth * (echo ? 0.26f : 0.62f)),
                    color[0], color[1], color[2], alpha * (echo ? 0.038f : 0.118f), 0.94f, echo ? 0.14f : 0.54f);
            if (!echo) {
                // 克制白芯，避免再次变成粗白乱线。
                drawAgeFadedStrip(core, Math.max(0.026f, baseWidth * 0.090f),
                        0.96f, 1.00f, 1.00f, alpha * 0.048f, 0.97f, 0.72f);
            }
            if (!echo && mature > 0.24f) {
                int activeFamily = familyBlend < 0.52f ? familyA : familyB;
                if (activeFamily == 1 || activeFamily == 4) {
                    drawV160SparseInterior(gesture, familyA, familyB, local, tail, head, cx, cy, angle, scale,
                            baseWidth, color, cyan, alpha * mature, samples);
                }
            }
        }

        private float v160PhraseMaturity(float local) {
            return smoother(clamp((local - 0.050f) / 0.36f, 0f, 1f)) * (1f - 0.08f * smoother(clamp((local - 0.82f) / 0.12f, 0f, 1f)));
        }

        private float v160HeadFamilyBlend(float local, float head) {
            // 新头部逐步试探下一种形态；旧尾部保持上一种形态并退隐。
            return smoother(clamp((local - 0.46f) / 0.30f, 0f, 1f)) * smoother(clamp((head - 0.40f) / 0.36f, 0f, 1f));
        }

        private ArrayList<float[]> buildV160Lane(int gesture, int familyA, int familyB, float local, float tail, float head,
                                                 float lane, float cx, float cy, float angle, float scale, int samples) {
            ArrayList<float[]> pts = new ArrayList<>();
            for (int i = 0; i < samples; i++) {
                float q = i / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float[] p = v160Point(gesture, familyA, familyB, local, u, lane, scale);
                float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
                pts.add(new float[]{cx + ca * p[0] - sa * p[1], cy + sa * p[0] + ca * p[1]});
            }
            return pts;
        }

        private float[] v160Point(int gesture, int familyA, int familyB, float local, float u, float lane, float scale) {
            float[] seed = v159SeedPoint(gesture, local, u, lane * 0.55f, scale);
            float[] a0 = v159TargetPoint(gesture, familyA, local, u, lane, scale, 0f);
            float[] a1 = v159TargetPoint(gesture, familyA, local, u, lane, scale, 1f);
            float[] b0 = v159TargetPoint(gesture + 53, familyB, local, u, lane, scale, 0f);
            float[] b1 = v159TargetPoint(gesture + 53, familyB, local, u, lane, scale, 1f);
            float birth = 0.016f + 0.70f * u;
            float age = local - birth;
            float maturity = smoother(clamp((age + 0.050f) / 0.30f, 0f, 1f));
            float internal = smoother(clamp((age - 0.08f) / 0.38f, 0f, 1f));
            float[] aa = new float[]{lerp(a0[0], a1[0], internal), lerp(a0[1], a1[1], internal)};
            float[] bb = new float[]{lerp(b0[0], b1[0], internal), lerp(b0[1], b1[1], internal)};
            // 关键：不是整段一起替换，而是新出生的头部优先进入下一形态。
            float birthBias = smoother(clamp((u - 0.44f) / 0.34f, 0f, 1f));
            float timeBias = v160HeadFamilyBlend(local, u);
            float morph = birthBias * timeBias;
            float tx = lerp(aa[0], bb[0], morph);
            float ty = lerp(aa[1], bb[1], morph);
            float x = lerp(seed[0], tx, maturity);
            float y = lerp(seed[1], ty, maturity);
            float phase = stableHash01(gesture, 16041) * 6.2831853f;
            float env = waveEnvelope(u);
            float jitter = (1f - 0.60f * Math.abs(lane));
            x += scale * 0.0055f * (float)Math.sin(phase + local * 2.0f + u * 2.8f) * env * maturity * jitter;
            y += scale * 0.0048f * (float)Math.cos(phase * 0.67f + local * 1.7f + u * 2.4f) * env * maturity * jitter;
            return new float[]{x, y};
        }

        private void drawV160SparseInterior(int gesture, int familyA, int familyB, float local, float tail, float head,
                                            float cx, float cy, float angle, float scale, float width,
                                            float[] color, float[] cyan, float alpha, int samples) {
            int lanes = cfg.powerSave ? 1 : 3;
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : (i / (lanes - 1f) - 0.5f) * 0.86f;
                ArrayList<float[]> line = buildV160Lane(gesture, familyA, familyB, local, tail, head, lane, cx, cy, angle, scale, Math.max(8, samples / 2));
                float a = alpha * (0.0045f + 0.0085f * (1f - Math.min(1f, Math.abs(lane))));
                drawAgeFadedStrip(line, Math.max(0.018f, width * 0.045f), cyan[0], cyan[1], cyan[2], a, 0.92f, 0.13f);
            }
        }

        private void drawV160Tip(int gesture, int familyA, int familyB, float local, float head,
                                 float cx, float cy, float angle, float scale,
                                 float[] hot, float alpha) {
            if (head <= 0.020f || alpha <= 0.001f) return;
            float[] p = v160Point(gesture, familyA, familyB, local, head, 0f, scale);
            float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
            float x = cx + ca * p[0] - sa * p[1];
            float y = cy + sa * p[0] + ca * p[1];
            float tipLife = 1f - smoother(clamp((local - 0.850f) / 0.11f, 0f, 1f));
            drawEllipse(x, y, Math.max(1.2f, scale * 0.0078f), Math.max(0.50f, scale * 0.0034f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.065f, 18);
        }

        private void drawReferenceVideoTimePainterV159(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V159：继续对照参考视频修正 V158 的主要差距。
            // V158 每段稳定为一个 motif，清楚但容易像“固定样式展示”。参考视频更像一段光形短句：
            // 从极小起笔开始，同一主体内部逐步成熟，局部由细线长成薄翼/网纱/钩形/环弧，旧部分按时间退隐。
            // 因此 V159 使用“出生时间 + 成熟度 + 家族内变体”来驱动几何本体，而不是直接展示预制 motif。
            float local = clamp(raw, 0f, 0.999f);
            float life = v159PhraseLife(local);
            if (life <= 0.002f) return;
            float head = v159Head(local);
            float tail = v159Tail(local, head);
            float[] center = v159PhraseCenter(gesture);
            float scale = minDim * (0.58f + 0.15f * stableHash01(gesture, 15901));
            float angle = v159PhraseAngle(gesture, local);
            int family = v159FamilyIndex(gesture);
            if (head <= tail + 0.026f) {
                drawEllipse(center[0], center[1], minDim * 0.0065f, minDim * 0.0028f,
                        angle, hot[0], hot[1], hot[2], alpha * life * 0.080f, 18);
                return;
            }
            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes; e >= 1; e--) {
                float oldLocal = local - e * 0.060f;
                if (oldLocal <= 0.015f) continue;
                float oldLife = v159PhraseLife(oldLocal);
                float oldHead = v159Head(oldLocal);
                float oldTail = v159Tail(oldLocal, oldHead);
                if (oldLife <= 0.004f || oldHead <= oldTail + 0.030f) continue;
                drawV159EvolvingGlyph(gesture, family, oldLocal, oldTail, oldHead,
                        center[0], center[1], v159PhraseAngle(gesture, oldLocal), scale,
                        mid, cyan, hot, alpha * oldLife * (e == 1 ? 0.046f : 0.025f), true);
            }
            drawV159EvolvingGlyph(gesture, family, local, tail, head,
                    center[0], center[1], angle, scale, mid, cyan, hot, alpha * life, false);
            drawV159Tip(gesture, family, local, head, center[0], center[1], angle, scale, hot, alpha * life);
        }

        private float v159PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.012f) / 0.18f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.875f) / 0.115f, 0f, 1f));
            return appear * vanish;
        }

        private float v159Head(float local) {
            float h = smoother(clamp((local - 0.018f) / 0.72f, 0f, 1f));
            float breath = 0.008f * (float)Math.sin(local * 6.2831853f * 1.08f) * waveEnvelope(h);
            return clamp(h + breath, 0f, 1f);
        }

        private float v159Tail(float local, float head) {
            // 尾部较早追赶，但保持足够可见窗口，避免“整段一次性消失”。
            float chase = smoother(clamp((local - 0.235f) / 0.54f, 0f, 1f));
            float window = 0.58f - 0.31f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.050f));
        }

        private int v159FamilyIndex(int gesture) {
            return (int)Math.floor(stableHash01(gesture, 15911) * 6.0f) % 6;
        }

        private float[] v159PhraseCenter(int gesture) {
            float cx = width * (0.18f + 0.62f * stableHash01(gesture, 15913));
            float cy = height * (0.20f + 0.50f * stableHash01(gesture, 15917));
            return new float[]{clamp(cx, width * 0.15f, width * 0.85f), clamp(cy, height * 0.18f, height * 0.74f)};
        }

        private float v159PhraseAngle(int gesture, float local) {
            float base = stableHash01(gesture, 15919) * 6.2831853f;
            // 参考视频是缓慢姿态呼吸，不是大幅度爬行。
            return base + 0.10f * (float)Math.sin(stableHash01(gesture, 15923) * 6.2831853f + local * 1.85f)
                    + 0.045f * (float)Math.sin(stableHash01(gesture, 15929) * 6.2831853f + local * 3.7f) * waveEnvelope(local);
        }

        private void drawV159EvolvingGlyph(int gesture, int family, float local, float tail, float head,
                                           float cx, float cy, float angle, float scale,
                                           float[] mid, float[] cyan, float[] hot, float alpha, boolean echo) {
            int samples = cfg.powerSave ? 34 : 58;
            ArrayList<float[]> core = buildV159Lane(gesture, family, local, tail, head, 0f, cx, cy, angle, scale, samples);
            if (core.size() < 2) return;
            float hue = fract(0.50f + stableHash01(gesture, 15931) * 0.34f + family * 0.042f + local * 0.050f);
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 0.98f, true);
            float mature = v159GlobalMaturity(local);
            float minD = Math.max(1f, Math.min(this.width, this.height));
            float lineWidth = Math.max(0.55f, minD * (0.0021f + 0.0010f * cfg.ribbonWidth));
            boolean surfaceLike = family == 0 || family == 1 || family == 2 || family == 3 || family == 4;
            if (surfaceLike && mature > 0.08f) {
                ArrayList<float[]> left = buildV159Lane(gesture, family, local, tail, head, -1f, cx, cy, angle, scale, samples);
                ArrayList<float[]> right = buildV159Lane(gesture, family, local, tail, head, 1f, cx, cy, angle, scale, samples);
                float sa = alpha * (echo ? 0.010f : 0.040f) * mature;
                drawRuledSurfaceAgeFaded(left, right, color[0], color[1], color[2], sa, 0.92f);
                if (!echo) {
                    drawAgeFadedStrip(left, Math.max(0.030f, lineWidth * 0.070f), color[0], color[1], color[2], alpha * 0.020f * mature, 0.92f, 0.22f);
                    drawAgeFadedStrip(right, Math.max(0.030f, lineWidth * 0.070f), hot[0], hot[1], hot[2], alpha * 0.018f * mature, 0.92f, 0.20f);
                }
            }
            drawAgeFadedStrip(core, Math.max(0.12f, lineWidth * (echo ? 0.34f : 0.70f)),
                    color[0], color[1], color[2], alpha * (echo ? 0.050f : 0.135f), 0.92f, echo ? 0.18f : 0.58f);
            if (!echo) {
                drawAgeFadedStrip(core, Math.max(0.035f, lineWidth * 0.125f),
                        0.96f, 1.00f, 1.00f, alpha * 0.062f, 0.96f, 0.82f);
            }
            // 只有场线/环网家族画极少量内部纹理，并且纹理从当前本体成熟度生长出来。
            if (!echo && (family == 1 || family == 4) && mature > 0.24f) {
                drawV159InteriorFilaments(gesture, family, local, tail, head, cx, cy, angle, scale, lineWidth, color, cyan, alpha * mature, samples);
            }
        }

        private float v159GlobalMaturity(float local) {
            return smoother(clamp((local - 0.060f) / 0.38f, 0f, 1f)) * (1f - 0.10f * smoother(clamp((local - 0.82f) / 0.12f, 0f, 1f)));
        }

        private ArrayList<float[]> buildV159Lane(int gesture, int family, float local, float tail, float head,
                                                 float lane, float cx, float cy, float angle, float scale, int samples) {
            ArrayList<float[]> pts = new ArrayList<>();
            for (int i = 0; i < samples; i++) {
                float q = i / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float[] p = v159Point(gesture, family, local, u, lane, scale);
                float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
                pts.add(new float[]{cx + ca * p[0] - sa * p[1], cy + sa * p[0] + ca * p[1]});
            }
            return pts;
        }

        private float[] v159Point(int gesture, int family, float local, float u, float lane, float scale) {
            float[] seed = v159SeedPoint(gesture, local, u, lane, scale);
            float[] t1 = v159TargetPoint(gesture, family, local, u, lane, scale, 0f);
            float[] t2 = v159TargetPoint(gesture, family, local, u, lane, scale, 1f);
            float birth = 0.018f + 0.72f * u;
            float age = local - birth;
            float maturity = smoother(clamp((age + 0.055f) / 0.34f, 0f, 1f));
            // 家族内部演化：不是跨越所有风格，而是在同一光形家族中从初型长成成熟型。
            float inner = smoother(clamp((age - 0.10f) / 0.42f, 0f, 1f));
            inner = clamp(inner + 0.10f * (float)Math.sin(local * 3.0f + stableHash01(gesture, 15937) * 6.2831853f) * waveEnvelope(u), 0f, 1f);
            float tx = lerp(t1[0], t2[0], inner);
            float ty = lerp(t1[1], t2[1], inner);
            float x = lerp(seed[0], tx, maturity);
            float y = lerp(seed[1], ty, maturity);
            float phase = stableHash01(gesture, 15941) * 6.2831853f;
            float env = waveEnvelope(u);
            x += scale * 0.0075f * (float)Math.sin(phase + local * 2.1f + u * 3.1f) * env * maturity;
            y += scale * 0.0060f * (float)Math.cos(phase * 0.7f + local * 1.8f + u * 2.6f) * env * maturity;
            return new float[]{x, y};
        }

        private float[] v159SeedPoint(int gesture, float local, float u, float lane, float scale) {
            float phase = stableHash01(gesture, 15943) * 6.2831853f;
            float env = waveEnvelope(u);
            float x = scale * (u - 0.50f) * 0.64f;
            float y = scale * (0.045f * (float)Math.sin(u * 3.1415927f * 1.25f + phase * 0.25f)
                    + lane * 0.012f * env);
            return new float[]{x, y};
        }

        private float[] v159TargetPoint(int gesture, int family, float local, float u, float lane, float scale, float variant) {
            float env = waveEnvelope(u);
            float phase = stableHash01(gesture, 15947) * 6.2831853f;
            float open = smoother(clamp((local - 0.05f) / 0.46f, 0f, 1f));
            float laneOpen = lane * open;
            float x;
            float y;
            if (family == 0) { // 书写丝带：由一笔长弧成熟为轻薄丝带。
                x = scale * (0.16f * (float)Math.sin((u - 0.12f) * 3.1415927f * (1.05f + 0.25f * variant) + phase * 0.16f)
                        + 0.040f * (float)Math.sin(u * 3.1415927f * (2.0f + variant) + local * 1.1f));
                y = scale * (u - 0.52f) * (0.82f + 0.10f * variant);
                x += laneOpen * scale * (0.018f + (0.070f + 0.040f * variant) * env);
            } else if (family == 1) { // 叶片/场线：由弧线成熟为轻网纱。
                float theta = -0.78f + (1.72f + 0.34f * variant) * u + 0.07f * (float)Math.sin(local * 1.4f + phase);
                float r = scale * (0.12f + (0.36f + 0.10f * variant) * env);
                x = r * (float)Math.cos(theta) + scale * (u - 0.50f) * 0.16f;
                y = r * (float)Math.sin(theta) * (0.62f + 0.08f * variant) + laneOpen * scale * (0.026f + 0.072f * env);
            } else if (family == 2) { // 宽薄翼面：一笔拉开成薄翼。
                x = scale * (u - 0.50f) * (0.76f + 0.14f * variant);
                y = scale * (0.08f * (float)Math.sin(u * 3.1415927f * (1.2f + 0.18f * variant) + phase * 0.18f)
                        + laneOpen * (0.026f + (0.135f + 0.060f * variant) * env * (1f - 0.22f * u)));
            } else if (family == 3) { // 钩形/花瓣：由短弧卷成花瓣回扫。
                float theta = -1.15f + (2.12f + 0.38f * variant) * u + 0.08f * (float)Math.sin(local * 1.8f + phase);
                float r = scale * (0.08f + (0.31f + 0.08f * variant) * env);
                x = scale * (u - 0.50f) * 0.26f + r * (float)Math.cos(theta) + laneOpen * scale * 0.035f * env;
                y = r * (float)Math.sin(theta) * 0.68f + laneOpen * scale * (0.024f + 0.020f * variant) * env;
            } else if (family == 4) { // 环形网纱：由半弧成熟为半闭合空间弧。
                float theta = -0.38f + (1.38f + 0.34f * variant) * 3.1415927f * u + 0.06f * (float)Math.sin(local * 1.5f + phase);
                float r = scale * (0.15f + (0.20f + 0.07f * variant) * env);
                x = r * (float)Math.cos(theta) + scale * (u - 0.50f) * 0.10f;
                y = r * (float)Math.sin(theta) * 0.64f + laneOpen * scale * (0.020f + 0.050f * env);
            } else { // 极简长弧：保持克制，只做细微弯曲成熟。
                x = scale * (u - 0.50f) * (0.76f + 0.10f * variant);
                y = scale * (0.070f * (float)Math.sin(u * 3.1415927f * (1.05f + 0.22f * variant) + phase * 0.32f)
                        + laneOpen * (0.028f + 0.018f * variant) * env);
            }
            return new float[]{x, y};
        }

        private void drawV159InteriorFilaments(int gesture, int family, float local, float tail, float head,
                                               float cx, float cy, float angle, float scale, float width,
                                               float[] color, float[] cyan, float alpha, int samples) {
            int lanes = cfg.powerSave ? 2 : 4;
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : (i / (lanes - 1f) - 0.5f) * 1.12f;
                ArrayList<float[]> line = buildV159Lane(gesture, family, local, tail, head, lane, cx, cy, angle, scale, Math.max(8, samples / 2));
                float a = alpha * (0.0075f + 0.012f * (1f - Math.min(1f, Math.abs(lane))));
                drawAgeFadedStrip(line, Math.max(0.024f, width * 0.055f), cyan[0], cyan[1], cyan[2], a, 0.92f, 0.16f);
            }
        }

        private void drawV159Tip(int gesture, int family, float local, float head,
                                 float cx, float cy, float angle, float scale,
                                 float[] hot, float alpha) {
            if (head <= 0.020f || alpha <= 0.001f) return;
            float[] p = v159Point(gesture, family, local, head, 0f, scale);
            float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
            float x = cx + ca * p[0] - sa * p[1];
            float y = cy + sa * p[0] + ca * p[1];
            float tipLife = 1f - smoother(clamp((local - 0.855f) / 0.10f, 0f, 1f));
            drawEllipse(x, y, Math.max(1.3f, scale * 0.0085f), Math.max(0.55f, scale * 0.0038f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.075f, 18);
        }

        private void drawReferenceVideoTimePainterV158(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V158：参考视频不是“同一条曲线在可见段内快速穿越 6 种样式”，而是
            // 一个清楚的光形短句在一段时间里保持统一的形态家族，同时内部参数缓慢呼吸、展开、退隐。
            // 因此 V158 将 V157 的 u*6.2 快速风格变化改为“单个参考 motif + 内部连续演化”。
            float local = clamp(raw, 0f, 0.999f);
            float life = v158PhraseLife(local);
            if (life <= 0.002f) return;
            float head = v158Head(local);
            float tail = v158Tail(local, head);
            float[] center = v158PhraseCenter(gesture);
            float scale = minDim * (0.54f + 0.17f * stableHash01(gesture, 15801));
            float angle = v158PhraseAngle(gesture, local);
            int motif = v158MotifIndex(gesture);
            if (head <= tail + 0.035f) {
                drawEllipse(center[0], center[1], minDim * 0.0080f, minDim * 0.0035f,
                        angle, hot[0], hot[1], hot[2], alpha * life * 0.090f, 18);
                return;
            }
            // 参考视频里旧痕迹是“同源时间切片”，不是重新画一组新主体。
            // 这里只保留两层极淡回声，并且回声使用同一 motif、同一中心，不再出现分身。
            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes; e >= 1; e--) {
                float oldLocal = local - e * 0.050f;
                if (oldLocal <= 0f) continue;
                float oldLife = v158PhraseLife(oldLocal);
                float oldHead = v158Head(oldLocal);
                float oldTail = v158Tail(oldLocal, oldHead);
                if (oldLife <= 0.004f || oldHead <= oldTail + 0.045f) continue;
                float echoAlpha = alpha * oldLife * (e == 1 ? 0.060f : 0.032f);
                drawV158ReferenceGlyph(gesture, motif, oldLocal, oldTail, oldHead,
                        center[0], center[1], v158PhraseAngle(gesture, oldLocal), scale,
                        mid, cyan, hot, echoAlpha, true);
            }
            drawV158ReferenceGlyph(gesture, motif, local, tail, head,
                    center[0], center[1], angle, scale, mid, cyan, hot, alpha * life, false);
            drawV158Tip(gesture, motif, local, head, center[0], center[1], angle, scale, hot, alpha * life);
        }

        private float v158PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.018f) / 0.16f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.86f) / 0.12f, 0f, 1f));
            return appear * vanish;
        }

        private float v158Head(float local) {
            float base = smoother(clamp((local - 0.020f) / 0.68f, 0f, 1f));
            float breath = 0.010f * (float)Math.sin(local * 6.2831853f * 1.15f) * waveEnvelope(base);
            return clamp(base + breath, 0f, 1f);
        }

        private float v158Tail(float local, float head) {
            // 尾部从中段开始追赶，制造“先画的内容边画边消失”。
            float chase = smoother(clamp((local - 0.24f) / 0.50f, 0f, 1f));
            float window = 0.62f - 0.34f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.060f));
        }

        private int v158MotifIndex(int gesture) {
            // 稳定但分布均匀：避免一段内部乱跳，又能保证每次短句不同。
            return (int)Math.floor(stableHash01(gesture, 15811) * 6.0f) % 6;
        }

        private float[] v158PhraseCenter(int gesture) {
            float cx = width * (0.20f + 0.58f * stableHash01(gesture, 15813));
            float cy = height * (0.22f + 0.48f * stableHash01(gesture, 15817));
            return new float[]{clamp(cx, width * 0.16f, width * 0.84f), clamp(cy, height * 0.18f, height * 0.72f)};
        }

        private float v158PhraseAngle(int gesture, float local) {
            float base = stableHash01(gesture, 15819) * 6.2831853f;
            // 只做缓慢姿态呼吸，不让主体像虫子一样持续爬动。
            return base + 0.14f * (float)Math.sin(stableHash01(gesture, 15823) * 6.2831853f + local * 2.0f)
                    + 0.06f * (float)Math.sin(stableHash01(gesture, 15829) * 6.2831853f + local * 4.2f) * waveEnvelope(local);
        }

        private void drawV158ReferenceGlyph(int gesture, int motif, float local, float tail, float head,
                                            float cx, float cy, float angle, float scale,
                                            float[] mid, float[] cyan, float[] hot, float alpha, boolean echo) {
            int samples = cfg.powerSave ? 32 : 52;
            ArrayList<float[]> core = buildV158Curve(gesture, motif, local, tail, head, 0f, cx, cy, angle, scale, samples);
            if (core.size() < 2) return;
            float hue = fract(0.52f + stableHash01(gesture, 15831) * 0.32f + motif * 0.045f + local * 0.055f);
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 0.96f, true);
            float open = smoother(clamp((local - 0.07f) / 0.34f, 0f, 1f));
            float lineWidth = Math.max(0.62f, Math.min(this.width, this.height) * (0.0024f + 0.0013f * cfg.ribbonWidth));
            float surfaceAlpha = alpha * (echo ? 0.016f : 0.052f) * open;
            boolean ribbonLike = motif == 0 || motif == 2 || motif == 3 || motif == 4;
            if (ribbonLike) {
                ArrayList<float[]> left = buildV158Curve(gesture, motif, local, tail, head, -1f, cx, cy, angle, scale, samples);
                ArrayList<float[]> right = buildV158Curve(gesture, motif, local, tail, head, 1f, cx, cy, angle, scale, samples);
                drawRuledSurfaceAgeFaded(left, right, color[0], color[1], color[2], surfaceAlpha, 0.92f);
                if (!echo) {
                    drawAgeFadedStrip(left, Math.max(0.04f, lineWidth * 0.10f), color[0], color[1], color[2], alpha * 0.030f, 0.92f, 0.26f);
                    drawAgeFadedStrip(right, Math.max(0.04f, lineWidth * 0.10f), hot[0], hot[1], hot[2], alpha * 0.028f, 0.92f, 0.24f);
                }
            }
            // 参考视频的主体通常是一条清楚的彩色光弦 + 很细的白色芯线。
            drawAgeFadedStrip(core, Math.max(0.16f, lineWidth * (echo ? 0.40f : 0.76f)),
                    color[0], color[1], color[2], alpha * (echo ? 0.052f : 0.150f), 0.92f, echo ? 0.20f : 0.62f);
            if (!echo) {
                drawAgeFadedStrip(core, Math.max(0.045f, lineWidth * 0.15f),
                        0.96f, 1.00f, 1.00f, alpha * 0.075f, 0.96f, 0.86f);
            }
            // 网纱/场线只作为“同一主体内部纹理”，数量克制，避免乱团。
            if (!echo && (motif == 1 || motif == 4)) {
                drawV158InteriorField(gesture, motif, local, tail, head, cx, cy, angle, scale, lineWidth, color, cyan, alpha, samples);
            }
        }

        private ArrayList<float[]> buildV158Curve(int gesture, int motif, float local, float tail, float head,
                                                  float lane, float cx, float cy, float angle, float scale, int samples) {
            ArrayList<float[]> pts = new ArrayList<>();
            for (int i = 0; i < samples; i++) {
                float q = i / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float[] p = v158Point(gesture, motif, local, u, lane, scale);
                float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
                pts.add(new float[]{cx + ca * p[0] - sa * p[1], cy + sa * p[0] + ca * p[1]});
            }
            return pts;
        }

        private float[] v158Point(int gesture, int motif, float local, float u, float lane, float scale) {
            float env = waveEnvelope(u);
            float open = smoother(clamp((local - 0.05f) / 0.42f, 0f, 1f));
            float phase = stableHash01(gesture, 15837) * 6.2831853f;
            float breathe = 0.88f + 0.16f * (float)Math.sin(phase + local * 2.0f);
            float laneOpen = lane * open;
            float x;
            float y;
            if (motif == 0) { // 细长书写丝带：类似参考视频开头的优雅竖弧。
                x = scale * (0.18f * (float)Math.sin((u - 0.18f) * Math.PI * 1.15f + phase * 0.18f)
                        + 0.040f * (float)Math.sin(u * Math.PI * 3.0f + local * 1.2f));
                y = scale * (u - 0.52f) * 0.92f;
                x += laneOpen * scale * (0.020f + 0.095f * env * breathe);
            } else if (motif == 1) { // 轻场线叶片/网纱。
                float theta = -0.92f + 2.05f * u + 0.08f * (float)Math.sin(local * 1.6f + phase);
                float r = scale * (0.12f + 0.48f * env);
                x = r * (float)Math.cos(theta) + scale * (u - 0.50f) * 0.12f;
                y = r * (float)Math.sin(theta) * 0.72f + laneOpen * scale * (0.030f + 0.090f * env);
            } else if (motif == 2) { // 宽薄翼/飘带。
                x = scale * (u - 0.50f) * 0.92f;
                y = scale * (0.10f * (float)Math.sin(u * Math.PI * 1.40f + phase * 0.20f)
                        + laneOpen * (0.030f + 0.205f * env * (1f - 0.28f * u)));
            } else if (motif == 3) { // 钩形/花瓣回扫。
                float theta = -1.28f + 2.55f * u + 0.10f * (float)Math.sin(local * 2.4f + phase);
                float r = scale * (0.08f + 0.40f * env);
                x = scale * (u - 0.50f) * 0.30f + r * (float)Math.cos(theta) + laneOpen * scale * 0.038f * env;
                y = r * (float)Math.sin(theta) * 0.70f + laneOpen * scale * 0.030f * env;
            } else if (motif == 4) { // 环形网纱/半闭合空间弧。
                float theta = -0.45f + 1.74f * (float)Math.PI * u + 0.08f * (float)Math.sin(local * 2.0f + phase);
                float r = scale * (0.17f + 0.28f * env);
                x = r * (float)Math.cos(theta) + scale * (u - 0.50f) * 0.12f;
                y = r * (float)Math.sin(theta) * 0.68f + laneOpen * scale * (0.024f + 0.060f * env);
            } else { // 极简长弧/细光线。
                x = scale * (u - 0.50f) * 0.88f;
                y = scale * (0.085f * (float)Math.sin(u * Math.PI * 1.25f + phase * 0.35f)
                        + laneOpen * 0.050f * env);
            }
            // 只允许细微活性，不让形体变成爬行动物式运动。
            x += scale * 0.012f * (float)Math.sin(phase + local * 3.0f + u * 2.7f) * env;
            y += scale * 0.010f * (float)Math.cos(phase * 0.7f + local * 2.4f + u * 2.2f) * env;
            return new float[]{x, y};
        }

        private void drawV158InteriorField(int gesture, int motif, float local, float tail, float head,
                                           float cx, float cy, float angle, float scale, float width,
                                           float[] color, float[] cyan, float alpha, int samples) {
            int lanes = cfg.powerSave ? 3 : 5;
            for (int i = 0; i < lanes; i++) {
                float lane = lanes <= 1 ? 0f : (i / (lanes - 1f) - 0.5f) * 1.35f;
                ArrayList<float[]> line = buildV158Curve(gesture, motif, local, tail, head, lane, cx, cy, angle, scale, Math.max(8, samples / 2));
                float a = alpha * (0.010f + 0.018f * (1f - Math.abs(lane) / 0.80f));
                drawAgeFadedStrip(line, Math.max(0.030f, width * 0.070f), cyan[0], cyan[1], cyan[2], a, 0.92f, 0.18f);
            }
        }

        private void drawV158Tip(int gesture, int motif, float local, float head,
                                 float cx, float cy, float angle, float scale,
                                 float[] hot, float alpha) {
            if (head <= 0.020f || alpha <= 0.001f) return;
            float[] p = v158Point(gesture, motif, local, head, 0f, scale);
            float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
            float x = cx + ca * p[0] - sa * p[1];
            float y = cy + sa * p[0] + ca * p[1];
            float tipLife = 1f - smoother(clamp((local - 0.84f) / 0.10f, 0f, 1f));
            drawEllipse(x, y, Math.max(1.6f, scale * 0.010f), Math.max(0.70f, scale * 0.0048f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.090f, 18);
        }

        private void drawReferenceVideoTimePainterV157(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V157：把 V156 的“每段固定 motif”改成“同一主体沿出生时间连续变形”。
            // 关键目标：不是直接替换完整形状，而是让一段正在被画出的光迹，
            // 在头部推进时依次长出线条、扇面、场线、丝带、花瓣、环形光弧，
            // 同时尾部持续追赶，让先画出的内容按节奏逐渐退隐。
            float local = clamp(raw, 0f, 0.999f);
            float life = v157PhraseLife(local);
            if (life <= 0.002f) return;
            float head = v157Head(local);
            float tail = v157Tail(local, head);
            if (head <= tail + 0.030f) {
                float[] c = v157PhraseCenter(gesture, minDim);
                drawEllipse(c[0], c[1], minDim * 0.006f, minDim * 0.0030f,
                        seedA, hot[0], hot[1], hot[2], alpha * life * 0.075f, 16);
                return;
            }
            float[] center = v157PhraseCenter(gesture, minDim);
            float scale = minDim * (0.46f + 0.15f * stableHash01(gesture, 15701));
            float angle = stableHash01(gesture, 15703) * 6.2831853f
                    + 0.18f * (float)Math.sin(seedA + local * 2.0f)
                    + 0.10f * (float)Math.sin(seedB + local * 3.6f) * waveEnvelope(local);
            float width = Math.max(0.76f, minDim * (0.0030f + 0.0016f * cfg.ribbonWidth));
            // 只保留一层非常淡的同源时间回声，表达“刚画过的痕迹在淡去”，避免复制主体。
            if (!cfg.powerSave) {
                float oldLocal = local - 0.060f;
                if (oldLocal > 0f) {
                    float oldLife = v157PhraseLife(oldLocal);
                    float oldHead = v157Head(oldLocal);
                    float oldTail = v157Tail(oldLocal, oldHead);
                    if (oldLife > 0.004f && oldHead > oldTail + 0.045f) {
                        drawV157EvolvingSubject(gesture, oldLocal, oldTail, oldHead,
                                center[0], center[1], angle, scale, width * 0.78f,
                                mid, cyan, hot, alpha * oldLife * 0.105f, true);
                    }
                }
            }
            drawV157EvolvingSubject(gesture, local, tail, head, center[0], center[1], angle,
                    scale, width, mid, cyan, hot, alpha * life, false);
            drawV157BrushTip(gesture, local, head, center[0], center[1], angle, scale, width, hot, alpha * life);
        }

        private float v157PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.012f) / 0.12f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.88f) / 0.10f, 0f, 1f));
            return appear * vanish;
        }

        private float v157Head(float local) {
            float raw = clamp((local - 0.018f) / 0.72f, 0f, 1f);
            float eased = smoother(raw);
            float breathe = 0.012f * (float)Math.sin(local * 6.2831853f * 1.4f) * waveEnvelope(raw);
            return clamp(eased + breathe, 0f, 1f);
        }

        private float v157Tail(float local, float head) {
            // 尾部从中前段就开始追赶：先画内容在创作过程中逐渐消失。
            float chase = smoother(clamp((local - 0.20f) / 0.58f, 0f, 1f));
            float window = 0.50f - 0.27f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.050f));
        }

        private float[] v157PhraseCenter(int gesture, float minDim) {
            float cx = width * (0.22f + 0.56f * stableHash01(gesture, 15711));
            float cy = height * (0.24f + 0.46f * stableHash01(gesture, 15713));
            cy = clamp(cy, height * 0.24f, height * 0.68f);
            return new float[]{cx, cy};
        }

        private void drawV157EvolvingSubject(int gesture, float local, float tail, float head,
                                             float cx, float cy, float angle, float scale, float width,
                                             float[] mid, float[] cyan, float[] hot, float alpha, boolean echo) {
            int samples = cfg.powerSave ? 24 : 38;
            ArrayList<float[]> core = buildV157Lane(gesture, local, tail, head, 0f, cx, cy, angle, scale, samples);
            if (core.size() < 2) return;
            float styleMid = v157StyleValue(gesture, local, (tail + head) * 0.5f);
            float hue = fract(0.52f + stableHash01(gesture, 15717) * 0.18f + styleMid * 0.020f + local * 0.080f);
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 0.94f, true);
            float bodyOpen = smoother(clamp((local - 0.07f) / 0.42f, 0f, 1f));
            float widthBoost = 0.88f + 0.30f * (float)Math.sin(styleMid * 1.7f + local * 2.1f) * waveEnvelope((tail + head) * 0.5f);
            ArrayList<float[]> left = buildV157Lane(gesture, local, tail, head, -1f, cx, cy, angle, scale, samples);
            ArrayList<float[]> right = buildV157Lane(gesture, local, tail, head, 1f, cx, cy, angle, scale, samples);
            float surfaceAlpha = alpha * (echo ? 0.020f : 0.050f) * bodyOpen;
            drawRuledSurfaceAgeFaded(left, right, color[0], color[1], color[2], surfaceAlpha, 0.90f);
            // 线条主体：彩色外光 + 细白芯线，避免多条白线堆叠成乱团。
            drawAgeFadedStrip(core, Math.max(0.18f, width * 0.56f * widthBoost),
                    color[0], color[1], color[2], alpha * (echo ? 0.060f : 0.145f), 0.90f, echo ? 0.20f : 0.58f);
            if (!echo) {
                drawAgeFadedStrip(core, Math.max(0.055f, width * 0.16f),
                        0.95f, 1.00f, 1.00f, alpha * 0.082f, 0.94f, 0.86f);
            }
            // 少量“随主体几何生成”的结构线，只在场线/扇面阶段轻微出现。
            float mode = fract(styleMid / 6f) * 6f;
            if (!echo && ((mode > 0.70f && mode < 2.55f) || (mode > 4.10f && mode < 4.85f))) {
                drawV157SubtleFieldLines(gesture, local, tail, head, cx, cy, angle, scale, width, color, cyan, alpha, samples);
            }
            // 边缘线控制主体边界，替代旧版本不明的两侧条纹。
            if (!echo) {
                drawAgeFadedStrip(left, Math.max(0.05f, width * 0.13f), color[0], color[1], color[2], alpha * 0.030f, 0.90f, 0.24f);
                drawAgeFadedStrip(right, Math.max(0.05f, width * 0.13f), hot[0], hot[1], hot[2], alpha * 0.032f, 0.92f, 0.28f);
            }
        }

        private ArrayList<float[]> buildV157Lane(int gesture, float local, float tail, float head,
                                                 float lane, float cx, float cy, float angle, float scale, int samples) {
            ArrayList<float[]> pts = new ArrayList<>();
            samples = Math.max(5, samples);
            for (int i = 0; i < samples; i++) {
                float q = i / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float[] p = v157Point(gesture, local, u, lane, scale);
                float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
                pts.add(new float[]{cx + ca * p[0] - sa * p[1], cy + sa * p[0] + ca * p[1]});
            }
            return pts;
        }

        private float v157StyleValue(int gesture, float local, float u) {
            // 风格由“出生位置 u”为主、local 为辅：新头部会持续发明新笔法，旧部分保留旧笔法并退隐。
            return stableHash01(gesture, 15719) * 6f + u * 6.20f + local * 0.72f;
        }

        private float[] v157Point(int gesture, float local, float u, float lane, float scale) {
            float styleValue = v157StyleValue(gesture, local, u);
            int styleA = ((int)Math.floor(styleValue)) % 6;
            int styleB = (styleA + 1) % 6;
            float mix = smoother(fract(styleValue));
            float[] a = v157PointForStyle(styleA, gesture, local, u, lane, scale);
            float[] b = v157PointForStyle(styleB, gesture, local, u, lane, scale);
            return new float[]{lerp(a[0], b[0], mix), lerp(a[1], b[1], mix)};
        }

        private float[] v157PointForStyle(int style, int gesture, float local, float u, float lane, float scale) {
            float env = waveEnvelope(u);
            float open = smoother(clamp((local - 0.06f) / 0.46f, 0f, 1f));
            float phase = stableHash01(gesture, 15723) * 6.2831853f;
            float laneOpen = lane * open;
            float x;
            float y;
            if (style == 0) { // 起笔线 / 极简长弧。
                x = scale * (u - 0.50f) * (0.92f + 0.06f * env);
                y = scale * (0.12f * (float)Math.sin(u * Math.PI * 1.18f + phase * 0.20f + local * 0.9f)
                        + laneOpen * env * 0.045f);
            } else if (style == 1) { // 扇形铺开。
                float a = -0.58f + 1.18f * u + 0.10f * (float)Math.sin(local * 2.7f + phase);
                float r = scale * (0.08f + 0.66f * smoother(u));
                x = r * (float)Math.cos(a) + laneOpen * scale * 0.045f * env;
                y = r * (float)Math.sin(a) * (0.66f + 0.10f * laneOpen);
            } else if (style == 2) { // 场线 / 网纱。
                x = scale * (u - 0.50f) * (0.70f + 0.18f * env);
                y = scale * (0.13f * (float)Math.sin(u * Math.PI * 2.1f + phase + local * 1.2f)
                        + laneOpen * (0.080f + 0.22f * env));
            } else if (style == 3) { // 飘带 / 薄翼。
                x = scale * (u - 0.50f) * (0.96f + 0.08f * env);
                y = scale * (0.09f * (float)Math.sin(u * Math.PI * 1.65f + phase * 0.40f)
                        + laneOpen * (0.028f + 0.23f * env * (1f - 0.35f * u)));
            } else if (style == 4) { // 花瓣 / 钩形回扫。
                float theta = (float)(-1.10f + 2.42f * u + 0.16f * Math.sin(local * 3.0f + phase));
                float r = scale * (0.11f + 0.42f * env);
                x = scale * (u - 0.50f) * 0.28f + r * (float)Math.cos(theta) + laneOpen * scale * 0.038f * env;
                y = r * (float)Math.sin(theta) * (0.62f + 0.12f * laneOpen);
            } else { // 环形光弧 / 半闭合网纱。
                float theta = (float)(-0.34f + 1.78f * Math.PI * u + 0.16f * Math.sin(local * 2.0f + phase));
                float r = scale * (0.17f + 0.27f * env);
                x = r * (float)Math.cos(theta) + scale * (u - 0.50f) * 0.14f;
                y = r * (float)Math.sin(theta) * 0.70f + laneOpen * scale * 0.045f * env;
            }
            return new float[]{x, y};
        }

        private void drawV157SubtleFieldLines(int gesture, float local, float tail, float head,
                                              float cx, float cy, float angle, float scale, float width,
                                              float[] color, float[] cyan, float alpha, int samples) {
            int ribs = cfg.powerSave ? 3 : 5;
            for (int r = 0; r < ribs; r++) {
                float lane = ribs <= 1 ? 0f : (r / (ribs - 1f) - 0.5f) * 1.55f;
                ArrayList<float[]> rib = buildV157Lane(gesture, local, tail, head, lane, cx, cy, angle, scale, Math.max(6, samples / 2));
                float a = alpha * (0.012f + 0.022f * (1f - Math.abs(lane) / 0.80f));
                drawAgeFadedStrip(rib, Math.max(0.035f, width * 0.10f), cyan[0], cyan[1], cyan[2], a, 0.90f, 0.18f);
            }
        }

        private void drawV157BrushTip(int gesture, float local, float head,
                                      float cx, float cy, float angle, float scale, float width,
                                      float[] hot, float alpha) {
            if (head <= 0.020f || alpha <= 0.001f) return;
            float[] p = v157Point(gesture, local, head, 0f, scale);
            float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
            float x = cx + ca * p[0] - sa * p[1];
            float y = cy + sa * p[0] + ca * p[1];
            float tipLife = 1f - smoother(clamp((local - 0.84f) / 0.10f, 0f, 1f));
            drawEllipse(x, y, Math.max(0.80f, width * 0.48f), Math.max(0.32f, width * 0.22f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.13f, 16);
        }

        private void drawReferenceVideoTimePainterV156(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            // V156：把参考视频抽象成“清晰主形体 + 连续生长窗口 + 早画早消失”。
            // 不再使用多 stream 乱线团，也不再让附着线承担主体变化。
            float local = clamp(raw, 0f, 0.999f);
            float life = v156PhraseLife(local);
            if (life <= 0.002f) return;
            int motif = v156MotifIndex(gesture);
            float[] center = v156PhraseCenter(gesture, minDim);
            float scale = minDim * (0.48f + 0.18f * stableHash01(gesture, 15601));
            float angle = stableHash01(gesture, 15603) * 6.2831853f
                    + 0.22f * (float)Math.sin(seedA + local * 2.20f)
                    + 0.14f * (float)Math.sin(seedB + local * 4.10f) * waveEnvelope(local);
            float width = Math.max(0.72f, minDim * (0.0034f + 0.0022f * cfg.ribbonWidth));
            float head = v156Head(local);
            float tail = v156Tail(local, head);
            if (head <= tail + 0.035f) {
                drawEllipse(center[0], center[1], width * 0.72f, width * 0.38f, angle,
                        hot[0], hot[1], hot[2], alpha * life * 0.10f, 18);
                return;
            }
            // 仅画一个主体，旧内容由 tail 裁掉；不主动复制完整历史主体。
            drawV156Motif(gesture, motif, local, tail, head, center[0], center[1], angle,
                    scale, width, mid, cyan, hot, alpha * life);
            drawV156BrushTip(gesture, motif, local, head, center[0], center[1], angle,
                    scale, width, hot, alpha * life);
        }

        private float v156PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.010f) / 0.13f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.86f) / 0.13f, 0f, 1f));
            return appear * vanish;
        }

        private float v156Head(float local) {
            float raw = clamp((local - 0.018f) / 0.74f, 0f, 1f);
            float eased = smoother(raw);
            float pulse = 0.018f * (float)Math.sin(local * 6.2831853f * 1.55f) * waveEnvelope(raw);
            return clamp(eased + pulse, 0f, 1f);
        }

        private float v156Tail(float local, float head) {
            // 尾部较早追赶，保持“先画先淡出”，避免等全画完一起消失。
            float chase = smoother(clamp((local - 0.23f) / 0.55f, 0f, 1f));
            float window = 0.66f - 0.38f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.055f));
        }

        private int v156MotifIndex(int gesture) {
            float r = stableHash01(gesture, 15607);
            if (r < 0.18f) return 0; // 长丝带
            if (r < 0.36f) return 1; // 扇形场线
            if (r < 0.55f) return 2; // 花瓣/钩形
            if (r < 0.73f) return 3; // 宽薄翼面
            if (r < 0.88f) return 4; // 环形网纱
            return 5;                // 极简光弧
        }

        private float[] v156PhraseCenter(int gesture, float minDim) {
            float cx = width * (0.20f + 0.60f * stableHash01(gesture, 15611));
            float cy = height * (0.24f + 0.48f * stableHash01(gesture, 15613));
            // 避开过低 Dock 区和过靠上的图标区。
            cy = clamp(cy, height * 0.22f, height * 0.70f);
            return new float[]{cx, cy};
        }

        private void drawV156Motif(int gesture, int motif, float local, float tail, float head,
                                   float cx, float cy, float angle, float scale, float width,
                                   float[] mid, float[] cyan, float[] hot, float alpha) {
            int samples = cfg.powerSave ? 24 : 36;
            ArrayList<float[]> core = buildV156Lane(gesture, motif, local, tail, head, 0f, cx, cy, angle, scale, samples);
            if (core.size() < 2) return;
            float hue = fract(0.50f + stableHash01(gesture, 15617) * 0.22f + local * 0.12f + motif * 0.045f);
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 0.95f, true);
            float bodyOpen = smoother(clamp((local - 0.12f) / 0.50f, 0f, 1f));
            if (motif == 1) {
                drawV156FanField(gesture, local, tail, head, cx, cy, angle, scale, width, color, cyan, alpha, samples);
            } else if (motif == 4) {
                drawV156LoopMesh(gesture, local, tail, head, cx, cy, angle, scale, width, color, cyan, alpha, samples);
            } else {
                ArrayList<float[]> laneA = buildV156Lane(gesture, motif, local, tail, head, -1f, cx, cy, angle, scale, samples);
                ArrayList<float[]> laneB = buildV156Lane(gesture, motif, local, tail, head, 1f, cx, cy, angle, scale, samples);
                float surfaceAlpha = alpha * (motif == 5 ? 0.018f : 0.055f) * bodyOpen;
                drawRuledSurfaceAgeFaded(laneA, laneB, color[0], color[1], color[2], surfaceAlpha, 0.90f);
                drawAgeFadedStrip(laneA, Math.max(0.08f, width * 0.28f), color[0], color[1], color[2], alpha * 0.030f, 0.90f, 0.25f);
                drawAgeFadedStrip(laneB, Math.max(0.08f, width * 0.32f), hot[0], hot[1], hot[2], alpha * 0.050f, 0.92f, 0.40f);
            }
            // 清晰主笔触：一条彩色外光 + 一条极细白色芯线。
            drawAgeFadedStrip(core, Math.max(0.16f, width * (motif == 5 ? 0.46f : 0.62f)), color[0], color[1], color[2], alpha * 0.145f, 0.90f, 0.58f);
            drawAgeFadedStrip(core, Math.max(0.06f, width * 0.18f), 0.96f, 1.00f, 1.00f, alpha * 0.100f, 0.94f, 0.88f);
        }

        private ArrayList<float[]> buildV156Lane(int gesture, int motif, float local, float tail, float head,
                                                 float lane, float cx, float cy, float angle, float scale, int samples) {
            ArrayList<float[]> pts = new ArrayList<>();
            samples = Math.max(4, samples);
            for (int i = 0; i < samples; i++) {
                float q = i / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float[] p = v156Point(gesture, motif, local, u, lane, scale);
                float x = p[0], y = p[1];
                float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
                pts.add(new float[]{cx + ca * x - sa * y, cy + sa * x + ca * y});
            }
            return pts;
        }

        private float[] v156Point(int gesture, int motif, float local, float u, float lane, float scale) {
            float env = waveEnvelope(u);
            float open = smoother(clamp((local - 0.10f) / 0.52f, 0f, 1f));
            float phase = stableHash01(gesture, 15619) * 6.2831853f;
            float laneOpen = lane * open;
            float x, y;
            if (motif == 0) { // 长丝带：像参考视频中大弧线逐渐拖出薄翼。
                x = scale * (u - 0.50f) * (0.92f + 0.12f * env);
                y = scale * (0.16f * (float)Math.sin(u * Math.PI * 1.35f + phase * 0.35f + local * 1.2f)
                        + laneOpen * env * (0.045f + 0.18f * smoother(u)));
            } else if (motif == 1) { // 扇形：点位用于主芯线，扇面另画。
                float a = -0.52f + 1.04f * u + 0.10f * (float)Math.sin(local * 3.0f + phase);
                float r = scale * (0.08f + 0.62f * smoother(u));
                x = r * (float)Math.cos(a);
                y = r * (float)Math.sin(a) * 0.72f + laneOpen * scale * 0.035f * env;
            } else if (motif == 2) { // 花瓣/钩形：不是闭合模板，而是连续回扫。
                float theta = (float)(-1.05f + 2.25f * u + 0.18f * Math.sin(local * 3.6f + phase));
                float r = scale * (0.12f + 0.40f * env);
                x = scale * (u - 0.50f) * 0.34f + r * (float)Math.cos(theta) + laneOpen * scale * 0.032f * env;
                y = r * (float)Math.sin(theta) * (0.58f + 0.10f * laneOpen);
            } else if (motif == 3) { // 宽薄翼面：参考白/青薄片状光带。
                x = scale * (u - 0.50f) * (0.80f + 0.18f * env);
                y = scale * (0.10f * (float)Math.sin(u * Math.PI * 1.8f + phase)
                        + laneOpen * (0.026f + 0.22f * env * (1f - 0.35f * u)));
            } else if (motif == 4) { // 环形网纱：点位用于主弧。
                float theta = (float)(-0.30f + 1.88f * Math.PI * u + 0.20f * Math.sin(local * 2.1f + phase));
                float r = scale * (0.19f + 0.26f * env);
                x = r * (float)Math.cos(theta) + scale * (u - 0.50f) * 0.16f;
                y = r * (float)Math.sin(theta) * 0.72f + laneOpen * scale * 0.030f * env;
            } else { // 极简光弧：留给参考视频里很克制的一笔。
                x = scale * (u - 0.50f) * 0.86f;
                y = scale * (0.18f * (float)Math.sin(u * Math.PI * 1.1f + phase * 0.25f + local * 0.9f)
                        + laneOpen * 0.055f * env);
            }
            return new float[]{x, y};
        }

        private void drawV156FanField(int gesture, float local, float tail, float head,
                                      float cx, float cy, float angle, float scale, float width,
                                      float[] color, float[] cyan, float alpha, int samples) {
            int ribs = cfg.powerSave ? 6 : 10;
            for (int r = 0; r < ribs; r++) {
                float lane = ribs <= 1 ? 0f : (r / (ribs - 1f) - 0.5f) * 2f;
                ArrayList<float[]> rib = buildV156Lane(gesture, 1, local, tail, head, lane, cx, cy, angle, scale, Math.max(6, samples / 2));
                float laneAlpha = alpha * (0.030f + 0.030f * (1f - Math.abs(lane)));
                drawAgeFadedStrip(rib, Math.max(0.04f, width * 0.16f), color[0], color[1], color[2], laneAlpha, 0.90f, 0.28f);
            }
        }

        private void drawV156LoopMesh(int gesture, float local, float tail, float head,
                                      float cx, float cy, float angle, float scale, float width,
                                      float[] color, float[] cyan, float alpha, int samples) {
            int lanes = cfg.powerSave ? 4 : 7;
            for (int r = 0; r < lanes; r++) {
                float lane = lanes <= 1 ? 0f : (r / (lanes - 1f) - 0.5f) * 2f;
                ArrayList<float[]> rib = buildV156Lane(gesture, 4, local, tail, head, lane, cx, cy, angle, scale, Math.max(8, samples / 2));
                float laneAlpha = alpha * (0.020f + 0.026f * (1f - Math.abs(lane)));
                drawAgeFadedStrip(rib, Math.max(0.04f, width * 0.13f), cyan[0], cyan[1], cyan[2], laneAlpha, 0.92f, 0.20f);
            }
        }

        private void drawV156BrushTip(int gesture, int motif, float local, float head,
                                      float cx, float cy, float angle, float scale, float width,
                                      float[] hot, float alpha) {
            if (head <= 0.025f || alpha <= 0.001f) return;
            float[] p = v156Point(gesture, motif, local, head, 0f, scale);
            float ca = (float)Math.cos(angle), sa = (float)Math.sin(angle);
            float x = cx + ca * p[0] - sa * p[1];
            float y = cy + sa * p[0] + ca * p[1];
            float tipLife = 1f - smoother(clamp((local - 0.82f) / 0.12f, 0f, 1f));
            drawEllipse(x, y, Math.max(0.9f, width * 0.60f), Math.max(0.35f, width * 0.28f), angle,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.16f, 18);
        }

        private void drawReferenceVideoTimePainterV154(int gesture, float raw, float minDim, float drawSec,
                                                       float seedA, float seedB, float seedC,
                                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            float local = clamp(raw, 0f, 0.999f);
            float life = v154PhraseLife(local);
            if (life <= 0.002f) return;
            float[] center = pureUnifiedCreationCenter(gesture);
            // 参考视频里主体不是满屏乱铺，而是黑场中一段一段被画出来的“光短句”。
            float phraseScale = minDim * (0.46f + 0.16f * stableHash01(gesture, 15401));
            float baseAngle = stableHash01(gesture, 15403) * 6.2831853f
                    + 0.55f * (float)Math.sin(seedA + local * 6.2831853f * 0.74f)
                    + 0.24f * (float)Math.sin(seedB + local * 6.2831853f * 1.43f) * waveEnvelope(local);
            float tx = (float)Math.cos(baseAngle), ty = (float)Math.sin(baseAngle);
            float nx = -ty, ny = tx;
            float widthBase = Math.max(0.58f, minDim * (0.0020f + 0.0015f * cfg.ribbonWidth));
            // 当前画到哪里、旧笔痕追到哪里：实现“边画边消失”，而不是全部画完才一起消失。
            float head = v154Head(local);
            float tail = v154Tail(local, head);
            if (head <= tail + 0.018f) {
                drawEllipse(center[0], center[1], widthBase * 0.70f, widthBase * 0.35f, baseAngle,
                        hot[0], hot[1], hot[2], alpha * life * 0.12f, 16);
                return;
            }
            // 极少量同源时间回声，只呈现“刚画过的短笔痕正在淡去”，不是复制完整主体。
            int echoes = cfg.powerSave ? 1 : 2;
            for (int e = echoes - 1; e >= 0; e--) {
                float lt = local - e * 0.045f;
                if (lt < 0f) continue;
                float eLife = v154PhraseLife(lt);
                if (eLife <= 0.002f) continue;
                float eHead = v154Head(lt);
                float eTail = v154Tail(lt, eHead);
                if (eHead <= eTail + 0.018f) continue;
                float echoAlpha = alpha * eLife * (e == 0 ? 1.0f : (0.12f / (e + 0.80f)));
                drawV154UnifiedCreativeField(gesture, lt, eTail, eHead, center[0], center[1], tx, ty, nx, ny,
                        phraseScale, widthBase, mid, cyan, hot, echoAlpha, e > 0);
            }
            drawV154LiveBrushTip(gesture, local, head, center[0], center[1], tx, ty, nx, ny,
                    phraseScale, widthBase, hot, alpha * life);
        }

        private float v154PhraseLife(float local) {
            float appear = smoother(clamp((local - 0.015f) / 0.16f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.88f) / 0.12f, 0f, 1f));
            return appear * vanish;
        }

        private float v154Head(float local) {
            // 头部推进不是线性，先慢速起笔，中段加速，末端提笔。
            float raw = clamp((local - 0.025f) / 0.72f, 0f, 1f);
            float eased = smoother(raw);
            float breath = 0.025f * (float)Math.sin(local * 6.2831853f * 2.05f) * waveEnvelope(raw);
            return clamp(eased + breath, 0f, 1f);
        }

        private float v154Tail(float local, float head) {
            // 尾部从中前段就开始追赶，让先画出的笔痕逐渐消失。
            float chase = smoother(clamp((local - 0.18f) / 0.64f, 0f, 1f));
            float window = 0.50f - 0.27f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.035f));
        }

        private void drawV154UnifiedCreativeField(int gesture, float local, float tail, float head,
                                                  float cx, float cy, float tx, float ty, float nx, float ny,
                                                  float scale, float widthBase,
                                                  float[] mid, float[] cyan, float[] hot, float alpha, boolean echo) {
            // V155：每条 stream 只是同一笔刷里的少量笔毛，不允许堆成独立乱线团。
            int streams = echo ? (cfg.powerSave ? 3 : 4) : (cfg.powerSave ? 5 : 7);
            for (int s = 0; s < streams; s++) {
                float lane = streams <= 1 ? 0f : (s / (streams - 1f) - 0.5f) * 2f;
                float laneJitter = stableSigned(gesture + s * 43, 15411) * 0.024f;
                float activeLane = clamp(lane * 0.62f + laneJitter, -0.72f, 0.72f);
                // 不同笔毛只保留极小延迟，避免出现多段互相打架的线团。
                float birthShift = 0.008f * stableHash01(gesture + s * 53, 15413);
                float segTail = clamp(tail - birthShift, 0f, 1f);
                float segHead = clamp(head - birthShift, 0f, 1f);
                if (segHead <= segTail + 0.035f) continue;
                ArrayList<float[]> pts = buildV154StreamPath(gesture, s, activeLane, local, segTail, segHead,
                        cx, cy, tx, ty, nx, ny, scale, echo ? 9 : 16);
                if (pts.size() < 2) continue;
                float style = v154LocalStyle(local, (segHead + segTail) * 0.5f, activeLane, gesture);
                float hue = fract(0.54f + stableHash01(gesture + s * 71, 15417) * 0.16f + local * 0.15f + style * 0.018f);
                float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 0.92f, true);
                float env = waveEnvelope((segHead + segTail) * 0.5f);
                float lanePower = 1f - 0.46f * Math.abs(activeLane);
                float centerBoost = 1f - Math.min(1f, Math.abs(lane));
                float width = widthBase * (0.36f + 0.72f * env) * (0.70f + 0.30f * lanePower) * (0.70f + 0.35f * centerBoost) * (echo ? 0.42f : 0.86f);
                float a = alpha * (echo ? 0.18f : 0.62f) * (0.42f + 0.58f * lanePower);
                drawAgeFadedStrip(pts, Math.max(0.08f, width), color[0], color[1], color[2], a, 0.88f, echo ? 0.15f : 0.62f);
                // 只给中心主笔毛一条轻高光，避免白色线条互相缠绕成乱团。
                if (!echo && Math.abs(lane) < 0.18f) {
                    drawAgeFadedStrip(pts, Math.max(0.045f, width * 0.24f), 0.93f, 1.00f, 1.00f, a * 0.38f, 0.92f, 0.78f);
                }
                // 肋线是截图中乱糊的关键原因，V155 只在场线阶段极少量出现。
                if (!echo && style > 1.7f && style < 2.6f && s == streams / 2) {
                    drawV154SoftRib(pts, scale, width, cyan, a * 0.10f);
                }
            }
        }

        private ArrayList<float[]> buildV154StreamPath(int gesture, int stream, float lane, float local,
                                                       float tail, float head,
                                                       float cx, float cy, float tx, float ty, float nx, float ny,
                                                       float scale, int samples) {
            ArrayList<float[]> pts = new ArrayList<>();
            samples = Math.max(4, samples);
            for (int i = 0; i < samples; i++) {
                float q = i / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float[] lp = v154LocalPoint(gesture, stream, lane, local, u, scale);
                float x = cx + tx * lp[0] + nx * lp[1];
                float y = cy + ty * lp[0] + ny * lp[1];
                pts.add(new float[]{x, y});
            }
            return pts;
        }

        private float[] v154LocalPoint(int gesture, int stream, float lane, float local, float u, float scale) {
            // V155：风格变化必须慢速、连续、统一；不能每条笔毛各自乱跳。
            // 旧内容保留旧笔法并淡出，新头部进入下一笔法，形成清楚的“时间绘画”。
            float styleTime = clamp(u * 0.72f + local * 0.28f, 0f, 0.999f);
            float stage = clamp(styleTime * 3.85f, 0f, 3.999f);
            int stageIndex = clampInt((int)Math.floor(stage), 0, 3);
            float mix = smoother(stage - stageIndex);
            int modeA = v154StyleIndex(gesture, stageIndex);
            int modeB = v154StyleIndex(gesture, stageIndex + 1);
            float[] a = v154PointForMode(modeA, gesture, stream, lane, local, u, scale);
            float[] b = v154PointForMode(modeB, gesture, stream, lane, local, u, scale);
            return new float[]{lerp(a[0], b[0], mix), lerp(a[1], b[1], mix)};
        }

        private float v154LocalStyle(float local, float u, float lane, int gesture) {
            float styleTime = clamp(u * 0.72f + local * 0.28f, 0f, 0.999f);
            return clamp(styleTime * 3.85f, 0f, 3.999f);
        }

        private int v154StyleIndex(int gesture, int stage) {
            int seed = clampInt((int)Math.floor(stableHash01(gesture, 15431) * 4f), 0, 3);
            // 去掉最容易造成乱团的星芒爆发，只保留线条、丝带、扇形、场线、花瓣的连续演化。
            int[] seq = new int[]{0, 3, 1, 2, 4, 3, 0};
            return seq[(stage + seed) % seq.length];
        }

        private float[] v154PointForMode(int mode, int gesture, int stream, float lane, float local, float u, float scale) {
            float env = waveEnvelope(u);
            float phase = stableHash01(gesture + stream * 97, 15437) * 6.2831853f;
            float laneSoft = lane * (0.78f + 0.22f * (float)Math.sin(local * 5.0f + stream * 0.31f));
            float x, y;
            if (mode == 1) { // 扇形/波束：头部逐渐打开，而不是直接出现一个扇形。
                float open = smoother(clamp((u - 0.08f) / 0.72f, 0f, 1f));
                x = scale * (-0.34f + 0.78f * u + 0.06f * (float)Math.sin(local * 8f + phase));
                y = scale * (laneSoft * (0.04f + 0.25f * open) + 0.045f * (float)Math.sin(u * Math.PI * 2.0f + phase));
            } else if (mode == 2) { // 场线/网纱：多根笔毛相互平行又缓慢弯曲。
                x = scale * (u - 0.50f) * (0.92f + 0.06f * (float)Math.sin(phase));
                y = scale * (laneSoft * 0.22f + 0.070f * env * (float)Math.sin(u * Math.PI * 2.25f + local * 4.0f + phase));
            } else if (mode == 3) { // 飘带：局部拉宽并漂浮。
                x = scale * (u - 0.50f) * (0.75f + 0.18f * env);
                y = scale * (0.17f * env * (float)Math.sin(u * Math.PI * 1.45f + laneSoft * 0.65f + local * 2.0f)
                        + laneSoft * 0.16f * (0.30f + 0.70f * env));
            } else if (mode == 4) { // 花瓣/钩形：连续回扫，不是预制花瓣。
                float theta = (float)(Math.PI * (0.12f + 1.55f * u)) + laneSoft * 0.38f + 0.20f * (float)Math.sin(local * 4.0f + phase);
                float r = scale * (0.13f + 0.38f * env);
                x = scale * (u - 0.50f) * 0.34f + r * (float)Math.cos(theta);
                y = r * (float)Math.sin(theta) * (0.60f + 0.22f * laneSoft);
            } else if (mode == 5) { // 星芒/喷泉：短暂爆发后由尾部追赶淡去。
                float theta = phase * 0.35f + laneSoft * 1.75f + u * 1.15f;
                float r = scale * (0.06f + 0.34f * smoother(u)) * (0.72f + 0.24f * env);
                x = r * (float)Math.cos(theta);
                y = r * (float)Math.sin(theta) * 0.76f;
            } else { // 初始书写线：只作为起笔阶段，很快被后续模式接管。
                x = scale * (u - 0.50f) * 0.82f;
                y = scale * (laneSoft * 0.08f + 0.10f * env * (float)Math.sin(u * Math.PI * 1.35f + phase + local * 1.4f));
            }
            return new float[]{x, y};
        }

        private void drawV154SoftRib(ArrayList<float[]> pts, float scale, float width, float[] cyan, float alpha) {
            if (pts.size() < 4 || alpha <= 0.001f) return;
            int n = pts.size();
            int step = cfg.powerSave ? 5 : 4;
            for (int i = step; i < n - step; i += step) {
                float[] p = pts.get(i);
                float[] a = pts.get(Math.max(0, i - 1));
                float[] b = pts.get(Math.min(n - 1, i + 1));
                float dx = b[0] - a[0], dy = b[1] - a[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float nx = -dy / dl, ny = dx / dl;
                float len = Math.min(scale * 0.036f, width * 2.2f);
                ArrayList<float[]> rib = new ArrayList<>(2);
                rib.add(new float[]{p[0] - nx * len * 0.20f, p[1] - ny * len * 0.20f});
                rib.add(new float[]{p[0] + nx * len, p[1] + ny * len});
                drawAgeFadedStrip(rib, Math.max(0.04f, width * 0.16f), cyan[0], cyan[1], cyan[2], alpha, 0.86f, 0.06f);
            }
        }

        private void drawV154LiveBrushTip(int gesture, float local, float head,
                                          float cx, float cy, float tx, float ty, float nx, float ny,
                                          float scale, float widthBase, float[] hot, float alpha) {
            if (head <= 0.02f || alpha <= 0.001f) return;
            float lane = stableSigned(gesture, 15461) * 0.20f;
            float[] lp = v154LocalPoint(gesture, 0, lane, local, head, scale);
            float x = cx + tx * lp[0] + nx * lp[1];
            float y = cy + ty * lp[0] + ny * lp[1];
            float tipLife = (1f - smoother(clamp((local - 0.82f) / 0.16f, 0f, 1f)));
            drawEllipse(x, y, Math.max(0.8f, widthBase * 0.92f), Math.max(0.35f, widthBase * 0.42f),
                    stableHash01(gesture, 15467) * 6.2831853f + local * 0.9f,
                    hot[0], hot[1], hot[2], alpha * tipLife * 0.12f, 16);
        }

        private float flowFieldCreationLife(float local) {
            float appear = smoother(clamp((local - 0.010f) / 0.18f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.84f) / 0.16f, 0f, 1f));
            return appear * vanish;
        }

        private float flowFieldStylePulse(float local, float lane, int gesture) {
            float primary = 0.5f + 0.5f * (float)Math.sin(local * 6.2831853f * 2.25f + lane * 1.80f + stableHash01(gesture, 20131) * 6.2831853f);
            float secondary = 0.5f + 0.5f * (float)Math.sin(local * 6.2831853f * 5.10f + lane * 4.70f + stableHash01(gesture, 20137) * 6.2831853f);
            return clamp(primary * 0.72f + secondary * 0.28f, 0f, 1f);
        }

        private int flowFieldStyleIndex(int gesture, float t, float lane) {
            int seed = clampInt((int)Math.floor(stableHash01(gesture, 20141) * 6f), 0, 5);
            int[] seq = new int[]{0, 1, 4, 3, 2, 5, 1, 3, 4, 2};
            int stage = clampInt((int)Math.floor(clamp(t, 0f, 0.999f) * 6.0f + 0.55f * lane), 0, 6);
            return seq[(stage + seed) % seq.length];
        }

        private int flowFieldNextStyleIndex(int gesture, float t, float lane) {
            int seed = clampInt((int)Math.floor(stableHash01(gesture, 20141) * 6f), 0, 5);
            int[] seq = new int[]{0, 1, 4, 3, 2, 5, 1, 3, 4, 2};
            int stage = clampInt((int)Math.floor(clamp(t, 0f, 0.999f) * 6.0f + 0.55f * lane) + 1, 0, 7);
            return seq[(stage + seed) % seq.length];
        }

        private float flowFieldStyleMix(float t, float lane) {
            float x = fract(clamp(t, 0f, 0.999f) * 6.0f + 0.55f * lane);
            return smoother(clamp((x - 0.42f) / 0.42f, 0f, 1f));
        }

        private float[] flowFieldParticleLocalPoint(int gesture, int particle, float lane, float age, float t, float scale) {
            int aMode = flowFieldStyleIndex(gesture, t, lane);
            int bMode = flowFieldNextStyleIndex(gesture, t, lane);
            float mix = flowFieldStyleMix(t, lane);
            float[] a = flowFieldPointForMode(aMode, gesture, particle, lane, age, t, scale);
            float[] b = flowFieldPointForMode(bMode, gesture, particle, lane, age, t, scale);
            float wobble = stableSigned(gesture + particle * 13, 20147) * scale * 0.010f * (float)Math.sin(t * 18.0f + lane * 2.3f);
            return new float[]{lerp(a[0], b[0], mix), lerp(a[1], b[1], mix) + wobble};
        }

        private float[] flowFieldPointForMode(int mode, int gesture, int particle, float lane, float age, float t, float scale) {
            float env = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * clamp(age, 0f, 1f))), 0.55f);
            float laneSoft = lane * (0.72f + 0.28f * (float)Math.sin(particle * 0.37f + t * 4.0f));
            float phase = stableHash01(gesture + particle * 19, 20153) * 6.2831853f;
            float x, y;
            if (mode == 1) { // 扇面流场：粒子从核心向外张开，不是预制扇形直接出现。
                float open = smoother(clamp(age / 0.82f, 0f, 1f));
                x = scale * (-0.18f + 0.62f * open + 0.06f * (float)Math.sin(t * 9.0f + phase));
                y = scale * laneSoft * (0.08f + 0.46f * open) + scale * 0.06f * env * (float)Math.sin(t * 8.0f + phase);
            } else if (mode == 2) { // 旋涡/星芒：通过连续极坐标运动形成，旧粒子继续淡出。
                float theta = phase * 0.30f + laneSoft * 1.65f + age * (2.10f + 0.60f * stableHash01(particle, 20159));
                float r = scale * (0.08f + 0.56f * smoother(age)) * (0.82f + 0.18f * laneSoft);
                x = r * (float)Math.cos(theta);
                y = r * (float)Math.sin(theta) * 0.78f;
            } else if (mode == 3) { // 飘带流：多条粒子轨迹共同形成漂浮丝带。
                x = scale * (age - 0.48f) * (0.92f + 0.10f * laneSoft);
                y = scale * (0.25f * (float)Math.sin(age * Math.PI * 1.55f + laneSoft * 1.15f + t * 2.0f) + laneSoft * 0.16f) * env;
            } else if (mode == 4) { // 场线/网纱：平行但有相位差的线束，不是中心线两侧肋线。
                x = scale * (age - 0.50f) * 0.96f;
                y = scale * (laneSoft * 0.36f + 0.12f * (float)Math.sin(age * Math.PI * 2.0f + phase + t * 3.0f)) * (0.65f + 0.35f * env);
            } else if (mode == 5) { // 花瓣回扫：粒子群产生半闭合轮廓，但随时间连续生成。
                float theta = (float)(Math.PI * (0.12f + 1.55f * age)) + laneSoft * 0.42f;
                float r = scale * (0.16f + 0.40f * env);
                x = scale * (age - 0.50f) * 0.32f + r * (float)Math.cos(theta);
                y = r * (float)Math.sin(theta) * (0.62f + 0.22f * laneSoft);
            } else { // 起笔/书写流：只是出生阶段，很快被后续流场接管。
                x = scale * (age - 0.50f) * 0.80f;
                y = scale * (laneSoft * 0.10f + 0.12f * (float)Math.sin((age + t * 0.20f) * Math.PI * 1.25f + phase)) * env;
            }
            return new float[]{x, y};
        }

        private float flowFieldParticleWidth(int gesture, int particle, float lane, float local, float age) {
            int mode = flowFieldStyleIndex(gesture, local, lane);
            float env = waveEnvelope(age);
            float pulse = 0.88f + 0.22f * (float)Math.sin(local * 9.0f + particle * 0.73f);
            if (mode == 1) return (0.55f + 0.70f * env) * pulse;
            if (mode == 2) return (0.42f + 0.42f * env) * pulse;
            if (mode == 3) return (0.74f + 0.88f * env) * pulse;
            if (mode == 4) return (0.35f + 0.28f * env) * pulse;
            if (mode == 5) return (0.62f + 0.58f * env) * pulse;
            return (0.42f + 0.30f * env) * pulse;
        }

        private void drawMetamorphicCreativeBrush(int gesture, float raw, float minDim, float drawSec,
                                                  float seedA, float seedB, float seedC,
                                                  float[] mid, float[] cyan, float[] hot, float alpha) {
            float local = clamp(raw, 0f, 0.999f);
            float life = metamorphicBrushLife(local);
            if (life <= 0.002f) return;
            float[] center = pureUnifiedCreationCenter(gesture);
            float baseAngle = metamorphicBrushAngle(gesture, local);
            float baseScale = minDim * (0.72f + 0.24f * stableHash01(gesture + 61, 19117));
            float baseWidth = Math.max(1.00f, minDim * (0.0060f + 0.0048f * cfg.ribbonWidth));
            float hue = fract(0.53f + stableHash01(gesture, 19107) * 0.34f + local * 0.28f + drawSec * 0.010f);
            float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, 1f, true);
            // 少量同源时间切片：不是复制多个主体，而是同一主体“先画内容正在淡去”的痕迹。
            int echoes = cfg.powerSave ? 2 : 3;
            for (int e = echoes - 1; e >= 0; e--) {
                float t = local - e * 0.060f;
                if (t < 0f) continue;
                float echoLife = metamorphicBrushLife(t);
                if (echoLife <= 0.002f) continue;
                float echoA = alpha * life * echoLife * (e == 0 ? 1.0f : (0.28f / (e + 0.55f)));
                float angle = metamorphicBrushAngle(gesture, t);
                float scale = baseScale * (0.98f + 0.06f * (float)Math.sin(t * 6.2831853f + seedA));
                drawMetamorphicCreativeSlice(gesture, t, center[0], center[1], angle, scale, baseWidth,
                        color, cyan, hot, echoA * 2.05f, e > 0);
            }
        }

        private float metamorphicBrushLife(float local) {
            float appear = smoother(clamp((local - 0.010f) / 0.13f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.82f) / 0.18f, 0f, 1f));
            return appear * vanish;
        }

        private float metamorphicHead(float local) {
            return smoother(clamp((local - 0.020f) / 0.66f, 0f, 1f));
        }

        private float metamorphicTail(float local, float head) {
            // 让尾部在创作中段就开始追赶，保证“先画的内容边画边慢慢消失”。
            float chase = smoother(clamp((local - 0.20f) / 0.62f, 0f, 1f));
            float window = 0.58f - 0.20f * chase;
            return clamp(head - window, 0f, Math.max(0f, head - 0.05f));
        }

        private float metamorphicBrushAngle(int gesture, float local) {
            float base = stableHash01(gesture, 19201) * 6.2831853f;
            float drift = (stableHash01(gesture, 19203) - 0.5f) * 0.95f * smoother(local);
            float breath = 0.30f * (float)Math.sin(local * 6.2831853f * 1.35f + stableHash01(gesture, 19207) * 6.2831853f) * waveEnvelope(local);
            return base + drift + breath;
        }

        private void drawMetamorphicCreativeSlice(int gesture, float local, float cx, float cy, float angle,
                                                  float scale, float widthPx, float[] color, float[] cyan, float[] hot,
                                                  float alpha, boolean echo) {
            if (alpha <= 0.001f) return;
            float head = metamorphicHead(local);
            float tail = metamorphicTail(local, head);
            if (head <= tail + 0.025f) return;
            ArrayList<float[]> pts = buildMetamorphicVisibleCurve(gesture, local, tail, head, cx, cy, angle, scale, cfg.powerSave ? 28 : 46);
            if (pts.size() < 3) return;
            drawMetamorphicBody(pts, gesture, local, tail, head, scale, widthPx, color, cyan, hot, alpha, echo);
            if (!echo) drawMetamorphicTip(pts, local, widthPx, hot, alpha);
        }

        private ArrayList<float[]> buildMetamorphicVisibleCurve(int gesture, float local, float tail, float head,
                                                                float cx, float cy, float angle, float scale, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            samples = Math.max(10, samples);
            float tx = (float)Math.cos(angle);
            float ty = (float)Math.sin(angle);
            float nx = -ty;
            float ny = tx;
            for (int i = 0; i < samples; i++) {
                float q = i / Math.max(1f, samples - 1f);
                float u = lerp(tail, head, q);
                float[] p = metamorphicPoint(gesture, local, u, cx, cy, tx, ty, nx, ny, scale);
                out.add(p);
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private float metamorphicApproxBirthLocal(float u) {
            // head ~= smoother((local-.02)/.66)，这里用近似反函数让每个位置携带“出生时”的笔法，
            // 于是旧部分保留旧笔法并逐渐淡出，头部继续创造新笔法。
            float x = clamp(u, 0f, 1f);
            float inv = (float)Math.pow(x, 0.58f);
            return clamp(0.020f + 0.66f * inv, 0f, 0.999f);
        }

        private int metamorphicStyleAt(int gesture, float birthLocal) {
            // 不使用固定顺序；每轮创作有自己的笔法序列，但每一段是连续演变而不是模板替换。
            int seed = clampInt((int)Math.floor(stableHash01(gesture, 19301) * 6f), 0, 5);
            int[] seq = new int[]{0, 1, 3, 2, 4, 5, 2, 3, 1, 4};
            int stage = clampInt((int)Math.floor(clamp(birthLocal, 0f, 0.999f) * 6.0f), 0, 5);
            return seq[(stage + seed) % seq.length];
        }

        private int metamorphicNextStyleAt(int gesture, float birthLocal) {
            int seed = clampInt((int)Math.floor(stableHash01(gesture, 19301) * 6f), 0, 5);
            int[] seq = new int[]{0, 1, 3, 2, 4, 5, 2, 3, 1, 4};
            int stage = clampInt((int)Math.floor(clamp(birthLocal, 0f, 0.999f) * 6.0f) + 1, 0, 6);
            return seq[(stage + seed) % seq.length];
        }

        private float metamorphicStyleMix(float birthLocal) {
            float x = fract(clamp(birthLocal, 0f, 0.999f) * 6.0f);
            return smoother(clamp((x - 0.50f) / 0.32f, 0f, 1f));
        }

        private float[] metamorphicPoint(int gesture, float local, float u, float cx, float cy,
                                         float tx, float ty, float nx, float ny, float scale) {
            float birth = metamorphicApproxBirthLocal(u);
            int aMode = metamorphicStyleAt(gesture, birth);
            int bMode = metamorphicNextStyleAt(gesture, birth);
            float mix = metamorphicStyleMix(birth);
            float[] a = metamorphicPointForStyle(aMode, gesture, local, u, scale);
            float[] b = metamorphicPointForStyle(bMode, gesture, local, u, scale);
            float lx = lerp(a[0], b[0], mix);
            float ly = lerp(a[1], b[1], mix);
            return new float[]{cx + tx * lx + nx * ly, cy + ty * lx + ny * ly};
        }

        private float[] metamorphicPointForStyle(int mode, int gesture, float local, float u, float scale) {
            float s = u - 0.5f;
            float env = waveEnvelope(u);
            float phase = stableHash01(gesture, 19341) * 6.2831853f;
            float wobble = (float)Math.sin(phase + u * 6.2831853f * (1.1f + 0.8f * stableHash01(gesture, 19343)) + local * 2.0f);
            float x;
            float y;
            if (mode == 1) { // 扇面：头部从线条铺开成扇形
                float open = smoother(clamp((u - 0.10f) / 0.86f, 0f, 1f));
                x = scale * (-0.34f + open * 0.92f);
                y = scale * (s * (0.22f + 0.46f * open) + 0.06f * wobble * env);
            } else if (mode == 2) { // 场线：宽弯曲，但仍是同一主体的变形场
                x = scale * (s * 0.96f + 0.06f * (float)Math.sin(u * 9.0f + phase));
                y = scale * (0.26f * (float)Math.sin(u * Math.PI * 1.35f + local * 2.2f) + 0.11f * wobble) * env;
            } else if (mode == 3) { // 丝带：大 S 弧，带漂浮感
                x = scale * s * (0.86f + 0.18f * env);
                y = scale * (0.34f * (float)Math.sin((u * 1.55f + 0.12f) * Math.PI + local * 1.8f) + 0.06f * wobble) * env;
            } else if (mode == 4) { // 花瓣/回扫：半闭合但不直接替换成模板
                float theta = (float)(Math.PI * (0.16f + 1.54f * u));
                x = scale * (0.36f * (float)Math.cos(theta) + 0.26f * s);
                y = scale * (0.30f * (float)Math.sin(theta) * (0.72f + 0.28f * env));
            } else if (mode == 5) { // 星芒/喷泉：局部跃迁式创作
                float open = smoother(clamp((u - 0.06f) / 0.82f, 0f, 1f));
                float r = scale * (0.12f + 0.55f * open);
                float theta = phase * 0.35f + u * 4.2f + 0.22f * (float)Math.sin(local * 4.0f);
                x = -scale * 0.18f + r * (float)Math.cos(theta) * (0.50f + 0.55f * u);
                y = r * (float)Math.sin(theta) * 0.55f;
            } else { // 初始线条：只作为起笔阶段，不再长期固定为线
                x = scale * s * 0.78f;
                y = scale * (0.18f * (float)Math.sin((u + local * 0.12f) * Math.PI * 1.25f + phase * 0.1f)) * env;
            }
            return new float[]{x, y};
        }

        private float metamorphicStyleWidthFactor(int mode, float u) {
            float env = waveEnvelope(u);
            if (mode == 1) return 0.72f + 0.70f * env;   // 扇形更宽
            if (mode == 2) return 0.46f + 0.34f * env;   // 场线较细
            if (mode == 3) return 0.92f + 0.72f * env;   // 丝带较宽
            if (mode == 4) return 0.78f + 0.58f * env;   // 花瓣柔宽
            if (mode == 5) return 0.42f + 0.48f * env;   // 星芒偏细亮
            return 0.40f + 0.28f * env;
        }

        private void drawMetamorphicBody(ArrayList<float[]> pts, int gesture, float local, float tail, float head,
                                         float scale, float widthPx, float[] color, float[] cyan, float[] hot,
                                         float alpha, boolean echo) {
            int n = pts.size();
            if (n < 3) return;
            for (int i = 1; i < n; i++) {
                float q = (i - 0.5f) / Math.max(1f, n - 1f);
                float u = lerp(tail, head, q);
                float birth = metamorphicApproxBirthLocal(u);
                int mode = metamorphicStyleAt(gesture, birth);
                int next = metamorphicNextStyleAt(gesture, birth);
                float mix = metamorphicStyleMix(birth);
                int visualMode = mix > 0.55f ? next : mode;
                float age = smoother(clamp((u - tail) / Math.max(0.03f, head - tail), 0f, 1f));
                float fadeOld = 0.35f + 0.65f * age;
                float w = widthPx * metamorphicStyleWidthFactor(visualMode, q) * (echo ? 0.38f : 1.0f);
                float a = alpha * fadeOld * (echo ? 0.24f : 0.82f);
                ArrayList<float[]> seg = new ArrayList<>(2);
                seg.add(pts.get(i - 1));
                seg.add(pts.get(i));
                drawStrip(seg, Math.max(0.08f, w), color[0], color[1], color[2], a * 0.075f);
                drawStrip(seg, Math.max(0.05f, w * 0.33f), 0.98f, 1.00f, 1.00f, a * 0.100f);
            }
            if (!echo) {
                drawMetamorphicMorphAccents(pts, gesture, local, tail, head, scale, widthPx, color, cyan, hot, alpha);
            }
        }

        private void drawMetamorphicMorphAccents(ArrayList<float[]> pts, int gesture, float local, float tail, float head,
                                                 float scale, float widthPx, float[] color, float[] cyan, float[] hot, float alpha) {
            int n = pts.size();
            if (n < 5) return;
            int dominant = metamorphicStyleAt(gesture, metamorphicApproxBirthLocal(head));
            if (dominant == 1 || dominant == 5) {
                float[] root = pts.get(Math.max(0, n / 8));
                int rays = cfg.powerSave ? 4 : 7;
                for (int r = 0; r < rays; r++) {
                    float q = lerp(0.25f, 0.98f, r / Math.max(1f, rays - 1f));
                    float[] end = sampleCurveUnit(pts, q);
                    ArrayList<float[]> ray = new ArrayList<>();
                    ray.add(root);
                    ray.add(new float[]{lerp(root[0], end[0], 0.52f), lerp(root[1], end[1], 0.52f)});
                    ray.add(end);
                    drawAgeFadedStrip(ray, Math.max(0.035f, widthPx * 0.22f), cyan[0], cyan[1], cyan[2], alpha * 0.040f, 0.86f, 0.38f);
                }
            }
            if (dominant == 2) {
                int lanes = cfg.powerSave ? 2 : 4;
                for (int l = 0; l < lanes; l++) {
                    float off = (l - (lanes - 1f) * 0.5f) * scale * 0.035f;
                    ArrayList<float[]> lane = offsetVisibleCurve(pts, off);
                    drawAgeFadedStrip(lane, Math.max(0.025f, widthPx * 0.12f), cyan[0], cyan[1], cyan[2], alpha * 0.030f, 0.86f, 0.20f);
                }
            }
            if (dominant == 3 || dominant == 4) {
                ArrayList<float[]> outer = offsetVisibleCurve(pts, scale * (dominant == 3 ? 0.055f : 0.070f));
                ArrayList<float[]> inner = offsetVisibleCurve(pts, -scale * (dominant == 3 ? 0.020f : 0.030f));
                drawRuledSurfaceAgeFaded(inner, outer, dominant == 3 ? color[0] : hot[0], dominant == 3 ? color[1] : hot[1], dominant == 3 ? color[2] : hot[2], alpha * 0.032f, 0.84f);
            }
        }

        private void drawMetamorphicTip(ArrayList<float[]> pts, float local, float widthPx, float[] hot, float alpha) {
            if (pts == null || pts.isEmpty()) return;
            float[] tip = pts.get(pts.size() - 1);
            float a = alpha * (0.10f + 0.12f * smoother(clamp(local / 0.70f, 0f, 1f)));
            drawEllipse(tip[0], tip[1], Math.max(1.2f, widthPx * 2.2f), Math.max(0.7f, widthPx * 1.25f), local * 6.2831853f,
                    hot[0], hot[1], hot[2], a, 14);
        }

        private float evolvingArtBrushLife(float local) {
            // 起笔不突然，中段保持足够亮度，末段逐渐消散。
            float appear = smoother(clamp((local - 0.010f) / 0.12f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.82f) / 0.20f, 0f, 1f));
            return appear * vanish;
        }

        private float evolvingArtBrushHead(float local) {
            // 头部推进速度稍快，避免长时间只有一根极短线。
            return smoother(clamp((local - 0.025f) / 0.56f, 0f, 1f));
        }

        private float evolvingArtBrushTail(float local) {
            // 尾部更早开始追赶：先画的内容会在新内容继续生成时逐渐淡出。
            float chase = smoother(clamp((local - 0.18f) / 0.64f, 0f, 1f));
            return clamp(chase * 0.88f, 0f, 0.88f);
        }

        private float evolvingArtBrushAngle(int gesture, float local) {
            float base = stableHash01(gesture, 18201) * 6.2831853f;
            float turnA = (stableHash01(gesture, 18203) - 0.5f) * 1.30f;
            float turnB = 0.34f * (float)Math.sin(local * 6.2831853f * 1.25f + stableHash01(gesture, 18207) * 6.2831853f);
            return base + turnA * smoother(local) + turnB * waveEnvelope(local);
        }

        private void drawContinuousEvolvingArtBrush(int gesture, float local,
                                                    float cx, float cy, float angle, float scale, float widthPx,
                                                    float[] color, float[] cyan, float[] hot, float alpha) {
            if (alpha <= 0.001f) return;
            ArrayList<float[]> full = buildEvolvingArtBrushPath(gesture, local, cx, cy, angle, scale, cfg.powerSave ? 44 : 72);
            if (full.size() < 4) return;
            float head = evolvingArtBrushHead(local);
            float tail = Math.min(evolvingArtBrushTail(local), Math.max(0f, head - 0.10f));
            if (head <= tail + 0.018f) return;
            ArrayList<float[]> visible = subCurveUnit(full, tail, head, cfg.powerSave ? 28 : 48);
            if (visible.size() < 3) return;

            // 淡的旧部：只画同一笔迹已经过的部分，表现边画边消失，不画预制完整形状。
            if (tail > 0.035f) {
                float oldStart = Math.max(0f, tail - 0.22f);
                ArrayList<float[]> old = subCurveUnit(full, oldStart, tail, cfg.powerSave ? 16 : 28);
                if (old.size() > 2) {
                    drawAgeFadedStrip(old, Math.max(0.08f, widthPx * 0.38f), color[0], color[1], color[2], alpha * 0.085f, 0.86f, 0.28f);
                }
            }

            drawEvolvingArtBrushForm(visible, gesture, local, tail, head, scale, widthPx, color, cyan, hot, alpha);
            drawEvolvingArtBrushTip(visible, local, widthPx, hot, alpha);
        }

        private int evolvingBrushLiveMode(int gesture, float local) {
            // 同一轮创作内必须明显换笔法：线条 → 扇形 → 场线 → 丝带 → 花瓣/回扫。
            int stage = clampInt((int)Math.floor(clamp(local, 0f, 0.999f) * 5.0f), 0, 4);
            int seed = (int)(stableHash01(gesture, 18401) * 5.0f);
            int[] seq = new int[]{0, 1, 2, 3, 4};
            return seq[(stage + seed) % seq.length];
        }

        private int evolvingBrushNextMode(int gesture, float local) {
            int stage = clampInt((int)Math.floor(clamp(local, 0f, 0.999f) * 5.0f) + 1, 0, 4);
            int seed = (int)(stableHash01(gesture, 18401) * 5.0f);
            int[] seq = new int[]{0, 1, 2, 3, 4};
            return seq[(stage + seed) % seq.length];
        }

        private float evolvingBrushModeMix(float local) {
            float x = fract(clamp(local, 0f, 0.999f) * 5.0f);
            // 中间快速换形，两端稳定，让用户能看见“突然改变笔法”。
            return smoother(clamp((x - 0.58f) / 0.26f, 0f, 1f));
        }

        private float[] evolvingPathPointForMode(int mode, float u, int gesture, float local,
                                                  float cx, float cy, float tx, float ty, float nx, float ny, float scale) {
            float s = u - 0.5f;
            float envelope = waveEnvelope(u);
            float wobble = (float)Math.sin((u * 2.4f + local * 0.36f + stableHash01(gesture, 18411)) * 6.2831853f);
            float x = 0f, y = 0f;
            if (mode == 1) { // 扇形：从收束点展开到宽扇面
                float fan = (u - 0.08f) / 0.92f;
                float open = smoother(clamp(fan, 0f, 1f));
                float arc = (u - 0.5f) * (1.05f + 0.22f * (float)Math.sin(local * 5.0f));
                x = scale * (-0.30f + open * 0.78f);
                y = scale * (float)Math.sin(arc) * (0.36f + 0.10f * open);
            } else if (mode == 2) { // 场线/网纱：宽弯曲、细密但不独立分身
                x = scale * s * 0.95f;
                y = scale * (0.30f * (float)Math.sin(u * Math.PI * 1.25f + local * 2.0f) + 0.10f * wobble) * envelope;
            } else if (mode == 3) { // 飘带：长 S，尾部轻扬
                x = scale * s * 1.05f;
                y = scale * (0.34f * (float)Math.sin((u * 1.55f + 0.12f) * Math.PI + local * 1.8f)) * envelope;
            } else if (mode == 4) { // 花瓣/回扫：半闭合轮廓，但仍由同一笔迹发展出来
                float theta = (float)(Math.PI * (0.12f + 1.58f * u));
                x = scale * (0.42f * (float)Math.cos(theta) + 0.18f * s);
                y = scale * (0.34f * (float)Math.sin(theta) * (0.72f + 0.28f * envelope));
            } else { // 线条起笔：优雅弧线，不带两侧条纹
                x = scale * s * 0.88f;
                y = scale * (0.22f * (float)Math.sin((u + local * 0.16f) * Math.PI * 1.18f)) * envelope;
            }
            return new float[]{cx + tx * x + nx * y, cy + ty * x + ny * y};
        }

        private ArrayList<float[]> buildEvolvingArtBrushPath(int gesture, float local, float cx, float cy, float angle, float scale, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            samples = Math.max(18, samples);
            float tx = (float)Math.cos(angle);
            float ty = (float)Math.sin(angle);
            float nx = -ty;
            float ny = tx;
            int m0 = evolvingBrushLiveMode(gesture, local);
            int m1 = evolvingBrushNextMode(gesture, local);
            float mix = evolvingBrushModeMix(local);
            // 形体本身随创作阶段实时变，不再只是一条线旁边挂小装饰。
            for (int i = 0; i < samples; i++) {
                float u = i / Math.max(1f, samples - 1f);
                float[] a = evolvingPathPointForMode(m0, u, gesture, local, cx, cy, tx, ty, nx, ny, scale);
                float[] b = evolvingPathPointForMode(m1, u, gesture, local, cx, cy, tx, ty, nx, ny, scale);
                out.add(new float[]{lerp(a[0], b[0], mix), lerp(a[1], b[1], mix)});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private ArrayList<float[]> subCurveUnit(ArrayList<float[]> curve, float start, float end, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            if (curve == null || curve.size() < 2) return out;
            start = clamp(start, 0f, 1f);
            end = clamp(end, 0f, 1f);
            if (end <= start + 0.008f) return out;
            samples = Math.max(3, samples);
            for (int i = 0; i < samples; i++) {
                float u = lerp(start, end, i / Math.max(1f, samples - 1f));
                out.add(sampleCurveUnit(curve, u));
            }
            return out;
        }

        private void drawEvolvingArtBrushForm(ArrayList<float[]> visible, int gesture, float local, float tail, float head,
                                              float scale, float widthPx, float[] color, float[] cyan, float[] hot, float alpha) {
            int n = visible.size();
            if (n < 3) return;
            int mode = evolvingBrushLiveMode(gesture, local);
            int nextMode = evolvingBrushNextMode(gesture, local);
            float mix = evolvingBrushModeMix(local);
            int activeMode = mix > 0.55f ? nextMode : mode;
            float span = Math.max(0.02f, head - tail);

            // 主体核心：当前形态不是固定线条，而是由整条可见曲线自身变成扇形/场线/丝带/花瓣。
            float mainWidth = widthPx * (activeMode == 0 ? 0.72f : activeMode == 1 ? 0.52f : activeMode == 2 ? 0.44f : activeMode == 3 ? 0.88f : 0.64f);
            drawAgeFadedStrip(visible, Math.max(0.10f, mainWidth), color[0], color[1], color[2], alpha * 0.135f, 0.92f, 0.62f);
            drawAgeFadedStrip(visible, Math.max(0.055f, mainWidth * 0.38f), 0.98f, 1.00f, 1.00f, alpha * 0.155f, 0.94f, 0.82f);

            if (activeMode == 1) {
                drawEvolvingFanBody(visible, scale, widthPx, cyan, hot, alpha);
            } else if (activeMode == 2) {
                drawEvolvingFieldBody(visible, scale, widthPx, cyan, alpha);
            } else if (activeMode == 3) {
                drawEvolvingRibbonBody(visible, scale, widthPx, color, hot, alpha);
            } else if (activeMode == 4) {
                drawEvolvingPetalBody(visible, scale, widthPx, hot, cyan, alpha);
            }
        }

        private void drawEvolvingFanBody(ArrayList<float[]> visible, float scale, float widthPx, float[] cyan, float[] hot, float alpha) {
            int n = visible.size();
            if (n < 4) return;
            float[] root = visible.get(Math.max(0, n / 8));
            int rays = cfg.powerSave ? 5 : 8;
            for (int r = 0; r < rays; r++) {
                float u = lerp(0.32f, 0.96f, r / Math.max(1f, rays - 1f));
                float[] end = sampleCurveUnit(visible, u);
                ArrayList<float[]> ray = new ArrayList<>();
                ray.add(root);
                ray.add(new float[]{lerp(root[0], end[0], 0.45f), lerp(root[1], end[1], 0.45f) - scale * 0.018f * (r - rays * 0.5f)});
                ray.add(end);
                drawAgeFadedStrip(ray, Math.max(0.035f, widthPx * 0.26f), cyan[0], cyan[1], cyan[2], alpha * 0.070f, 0.90f, 0.45f);
            }
            drawEllipse(root[0], root[1], Math.max(0.8f, widthPx * 1.4f), Math.max(0.5f, widthPx * 0.85f), 0f, hot[0], hot[1], hot[2], alpha * 0.07f, 12);
        }

        private void drawEvolvingFieldBody(ArrayList<float[]> visible, float scale, float widthPx, float[] cyan, float alpha) {
            int lanes = cfg.powerSave ? 3 : 5;
            for (int l = 0; l < lanes; l++) {
                float q = lanes <= 1 ? 0.5f : l / (lanes - 1f);
                float offset = (q - 0.5f) * scale * 0.11f;
                ArrayList<float[]> lane = offsetVisibleCurve(visible, offset);
                drawAgeFadedStrip(lane, Math.max(0.025f, widthPx * 0.16f), cyan[0], cyan[1], cyan[2], alpha * (0.030f + 0.024f * (1f - Math.abs(q - 0.5f) * 2f)), 0.88f, 0.34f);
            }
        }

        private void drawEvolvingRibbonBody(ArrayList<float[]> visible, float scale, float widthPx, float[] color, float[] hot, float alpha) {
            ArrayList<float[]> outer = offsetVisibleCurve(visible, scale * 0.060f);
            ArrayList<float[]> inner = offsetVisibleCurve(visible, -scale * 0.020f);
            drawRuledSurfaceAgeFaded(inner, outer, color[0], color[1], color[2], alpha * 0.060f, 0.88f);
            drawAgeFadedStrip(outer, Math.max(0.040f, widthPx * 0.25f), hot[0], hot[1], hot[2], alpha * 0.070f, 0.90f, 0.52f);
        }

        private void drawEvolvingPetalBody(ArrayList<float[]> visible, float scale, float widthPx, float[] hot, float[] cyan, float alpha) {
            ArrayList<float[]> outer = offsetVisibleCurve(visible, scale * 0.075f);
            ArrayList<float[]> inner = offsetVisibleCurve(visible, -scale * 0.035f);
            drawRuledSurfaceAgeFaded(inner, outer, hot[0], hot[1], hot[2], alpha * 0.052f, 0.90f);
            drawAgeFadedStrip(outer, Math.max(0.035f, widthPx * 0.20f), cyan[0], cyan[1], cyan[2], alpha * 0.050f, 0.88f, 0.40f);
        }

        private ArrayList<float[]> offsetVisibleCurve(ArrayList<float[]> curve, float offset) {
            ArrayList<float[]> out = new ArrayList<>();
            int n = curve.size();
            for (int i = 0; i < n; i++) {
                float[] pPrev = curve.get(Math.max(0, i - 1));
                float[] pNext = curve.get(Math.min(n - 1, i + 1));
                float dx = pNext[0] - pPrev[0];
                float dy = pNext[1] - pPrev[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float taper = 0.25f + 0.75f * waveEnvelope(i / Math.max(1f, n - 1f));
                out.add(new float[]{curve.get(i)[0] + nx * offset * taper, curve.get(i)[1] + ny * offset * taper});
            }
            return out;
        }

        private void drawEvolvingArtBrushTip(ArrayList<float[]> visible, float local, float widthPx, float[] hot, float alpha) {
            if (visible == null || visible.isEmpty()) return;
            float[] tip = visible.get(visible.size() - 1);
            float tipA = alpha * (0.09f + 0.08f * smoother(clamp(local / 0.70f, 0f, 1f)));
            drawEllipse(tip[0], tip[1], Math.max(0.75f, widthPx * 1.95f), Math.max(0.42f, widthPx * 1.10f), local * 6.2831853f,
                    hot[0], hot[1], hot[2], tipA, 14);
        }

        private void drawLiveChangingPureMark(int gesture, int mark, float local,
                                              float cx, float cy, float angle, float scale, float widthPx,
                                              float[] color, float[] cyan, float[] hot, float alpha) {
            if (alpha <= 0.001f) return;
            // 同一笔内部实时换笔法：线条 → 扇形 → 网纱 → 丝带 → 花瓣/爆发，
            // 不是一个固定形状从头画到尾。
            float live = clamp((local - 0.02f) / 0.82f, 0f, 0.999f);
            float phase = live * 4.35f;
            int step = clampInt((int)Math.floor(phase), 0, 4);
            float mix = smoother(fract(phase));
            int styleA = pureLiveStageStyle(gesture, mark, step);
            int styleB = pureLiveStageStyle(gesture, mark, step + 1);
            float beat = 0.82f + 0.22f * (float)Math.sin(local * 6.2831853f * 1.25f + mark * 0.73f);
            float aA = alpha * beat * (1f - 0.42f * mix);
            float aB = alpha * beat * (0.30f + 0.76f * mix);
            drawPureMark(styleA, gesture, mark, local, cx, cy, angle, scale, widthPx, color, cyan, hot, aA);
            if (styleB != styleA && mix > 0.08f) {
                // V149：过渡笔法必须贴在同一主体中心，不再偏移成“另一个独立主体”。
                float angleB = angle + 0.12f * (float)Math.sin(mark * 1.9f + local * 4.1f);
                drawPureMark(styleB, gesture + 19, mark, local * 0.985f + 0.012f,
                        cx,
                        cy,
                        angleB, scale * (0.96f + 0.08f * mix), widthPx * (0.96f + 0.08f * mix),
                        color, cyan, hot, aB * 0.82f);
            }
        }

        private int pureLiveStageStyle(int gesture, int mark, int step) {
            int offset = clampInt((int)Math.floor(stableHash01(gesture + mark * 13, 18021) * 6f), 0, 5);
            int[] seq = new int[]{0, 1, 2, 3, 4, 5, 2, 3, 1, 4, 0};
            return seq[(step + offset) % seq.length];
        }

        private float pureMarkLife(float local) {
            // 更长的出现、发展、退隐期：让用户能看见过程，而不是一闪而过。
            float appear = smoother(clamp((local + 0.03f) / 0.20f, 0f, 1f));
            float hold = 1f - 0.16f * smoother(clamp((local - 0.32f) / 0.28f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.72f) / 0.36f, 0f, 1f));
            return appear * hold * vanish;
        }

        private float pureMarkReveal(float local) {
            // 早期只露出小段，随后进入稳定发展，不再长时间只有一根细线。
            return smoother(clamp((local - 0.015f) / 0.34f, 0f, 1f));
        }

        private int pureMarkStyle(int gesture, int mark) {
            int offset = clampInt((int)Math.floor(stableHash01(gesture, 17021) * 6f), 0, 5);
            int[] order = new int[]{0, 2, 4, 1, 3, 5, 2, 0, 4, 3, 1};
            return order[(mark + offset) % order.length];
        }

        private float[] pureMarkCenter(int gesture, int mark) {
            float rx = stableHash01(gesture + mark * 61, 18031);
            float ry = stableHash01(gesture + mark * 67, 18037);
            float x = width * (0.12f + 0.76f * rx);
            float y = height * (0.22f + 0.46f * ry);
            y = Math.min(y, height * 0.70f);
            return new float[]{x, y};
        }

        private float[] pureUnifiedCreationCenter(int gesture) {
            // 单一主创作主体的构图中心：每一轮重新选点，但同一轮内绝不分裂成多个中心。
            float rx = stableHash01(gesture, 18131);
            float ry = stableHash01(gesture, 18137);
            float x = width * (0.20f + 0.60f * rx);
            float y = height * (0.26f + 0.36f * ry);
            y = Math.min(y, height * 0.66f);
            return new float[]{x, y};
        }

        private float pureMarkAngle(int gesture, int mark, float local) {
            float base = stableHash01(gesture + mark * 71, 17041) * 6.2831853f;
            float turn = (stableHash01(gesture + mark * 73, 17043) - 0.5f) * 1.50f;
            return base + turn * smoother(clamp(local, 0f, 1f));
        }

        private void drawPureMark(int style, int gesture, int mark, float local,
                                  float cx, float cy, float angle, float scale, float widthPx,
                                  float[] color, float[] cyan, float[] hot, float alpha) {
            if (style == 0) {
                drawPureCalligraphyStroke(gesture, mark, local, cx, cy, angle, scale, widthPx, color, hot, alpha);
            } else if (style == 1) {
                drawPureFanBurst(gesture, mark, local, cx, cy, angle, scale, widthPx, color, cyan, hot, alpha);
            } else if (style == 2) {
                drawPureFieldLines(gesture, mark, local, cx, cy, angle, scale, widthPx, color, cyan, alpha);
            } else if (style == 3) {
                drawPureRibbonThreads(gesture, mark, local, cx, cy, angle, scale, widthPx, color, cyan, hot, alpha);
            } else if (style == 4) {
                drawPurePetalSketch(gesture, mark, local, cx, cy, angle, scale, widthPx, color, hot, alpha);
            } else {
                drawPureSparkBloom(gesture, mark, local, cx, cy, angle, scale, widthPx, color, hot, alpha);
            }
        }

        private ArrayList<float[]> slicePureCurve(ArrayList<float[]> curve, float reveal) {
            ArrayList<float[]> out = new ArrayList<>();
            if (curve == null || curve.size() < 2 || reveal <= 0.006f) return out;
            int samples = Math.max(4, (int)(curve.size() * clamp(reveal, 0.012f, 1f)));
            for (int i = 0; i < samples; i++) {
                float u = clamp(reveal, 0.012f, 1f) * i / Math.max(1f, samples - 1f);
                out.add(sampleCurveUnit(curve, u));
            }
            return out;
        }

        private ArrayList<float[]> pureBezier(float x0, float y0, float x1, float y1, float x2, float y2, float x3, float y3, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            samples = Math.max(2, samples);
            for (int i = 0; i < samples; i++) {
                float u = i / Math.max(1f, samples - 1f);
                float one = 1f - u;
                out.add(new float[]{one * one * one * x0 + 3f * one * one * u * x1 + 3f * one * u * u * x2 + u * u * u * x3,
                        one * one * one * y0 + 3f * one * one * u * y1 + 3f * one * u * u * y2 + u * u * u * y3});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private void drawPureCalligraphyStroke(int gesture, int mark, float local,
                                               float cx, float cy, float angle, float scale, float widthPx,
                                               float[] color, float[] hot, float alpha) {
            float reveal = pureMarkReveal(local);
            float tx = (float)Math.cos(angle), ty = (float)Math.sin(angle);
            float nx = -ty, ny = tx;
            float side = stableHash01(gesture + mark * 79, 17051) < 0.5f ? -1f : 1f;
            ArrayList<float[]> curve = pureBezier(cx - tx * scale * 0.48f, cy - ty * scale * 0.48f,
                    cx - tx * scale * 0.18f + nx * side * scale * 0.22f, cy - ty * scale * 0.18f + ny * side * scale * 0.22f,
                    cx + tx * scale * 0.16f - nx * side * scale * 0.18f, cy + ty * scale * 0.16f - ny * side * scale * 0.18f,
                    cx + tx * scale * 0.50f, cy + ty * scale * 0.50f, cfg.powerSave ? 18 : 30);
            ArrayList<float[]> visible = slicePureCurve(curve, reveal);
            drawAgeFadedStrip(visible, Math.max(0.10f, widthPx * 1.65f), color[0], color[1], color[2], alpha * 0.220f, 0.92f, 0.64f);
            drawAgeFadedStrip(visible, Math.max(0.05f, widthPx * 0.65f), 1f, 1f, 1f, alpha * 0.300f, 0.96f, 0.88f);
        }

        private void drawPureFanBurst(int gesture, int mark, float local,
                                      float cx, float cy, float angle, float scale, float widthPx,
                                      float[] color, float[] cyan, float[] hot, float alpha) {
            float reveal = pureMarkReveal(local);
            int rays = cfg.powerSave ? 6 : 10;
            float spread = 0.95f + 0.55f * stableHash01(gesture + mark * 83, 17061);
            for (int r = 0; r < rays; r++) {
                float q = rays <= 1 ? 0.5f : r / (rays - 1f);
                float a = angle + (q - 0.5f) * spread;
                float tx = (float)Math.cos(a), ty = (float)Math.sin(a);
                float nx = -ty, ny = tx;
                float len = scale * (0.34f + 0.32f * (1f - Math.abs(q - 0.5f) * 2f));
                ArrayList<float[]> ray = pureBezier(cx, cy,
                        cx + tx * len * 0.32f + nx * scale * 0.08f, cy + ty * len * 0.32f + ny * scale * 0.08f,
                        cx + tx * len * 0.70f - nx * scale * 0.04f, cy + ty * len * 0.70f - ny * scale * 0.04f,
                        cx + tx * len, cy + ty * len, cfg.powerSave ? 10 : 16);
                ArrayList<float[]> visible = slicePureCurve(ray, reveal);
                float aa = alpha * (0.120f + 0.130f * (1f - Math.abs(q - 0.5f) * 1.6f));
                drawAgeFadedStrip(visible, Math.max(0.045f, widthPx * 0.72f), color[0], color[1], color[2], aa, 0.90f, 0.48f);
            }
            drawEllipse(cx, cy, Math.max(1.2f, widthPx * 4.2f), Math.max(0.8f, widthPx * 2.2f), angle, hot[0], hot[1], hot[2], alpha * 0.120f * reveal, 18);
        }

        private void drawPureFieldLines(int gesture, int mark, float local,
                                        float cx, float cy, float angle, float scale, float widthPx,
                                        float[] color, float[] cyan, float alpha) {
            float reveal = pureMarkReveal(local);
            int lines = cfg.powerSave ? 5 : 8;
            float tx = (float)Math.cos(angle), ty = (float)Math.sin(angle);
            float nx = -ty, ny = tx;
            for (int i = 0; i < lines; i++) {
                float q = lines <= 1 ? 0.5f : i / (lines - 1f);
                float offset = (q - 0.5f) * scale * 0.42f;
                float bend = (stableHash01(gesture + mark * 89 + i, 17071) - 0.5f) * scale * 0.20f;
                ArrayList<float[]> line = pureBezier(cx - tx * scale * 0.38f + nx * offset, cy - ty * scale * 0.38f + ny * offset,
                        cx - tx * scale * 0.10f + nx * (offset * 0.45f + bend), cy - ty * scale * 0.10f + ny * (offset * 0.45f + bend),
                        cx + tx * scale * 0.18f + nx * (offset * 0.25f - bend), cy + ty * scale * 0.18f + ny * (offset * 0.25f - bend),
                        cx + tx * scale * 0.46f + nx * offset * 0.10f, cy + ty * scale * 0.46f + ny * offset * 0.10f, cfg.powerSave ? 12 : 18);
                ArrayList<float[]> visible = slicePureCurve(line, reveal);
                drawAgeFadedStrip(visible, Math.max(0.035f, widthPx * 0.55f), cyan[0], cyan[1], cyan[2], alpha * 0.145f, 0.92f, 0.40f);
            }
        }

        private void drawPureRibbonThreads(int gesture, int mark, float local,
                                           float cx, float cy, float angle, float scale, float widthPx,
                                           float[] color, float[] cyan, float[] hot, float alpha) {
            float reveal = pureMarkReveal(local);
            int strands = cfg.powerSave ? 4 : 7;
            float tx = (float)Math.cos(angle), ty = (float)Math.sin(angle);
            float nx = -ty, ny = tx;
            for (int s = 0; s < strands; s++) {
                float q = strands <= 1 ? 0.5f : s / (strands - 1f);
                float offset = (q - 0.5f) * scale * 0.22f;
                float wave = (float)Math.sin(q * 6.2831853f + stableHash01(gesture + mark, 17081) * 6.2831853f);
                ArrayList<float[]> strand = pureBezier(cx - tx * scale * 0.46f + nx * offset, cy - ty * scale * 0.46f + ny * offset,
                        cx - tx * scale * 0.16f + nx * (offset + scale * 0.12f * wave), cy - ty * scale * 0.16f + ny * (offset + scale * 0.12f * wave),
                        cx + tx * scale * 0.18f + nx * (offset - scale * 0.08f * wave), cy + ty * scale * 0.18f + ny * (offset - scale * 0.08f * wave),
                        cx + tx * scale * 0.50f + nx * offset * 0.25f, cy + ty * scale * 0.50f + ny * offset * 0.25f, cfg.powerSave ? 14 : 22);
                ArrayList<float[]> visible = slicePureCurve(strand, reveal);
                float aa = alpha * (0.135f + 0.110f * waveEnvelope(q));
                drawAgeFadedStrip(visible, Math.max(0.045f, widthPx * (0.24f + 0.16f * waveEnvelope(q))), color[0], color[1], color[2], aa, 0.92f, 0.52f);
            }
        }

        private void drawPurePetalSketch(int gesture, int mark, float local,
                                         float cx, float cy, float angle, float scale, float widthPx,
                                         float[] color, float[] hot, float alpha) {
            float reveal = pureMarkReveal(local);
            float tx = (float)Math.cos(angle), ty = (float)Math.sin(angle);
            float nx = -ty, ny = tx;
            float side = stableHash01(gesture + mark * 97, 17091) < 0.5f ? -1f : 1f;
            ArrayList<float[]> a = pureBezier(cx - tx * scale * 0.36f, cy - ty * scale * 0.36f,
                    cx - tx * scale * 0.08f + nx * side * scale * 0.30f, cy - ty * scale * 0.08f + ny * side * scale * 0.30f,
                    cx + tx * scale * 0.22f + nx * side * scale * 0.22f, cy + ty * scale * 0.22f + ny * side * scale * 0.22f,
                    cx + tx * scale * 0.44f, cy + ty * scale * 0.44f, cfg.powerSave ? 14 : 24);
            ArrayList<float[]> b = pureBezier(cx - tx * scale * 0.34f, cy - ty * scale * 0.34f,
                    cx - tx * scale * 0.04f - nx * side * scale * 0.12f, cy - ty * scale * 0.04f - ny * side * scale * 0.12f,
                    cx + tx * scale * 0.24f - nx * side * scale * 0.10f, cy + ty * scale * 0.24f - ny * side * scale * 0.10f,
                    cx + tx * scale * 0.44f, cy + ty * scale * 0.44f, cfg.powerSave ? 14 : 24);
            drawAgeFadedStrip(slicePureCurve(a, reveal), Math.max(0.055f, widthPx * 0.72f), color[0], color[1], color[2], alpha * 0.185f, 0.92f, 0.56f);
            drawAgeFadedStrip(slicePureCurve(b, reveal), Math.max(0.040f, widthPx * 0.55f), hot[0], hot[1], hot[2], alpha * 0.145f, 0.92f, 0.46f);
        }

        private void drawPureSparkBloom(int gesture, int mark, float local,
                                        float cx, float cy, float angle, float scale, float widthPx,
                                        float[] color, float[] hot, float alpha) {
            float reveal = pureMarkReveal(local);
            int sparks = cfg.powerSave ? 5 : 8;
            for (int s = 0; s < sparks; s++) {
                float a = angle + s * 6.2831853f / sparks + (stableHash01(gesture + mark * 101 + s, 17101) - 0.5f) * 0.60f;
                float tx = (float)Math.cos(a), ty = (float)Math.sin(a);
                float len = scale * (0.12f + 0.26f * stableHash01(gesture + mark * 103 + s, 17103));
                ArrayList<float[]> spark = pureBezier(cx, cy, cx + tx * len * 0.38f, cy + ty * len * 0.38f,
                        cx + tx * len * 0.70f, cy + ty * len * 0.70f,
                        cx + tx * len, cy + ty * len, cfg.powerSave ? 8 : 12);
                drawAgeFadedStrip(slicePureCurve(spark, reveal), Math.max(0.040f, widthPx * 0.50f), color[0], color[1], color[2], alpha * 0.160f, 0.88f, 0.55f);
            }
            drawEllipse(cx, cy, Math.max(1.1f, widthPx * 4.0f), Math.max(0.7f, widthPx * 2.0f), angle, hot[0], hot[1], hot[2], alpha * 0.105f * reveal, 16);
        }

        private float freeBrushLife(float local) {
            float appear = smoother(clamp((local + 0.04f) / 0.18f, 0f, 1f));
            float vanish = 1f - smoother(clamp((local - 0.74f) / 0.32f, 0f, 1f));
            return appear * vanish;
        }

        private float freeBrushGrow(float local) {
            // 前期不是拖尾蛇行，而是短笔触快速建立方向，然后中段充分展开。
            return clamp(0.02f + 0.98f * smoother(clamp((local - 0.02f) / 0.70f, 0f, 1f)), 0f, 1f);
        }

        private float freeBrushBeat(float local) {
            return 0.5f + 0.5f * (float)Math.sin(local * 6.2831853f * 1.35f);
        }

        private int freeBrushEventStyle(int gesture, int event) {
            // 固定但多样的事件序列：同一短句内一定换笔法，而不是一直画同一种身体。
            int offset = clampInt((int)Math.floor(stableHash01(gesture, 16021) * 5f), 0, 4);
            int[] order = new int[]{0, 2, 4, 3, 1, 2, 4}; // 线、扇、网、丝带、花瓣、网、丝带
            return order[(event + offset) % order.length];
        }

        private float[] freeBrushEventCenter(int gesture, int event, float minDim) {
            float safeW = Math.max(1f, width);
            float safeH = Math.max(1f, height);
            float rx = stableHash01(gesture + event * 37, 16031);
            float ry = stableHash01(gesture + event * 41, 16037);
            float x = safeW * (0.22f + 0.56f * rx);
            float y = safeH * (0.22f + 0.50f * ry);
            // 避开底部桌面图标区域，同时保持画面分布随机。
            y = clamp(y, safeH * 0.18f, safeH * 0.73f);
            return new float[]{x, y};
        }

        private float freeBrushEventAngle(int gesture, int event, float t) {
            float base = stableHash01(gesture + event * 53, 16041) * 6.2831853f;
            float sway = 0.28f * (float)Math.sin(t * (0.30f + 0.10f * event) + stableHash01(gesture, 16043) * 6.2831853f);
            return base + sway;
        }

        private ArrayList<float[]> buildFreeBrushSpine(float cx, float cy, float angle, float scale,
                                                       int gesture, int event, float local, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            float tx = (float)Math.cos(angle);
            float ty = (float)Math.sin(angle);
            float nx = -ty;
            float ny = tx;
            float bend = (stableHash01(gesture + event * 59, 16051) - 0.5f) * 2f;
            float curl = (stableHash01(gesture + event * 61, 16057) - 0.5f) * 2f;
            float length = scale * (0.72f + 0.42f * stableHash01(gesture + event * 67, 16063));
            float curveAmp = scale * (0.16f + 0.24f * stableHash01(gesture + event * 71, 16069));
            samples = Math.max(8, samples);
            for (int i = 0; i < samples; i++) {
                float u = i / Math.max(1f, samples - 1f);
                float s = u - 0.50f;
                float eased = smoother(u);
                float wave = (float)Math.sin((u * 1.15f + local * 0.16f) * 6.2831853f + curl * 1.7f);
                float x = cx + tx * s * length + nx * curveAmp * bend * (float)Math.sin(Math.PI * eased) + nx * wave * scale * 0.040f * waveEnvelope(u);
                float y = cy + ty * s * length + ny * curveAmp * bend * (float)Math.sin(Math.PI * eased) + ny * wave * scale * 0.040f * waveEnvelope(u);
                out.add(new float[]{x, y});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private ArrayList<float[]> freeBrushSubCurve(ArrayList<float[]> curve, float start, float end) {
            ArrayList<float[]> out = new ArrayList<>();
            if (curve == null || curve.size() < 2) return out;
            start = clamp(start, 0f, 1f);
            end = clamp(end, 0f, 1f);
            if (end <= start + 0.01f) end = Math.min(1f, start + 0.01f);
            int samples = Math.max(3, (int)((end - start) * curve.size()) + 3);
            for (int i = 0; i < samples; i++) {
                float u = lerp(start, end, i / Math.max(1f, samples - 1f));
                out.add(sampleCurveUnit(curve, u));
            }
            return out;
        }

        private float[] sampleCurveUnit(ArrayList<float[]> curve, float u) {
            int n = curve.size();
            float pos = clamp(u, 0f, 1f) * (n - 1f);
            int i0 = clampInt((int)Math.floor(pos), 0, n - 1);
            int i1 = clampInt(i0 + 1, 0, n - 1);
            float f = pos - i0;
            float[] a = curve.get(i0);
            float[] b = curve.get(i1);
            return new float[]{lerp(a[0], b[0], f), lerp(a[1], b[1], f)};
        }

        private void drawFreeBrushEvent(ArrayList<float[]> pts, int style, int gesture, int event, float local,
                                        float minDim, float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            if (style == 2) {
                drawFreeBrushFan(pts, gesture, event, local, minDim, color, cyan, hot, alpha, widthPx);
            } else if (style == 4) {
                drawFreeBrushMesh(pts, gesture, event, local, minDim, color, cyan, hot, alpha, widthPx);
            } else if (style == 3) {
                drawFreeBrushRibbon(pts, gesture, event, local, minDim, color, cyan, hot, alpha, widthPx, 1.30f);
            } else if (style == 1) {
                drawFreeBrushPetal(pts, gesture, event, local, minDim, color, cyan, hot, alpha, widthPx);
            } else {
                drawFreeBrushLine(pts, gesture, event, local, minDim, color, cyan, hot, alpha, widthPx);
            }
        }

        private void drawFreeBrushLine(ArrayList<float[]> pts, int gesture, int event, float local,
                                       float minDim, float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            drawAgeFadedStrip(pts, Math.max(0.18f, widthPx * 1.65f), color[0], color[1], color[2], alpha * 0.065f, 0.90f, 0.70f);
            drawAgeFadedStrip(pts, Math.max(0.08f, widthPx * 0.36f), 0.98f, 1.00f, 1.00f, alpha * 0.095f, 0.92f, 0.88f);
            if (pts.size() > 2) {
                float[] tip = pts.get(pts.size() - 1);
                float[] prev = pts.get(Math.max(0, pts.size() - 3));
                drawEllipse(tip[0], tip[1], Math.max(1.2f, widthPx * 3.8f), Math.max(0.8f, widthPx * 1.4f),
                        (float)Math.atan2(tip[1] - prev[1], tip[0] - prev[0]), 1f, 1f, 1f, alpha * 0.060f, 18);
            }
        }

        private void drawFreeBrushRibbon(ArrayList<float[]> pts, int gesture, int event, float local,
                                         float minDim, float[] color, float[] cyan, float[] hot, float alpha, float widthPx, float widenMul) {
            ArrayList<float[]> inner = new ArrayList<>();
            ArrayList<float[]> outer = new ArrayList<>();
            int n = pts.size();
            float side = stableHash01(gesture + event * 73, 16081) < 0.5f ? -1f : 1f;
            float open = smoother(clamp((local - 0.08f) / 0.58f, 0f, 1f));
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float[] pPrev = pts.get(Math.max(0, i - 1));
                float[] pNext = pts.get(Math.min(n - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float tx = dx / dl, ty = dy / dl;
                float nx = -ty * side, ny = tx * side;
                float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.55f);
                float wide = minDim * (0.006f + 0.064f * body * open * widenMul);
                float small = minDim * (0.0012f + 0.011f * body);
                float sweep = minDim * (0.006f + 0.020f * body) * (0.25f + 0.75f * u);
                inner.add(new float[]{pts.get(i)[0] - nx * small, pts.get(i)[1] - ny * small});
                outer.add(new float[]{pts.get(i)[0] + nx * wide + tx * sweep, pts.get(i)[1] + ny * wide + ty * sweep});
            }
            drawRuledSurfaceAgeFaded(inner, outer, color[0], color[1], color[2], alpha * 0.072f, 0.90f);
            drawAgeFadedStrip(pts, Math.max(0.16f, widthPx * 0.72f), cyan[0], cyan[1], cyan[2], alpha * 0.048f, 0.88f, 0.60f);
            drawAgeFadedStrip(outer, Math.max(0.08f, widthPx * 0.72f), hot[0], hot[1], hot[2], alpha * 0.045f, 0.86f, 0.46f);
        }

        private void drawFreeBrushPetal(ArrayList<float[]> pts, int gesture, int event, float local,
                                        float minDim, float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            drawFreeBrushRibbon(pts, gesture, event, local, minDim, color, cyan, hot, alpha, widthPx, 1.70f);
            if (pts.size() > 4) {
                int midIdx = pts.size() / 2;
                float[] p = pts.get(midIdx);
                drawEllipse(p[0], p[1], Math.max(2.0f, widthPx * 4.8f), Math.max(0.8f, widthPx * 1.8f),
                        stableHash01(gesture + event, 16091) * 6.2831853f, color[0], color[1], color[2], alpha * 0.105f, 24);
            }
        }

        private void drawFreeBrushFan(ArrayList<float[]> pts, int gesture, int event, float local,
                                      float minDim, float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            if (pts.size() < 3) return;
            float[] root = pts.get(0);
            float[] end = pts.get(pts.size() - 1);
            float dx = end[0] - root[0], dy = end[1] - root[1];
            float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
            float tx = dx / dl, ty = dy / dl;
            float nx = -ty, ny = tx;
            float side = stableHash01(gesture + event * 79, 16101) < 0.5f ? -1f : 1f;
            int rays = cfg.powerSave ? 8 : 14;
            float open = smoother(clamp((local - 0.06f) / 0.58f, 0f, 1f));
            for (int r = 0; r < rays; r++) {
                float q = rays <= 1 ? 0.5f : r / (rays - 1f);
                float centered = (q - 0.5f) * 2f;
                float spread = centered * side * minDim * (0.10f + 0.12f * open);
                float len = dl * (0.55f + 0.42f * (1f - Math.abs(centered)));
                float ex = root[0] + tx * len + nx * spread;
                float ey = root[1] + ty * len + ny * spread;
                float cx = root[0] + tx * len * 0.45f + nx * spread * 0.35f;
                float cy = root[1] + ty * len * 0.45f + ny * spread * 0.35f;
                ArrayList<float[]> ray = buildFreeQuadratic(root[0], root[1], cx, cy, ex, ey, cfg.powerSave ? 12 : 20);
                drawAgeFadedStrip(ray, Math.max(0.06f, widthPx * (0.18f + 0.16f * (1f - Math.abs(centered)))),
                        color[0], color[1], color[2], alpha * (0.024f + 0.032f * (1f - Math.abs(centered))), 0.86f, 0.48f);
            }
            drawAgeFadedStrip(pts, Math.max(0.12f, widthPx * 0.58f), cyan[0], cyan[1], cyan[2], alpha * 0.050f, 0.90f, 0.66f);
        }

        private void drawFreeBrushMesh(ArrayList<float[]> pts, int gesture, int event, float local,
                                       float minDim, float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            drawFreeBrushRibbon(pts, gesture, event, local, minDim, color, cyan, hot, alpha * 0.82f, widthPx, 1.25f);
            if (pts.size() < 5) return;
            int ribs = cfg.powerSave ? 5 : 9;
            for (int r = 1; r <= ribs; r++) {
                float u = r / (ribs + 1f);
                int idx = clampInt((int)(u * (pts.size() - 1)), 1, pts.size() - 2);
                float[] p = pts.get(idx);
                float[] prev = pts.get(idx - 1);
                float[] next = pts.get(idx + 1);
                float dx = next[0] - prev[0], dy = next[1] - prev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float nx = -dy / dl, ny = dx / dl;
                float side = stableHash01(gesture + event * 83, 16111) < 0.5f ? -1f : 1f;
                float span = minDim * (0.025f + 0.055f * waveEnvelope(u)) * side;
                ArrayList<float[]> rib = new ArrayList<>();
                rib.add(new float[]{p[0] - nx * span * 0.40f, p[1] - ny * span * 0.40f});
                rib.add(p);
                rib.add(new float[]{p[0] + nx * span, p[1] + ny * span});
                drawAgeFadedStrip(rib, Math.max(0.04f, widthPx * 0.12f), cyan[0], cyan[1], cyan[2], alpha * 0.105f * waveEnvelope(u), 0.88f, 0.32f);
            }
        }

        private ArrayList<float[]> buildFreeQuadratic(float x0, float y0, float x1, float y1, float x2, float y2, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            samples = Math.max(2, samples);
            for (int i = 0; i < samples; i++) {
                float u = i / Math.max(1f, samples - 1f);
                float one = 1f - u;
                out.add(new float[]{one * one * x0 + 2f * one * u * x1 + u * u * x2,
                        one * one * y0 + 2f * one * u * y1 + u * u * y2});
            }
            return out;
        }

        private ArrayList<float[]> buildGenerativeMystifyCurve(int gesture, float time, float minDim, float seedA, float seedB, float seedC, int samples) {
            float duration = generativePhraseDuration(gesture);
            float pos = time / duration;
            int phraseA = (int)Math.floor(pos);
            int phraseB = phraseA + 1;
            float local = fract(pos);
            // V141：短句主体在 85% 之前保持同一构图，只做内部展开。
            // 这样观众看到的是“这一笔慢慢画出来”，不是画完后突然分身/morph。
            float mix = generativePhraseMorphMix(local);
            int modeA = generativePhraseMode(gesture, phraseA);
            int modeB = generativePhraseMode(gesture, phraseB);
            int countA = generativeControlCount(gesture, phraseA, modeA);
            int countB = generativeControlCount(gesture, phraseB, modeB);
            int count = mix < 0.001f ? countA : Math.max(countA, countB);
            float[][] ctl = new float[count][3];
            float[] centerA = generativePhraseCenter(gesture, phraseA, minDim);
            float[] centerB = generativePhraseCenter(gesture, phraseB, minDim);
            float centerX = lerp(centerA[0], centerB[0], mix);
            float centerY = lerp(centerA[1], centerB[1], mix);
            float scaleA = generativePhraseScale(gesture, phraseA, minDim);
            float scaleB = generativePhraseScale(gesture, phraseB, minDim);
            float open = smoother(clamp(local / 0.78f, 0f, 1f));
            float scale = lerp(scaleA, scaleB, mix) * (0.74f + 0.30f * open + 0.10f * generativePhrasePulse(time, gesture));
            // 稳定的“运笔时间”：随短句进度推进，但避免全局漂移造成蛇乱窜。
            float phraseTime = phraseA * 0.41f + open * duration * 0.13f;
            for (int i = 0; i < count; i++) {
                float u = i / Math.max(1f, count - 1f);
                float[] pa = generativeControlPoint(gesture, phraseA, modeA, u, phraseTime, scale, seedA, seedB, seedC);
                if (mix > 0.001f) {
                    float[] pb = generativeControlPoint(gesture, phraseB, modeB, u, phraseTime + 0.37f, scale, seedA + 0.37f, seedB + 0.23f, seedC + 0.19f);
                    ctl[i][0] = lerp(pa[0], pb[0], mix);
                    ctl[i][1] = lerp(pa[1], pb[1], mix);
                    ctl[i][2] = lerp(pa[2], pb[2], mix);
                } else {
                    ctl[i][0] = pa[0];
                    ctl[i][1] = pa[1];
                    ctl[i][2] = pa[2];
                }
            }
            float yawA = generativePhraseHash(gesture, phraseA, 14101) * 6.2831853f;
            float yawB = generativePhraseHash(gesture, phraseB, 14101) * 6.2831853f;
            float yaw = lerpAngle(yawA, yawB, mix) + 0.16f * (float)Math.sin(open * Math.PI) * (generativePhraseHash(gesture, phraseA, 14103) - 0.5f);
            float roll = 0.42f * (float)Math.sin(open * 1.7f + seedB + phraseA * 0.21f);
            float pitch = 0.34f * (float)Math.sin(open * 1.4f + seedC + phraseA * 0.17f);
            float cameraFov = generativeCameraFov(time, gesture, minDim);
            ArrayList<float[]> out = new ArrayList<>(samples);
            for (int s = 0; s < samples; s++) {
                float q = s / Math.max(1f, samples - 1f);
                float posCtl = q * (count - 1f);
                int i1 = clampInt((int)Math.floor(posCtl), 0, count - 1);
                float t = smoother(posCtl - i1);
                int i0 = clampInt(i1 - 1, 0, count - 1);
                int i2 = clampInt(i1 + 1, 0, count - 1);
                int i3 = clampInt(i1 + 2, 0, count - 1);
                float[] p3 = catmullRomPoint3(ctl[i0], ctl[i1], ctl[i2], ctl[i3], t);
                float[] pr = projectMystify3dPoint(p3[0], p3[1], p3[2], yaw, roll, pitch, cameraFov);
                out.add(new float[]{centerX + pr[0], centerY + pr[1]});
            }
            return polishGenerativeBrushCurve(out, samples);
        }

        private ArrayList<float[]> polishGenerativeBrushCurve(ArrayList<float[]> raw, int samples) {
            if (raw == null || raw.size() < 4) return raw;
            ArrayList<float[]> uniform = resampleCurveByArcLength(raw, Math.max(16, samples));
            ArrayList<float[]> smooth = chaikinSmoothCurve(uniform, cfg.powerSave ? 1 : 2);
            return resampleCurveByArcLength(smooth, Math.max(16, samples));
        }

        private ArrayList<float[]> resampleCurveByArcLength(ArrayList<float[]> curve, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            if (curve == null || curve.isEmpty()) return out;
            samples = Math.max(2, samples);
            int n = curve.size();
            float[] acc = new float[n];
            acc[0] = 0f;
            for (int i = 1; i < n; i++) {
                float[] a = curve.get(i - 1);
                float[] b = curve.get(i);
                float dx = b[0] - a[0];
                float dy = b[1] - a[1];
                acc[i] = acc[i - 1] + (float)Math.sqrt(dx * dx + dy * dy);
            }
            float total = acc[n - 1];
            if (total <= 0.001f) {
                for (int i = 0; i < samples; i++) out.add(curve.get(Math.min(n - 1, i * n / samples)));
                return out;
            }
            int cursor = 1;
            for (int s = 0; s < samples; s++) {
                float target = total * (s / Math.max(1f, samples - 1f));
                while (cursor < n - 1 && acc[cursor] < target) cursor++;
                int i0 = Math.max(0, cursor - 1);
                int i1 = Math.min(n - 1, cursor);
                float span = Math.max(0.0001f, acc[i1] - acc[i0]);
                float f = clamp((target - acc[i0]) / span, 0f, 1f);
                float[] a = curve.get(i0);
                float[] b = curve.get(i1);
                out.add(new float[]{lerp(a[0], b[0], f), lerp(a[1], b[1], f)});
            }
            return out;
        }

        private ArrayList<float[]> chaikinSmoothCurve(ArrayList<float[]> curve, int passes) {
            ArrayList<float[]> current = curve;
            for (int pass = 0; pass < passes; pass++) {
                if (current == null || current.size() < 3) return current;
                ArrayList<float[]> next = new ArrayList<>();
                next.add(current.get(0));
                for (int i = 0; i < current.size() - 1; i++) {
                    float[] a = current.get(i);
                    float[] b = current.get(i + 1);
                    next.add(new float[]{lerp(a[0], b[0], 0.25f), lerp(a[1], b[1], 0.25f)});
                    next.add(new float[]{lerp(a[0], b[0], 0.75f), lerp(a[1], b[1], 0.75f)});
                }
                next.add(current.get(current.size() - 1));
                current = next;
            }
            return current;
        }

        private float[] generativeControlPoint(int gesture, int phrase, int mode, float u, float time, float scale,
                                               float seedA, float seedB, float seedC) {
            float ordered = (u - 0.5f) * 2f;
            float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.42f);
            float h0 = generativePhraseHash(gesture, phrase, 14201);
            float h1 = generativePhraseHash(gesture, phrase, 14203);
            float h2 = generativePhraseHash(gesture, phrase, 14207);
            float h3 = generativePhraseHash(gesture, phrase, 14209);
            float sign = h0 < 0.5f ? -1f : 1f;
            float pulse = generativePhrasePulse(time, gesture + phrase * 7);
            float bounceX = mystifyBounce(time * (0.036f + 0.030f * h0) + h1) * 2f - 1f;
            float bounceY = mystifyBounce(time * (0.052f + 0.035f * h1) + h2) * 2f - 1f;
            float x = ordered * scale * (0.34f + 0.44f * h3);
            float y = 0f, z = 0f;
            switch (mode) {
                case 0: // 经典 Mystify 弓形光弦
                    y = sign * scale * (0.18f + 0.62f * body) * (0.60f + 0.45f * pulse);
                    z = scale * sign * (ordered * ordered - 0.34f) * (0.26f + 0.46f * h2);
                    break;
                case 1: // 双 S 变形
                    y = scale * ((float)Math.sin(2f * Math.PI * u + h1 * 6.2831853f) * (0.34f + 0.44f * h2)
                            + (float)Math.sin(4f * Math.PI * u + seedA) * 0.14f) * (0.72f + 0.40f * pulse);
                    z = scale * (float)Math.cos(Math.PI * u + seedB) * (0.20f + 0.42f * h3);
                    break;
                case 2: // 扇形喷出
                    y = sign * scale * body * (0.22f + 0.86f * u) * (0.42f + 0.46f * h1) * (0.82f + 0.42f * pulse);
                    z = scale * (u - 0.15f) * body * (0.18f + 0.48f * h2);
                    break;
                case 3: // 钩形折返
                    x *= (0.56f + 0.48f * u);
                    y = sign * scale * (float)Math.sin(Math.PI * (u * 1.28f + 0.06f)) * (0.24f + 0.58f * h1) * (0.72f + 0.38f * pulse);
                    z = scale * (float)Math.sin(2f * Math.PI * u + h2 * 6.2831853f) * (0.16f + 0.42f * h3);
                    break;
                case 4: // 蝴蝶翼/双瓣
                    y = sign * scale * (Math.abs(ordered) * 0.28f + body * 0.52f) * (ordered < 0f ? 1f : -0.72f) * (0.70f + 0.44f * pulse);
                    z = scale * (float)Math.sin(2f * Math.PI * u) * (0.26f + 0.42f * h2);
                    break;
                case 5: // 螺旋扭结
                    float theta = (float)(2.8 * Math.PI * u + h0 * 6.2831853f + time * 0.055f);
                    x = ordered * scale * (0.30f + 0.35f * h3);
                    y = scale * (float)Math.sin(theta) * (0.18f + 0.50f * body) * (0.78f + 0.36f * pulse);
                    z = scale * (float)Math.cos(theta) * (0.18f + 0.46f * body);
                    break;
                case 6: // 星芒爆发
                    float burst = (u < 0.5f ? u * 2f : (1f - u) * 2f);
                    y = sign * scale * (0.12f + 0.78f * burst) * (0.42f + 0.38f * h1) * (0.55f + 0.70f * pulse);
                    z = scale * (float)Math.sin(3f * Math.PI * u + seedC) * (0.20f + 0.42f * h2);
                    break;
                case 7: // 长藤卷曲
                    y = sign * scale * ((float)Math.sin(Math.PI * u) * 0.38f + (float)Math.sin(3f * Math.PI * u + seedB) * 0.22f) * (0.86f + 0.40f * pulse);
                    z = scale * ((float)Math.cos(2f * Math.PI * u + h2 * 6.2831853f)) * (0.16f + 0.44f * body);
                    break;
                case 8: // 羽化波束
                    x = ordered * scale * (0.44f + 0.28f * h3);
                    y = sign * scale * body * (0.20f + 0.74f * u) * (0.50f + 0.40f * h1) * (0.72f + 0.44f * pulse);
                    z = scale * (float)Math.sin(Math.PI * u + seedC) * (0.18f + 0.52f * h2);
                    break;
                default: // 云门开合
                    y = sign * scale * (float)Math.sin(Math.PI * u + 0.30f * (float)Math.sin(time * 0.06f + seedA)) * (0.28f + 0.60f * h1) * (0.76f + 0.34f * pulse);
                    z = scale * (ordered * ordered - 0.25f) * (0.22f + 0.50f * h2);
                    break;
            }
            x += scale * 0.030f * bounceX * body;
            y += scale * 0.055f * bounceY * body;
            z += scale * 0.040f * (float)Math.sin(time * (0.030f + 0.020f * h2) + h3 * 6.2831853f) * body;
            // V141：形体不是画完后再变；控制点自身随短句进度逐步打开。
            float p = generativePhrasePhase(time, gesture);
            float open = smoother(clamp(p / 0.78f, 0f, 1f));
            x *= (0.82f + 0.18f * open);
            y *= (0.18f + 0.82f * open);
            z *= (0.12f + 0.88f * open);
            return new float[]{x, y, z};
        }

        private void drawGenerativeMystifyCurrent(ArrayList<float[]> curve, float minDim, int gesture, float time,
                                                   float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            drawAgeFadedStrip(curve, widthPx * 1.22f, color[0], color[1], color[2], alpha * 0.072f, 0.96f, 0.72f);
            drawAgeFadedStrip(curve, Math.max(0.055f, widthPx * 0.42f), 0.96f, 1.00f, 1.00f, alpha * 0.132f, 0.98f, 0.92f);
            // V139：不再额外叠加独立 ribbon/rib/accent，避免“先绘制后分身/复制”的分离感。
        }

        private void drawGenerativeAttachedRibbon(ArrayList<float[]> curve, float minDim, int gesture, float time,
                                                   float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            if (curve == null || curve.size() < 8) return;
            int phrase = (int)Math.floor(time / generativePhraseDuration(gesture));
            int mode = generativePhraseMode(gesture, phrase);
            float side = generativePhraseHash(gesture, phrase, 14301) < 0.5f ? -1f : 1f;
            if (mode == 2 || mode == 8) {
                float amount = side * minDim * (0.035f + 0.055f * generativePhraseHash(gesture, phrase, 14303));
                ArrayList<float[]> outer = offsetCurveByNormal(curve, amount);
                drawRuledSurfaceAgeFaded(curve, outer, color[0], color[1], color[2], alpha * 0.024f, 0.92f);
            } else if (mode == 6 || mode == 4) {
                int n = curve.size();
                int pivot = clampInt((int)(n * (0.34f + 0.28f * generativePhraseHash(gesture, phrase, 14307))), 1, n - 2);
                int step = 8;
                float[] pp = curve.get(pivot);
                for (int i = 2; i < n - 2; i += step) {
                    if (Math.abs(i - pivot) < step) continue;
                    ArrayList<float[]> rib = new ArrayList<>();
                    rib.add(pp);
                    rib.add(curve.get(i));
                    float u = i / Math.max(1f, n - 1f);
                    drawAgeFadedStrip(rib, Math.max(0.045f, widthPx * 0.50f), cyan[0], cyan[1], cyan[2], alpha * 0.018f * waveEnvelope(u), 0.88f, 0.18f);
                }
            } else {
                int n = curve.size();
                int start = clampInt((int)(n * (0.20f + 0.42f * generativePhraseHash(gesture, phrase, 14311))), 1, n - 5);
                int end = clampInt(start + 7, start + 2, n - 1);
                ArrayList<float[]> accent = new ArrayList<>();
                for (int i = start; i <= end; i++) accent.add(curve.get(i));
                drawAgeFadedStrip(accent, Math.max(0.07f, widthPx * 0.65f), hot[0], hot[1], hot[2], alpha * 0.045f, 0.92f, 0.70f);
            }
        }

        private ArrayList<ArrayList<float[]>> generativeCreationSegments(ArrayList<float[]> curve, float reveal, int gesture, float time) {
            // V144：短句必须从“无”开始，而不是直接显示一段已画好的线。
            // 初始阶段只蓄光，不画线；随后长度、宽度、亮度同时渐进增长。
            ArrayList<ArrayList<float[]>> out = new ArrayList<>();
            if (curve == null || curve.size() < 4 || reveal <= 0.001f) return out;
            float phase = generativePhrasePhase(time, gesture);
            if (phase < 0.050f) return out;
            float fade = 1f - smoother(clamp((phase - 0.88f) / 0.12f, 0f, 1f));
            if (fade <= 0.025f) return out;

            float birth = smoother(clamp((phase - 0.050f) / 0.100f, 0f, 1f));
            float head = smoother(clamp((phase - 0.050f) / 0.20f, 0f, 1f));
            float body = smoother(clamp((phase - 0.15f) / 0.46f, 0f, 1f));
            float finish = smoother(clamp((phase - 0.60f) / 0.28f, 0f, 1f));
            float endU = clamp((0.018f + 0.250f * head + 0.510f * body + 0.222f * finish) * birth, 0f, 1f);
            if (endU <= 0.014f) return out;

            // 边画边淡去：尾端在中后段逐渐追上，但不让整条主体突然完整呈现。
            float windowGrow = smoother(clamp((phase - 0.07f) / 0.46f, 0f, 1f));
            float windowShrink = smoother(clamp((phase - 0.64f) / 0.30f, 0f, 1f));
            float window = lerp(0.040f, 0.58f, windowGrow) * lerp(1.0f, 0.38f, windowShrink);
            float startU = clamp(endU - window, 0f, 0.98f);
            float span = endU - startU;
            if (span < 0.018f) {
                startU = Math.max(0f, endU - 0.018f * birth);
                span = endU - startU;
            }
            if (span <= 0.006f) return out;

            int samples = Math.max(8, (int)(curve.size() * Math.max(0.030f, span)));
            ArrayList<float[]> seg = subCurveByUnit(curve, startU, endU, samples);
            if (seg.size() >= 3) out.add(seg);
            return out;
        }

        private int generativeBrushShapeStyle(int gesture, float time) {
            float phase = generativePhrasePhase(time, gesture);
            return generativeBrushShapeStyleLive(gesture, time, phase);
        }

        private int generativeBrushShapeStyleLive(int gesture, float time, float phase) {
            int phrase = (int)Math.floor(time / Math.max(1.0f, generativePhraseDuration(gesture)));
            float shifted = clamp(phase, 0f, 0.999f);
            // V145：同一短句内要能实时换笔法，不能整段固定一种形状。
            // 7 个节拍覆盖线、扇、网、丝带、花瓣，并允许重复/回扫。
            int stage = clampInt((int)Math.floor(shifted * 7.0f), 0, 6);
            int order = (int)Math.floor(generativePhraseHash(gesture, phrase, 15311) * 6.0f);
            return generativeBrushStyleFromOrder(order, stage);
        }

        private int generativeBrushStyleFromOrder(int order, int stage) {
            order = Math.abs(order) % 6;
            stage = clampInt(stage, 0, 6);
            if (order == 0) {
                int[] seq = {0, 2, 4, 3, 1, 4, 3}; // 线 -> 扇 -> 网 -> 丝带 -> 花瓣 -> 网 -> 丝带
                return seq[stage];
            } else if (order == 1) {
                int[] seq = {0, 1, 3, 4, 2, 3, 1}; // 线 -> 花瓣 -> 丝带 -> 网 -> 扇 -> 丝带 -> 花瓣
                return seq[stage];
            } else if (order == 2) {
                int[] seq = {3, 0, 2, 1, 4, 2, 3}; // 丝带 -> 线 -> 扇 -> 花瓣 -> 网 -> 扇 -> 丝带
                return seq[stage];
            } else if (order == 3) {
                int[] seq = {0, 4, 2, 3, 1, 2, 4}; // 线 -> 网 -> 扇 -> 丝带 -> 花瓣 -> 扇 -> 网
                return seq[stage];
            } else if (order == 4) {
                int[] seq = {1, 0, 3, 2, 4, 1, 3}; // 花瓣 -> 线 -> 丝带 -> 扇 -> 网 -> 花瓣 -> 丝带
                return seq[stage];
            } else {
                int[] seq = {2, 4, 0, 3, 1, 4, 2}; // 扇 -> 网 -> 线 -> 丝带 -> 花瓣 -> 网 -> 扇
                return seq[stage];
            }
        }

        private float generativeBrushStyleChangePulse(float phase) {
            float local = fract(clamp(phase, 0f, 0.999f) * 7.0f);
            float enter = smoother(clamp(local / 0.16f, 0f, 1f));
            float leave = 1f - smoother(clamp((local - 0.78f) / 0.22f, 0f, 1f));
            return enter * leave;
        }

        private void sortIntervalsByStart(ArrayList<float[]> intervals) {
            for (int i = 1; i < intervals.size(); i++) {
                float[] key = intervals.get(i);
                int j = i - 1;
                while (j >= 0 && intervals.get(j)[0] > key[0]) {
                    intervals.set(j + 1, intervals.get(j));
                    j--;
                }
                intervals.set(j + 1, key);
            }
        }

        private int generativePaintProcessMode(int gesture, float time) {
            float r = stableHash01(gesture + (int)Math.floor(time / Math.max(1.0f, generativePhraseDuration(gesture))), 14511);
            if (r < 0.28f) return 0;
            if (r < 0.52f) return 1;
            if (r < 0.78f) return 2;
            return 3;
        }

        private ArrayList<float[]> subCurveByUnit(ArrayList<float[]> curve, float startU, float endU, int samples) {
            ArrayList<float[]> out = new ArrayList<>();
            if (curve == null || curve.isEmpty()) return out;
            startU = clamp(startU, 0f, 1f);
            endU = clamp(endU, 0f, 1f);
            if (endU < startU) {
                float tmp = startU;
                startU = endU;
                endU = tmp;
            }
            int n = curve.size();
            samples = clampInt(samples, 3, Math.max(3, n));
            for (int i = 0; i < samples; i++) {
                float u = lerp(startU, endU, i / Math.max(1f, samples - 1f));
                float pos = u * (n - 1f);
                int idx = clampInt((int)Math.floor(pos), 0, n - 1);
                int idx2 = clampInt(idx + 1, 0, n - 1);
                float f = pos - idx;
                float[] a = curve.get(idx);
                float[] b = curve.get(idx2);
                out.add(new float[]{lerp(a[0], b[0], f), lerp(a[1], b[1], f)});
            }
            return out;
        }

        private void drawGenerativeGrowingFormSegments(ArrayList<ArrayList<float[]>> segments, float minDim, int gesture, float time,
                                                        float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            int i = 0;
            for (ArrayList<float[]> seg : segments) {
                if (seg == null || seg.size() < 4) continue;
                drawGenerativeGrowingForm(seg, minDim, gesture + i * 43, time + i * 0.17f, color, cyan, hot, alpha, widthPx);
                i++;
            }
        }

        private void drawGenerativeGrowingForm(ArrayList<float[]> seg, float minDim, int gesture, float time,
                                               float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            int n = seg.size();
            if (n < 4 || alpha <= 0.001f) return;
            float side = stableHash01(gesture, 15101) < 0.5f ? -1f : 1f;
            float phase = generativePhrasePhase(time, gesture);
            int brushStyle = generativeBrushShapeStyleLive(gesture, time, phase);
            float develop = smoother(clamp((phase - 0.045f) / 0.42f, 0f, 1f));
            float release = 1f - smoother(clamp((phase - 0.88f) / 0.12f, 0f, 1f));
            float stylePulse = generativeBrushStyleChangePulse(phase);
            float phraseBeat = clamp(phase * 7.0f, 0f, 6.999f);
            float breath = 0.84f + 0.18f * (float)Math.sin(time * 0.55f + stableHash01(gesture, 15103) * 6.2831853f);
            ArrayList<float[]> inner = new ArrayList<>(n);
            ArrayList<float[]> outer = new ArrayList<>(n);
            ArrayList<float[]> brightEdge = new ArrayList<>(n);
            for (int j = 0; j < n; j++) {
                float u = j / Math.max(1f, n - 1f);
                float[] prev = seg.get(Math.max(0, j - 1));
                float[] next = seg.get(Math.min(n - 1, j + 1));
                float dx = next[0] - prev[0];
                float dy = next[1] - prev[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001f) len = 1f;
                float tx = dx / len;
                float ty = dy / len;
                float nx = -ty * side;
                float ny = tx * side;
                float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.50f);
                float front = smoother(clamp((u - 0.03f) / 0.70f, 0f, 1f));
                float tailTaper = 1f - 0.28f * smoother(clamp((u - 0.82f) / 0.18f, 0f, 1f));
                float localPulse = 0.88f + 0.12f * (float)Math.sin(time * 0.92f + u * 5.4f + stableHash01(gesture, 15107) * 6.2831853f);
                float styleOpen = smoother(clamp((phase - 0.08f) / 0.56f, 0f, 1f));
                int localStyle = generativeBrushShapeStyleLive(gesture + (int)(u * 31f), time + u * 0.42f, fract(phase + u * 0.38f));
                float shapeMul = 1f;
                float asymMul = 1f;
                float flowMul = 1f;
                if (localStyle == 0) { // 细线/起笔：保持收束，但不僵死
                    shapeMul = 0.46f + 0.18f * waveEnvelope(u) * smoother(clamp((phraseBeat - 0.20f) / 0.70f, 0f, 1f));
                    asymMul = 0.58f + 0.14f * u;
                    flowMul = 0.64f;
                } else if (localStyle == 1) { // 花瓣/羽翼：中段宽、两端极细
                    shapeMul = 1.18f + 1.02f * (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 1.10f) * styleOpen;
                    asymMul = 0.72f + 0.42f * u;
                    flowMul = 0.72f;
                } else if (localStyle == 2) { // 扇形/波束：尾部细，前段逐渐铺开
                    shapeMul = 0.72f + 1.55f * smoother(clamp((u - 0.12f) / 0.66f, 0f, 1f)) * styleOpen;
                    asymMul = 0.84f + 0.62f * u;
                    flowMul = 1.22f;
                } else if (localStyle == 3) { // 飘带/钩形：更强调随风抛起的丝带
                    shapeMul = 0.86f + 1.30f * smoother(clamp((u - 0.32f) / 0.50f, 0f, 1f)) * styleOpen;
                    asymMul = 1.12f - 0.30f * u;
                    flowMul = 1.42f;
                } else if (localStyle == 4) { // 网纱/场线：更宽、更轻，肋线稍多
                    shapeMul = 0.94f + 1.72f * waveEnvelope(u) * styleOpen;
                    asymMul = 0.90f + 0.30f * (float)Math.sin(u * Math.PI);
                    flowMul = 0.86f;
                }
                // 短句内部换笔法时，给一个短暂的“抑扬顿挫”脉冲，让变化被看见但不过度跳变。
                float accent = 1.0f + 0.34f * stylePulse * waveEnvelope(u);
                float wide = minDim * (0.0075f + 0.078f * body * front * develop) * tailTaper * breath * localPulse * shapeMul * accent;
                float minor = minDim * (0.0015f + 0.015f * body * (0.64f + 0.36f * develop)) * (0.78f + 0.18f * shapeMul);
                float flow = minDim * (0.002f + 0.020f * body * develop) * (0.20f + 0.80f * u) * flowMul;
                float x = seg.get(j)[0];
                float y = seg.get(j)[1];
                inner.add(new float[]{x - nx * minor * asymMul - tx * flow * 0.10f, y - ny * minor * asymMul - ty * flow * 0.10f});
                outer.add(new float[]{x + nx * wide + tx * flow, y + ny * wide + ty * flow});
                brightEdge.add(new float[]{x + nx * wide * 0.80f + tx * flow * 0.88f, y + ny * wide * 0.80f + ty * flow * 0.88f});
            }
            drawRuledSurfaceAgeFaded(inner, outer, color[0], color[1], color[2], alpha * 0.220f * release, 0.92f);
            drawAgeFadedStrip(seg, Math.max(0.22f, widthPx * 0.95f), cyan[0], cyan[1], cyan[2], alpha * 0.055f * release, 0.88f, 0.64f);
            drawAgeFadedStrip(seg, Math.max(0.10f, widthPx * 0.42f), 0.98f, 1.00f, 1.00f, alpha * 0.095f * release, 0.90f, 0.86f);
            drawAgeFadedStrip(brightEdge, Math.max(0.10f, widthPx * 0.42f), hot[0], hot[1], hot[2], alpha * 0.058f * release, 0.86f, 0.50f);
            int ribs = brushStyle == 4 ? (cfg.powerSave ? 6 : 11) : (brushStyle == 0 ? (cfg.powerSave ? 3 : 5) : (brushStyle == 3 ? (cfg.powerSave ? 3 : 5) : (cfg.powerSave ? 4 : 8)));
            for (int r = 1; r <= ribs; r++) {
                float u = r / (ribs + 1f);
                int idx = clampInt((int)(u * (n - 1)), 1, n - 2);
                float ribLife = waveEnvelope(u) * develop * release;
                if (ribLife <= 0.02f) continue;
                ArrayList<float[]> rib = new ArrayList<>();
                rib.add(inner.get(idx));
                rib.add(new float[]{lerp(inner.get(idx)[0], outer.get(idx)[0], 0.48f), lerp(inner.get(idx)[1], outer.get(idx)[1], 0.48f)});
                rib.add(outer.get(idx));
                drawAgeFadedStrip(rib, Math.max(0.055f, widthPx * 0.18f), cyan[0], cyan[1], cyan[2], alpha * 0.020f * ribLife, 0.88f, 0.24f);
            }
        }

        private void drawGenerativeMystifyCurrentSegments(ArrayList<ArrayList<float[]>> segments, float minDim, int gesture, float time,
                                                          float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            int i = 0;
            for (ArrayList<float[]> seg : segments) {
                if (seg == null || seg.size() < 3) continue;
                float emphasis = 0.86f + 0.18f * waveEnvelope(i / Math.max(1f, segments.size() - 1f));
                drawGenerativeMystifyCurrent(seg, minDim, gesture + i * 31, time, color, cyan, hot, alpha * emphasis, widthPx);
                i++;
            }
        }

        private void drawGenerativeTrailSegments(ArrayList<ArrayList<float[]>> segments, float widthPx, float[] color, float alpha) {
            int i = 0;
            for (ArrayList<float[]> seg : segments) {
                if (seg == null || seg.size() < 3) continue;
                float a = alpha * (0.62f + 0.22f * waveEnvelope(i / Math.max(1f, segments.size() - 1f)));
                float w = widthPx * (0.66f + 0.12f * waveEnvelope(i / Math.max(1f, segments.size() - 1f)));
                drawAgeFadedStrip(seg, w, color[0], color[1], color[2], a, 0.94f, 0.28f);
                i++;
            }
        }

        private void drawGenerativeSegmentTips(ArrayList<ArrayList<float[]>> segments, float minDim, int gesture, float time,
                                               float[] color, float[] hot, float alpha, float widthPx) {
            int i = 0;
            for (ArrayList<float[]> seg : segments) {
                if (seg == null || seg.size() < 3) continue;
                drawGenerativeDrawingTip(seg, minDim, gesture + i * 37, time + i * 0.13f, color, hot, alpha * 0.56f, widthPx);
                // seed 只在起笔阶段提示，不再像另一个独立主体。
                drawGenerativeDrawingSeed(seg, minDim, gesture + i * 41, time + i * 0.19f, color, hot, alpha * 0.24f, widthPx);
                i++;
            }
        }

        private void drawGenerativeDrawingSeed(ArrayList<float[]> curve, float minDim, int gesture, float time,
                                               float[] color, float[] hot, float alpha, float widthPx) {
            if (curve == null || curve.size() < 2 || alpha <= 0.001f) return;
            float[] seed = curve.get(0);
            float[] next = curve.get(Math.min(curve.size() - 1, 2));
            float angle = (float)Math.atan2(next[1] - seed[1], next[0] - seed[0]);
            float p = generativePhrasePhase(time, gesture);
            if (p > 0.24f) return;
            float seedStage = smoother(clamp(p / 0.08f, 0f, 1f)) * (1f - smoother(clamp((p - 0.18f) / 0.06f, 0f, 1f)));
            float rx = Math.max(1.2f, widthPx * 3.6f) * seedStage;
            float ry = Math.max(0.7f, widthPx * 1.30f) * seedStage;
            drawEllipse(seed[0], seed[1], rx, ry, angle, color[0], color[1], color[2], alpha * 0.120f * seedStage, 18);
        }

        private ArrayList<float[]> sliceCurveForDrawingProgress(ArrayList<float[]> curve, float reveal) {
            ArrayList<float[]> out = new ArrayList<>();
            if (curve == null || curve.isEmpty()) return out;
            reveal = clamp(reveal, 0f, 1f);
            int n = curve.size();
            float end = reveal * (n - 1f);
            int endIndex = clampInt((int)Math.floor(end), 0, n - 1);
            for (int i = 0; i <= endIndex; i++) {
                out.add(curve.get(i));
            }
            if (endIndex < n - 1) {
                float f = end - endIndex;
                float[] a = curve.get(endIndex);
                float[] b = curve.get(endIndex + 1);
                out.add(new float[]{lerp(a[0], b[0], f), lerp(a[1], b[1], f)});
            }
            return out;
        }

        private void drawGenerativeDrawingTip(ArrayList<float[]> curve, float minDim, int gesture, float time,
                                              float[] color, float[] hot, float alpha, float widthPx) {
            if (curve == null || curve.size() < 2 || alpha <= 0.001f) return;
            int n = curve.size();
            float[] tip = curve.get(n - 1);
            float[] prev = curve.get(Math.max(0, n - 3));
            float angle = (float)Math.atan2(tip[1] - prev[1], tip[0] - prev[0]);
            float pulse = generativePhrasePulse(time, gesture);
            float p = generativePhrasePhase(time, gesture);
            float drawStage = smoother(clamp((p - 0.050f) / 0.10f, 0f, 1f)) * (1f - smoother(clamp((p - 0.82f) / 0.14f, 0f, 1f)));
            float rx = Math.max(1.6f, widthPx * (5.4f + 2.2f * pulse)) * drawStage;
            float ry = Math.max(0.9f, widthPx * (2.0f + 0.9f * pulse)) * drawStage;
            drawEllipse(tip[0], tip[1], rx, ry, angle, 0.98f, 1.0f, 1.0f, alpha * 0.12f * drawStage, 24);
            drawEllipse(tip[0], tip[1], rx * 1.85f, ry * 1.85f, angle, color[0], color[1], color[2], alpha * 0.105f * drawStage, 24);
            if (n > 5) {
                ArrayList<float[]> spark = new ArrayList<>();
                for (int i = Math.max(0, n - 6); i < n; i++) spark.add(curve.get(i));
                drawAgeFadedStrip(spark, Math.max(0.06f, widthPx * 0.60f), hot[0], hot[1], hot[2], alpha * 0.055f * drawStage, 0.88f, 0.95f);
            }
        }


        private int generativePhraseMode(int gesture, int phrase) {
            int mode = clampInt((int)Math.floor(generativePhraseHash(gesture, phrase, 14051) * 10f), 0, 9);
            int prev = clampInt((int)Math.floor(generativePhraseHash(gesture, phrase - 1, 14051) * 10f), 0, 9);
            if (mode == prev) mode = (mode + 3) % 10;
            return mode;
        }

        private int generativeControlCount(int gesture, int phrase, int mode) {
            int base = 5 + Math.floorMod(mode + phrase, 4);
            if (mode == 5 || mode == 7 || mode == 9) base += 1;
            if (generativePhraseHash(gesture, phrase, 14061) > 0.72f) base += 1;
            return clampInt(base, 5, 9);
        }

        private float generativePhraseDuration(int gesture) {
            // V141：保持足够慢，但不要慢到长时间只看到一根未展开的线。
            return 9.8f + 3.2f * stableHash01(gesture, 14071);
        }

        private float generativePhraseMorphMix(float local) {
            // 只有最后极短时间过渡到下一句，避免当前作品还没看清就变成另一个。
            return smoother(clamp((local - 0.92f) / 0.06f, 0f, 1f));
        }

        private float generativePhraseLife(float time, int gesture) {
            float p = generativePhrasePhase(time, gesture);
            float in = smoother(clamp(p / 0.10f, 0f, 1f));
            float out = 1f - smoother(clamp((p - 0.92f) / 0.08f, 0f, 1f));
            return clamp(in * out, 0f, 1f);
        }

        private float generativePhraseReveal(float time, int gesture) {
            float p = generativePhrasePhase(time, gesture);
            float draw = smoother(clamp((p - 0.030f) / 0.82f, 0f, 1f));
            return clamp(draw, 0f, 1f);
        }

        private float generativePhrasePhase(float time, int gesture) {
            return fract(Math.max(0f, time) / generativePhraseDuration(gesture));
        }

        private float generativePhrasePulse(float time, int gesture) {
            float p = generativePhrasePhase(time, gesture);
            float drawSurge = smoother(clamp(p / 0.55f, 0f, 1f)) * (1f - 0.18f * smoother(clamp((p - 0.82f) / 0.16f, 0f, 1f)));
            float surge = (float)Math.sin(Math.PI * clamp(p, 0f, 1f));
            float flicker = 0.5f + 0.5f * (float)Math.sin(time * 0.64f + stableHash01(gesture, 14081) * 6.2831853f);
            return clamp(0.22f + 0.54f * drawSurge + 0.24f * (0.76f * surge + 0.24f * flicker), 0f, 1f);
        }

        private float[] generativePhraseCenter(int gesture, int phrase, float minDim) {
            float rx = generativePhraseHash(gesture, phrase, 14091);
            float ry = generativePhraseHash(gesture, phrase, 14093);
            float marginX = width * 0.10f;
            float top = height * 0.14f;
            float bottom = height * 0.76f;
            float x = lerp(marginX, width - marginX, rx);
            float y = lerp(top, bottom, ry);
            return new float[]{x, y};
        }

        private float generativePhraseScale(int gesture, int phrase, float minDim) {
            return minDim * (0.30f + 0.56f * generativePhraseHash(gesture, phrase, 14111));
        }

        private float generativeCameraFov(float time, int gesture, float minDim) {
            float v = 0.56f + 0.28f * (float)Math.sin(time * 0.040f + stableHash01(gesture, 14121) * 6.2831853f)
                    + 0.16f * (float)Math.sin(time * 0.113f + stableHash01(gesture, 14123) * 6.2831853f);
            return minDim * clamp(v, 0.30f, 1.05f);
        }

        private float generativeStringLife(float time, int gesture, int index) {
            float p = 0.5f + 0.5f * (float)Math.sin(time * (0.060f + 0.014f * index) + stableHash01(gesture, 14131) * 6.2831853f);
            return clamp(0.36f + 0.64f * smoother(p), 0f, 1f);
        }

        private float generativePhraseHash(int gesture, int phrase, int salt) {
            return stableHash01(gesture * 191 + phrase * 1297, salt);
        }

        private void drawScreensaverArtistBrush(ArrayList<float[]> sourceStroke, int gesture, float raw, float progress,
                                                float minDim, float drawSec, float seedA, float seedB, float seedC,
                                                float[] mid, float[] cyan, float[] hot, float alpha) {
            // V132：根据实拍视频重新校准为“时间绘画”模型。
            // 重点不是让一个成品四处漂移，而是让每个时间短句都重新选择构图中心、尺度、拓扑、亮度和残影节奏，
            // 像 Windows7 Mystify 那样不断即兴创造新的光弦作品。
            int strings = cfg.powerSave ? 1 : 3;
            int trails = cfg.powerSave ? 16 : 26;
            float speed = mystifySpeed(drawSec, gesture, seedA);
            float phrasePulse = mystifyCreativePhrasePulse(drawSec, gesture, seedC);
            float trailGap = (0.018f + 0.022f * stableHash01(gesture, 12711)) * lerp(1.80f, 0.46f, speed)
                    * (0.78f + 0.72f * phrasePulse);
            float cameraFov = mystifyCameraFov(drawSec, gesture, minDim);
            float lineWidth = mystifyLineWidth(minDim);
            for (int s = 0; s < strings; s++) {
                int sg = gesture * 17 + 113 * s + 1009;
                float phaseShift = s * 1.91f + stableHash01(sg, 12717) * 1.6f;
                float life = mystifyStringLife(drawSec, sg, s);
                float stringAlpha = alpha * life * (s == 0 ? 1.0f : (s == 1 ? 0.46f : 0.26f));
                if (stringAlpha <= alpha * 0.025f) continue;
                for (int k = trails - 1; k >= 0; k--) {
                    float age = k / Math.max(1f, trails - 1f);
                    float time = drawSec - k * trailGap - s * 0.23f;
                    ArrayList<float[]> curve = buildWindows7MystifyString(sourceStroke, sg, time, minDim, cameraFov,
                            seedA + phaseShift, seedB + s * 0.31f, seedC + s * 0.57f, cfg.powerSave ? 60 : 96);
                    if (curve.size() < 4) continue;
                    float remain = 1f - age;
                    float trailAlpha = stringAlpha * (0.0022f + 0.026f * remain * remain * remain);
                    float hue = fract(0.56f + sg * 0.041f + time * 0.023f - age * 0.060f + 0.018f * phrasePulse);
                    float[] color = mystifyPaletteFromHue(hue, mid, cyan, hot, remain, k == 0);
                    if (k == 0) {
                        drawWindows7MystifyCurrent(curve, minDim, sg, time, color, cyan, hot, stringAlpha, lineWidth * (s == 0 ? 1.0f : 0.78f));
                    } else {
                        drawWindows7MystifyTrail(curve, minDim, color, trailAlpha, lineWidth * (0.44f + 0.42f * remain) * (s == 0 ? 1.0f : 0.72f));
                    }
                }
            }
        }

        private ArrayList<float[]> buildWindows7MystifyString(ArrayList<float[]> sourceStroke, int gesture, float time,
                                                              float minDim, float cameraFov, float seedA, float seedB, float seedC,
                                                              int samples) {
            float[] sourceCenter = mystifySourceCenter(sourceStroke);
            float stage = mystifyStageRadius(sourceStroke, minDim);

            // V132：每个短句重新生成“构图中心 + 舞台尺度 + 控制点数量 + 拓扑语法”。
            // 这样看起来不是一个主体在漂移，而是连续出现新的即兴绘画作品。
            float phraseDuration = mystifyPhraseDuration(gesture);
            float phrasePos = time / phraseDuration + stableHash01(gesture, 12901) * 0.73f;
            int phraseA = (int)Math.floor(phrasePos);
            float phraseLocal = fract(phrasePos);
            float phraseMix = mystifyPhraseMorphMix(phraseLocal);
            int phraseB = phraseA + 1;
            int modeA = mystifyPhraseMode(gesture, phraseA);
            int modeB = mystifyPhraseMode(gesture, phraseB);
            int controlCount = cfg.powerSave ? 5 : mystifyPhraseControlCount(modeA, modeB, gesture, phraseA);
            float[][] ctl = new float[controlCount][3];
            float phraseEnergy = mystifyCreativePhrasePulse(time, gesture, seedC);
            float[] centerA = mystifyPhraseScreenCenter(gesture, phraseA, minDim);
            float[] centerB = mystifyPhraseScreenCenter(gesture, phraseB, minDim);
            float[] center = new float[]{
                    lerp(sourceCenter[0], lerp(centerA[0], centerB[0], phraseMix), 0.88f),
                    lerp(sourceCenter[1], lerp(centerA[1], centerB[1], phraseMix), 0.88f)
            };
            float stageA = mystifyPhraseStageScale(gesture, phraseA);
            float stageB = mystifyPhraseStageScale(gesture, phraseB);
            stage = minDim * lerp(stageA, stageB, phraseMix) * (0.86f + 0.38f * phraseEnergy);
            float phraseAngleA = mystifyPhraseHash(gesture, phraseA, 12801) * 6.2831853f;
            float phraseAngleB = mystifyPhraseHash(gesture, phraseB, 12801) * 6.2831853f;
            float baseAngle = lerpAngle(phraseAngleA, phraseAngleB, phraseMix)
                    + time * (0.018f + 0.054f * mystifyPhraseHash(gesture, phraseA, 12803))
                    + 1.46f * (mystifyPhraseHash(gesture, phraseA, 12807) - 0.5f) * phraseEnergy;
            float span = stage * (0.42f + 1.72f * mystifyPhraseHash(gesture, phraseA, 12805))
                    * (0.48f + 1.02f * phraseEnergy);
            for (int i = 0; i < controlCount; i++) {
                float[] pa = mystifyPhraseControlPoint(gesture, phraseA, i, controlCount, time, stage, seedA, seedB, seedC, span, phraseEnergy);
                float[] pb = mystifyPhraseControlPoint(gesture, phraseB, i, controlCount, time, stage, seedA, seedB, seedC, span, phraseEnergy);
                ctl[i][0] = lerp(pa[0], pb[0], phraseMix);
                ctl[i][1] = lerp(pa[1], pb[1], phraseMix);
                ctl[i][2] = lerp(pa[2], pb[2], phraseMix);
            }

            float yaw = baseAngle + 0.48f * (float)Math.sin(time * 0.033f + seedA)
                    + 0.34f * (float)Math.sin(time * 0.081f + seedC) * phraseEnergy;
            float roll = 0.58f * (float)Math.sin(time * 0.026f + seedB)
                    + 0.42f * (float)Math.sin(time * 0.064f + seedC + phraseMix * 2.6f);
            float pitch = 0.46f * (float)Math.sin(time * 0.037f + seedC)
                    + 0.26f * (float)Math.sin(time * 0.093f + seedA + phraseLocal * 2.0f);
            float driftX = (float)Math.sin(time * 0.015f + seedB + phraseA * 0.19f) * stage * (0.020f + 0.040f * phraseEnergy);
            float driftY = (float)Math.cos(time * 0.017f + seedC + phraseA * 0.23f) * stage * (0.018f + 0.034f * phraseEnergy);

            ArrayList<float[]> out = new ArrayList<>(samples);
            for (int s = 0; s < samples; s++) {
                float q = s / Math.max(1f, samples - 1f);
                float pos = q * (controlCount - 1f);
                int i1 = clampInt((int)Math.floor(pos), 0, controlCount - 1);
                float local = pos - i1;
                int i0 = clampInt(i1 - 1, 0, controlCount - 1);
                int i2 = clampInt(i1 + 1, 0, controlCount - 1);
                int i3 = clampInt(i1 + 2, 0, controlCount - 1);
                float[] p3d = catmullRomPoint3(ctl[i0], ctl[i1], ctl[i2], ctl[i3], smoother(local));
                float[] projected = projectMystify3dPoint(p3d[0], p3d[1], p3d[2], yaw, roll, pitch, cameraFov);
                out.add(new float[]{center[0] + driftX + projected[0], center[1] + driftY + projected[1]});
            }
            return out;
        }

        private float[] mystifyPhraseControlPoint(int gesture, int phrase, int i, int controlCount, float time,
                                                  float stage, float seedA, float seedB, float seedC, float span, float phraseEnergy) {
            float u = i / Math.max(1f, controlCount - 1f);
            float ordered = (u - 0.5f) * 2f;
            float envelope = 0.34f + 0.66f * (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.46f);
            int mode = mystifyPhraseMode(gesture, phrase);
            float h0 = mystifyPhraseHash(gesture, phrase, 12911);
            float h1 = mystifyPhraseHash(gesture, phrase, 12917);
            float h2 = mystifyPhraseHash(gesture, phrase, 12923);
            float h3 = mystifyPhraseHash(gesture, phrase, 12927);
            float sign = h0 < 0.5f ? -1f : 1f;
            float phraseLocal = fract(time / mystifyPhraseDuration(gesture) + stableHash01(gesture, 12901) * 0.73f);
            float open = smoother(clamp(phraseLocal / 0.30f, 0f, 1f)) * (1f - 0.18f * smoother(clamp((phraseLocal - 0.82f) / 0.18f, 0f, 1f)));
            float surge = 0.74f + 0.34f * (float)Math.sin(phraseLocal * 6.2831853f + h3 * 6.2831853f)
                    + 0.18f * (float)Math.sin(phraseLocal * 12.56637f + h1 * 6.2831853f);
            float lateral = stage * (0.30f + 0.58f * h1) * (0.66f + 0.82f * phraseEnergy) * open * clamp(surge, 0.42f, 1.36f);
            float depth = stage * (0.26f + 0.62f * h2) * (0.66f + 0.72f * phraseEnergy) * clamp(1.10f - 0.30f * surge, 0.55f, 1.22f);
            float x = ordered * span * (0.32f + 0.34f * h3);
            float y;
            float z;
            switch (mode) {
                case 0: // 大弓形展开
                    y = sign * lateral * (float)Math.sin(Math.PI * u) * (0.68f + 0.28f * (float)Math.sin(time * 0.090f + seedA));
                    z = depth * (ordered * ordered - 0.34f) * sign;
                    break;
                case 1: // 双 S 扭转
                    y = lateral * ((float)Math.sin(2.0f * Math.PI * u + h2 * 6.2831853f) * 0.74f
                            + (float)Math.sin(4.0f * Math.PI * u + h1 * 6.2831853f) * 0.18f);
                    z = depth * (float)Math.cos(Math.PI * u + h1 * 6.2831853f) * envelope;
                    break;
                case 2: // 钩形短句
                    y = sign * lateral * (ordered * ordered * 0.98f - 0.32f) + lateral * 0.24f * (float)Math.sin(Math.PI * u + seedB);
                    z = depth * (float)Math.sin(1.55f * Math.PI * u + h0 * 6.2831853f) * envelope;
                    x += sign * stage * 0.14f * (float)Math.sin(Math.PI * u);
                    break;
                case 3: // 扇形开合
                    y = sign * lateral * ordered * (0.42f + 0.58f * (float)Math.sin(Math.PI * u));
                    z = depth * (float)Math.sin(Math.PI * u + h1 * 3.0f) * (0.48f + 0.52f * Math.abs(ordered));
                    x *= 0.78f + 0.30f * Math.abs(ordered);
                    break;
                case 4: // 多频波浪即兴
                    y = lateral * ((float)Math.sin(Math.PI * u * 1.45f + h0 * 6.2831853f) * 0.62f
                            + (float)Math.sin(Math.PI * u * 3.35f + h1 * 6.2831853f) * 0.28f) * envelope;
                    z = depth * ((float)Math.cos(Math.PI * u * 1.30f + h2 * 6.2831853f) * 0.76f
                            + (float)Math.sin(Math.PI * u * 2.7f + h3 * 6.2831853f) * 0.16f);
                    break;
                case 5: // 折返 / 花冠式开合
                    y = sign * lateral * (float)Math.sin(Math.PI * u) * (0.42f + 0.50f * (float)Math.sin(2f * Math.PI * u + h1 * 6.2831853f));
                    z = depth * (float)Math.sin(2.0f * Math.PI * u + h2 * 6.2831853f) * envelope;
                    x += stage * 0.10f * sign * (float)Math.sin(2.0f * Math.PI * u + h0 * 6.2831853f);
                    break;
                case 6: // 蝴蝶翼式双瓣
                    y = sign * lateral * (float)Math.sin(2f * Math.PI * u) * (0.18f + 0.82f * Math.abs(ordered));
                    z = depth * (float)Math.sin(Math.PI * u) * (0.55f + 0.45f * (float)Math.cos(2f * Math.PI * u + h1 * 6.2831853f));
                    x += stage * 0.12f * (float)Math.sin(Math.PI * u + h2 * 6.2831853f);
                    break;
                case 7: // 螺旋绞索
                    float theta = (float)(2.4 * Math.PI * u + h0 * 6.2831853f + time * 0.050f);
                    y = lateral * (float)Math.sin(theta) * envelope;
                    z = depth * (float)Math.cos(theta) * envelope;
                    x *= 0.84f + 0.20f * (float)Math.sin(Math.PI * u);
                    break;
                case 8: // 闪电式折线但保持曲线插值
                    float step = (float)Math.sin(Math.PI * u * 4f + h0 * 6.2831853f);
                    y = sign * lateral * (0.52f * step + 0.26f * (float)Math.sin(Math.PI * u + h2 * 6.2831853f)) * envelope;
                    z = depth * (float)Math.cos(Math.PI * u * 2.2f + h1 * 6.2831853f) * envelope;
                    break;
                case 9: // 喷泉式扩散
                    float fan = (float)Math.pow(Math.abs(ordered), 0.72f) * (ordered < 0f ? -1f : 1f);
                    y = sign * lateral * fan * (0.38f + 0.62f * (float)Math.sin(Math.PI * u));
                    z = depth * (float)Math.sin(Math.PI * u + h2 * 6.2831853f) * (0.40f + 0.60f * Math.abs(fan));
                    x += stage * 0.08f * sign * (float)Math.sin(Math.PI * u * 1.5f + h3 * 6.2831853f);
                    break;
                case 10: // 星芒压缩 / 爆发
                    float star = (float)Math.sin(Math.PI * u) * (0.45f + 0.55f * (float)Math.sin(3f * Math.PI * u + h0 * 6.2831853f));
                    y = sign * lateral * star * (0.45f + 0.55f * Math.abs(ordered));
                    z = depth * (ordered * ordered - 0.22f) * (float)Math.sin(phraseLocal * 6.2831853f + h2 * 6.2831853f);
                    x *= 0.66f + 0.56f * Math.abs(star);
                    break;
                case 11: // 长藤卷曲
                    float vine = (float)Math.sin(1.35f * Math.PI * u + h0 * 6.2831853f);
                    y = sign * lateral * (vine * 0.62f + ordered * 0.28f) * envelope;
                    z = depth * (float)Math.sin(2.8f * Math.PI * u + h2 * 6.2831853f + phraseLocal * 1.8f) * envelope;
                    x += sign * stage * 0.16f * (float)Math.sin(Math.PI * u + h1 * 6.2831853f);
                    break;
                case 12: // 云门式开合
                    float gate = smoother(clamp(Math.abs(ordered), 0f, 1f));
                    y = sign * lateral * (0.30f + 0.70f * gate) * (float)Math.sin(Math.PI * u + h0 * 3.14159f);
                    z = depth * (0.55f - gate) * (float)Math.cos(2f * Math.PI * u + h2 * 6.2831853f);
                    x *= 0.72f + 0.46f * gate;
                    break;
                default: // 羽化波束
                    float feather = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.55f);
                    y = lateral * ((float)Math.sin(2.6f * Math.PI * u + h0 * 6.2831853f) * 0.52f
                            + sign * ordered * 0.38f) * feather;
                    z = depth * ((float)Math.cos(1.8f * Math.PI * u + h1 * 6.2831853f) * 0.70f
                            + (float)Math.sin(4.4f * Math.PI * u + h3 * 6.2831853f) * 0.16f) * feather;
                    x += stage * 0.10f * (float)Math.sin(3f * Math.PI * u + h2 * 6.2831853f);
                    break;
            }
            float bx = mystifyBounce(time * (0.040f + 0.030f * mystifyPhraseHash(gesture, phrase + i, 12931)) + h0) * 2f - 1f;
            float by = mystifyBounce(time * (0.062f + 0.038f * mystifyPhraseHash(gesture, phrase + i, 12937)) + h1) * 2f - 1f;
            float bz = mystifyBounce(time * (0.052f + 0.034f * mystifyPhraseHash(gesture, phrase + i, 12941)) + h2) * 2f - 1f;
            float localFlick = (float)Math.sin(time * (0.22f + 0.12f * h3) + i * 1.37f + h0 * 6.2831853f);
            x += bx * stage * (0.105f + 0.090f * envelope) + localFlick * stage * 0.030f * envelope;
            y += by * lateral * (0.30f + 0.30f * envelope) + localFlick * lateral * 0.055f;
            z += bz * depth * (0.30f + 0.30f * envelope) - localFlick * depth * 0.040f;
            return new float[]{x, y, z};
        }

        private int mystifyPhraseMode(int gesture, int phrase) {
            int mode = clampInt((int)Math.floor(mystifyPhraseHash(gesture, phrase, 12961) * 14f), 0, 13);
            int prev = clampInt((int)Math.floor(mystifyPhraseHash(gesture, phrase - 1, 12961) * 14f), 0, 13);
            if (mode == prev) mode = (mode + 5) % 14;
            return mode;
        }

        private float mystifyPhraseDuration(int gesture) {
            // 实拍视频里的“惊喜感”来自一个形态有足够时间被看见，然后又进入新形态；不能过短也不能过长。
            return 2.20f + 3.10f * stableHash01(gesture, 12971);
        }

        private float mystifyPhraseMorphMix(float local) {
            local = clamp(local, 0f, 1f);
            // 前后有短暂停留，中段快速而丝滑地变形，形成“蓄势—变化—稳定”的时间绘画句法。
            float t = clamp((local - 0.16f) / 0.68f, 0f, 1f);
            return smoother(t);
        }

        private int mystifyPhraseControlCount(int modeA, int modeB, int gesture, int phrase) {
            int expressive = Math.max(modeA, modeB);
            int base = (expressive == 7 || expressive == 11 || expressive == 13) ? 9 : 7;
            if (expressive == 8 || expressive == 10) base = 6;
            return clampInt(base + (mystifyPhraseHash(gesture, phrase, 13017) > 0.68f ? 1 : 0), 5, 10);
        }

        private float[] mystifyPhraseScreenCenter(int gesture, int phrase, float minDim) {
            float rx = mystifyPhraseHash(gesture, phrase, 13031);
            float ry = mystifyPhraseHash(gesture, phrase, 13037);
            float x = lerp(width * 0.18f, width * 0.82f, rx);
            float y = lerp(height * 0.18f, height * 0.70f, ry);
            // 避开过低的导航/Dock 区，同时允许主体偶尔贴近边缘产生屏保式出入画感。
            return new float[]{clamp(x, width * 0.08f, width * 0.92f), clamp(y, height * 0.10f, height * 0.76f)};
        }

        private float lerpAngle(float a, float b, float t) {
            float d = ((b - a + 3.1415927f) % 6.2831853f) - 3.1415927f;
            if (d < -3.1415927f) d += 6.2831853f;
            return a + d * clamp(t, 0f, 1f);
        }

        private float[] mystifyPhraseCenterOffset(int gesture, int phrase, float stage) {
            float a = mystifyPhraseHash(gesture, phrase, 13001) * 6.2831853f;
            float b = mystifyPhraseHash(gesture, phrase, 13003) * 6.2831853f;
            float r = stage * (0.04f + 0.24f * mystifyPhraseHash(gesture, phrase, 13007));
            return new float[]{(float)Math.cos(a) * r + (float)Math.sin(b * 1.7f) * stage * 0.040f,
                    (float)Math.sin(a) * r * 0.78f + (float)Math.cos(b * 1.3f) * stage * 0.032f};
        }

        private float mystifyPhraseStageScale(int gesture, int phrase) {
            // 直接返回相对 minDim 的舞台半径，让每个短句有明显大小差异。
            return 0.30f + 0.62f * mystifyPhraseHash(gesture, phrase, 13011);
        }

        private float mystifyStringLife(float time, int gesture, int slot) {
            float p = fract(time / (3.4f + 2.2f * stableHash01(gesture, 13021)) + slot * 0.29f + stableHash01(gesture, 13023));
            float in = smoother(clamp(p / 0.16f, 0f, 1f));
            float out = 1f - smoother(clamp((p - 0.82f) / 0.18f, 0f, 1f));
            float swell = 0.78f + 0.22f * (float)Math.sin(p * 6.2831853f + stableHash01(gesture, 13027) * 6.2831853f);
            return clamp(0.12f + 0.88f * in * out * swell, 0f, 1f);
        }

        private float mystifyPhraseHash(int gesture, int phrase, int salt) {
            return stableHash01(gesture * 131 + phrase * 977, salt);
        }

        private float mystifyCreativePhrasePulse(float time, int gesture, float seed) {
            float phraseDuration = mystifyPhraseDuration(gesture);
            float p = fract(time / phraseDuration + stableHash01(gesture, 12979) * 0.5f);
            float attack = smoother(clamp(p / 0.28f, 0f, 1f));
            float release = 1f - smoother(clamp((p - 0.78f) / 0.22f, 0f, 1f));
            float breath = 0.5f + 0.5f * (float)Math.sin(time * 0.91f + seed + stableHash01(gesture, 12983) * 6.2831853f);
            return clamp((0.35f + 0.65f * attack * release) * (0.78f + 0.22f * breath), 0f, 1f);
        }

        private float[] catmullRomPoint3(float[] p0, float[] p1, float[] p2, float[] p3, float t) {
            float t2 = t * t;
            float t3 = t2 * t;
            float x = 0.5f * ((2f * p1[0]) + (-p0[0] + p2[0]) * t +
                    (2f * p0[0] - 5f * p1[0] + 4f * p2[0] - p3[0]) * t2 +
                    (-p0[0] + 3f * p1[0] - 3f * p2[0] + p3[0]) * t3);
            float y = 0.5f * ((2f * p1[1]) + (-p0[1] + p2[1]) * t +
                    (2f * p0[1] - 5f * p1[1] + 4f * p2[1] - p3[1]) * t2 +
                    (-p0[1] + 3f * p1[1] - 3f * p2[1] + p3[1]) * t3);
            float z = 0.5f * ((2f * p1[2]) + (-p0[2] + p2[2]) * t +
                    (2f * p0[2] - 5f * p1[2] + 4f * p2[2] - p3[2]) * t2 +
                    (-p0[2] + 3f * p1[2] - 3f * p2[2] + p3[2]) * t3);
            return new float[]{x, y, z};
        }

        private float[] projectMystify3dPoint(float x, float y, float z, float yaw, float roll, float pitch, float cameraFov) {
            float cy = (float)Math.cos(yaw), sy = (float)Math.sin(yaw);
            float cr = (float)Math.cos(roll), sr = (float)Math.sin(roll);
            float cp = (float)Math.cos(pitch), sp = (float)Math.sin(pitch);
            float x1 = x;
            float y1 = y * cp - z * sp;
            float z1 = y * sp + z * cp;
            float x2 = x1 * cr - y1 * sr;
            float y2 = x1 * sr + y1 * cr;
            float z2 = z1;
            float sx = x2 * cy - y2 * sy;
            float sy2 = x2 * sy + y2 * cy;
            float perspective = cameraFov / Math.max(cameraFov * 0.34f, cameraFov + z2);
            return new float[]{sx * perspective, sy2 * perspective};
        }

        private float mystifyStageRadius(ArrayList<float[]> stroke, float minDim) {
            if (stroke == null || stroke.size() < 2) return minDim * 0.58f;
            float[] c = mystifySourceCenter(stroke);
            float maxD = 0f;
            for (float[] p : stroke) {
                float dx = p[0] - c[0];
                float dy = p[1] - c[1];
                maxD = Math.max(maxD, (float)Math.sqrt(dx * dx + dy * dy));
            }
            return clamp(maxD * 1.04f, minDim * 0.42f, minDim * 0.72f);
        }

        private float mystifyCameraFov(float time, int gesture, float minDim) {
            // 类比 Windows7 Mystify 的 CameraFOV：低值更近，形体更包围；高值更远，线更轻。
            float f = 0.58f + 0.30f * (float)Math.sin(time * 0.036f + stableHash01(gesture, 12741) * 6.2831853f)
                    + 0.18f * (float)Math.sin(time * 0.097f + stableHash01(gesture, 12743) * 6.2831853f)
                    + 0.07f * (float)Math.sin(time * 0.173f + stableHash01(gesture, 12747) * 6.2831853f);
            return minDim * clamp(f, 0.32f, 1.18f);
        }

        private float mystifyLineWidth(float minDim) {
            // 类比 LineWidth：亮核保持清晰，外层不要堆成雾。
            return Math.max(0.08f, minDim * (0.00050f + 0.00055f * cfg.ribbonWidth));
        }

        private float mystifySpeed(float time, int gesture, float seed) {
            float a = 0.5f + 0.5f * (float)Math.sin(time * 0.070f + seed + stableHash01(gesture, 12751) * 6.2831853f);
            float b = 0.5f + 0.5f * (float)Math.sin(time * 0.121f + seed * 0.8f + stableHash01(gesture, 12753) * 6.2831853f);
            return smoother(clamp(a * 0.68f + b * 0.32f, 0f, 1f));
        }

        private void drawWindows7MystifyTrail(ArrayList<float[]> curve, float minDim, float[] color, float alpha, float widthPx) {
            drawAgeFadedStrip(curve, widthPx, color[0], color[1], color[2], alpha, 0.96f, 0.30f);
        }

        private void drawWindows7MystifyCurrent(ArrayList<float[]> curve, float minDim, int gesture, float time,
                                                float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            // 当前光弦由“彩色外线 + 青白亮核 + 少量局部高光”组成，不再画宽膜面。
            drawAgeFadedStrip(curve, widthPx * 1.26f, color[0], color[1], color[2], alpha * 0.220f, 0.96f, 0.78f);
            drawAgeFadedStrip(curve, Math.max(0.06f, widthPx * 0.52f), 0.96f, 1.00f, 1.00f, alpha * 0.116f, 0.98f, 0.92f);
            int n = curve.size();
            int accentStart = clampInt((int)(n * (0.18f + 0.30f * stableHash01(gesture, 12761))), 1, n - 6);
            int accentEnd = clampInt(accentStart + (cfg.powerSave ? 5 : 9), accentStart + 2, n - 1);
            ArrayList<float[]> accent = new ArrayList<>();
            for (int i = accentStart; i <= accentEnd; i++) accent.add(curve.get(i));
            drawAgeFadedStrip(accent, Math.max(0.06f, widthPx * 0.70f), hot[0], hot[1], hot[2], alpha * 0.185f, 0.92f, 0.42f);
            drawMystifyTimePaintingAccent(curve, minDim, gesture, time, color, cyan, hot, alpha, widthPx);
        }

        private void drawMystifyTimePaintingAccent(ArrayList<float[]> curve, float minDim, int gesture, float time,
                                                    float[] color, float[] cyan, float[] hot, float alpha, float widthPx) {
            if (curve.size() < 8 || alpha <= 0.001f) return;
            float phraseDuration = mystifyPhraseDuration(gesture);
            int phrase = (int)Math.floor(time / phraseDuration + stableHash01(gesture, 12901) * 0.73f);
            int mode = mystifyPhraseMode(gesture, phrase);
            int accent = Math.floorMod(mode, 4);
            if (accent == 0) {
                float side = mystifyPhraseHash(gesture, phrase, 13101) < 0.5f ? -1f : 1f;
                float amount = side * minDim * (0.030f + 0.080f * mystifyPhraseHash(gesture, phrase, 13103));
                ArrayList<float[]> outer = offsetCurveByNormal(curve, amount);
                drawRuledSurfaceAgeFaded(curve, outer, color[0], color[1], color[2], alpha * 0.026f, 0.92f);
                drawAgeFadedStrip(outer, Math.max(0.06f, widthPx * 0.72f), cyan[0], cyan[1], cyan[2], alpha * 0.026f, 0.94f, 0.34f);
            } else if (accent == 1) {
                int n = curve.size();
                int pivotIndex = clampInt((int)(n * (0.32f + 0.34f * mystifyPhraseHash(gesture, phrase, 13107))), 1, n - 2);
                float[] pivot = curve.get(pivotIndex);
                int step = cfg.powerSave ? 10 : 7;
                for (int i = 2; i < n - 2; i += step) {
                    float u = i / Math.max(1f, n - 1f);
                    if (Math.abs(i - pivotIndex) < step) continue;
                    ArrayList<float[]> rib = new ArrayList<>();
                    rib.add(pivot);
                    float[] p = curve.get(i);
                    float cx = lerp(pivot[0], p[0], 0.58f) + (p[1] - pivot[1]) * 0.040f;
                    float cy = lerp(pivot[1], p[1], 0.58f) - (p[0] - pivot[0]) * 0.040f;
                    rib.add(new float[]{cx, cy});
                    rib.add(p);
                    float a = alpha * (0.010f + 0.030f * (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.50f));
                    drawAgeFadedStrip(rib, Math.max(0.05f, widthPx * 0.55f), cyan[0], cyan[1], cyan[2], a, 0.90f, 0.22f);
                }
            } else if (accent == 2) {
                int n = curve.size();
                int start = clampInt((int)(n * (0.18f + 0.36f * mystifyPhraseHash(gesture, phrase, 13111))), 1, n - 5);
                int end = clampInt(start + (cfg.powerSave ? 6 : 12), start + 2, n - 1);
                ArrayList<float[]> flare = new ArrayList<>();
                for (int i = start; i <= end; i++) flare.add(curve.get(i));
                drawAgeFadedStrip(flare, Math.max(0.08f, widthPx * 0.72f), 0.98f, 1.00f, 1.00f, alpha * 0.066f, 0.94f, 0.80f);
                drawScreensaverBrushTip(flare, minDim, hot, cyan, alpha * 0.55f);
            } else {
                float side = mystifyPhraseHash(gesture, phrase, 13117) < 0.5f ? -1f : 1f;
                ArrayList<float[]> inner = offsetCurveByNormal(curve, side * minDim * 0.010f);
                ArrayList<float[]> outer = offsetCurveByNormal(curve, side * minDim * (0.055f + 0.050f * mystifyPhraseHash(gesture, phrase, 13119)));
                drawRuledSurfaceAgeFaded(inner, outer, hot[0], hot[1], hot[2], alpha * 0.032f, 0.90f);
            }
        }

        private float mystifyImprovisationPulse(float time, int gesture, float seed) {
            float a = 0.5f + 0.5f * (float)Math.sin(time * 0.074f + seed + stableHash01(gesture, 12651) * 6.2831853f);
            float b = 0.5f + 0.5f * (float)Math.sin(time * 0.139f + seed * 0.73f + stableHash01(gesture, 12657) * 6.2831853f);
            float c = 0.5f + 0.5f * (float)Math.sin(time * 0.035f + seed * 1.21f + stableHash01(gesture, 12659) * 6.2831853f);
            return smoother(clamp(a * 0.50f + b * 0.34f + c * 0.16f, 0f, 1f));
        }

        private float mystifyBounce(float x) {
            x = fract(x);
            return x < 0.5f ? x * 2f : (1f - x) * 2f;
        }

        private float[] mystifySourceCenter(ArrayList<float[]> stroke) {
            if (stroke == null || stroke.isEmpty()) return new float[]{width * 0.5f, height * 0.45f};
            float sx = 0f, sy = 0f;
            for (float[] p : stroke) {
                sx += p[0];
                sy += p[1];
            }
            float n = Math.max(1f, stroke.size());
            return new float[]{sx / n, sy / n};
        }

        private float[] mystifySourceAxis(ArrayList<float[]> stroke) {
            if (stroke == null || stroke.size() < 2) return new float[]{1f, 0f};
            float[] a = stroke.get(0);
            float[] b = stroke.get(stroke.size() - 1);
            float dx = b[0] - a[0];
            float dy = b[1] - a[1];
            float len = (float)Math.sqrt(dx * dx + dy * dy);
            if (len < 0.001f) return new float[]{1f, 0f};
            return new float[]{dx / len, dy / len};
        }

        private float[] mystifyPaletteFromHue(float hue, float[] mid, float[] cyan, float[] hot, float remain, boolean brightCore) {
            // 正弦色轮比固定青色更接近 Windows7 Mystify 的颜色循环，但保持冷色主导，避免桌面过花。
            float h = hue * 6.2831853f;
            float cr = 0.10f + 0.34f * (0.5f + 0.5f * (float)Math.sin(h + 0.20f));
            float cg = 0.42f + 0.42f * (0.5f + 0.5f * (float)Math.sin(h + 2.10f));
            float cb = 0.70f + 0.28f * (0.5f + 0.5f * (float)Math.sin(h + 4.10f));
            cr = lerp(cr, cyan[0], 0.34f + 0.22f * remain);
            cg = lerp(cg, cyan[1], 0.28f + 0.20f * remain);
            cb = lerp(cb, cyan[2], 0.18f + 0.18f * remain);
            if (brightCore) {
                cr = lerp(cr, 0.98f, 0.62f);
                cg = lerp(cg, 1.00f, 0.56f);
                cb = lerp(cb, 1.00f, 0.50f);
            }
            return new float[]{cr, cg, cb};
        }

        private float[] sampleSourceStrokeByU(ArrayList<float[]> stroke, float u) {
            int last = Math.max(0, stroke.size() - 1);
            float pos = clamp(u, 0f, 1f) * last;
            int i0 = clampInt((int)Math.floor(pos), 0, last);
            int i1 = clampInt(i0 + 1, 0, last);
            float f = pos - i0;
            float[] a = stroke.get(i0);
            float[] b = stroke.get(i1);
            return new float[]{lerp(a[0], b[0], f), lerp(a[1], b[1], f)};
        }

        private float[] catmullRomPoint(float[] p0, float[] p1, float[] p2, float[] p3, float t) {
            float t2 = t * t;
            float t3 = t2 * t;
            float x = 0.5f * ((2f * p1[0]) + (-p0[0] + p2[0]) * t +
                    (2f * p0[0] - 5f * p1[0] + 4f * p2[0] - p3[0]) * t2 +
                    (-p0[0] + 3f * p1[0] - 3f * p2[0] + p3[0]) * t3);
            float y = 0.5f * ((2f * p1[1]) + (-p0[1] + p2[1]) * t +
                    (2f * p0[1] - 5f * p1[1] + 4f * p2[1] - p3[1]) * t2 +
                    (-p0[1] + 3f * p1[1] - 3f * p2[1] + p3[1]) * t3);
            return new float[]{x, y};
        }

        private ArrayList<float[]> offsetCurveByNormal(ArrayList<float[]> curve, float amount) {
            ArrayList<float[]> out = new ArrayList<>(curve.size());
            int n = curve.size();
            for (int i = 0; i < n; i++) {
                float[] prev = curve.get(Math.max(0, i - 1));
                float[] next = curve.get(Math.min(n - 1, i + 1));
                float dx = next[0] - prev[0];
                float dy = next[1] - prev[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float u = i / Math.max(1f, n - 1f);
                float envelope = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.62f);
                out.add(new float[]{curve.get(i)[0] + nx * amount * envelope, curve.get(i)[1] + ny * amount * envelope});
            }
            return out;
        }

        private void drawScreensaverBrushTip(ArrayList<float[]> curve, float minDim, float[] hot, float[] cyan, float alpha) {
            if (curve.size() < 2) return;
            float[] p = curve.get(curve.size() - 1);
            float[] q = curve.get(Math.max(0, curve.size() - 4));
            float ang = (float)Math.atan2(p[1] - q[1], p[0] - q[0]);
            drawEllipse(p[0], p[1], Math.max(2.0f, minDim * 0.0065f), Math.max(0.9f, minDim * 0.0032f), ang, hot[0], hot[1], hot[2], alpha * 0.135f, 18);
            drawEllipse(p[0], p[1], Math.max(4.2f, minDim * 0.0145f), Math.max(2.2f, minDim * 0.0072f), ang, cyan[0], cyan[1], cyan[2], alpha * 0.105f, 18);
        }

        private int improvisedArtistBrushStyle(int gesture) {
            float r = fract(gesture * 0.6180339887f + stableHash01(gesture, 11041) * 0.41f + stableHash01(gesture / 2, 11059) * 0.27f);
            if (r < 0.30f) return 0; // 丝带主导
            if (r < 0.56f) return 1; // 花瓣薄幕
            if (r < 0.76f) return 2; // 网纱生长
            return 3;                // 书写流翼
        }

        private ArrayList<float[]> buildImprovisedArtistSpine(ArrayList<float[]> stroke, int samples, int gesture) {
            samples = Math.max(10, samples);
            ArrayList<float[]> out = new ArrayList<>(samples);
            float maxIdx = Math.max(0, stroke.size() - 1);
            for (int i = 0; i < samples; i++) {
                float u = i / Math.max(1f, samples - 1f);
                float remap = artistStrokeRemap(u, gesture);
                float pos = maxIdx * remap;
                float[] prev = sampleStrokePoint(stroke, Math.max(0f, pos - 0.9f));
                float[] cur = sampleStrokePoint(stroke, pos);
                float[] next = sampleStrokePoint(stroke, Math.min(maxIdx, pos + 0.9f));
                float cadence = artistStrokeCadence(u, gesture);
                float lead = minDimSafe() * 0.0001f; // tiny scale anchor for consistent motion feeling
                float x = prev[0] * 0.16f + cur[0] * 0.56f + next[0] * 0.28f + (next[0] - prev[0]) * 0.08f * cadence + lead * 0f;
                float y = prev[1] * 0.16f + cur[1] * 0.56f + next[1] * 0.28f + (next[1] - prev[1]) * 0.08f * cadence;
                out.add(new float[]{x, y});
            }
            return out;
        }

        private float[] sampleStrokePoint(ArrayList<float[]> stroke, float pos) {
            int last = Math.max(0, stroke.size() - 1);
            pos = clamp(pos, 0f, last);
            int i0 = clampInt((int)Math.floor(pos), 0, last);
            int i1 = clampInt(i0 + 1, 0, last);
            float f = pos - i0;
            float[] a = stroke.get(i0);
            float[] b = stroke.get(i1);
            return new float[]{lerp(a[0], b[0], f), lerp(a[1], b[1], f)};
        }

        private float artistStrokeRemap(float u, int gesture) {
            float ease = smoother(u);
            float settle = smoother(clamp((u - 0.03f) / 0.94f, 0f, 1f));
            float shaped = lerp(u, lerp(ease, settle, 0.30f), 0.58f);
            float breath = 0.010f * (float)Math.sin(stableHash01(gesture, 11211) * 6.2831853f + u * 3.1f) * waveEnvelope(u);
            return clamp(shaped + breath, 0f, 1f);
        }

        private float artistStrokePressure(float u, int gesture, float bias) {
            float attack = smoother(clamp(u / 0.16f, 0f, 1f));
            float release = smoother(clamp((1f - u) / 0.22f, 0f, 1f));
            float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * clamp(u, 0f, 1f))), 0.42f);
            float pulse = 0.90f + 0.16f * (float)Math.sin(stableHash01(gesture, 11219) * 6.2831853f + u * 5.8f + bias * 2.6f);
            return Math.max(0.08f, (0.22f + 0.78f * body) * (0.74f + 0.26f * attack) * (0.82f + 0.18f * release) * pulse);
        }

        private float artistStrokeCadence(float u, int gesture) {
            float phrase = 0.5f + 0.5f * (float)Math.sin(stableHash01(gesture, 11237) * 6.2831853f + u * 4.4f + 0.6f);
            float gate = smoother(clamp((u - 0.08f) / 0.84f, 0f, 1f));
            return gate * phrase;
        }

        private float artistStrokeFlourish(float u, int gesture, float phase) {
            return (float)Math.sin(stableHash01(gesture, 11257) * 6.2831853f + u * 6.8f + phase) * waveEnvelope(u);
        }

        private float minDimSafe() {
            return Math.max(1f, Math.min(width, height));
        }

        private void drawArtistBrushEssence(ArrayList<float[]> spine, float minDim, float[] cyan, float[] hot, float alpha) {
            int n = spine.size();
            if (n < 4 || alpha <= 0.001f) return;
            ArrayList<float[]> trunk = new ArrayList<>();
            ArrayList<float[]> tip = new ArrayList<>();
            int trunkEnd = Math.max(2, (int)(n * 0.42f));
            int tipStart = Math.max(0, n - Math.max(3, (int)(n * 0.22f)));
            for (int i = 0; i < trunkEnd; i++) trunk.add(spine.get(i));
            for (int i = tipStart; i < n; i++) tip.add(spine.get(i));
            drawAgeFadedStrip(trunk, Math.max(0.12f, minDim * 0.0011f), hot[0], hot[1], hot[2], alpha * 0.026f, 0.78f, 0.26f);
            drawAgeFadedStrip(tip, Math.max(0.12f, minDim * 0.0011f), 0.99f, 1.00f, 1.00f, alpha * 0.220f, 0.88f, 1.00f);
        }

        private void drawArtistRibbonSweep(ArrayList<float[]> spine, int gesture, float minDim,
                                           float seedA, float seedB, float[] mid, float[] cyan, float[] hot, float alpha) {
            float side = stableHash01(gesture, 11101) < 0.5f ? -1f : 1f;
            ArrayList<float[]> inner = new ArrayList<>();
            ArrayList<float[]> outer = new ArrayList<>();
            int n = spine.size();
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float[] pPrev = spine.get(Math.max(0, i - 1));
                float[] pNext = spine.get(Math.min(n - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float tx = dx / dl, ty = dy / dl;
                float nx = -ty * side, ny = tx * side;
                float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.58f);
                float pressure = artistStrokePressure(u, gesture, 0.12f);
                float cadence = artistStrokeCadence(u, gesture);
                float flourish = artistStrokeFlourish(u, gesture, 0.0f);
                float swell = smoother(clamp((u - 0.10f) / 0.72f, 0f, 1f));
                float wOuter = minDim * (0.007f + 0.100f * body * swell * pressure);
                float wInner = minDim * (0.0012f + 0.016f * body * (0.80f + 0.20f * cadence));
                float sweep = minDim * (0.006f + 0.030f * body * pressure) * (0.16f + 0.84f * u);
                float counter = minDim * 0.010f * flourish * body;
                outer.add(new float[]{spine.get(i)[0] + nx * (wOuter + counter) + tx * (sweep + minDim * 0.014f * cadence * body), spine.get(i)[1] + ny * (wOuter + counter) + ty * (sweep + minDim * 0.014f * cadence * body)});
                inner.add(new float[]{spine.get(i)[0] - nx * wInner - tx * minDim * 0.003f * cadence, spine.get(i)[1] - ny * wInner - ty * minDim * 0.003f * cadence});
            }
            drawRuledSurfaceAgeFaded(inner, outer, hot[0], hot[1], hot[2], alpha * 0.094f, 0.92f);
            drawAgeFadedStrip(spine, Math.max(0.22f, minDim * 0.0021f), cyan[0], cyan[1], cyan[2], alpha * 0.185f, 0.84f, 0.60f);
            drawAgeFadedStrip(spine, Math.max(0.10f, minDim * 0.0010f), 0.98f, 0.99f, 1.00f, alpha * 0.090f, 0.88f, 0.84f);
            drawAgeFadedStrip(outer, Math.max(0.14f, minDim * 0.0013f), hot[0], hot[1], hot[2], alpha * 0.050f, 0.86f, 0.54f);
            drawArtistBrushEssence(spine, minDim, cyan, hot, alpha);
        }

        private void drawArtistPetalVeil(ArrayList<float[]> spine, int gesture, float minDim,
                                         float seedA, float seedB, float[] mid, float[] cyan, float[] hot, float alpha) {
            float side = stableHash01(gesture, 11131) < 0.5f ? -1f : 1f;
            ArrayList<float[]> veilA = new ArrayList<>();
            ArrayList<float[]> veilB = new ArrayList<>();
            int n = spine.size();
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float[] pPrev = spine.get(Math.max(0, i - 1));
                float[] pNext = spine.get(Math.min(n - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float tx = dx / dl, ty = dy / dl;
                float nx = -ty * side, ny = tx * side;
                float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.54f);
                float pressure = artistStrokePressure(u, gesture, 0.28f);
                float cadence = artistStrokeCadence(u, gesture);
                float flourish = artistStrokeFlourish(u, gesture, 1.2f);
                float open = smoother(clamp((u - 0.06f) / 0.76f, 0f, 1f));
                float wave = (float)Math.sin(seedB + u * 4.6f);
                float wA = minDim * (0.005f + 0.082f * body * open * pressure);
                float wB = minDim * (0.002f + 0.040f * body * open * (0.76f + 0.24f * cadence));
                float drag = minDim * (0.012f + 0.050f * body * pressure) * (0.18f + 0.82f * u);
                veilA.add(new float[]{spine.get(i)[0] + nx * (wA + minDim * 0.006f * flourish * body) + tx * (drag + minDim * 0.012f * cadence * body), spine.get(i)[1] + ny * (wA + minDim * 0.006f * flourish * body) + ty * (drag + minDim * 0.012f * cadence * body)});
                veilB.add(new float[]{spine.get(i)[0] + nx * wB * (0.56f + 0.16f * wave), spine.get(i)[1] + ny * wB * (0.56f + 0.16f * wave)});
            }
            drawRuledSurfaceAgeFaded(veilB, veilA, hot[0], hot[1], hot[2], alpha * 0.086f, 0.90f);
            drawAgeFadedStrip(spine, Math.max(0.18f, minDim * 0.0016f), cyan[0], cyan[1], cyan[2], alpha * 0.048f, 0.84f, 0.58f);
            drawAgeFadedStrip(veilA, Math.max(0.10f, minDim * 0.0010f), 0.98f, 0.99f, 1.00f, alpha * 0.064f, 0.88f, 0.70f);
            drawArtistBrushEssence(spine, minDim, cyan, hot, alpha);
        }

        private void drawArtistMeshBloom(ArrayList<float[]> spine, int gesture, float minDim,
                                         float seedA, float seedB, float[] mid, float[] cyan, float[] hot, float alpha) {
            float side = stableHash01(gesture, 11161) < 0.5f ? -1f : 1f;
            ArrayList<float[]> inner = new ArrayList<>();
            ArrayList<float[]> outer = new ArrayList<>();
            int n = spine.size();
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float[] pPrev = spine.get(Math.max(0, i - 1));
                float[] pNext = spine.get(Math.min(n - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float tx = dx / dl, ty = dy / dl;
                float nx = -ty * side, ny = tx * side;
                float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.70f);
                float pressure = artistStrokePressure(u, gesture, 0.44f);
                float cadence = artistStrokeCadence(u, gesture);
                float flourish = artistStrokeFlourish(u, gesture, 2.1f);
                float grow = smoother(clamp((u - 0.08f) / 0.70f, 0f, 1f));
                float wIn = minDim * (0.004f + 0.030f * body * grow * (0.80f + 0.20f * cadence));
                float wOut = minDim * (0.014f + 0.090f * body * grow * pressure);
                float drag = minDim * (0.010f + 0.034f * body * pressure) * (0.10f + 0.90f * u);
                inner.add(new float[]{spine.get(i)[0] + nx * wIn, spine.get(i)[1] + ny * wIn});
                outer.add(new float[]{spine.get(i)[0] + nx * (wOut + minDim * 0.006f * flourish * body) + tx * (drag + minDim * 0.012f * cadence * body), spine.get(i)[1] + ny * (wOut + minDim * 0.006f * flourish * body) + ty * (drag + minDim * 0.012f * cadence * body)});
            }
            drawRuledSurfaceAgeFaded(inner, outer, mid[0], mid[1], mid[2], alpha * 0.056f, 0.88f);
            int ribStep = cfg.powerSave ? 4 : 3;
            for (int i = 1; i < n - 1; i += ribStep) {
                ArrayList<float[]> rib = new ArrayList<>();
                rib.add(spine.get(i));
                rib.add(new float[]{lerp(inner.get(i)[0], outer.get(i)[0], 0.52f), lerp(inner.get(i)[1], outer.get(i)[1], 0.52f)});
                rib.add(outer.get(i));
                drawAgeFadedStrip(rib, Math.max(0.08f, minDim * 0.0008f), cyan[0], cyan[1], cyan[2], alpha * 0.105f, 0.86f, 0.38f);
            }
            drawAgeFadedStrip(spine, Math.max(0.18f, minDim * 0.0015f), hot[0], hot[1], hot[2], alpha * 0.050f, 0.84f, 0.62f);
            drawAgeFadedStrip(outer, Math.max(0.10f, minDim * 0.0009f), 0.96f, 0.99f, 1.00f, alpha * 0.160f, 0.86f, 0.46f);
            drawArtistBrushEssence(spine, minDim, cyan, hot, alpha);
        }

        private void drawArtistCalligraphicWing(ArrayList<float[]> spine, int gesture, float minDim,
                                                float seedA, float seedB, float[] mid, float[] cyan, float[] hot, float alpha) {
            float majorSide = stableHash01(gesture, 11191) < 0.5f ? -1f : 1f;
            ArrayList<float[]> left = new ArrayList<>();
            ArrayList<float[]> right = new ArrayList<>();
            int n = spine.size();
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float[] pPrev = spine.get(Math.max(0, i - 1));
                float[] pNext = spine.get(Math.min(n - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float tx = dx / dl, ty = dy / dl;
                float nx = -ty, ny = dx;
                float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.60f);
                float pressure = artistStrokePressure(u, gesture, 0.66f);
                float cadence = artistStrokeCadence(u, gesture);
                float flourish = artistStrokeFlourish(u, gesture, 3.2f);
                float wing = smoother(clamp((u - 0.10f) / 0.72f, 0f, 1f));
                float wMajor = minDim * (0.012f + 0.100f * body * wing * pressure);
                float wMinor = minDim * (0.0022f + 0.022f * body * (0.78f + 0.22f * cadence));
                float sweep = minDim * (0.010f + 0.030f * body * pressure) * (0.18f + 0.82f * u);
                left.add(new float[]{spine.get(i)[0] + nx * (wMajor + minDim * 0.006f * flourish * body) * majorSide + tx * (sweep + minDim * 0.014f * cadence * body), spine.get(i)[1] + ny * (wMajor + minDim * 0.006f * flourish * body) * majorSide + ty * (sweep + minDim * 0.014f * cadence * body)});
                right.add(new float[]{spine.get(i)[0] - nx * wMinor * majorSide - tx * minDim * 0.003f * cadence, spine.get(i)[1] - ny * wMinor * majorSide - ty * minDim * 0.003f * cadence});
            }
            drawRuledSurfaceAgeFaded(right, left, hot[0], hot[1], hot[2], alpha * 0.090f, 0.92f);
            drawAgeFadedStrip(spine, Math.max(0.20f, minDim * 0.0019f), cyan[0], cyan[1], cyan[2], alpha * 0.050f, 0.84f, 0.60f);
            drawAgeFadedStrip(spine, Math.max(0.10f, minDim * 0.00095f), 0.98f, 0.99f, 1.00f, alpha * 0.086f, 0.88f, 0.84f);
            drawAgeFadedStrip(left, Math.max(0.12f, minDim * 0.0010f), hot[0], hot[1], hot[2], alpha * 0.048f, 0.86f, 0.54f);
            drawArtistBrushEssence(spine, minDim, cyan, hot, alpha);
        }

        private void drawFieldFanStyle(ArrayList<float[]> stroke, int gesture, float raw,
                                       float minDim, float drawSec, float seedA, float seedB, float seedC,
                                       float[] mid, float[] cyan, float[] hot, float alpha) {
            int n = stroke.size();
            float[] pStart = stroke.get(0);
            float[] pMid = stroke.get(n / 2);
            float[] pEnd = stroke.get(n - 1);
            float tx = pEnd[0] - pStart[0];
            float ty = pEnd[1] - pStart[1];
            float tLen = (float)Math.sqrt(tx * tx + ty * ty);
            if (tLen < 0.001f) { tx = 1f; ty = 0f; tLen = 1f; }
            tx /= tLen; ty /= tLen;
            float nx = -ty, ny = tx;
            float side = stableHash01(gesture, 9721) < 0.5f ? -1f : 1f;
            float fanFlip = stableHash01(gesture, 9733) < 0.5f ? -1f : 1f;
            float bodyOpen = smoother(clamp((raw - 0.05f) / 0.32f, 0f, 1f));
            float lateFold = 1f - 0.18f * smoother(clamp((raw - 0.76f) / 0.16f, 0f, 1f));
            float[] neckBase = stroke.get(clampInt((int)(n * 0.68f), 0, n - 1));
            float nexusX = lerp(pMid[0], pEnd[0], 0.58f) + nx * minDim * 0.010f * side;
            float nexusY = lerp(pMid[1], pEnd[1], 0.58f) + ny * minDim * 0.010f * side;
            nexusX = lerp(nexusX, neckBase[0], 0.25f);
            nexusY = lerp(nexusY, neckBase[1], 0.25f);
            float fanDirX = -tx * (0.92f + 0.16f * stableHash01(gesture, 9741)) + nx * side * (0.22f + 0.18f * fanFlip);
            float fanDirY = -ty * (0.92f + 0.16f * stableHash01(gesture, 9741)) + ny * side * (0.22f + 0.18f * fanFlip);
            float fdLen = (float)Math.sqrt(fanDirX * fanDirX + fanDirY * fanDirY);
            if (fdLen < 0.001f) fdLen = 1f;
            fanDirX /= fdLen; fanDirY /= fdLen;
            float fanNormX = -fanDirY, fanNormY = fanDirX;
            float fanLen = minDim * (0.68f + 0.30f * stableHash01(gesture, 9749)) * (0.78f + 0.30f * bodyOpen);
            float fanSpread = minDim * (0.34f + 0.22f * stableHash01(gesture, 9757)) * bodyOpen * lateFold;
            float curvature = 0.24f + 0.22f * stableHash01(gesture, 9769);
            int lineCount = cfg.powerSave ? 18 : 32;
            int samples = cfg.powerSave ? 24 : 42;
            for (int l = 0; l < lineCount; l++) {
                float q = lineCount <= 1 ? 0.5f : l / (lineCount - 1f);
                float centered = (q - 0.5f) * 2f;
                float arcWeight = (float)Math.pow(Math.max(0f, 1f - Math.abs(centered) * 0.22f), 1.3f);
                float spread = centered * fanSpread * (0.82f + 0.18f * (float)Math.sin(seedA + l * 0.73f));
                float length = fanLen * (0.78f + 0.28f * (1f - Math.abs(centered))) *
                        (0.94f + 0.10f * (float)Math.sin(seedB + l * 0.51f));
                float farX = nexusX + fanDirX * length + fanNormX * spread;
                float farY = nexusY + fanDirY * length + fanNormY * spread;
                float ctrlX = nexusX + fanDirX * length * (0.42f + 0.10f * centered) +
                        fanNormX * spread * (0.34f + curvature) + tx * minDim * 0.05f * side;
                float ctrlY = nexusY + fanDirY * length * (0.42f + 0.10f * centered) +
                        fanNormY * spread * (0.34f + curvature) + ty * minDim * 0.05f * side;
                ArrayList<float[]> line = buildQuadraticCurve(farX, farY, ctrlX, ctrlY, nexusX, nexusY, samples);
                float edgeBoost = 1f - Math.abs(centered);
                float a = alpha * (0.022f + 0.052f * arcWeight + 0.020f * Math.max(0f, edgeBoost));
                float width = Math.max(0.12f, minDim * (0.00095f + 0.00055f * edgeBoost));
                drawAgeFadedStrip(line, width, cyan[0], cyan[1], cyan[2], a, 0.72f, 0.45f);
            }
            int innerCount = cfg.powerSave ? 6 : 10;
            for (int l = 0; l < innerCount; l++) {
                float q = innerCount <= 1 ? 0.5f : l / (innerCount - 1f);
                float centered = (q - 0.5f) * 2f;
                float spread = centered * fanSpread * 0.48f;
                float length = fanLen * (0.44f + 0.22f * (1f - Math.abs(centered)));
                float farX = nexusX + fanDirX * length + fanNormX * spread;
                float farY = nexusY + fanDirY * length + fanNormY * spread;
                float ctrlX = nexusX + fanDirX * length * 0.46f + fanNormX * spread * 0.72f;
                float ctrlY = nexusY + fanDirY * length * 0.46f + fanNormY * spread * 0.72f;
                ArrayList<float[]> line = buildQuadraticCurve(farX, farY, ctrlX, ctrlY, nexusX, nexusY, samples);
                drawAgeFadedStrip(line, Math.max(0.16f, minDim * 0.00145f), hot[0], hot[1], hot[2], alpha * 0.060f, 0.78f, 0.70f);
            }
            ArrayList<float[]> neck = new ArrayList<>();
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                if (u < 0.38f) continue;
                float[] p = stroke.get(i);
                float pull = smoother(clamp((u - 0.38f) / 0.62f, 0f, 1f));
                neck.add(new float[]{lerp(p[0], nexusX, pull * 0.26f), lerp(p[1], nexusY, pull * 0.26f)});
            }
            if (neck.size() > 2) {
                drawAgeFadedStrip(neck, Math.max(0.34f, minDim * 0.0036f), hot[0], hot[1], hot[2], alpha * 0.140f, 0.74f, 0.70f);
                drawAgeFadedStrip(neck, Math.max(0.80f, minDim * 0.0075f), cyan[0], cyan[1], cyan[2], alpha * 0.145f, 0.70f, 0.35f);
            }
            drawEllipse(nexusX, nexusY, Math.max(2.8f, minDim * 0.0105f), Math.max(1.8f, minDim * 0.0060f), seedA + drawSec * 0.12f, hot[0], hot[1], hot[2], alpha * 0.180f, 28);
            drawEllipse(nexusX, nexusY, Math.max(5.6f, minDim * 0.0220f), Math.max(3.8f, minDim * 0.0140f), seedA + drawSec * 0.12f, cyan[0], cyan[1], cyan[2], alpha * 0.120f, 28);
        }

        private void drawOrbitMeshStyle(ArrayList<float[]> stroke, int gesture, float raw,
                                        float minDim, float drawSec, float seedA, float seedB, float seedC,
                                        float[] mid, float[] cyan, float[] hot, float alpha) {
            int n = stroke.size();
            float[] a = stroke.get(0), b = stroke.get(n - 1), m = stroke.get(n / 2);
            float cx = lerp(a[0], b[0], 0.50f);
            float cy = lerp(a[1], b[1], 0.50f);
            float tx = b[0] - a[0], ty = b[1] - a[1];
            float len = (float)Math.sqrt(tx * tx + ty * ty);
            if (len < 0.001f) { tx = 1f; ty = 0f; len = 1f; }
            tx /= len; ty /= len;
            float nx = -ty, ny = tx;
            float radius = minDim * (0.24f + 0.10f * stableHash01(gesture, 9811));
            float span = 2.20f + 0.70f * stableHash01(gesture, 9823);
            int ribs = cfg.powerSave ? 12 : 20;
            int samples = cfg.powerSave ? 24 : 38;
            for (int i = 0; i < ribs; i++) {
                float q = i / Math.max(1f, ribs - 1f);
                float skew = (q - 0.5f) * 2f;
                float innerR = radius * (0.36f + 0.12f * q);
                float outerR = radius * (0.84f + 0.28f * q);
                float startAng = seedA + 1.05f + skew * 0.66f;
                float endAng = startAng + span * (0.84f + 0.20f * (1f - Math.abs(skew)));
                ArrayList<float[]> inner = new ArrayList<>();
                ArrayList<float[]> outer = new ArrayList<>();
                for (int s = 0; s < samples; s++) {
                    float u = s / Math.max(1f, samples - 1f);
                    float ang = lerp(startAng, endAng, u);
                    float wave = (float)Math.sin(seedB + q * 4.4f + u * 4.6f);
                    float ix = cx + tx * (float)Math.cos(ang) * innerR + nx * (float)Math.sin(ang) * innerR * (0.84f + 0.08f * wave);
                    float iy = cy + ty * (float)Math.cos(ang) * innerR + ny * (float)Math.sin(ang) * innerR * (0.84f + 0.08f * wave);
                    float ox = cx + tx * (float)Math.cos(ang) * outerR + nx * (float)Math.sin(ang) * outerR * (0.96f + 0.08f * wave);
                    float oy = cy + ty * (float)Math.cos(ang) * outerR + ny * (float)Math.sin(ang) * outerR * (0.96f + 0.08f * wave);
                    inner.add(new float[]{ix, iy});
                    outer.add(new float[]{ox, oy});
                }
                float aMesh = alpha * (0.012f + 0.018f * (1f - Math.abs(skew)));
                drawRuledSurfaceAgeFaded(inner, outer, mid[0], mid[1], mid[2], aMesh, 0.88f);
                drawAgeFadedStrip(outer, Math.max(0.12f, minDim * 0.0010f), cyan[0], cyan[1], cyan[2], alpha * 0.020f, 0.82f, 0.38f);
            }
            ArrayList<float[]> spark = buildQuadraticCurve(m[0], m[1], cx + nx * radius * 0.16f, cy + ny * radius * 0.16f, cx + tx * radius * 0.12f, cy + ty * radius * 0.12f, cfg.powerSave ? 14 : 22);
            drawAgeFadedStrip(spark, Math.max(0.18f, minDim * 0.0021f), hot[0], hot[1], hot[2], alpha * 0.085f, 0.84f, 0.70f);
        }

        private void drawBladeRibbonStyle(ArrayList<float[]> stroke, int gesture, float raw,
                                          float minDim, float drawSec, float seedA, float seedB, float seedC,
                                          float[] mid, float[] cyan, float[] hot, float alpha) {
            int n = stroke.size();
            float[] a = stroke.get(0), b = stroke.get(n - 1), m = stroke.get(n / 2);
            float ctrl1x = lerp(a[0], m[0], 0.55f) + stableSigned(gesture, 9841) * minDim * 0.10f;
            float ctrl1y = lerp(a[1], m[1], 0.55f) + stableSigned(gesture, 9847) * minDim * 0.10f;
            float ctrl2x = lerp(m[0], b[0], 0.55f) + stableSigned(gesture, 9853) * minDim * 0.16f;
            float ctrl2y = lerp(m[1], b[1], 0.55f) + stableSigned(gesture, 9859) * minDim * 0.16f;
            ArrayList<float[]> center = buildCubicCurve(a[0], a[1], ctrl1x, ctrl1y, ctrl2x, ctrl2y, b[0], b[1], cfg.powerSave ? 24 : 40);
            ArrayList<float[]> left = new ArrayList<>();
            ArrayList<float[]> right = new ArrayList<>();
            int csz = center.size();
            for (int i = 0; i < csz; i++) {
                float u = i / Math.max(1f, csz - 1f);
                float[] pPrev = center.get(Math.max(0, i - 1));
                float[] pNext = center.get(Math.min(csz - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float nx = -dy / dl, ny = dx / dl;
                float taper = (0.10f + 0.90f * (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.62f));
                float width = minDim * (0.012f + 0.086f * taper) * (0.74f + 0.30f * smoother(clamp((u - 0.24f) / 0.60f, 0f, 1f)));
                left.add(new float[]{center.get(i)[0] + nx * width, center.get(i)[1] + ny * width});
                right.add(new float[]{center.get(i)[0] - nx * width * (0.10f + 0.12f * u), center.get(i)[1] - ny * width * (0.10f + 0.12f * u)});
            }
            drawRuledSurfaceAgeFaded(right, left, hot[0], hot[1], hot[2], alpha * 0.090f, 0.92f);
            drawAgeFadedStrip(center, Math.max(0.42f, minDim * 0.0042f), cyan[0], cyan[1], cyan[2], alpha * 0.042f, 0.80f, 0.55f);
            drawAgeFadedStrip(center, Math.max(0.12f, minDim * 0.0013f), 0.98f, 0.99f, 1.00f, alpha * 0.072f, 0.84f, 0.68f);
            drawAgeFadedStrip(left, Math.max(0.16f, minDim * 0.0015f), hot[0], hot[1], hot[2], alpha * 0.060f, 0.88f, 0.60f);
        }

        private void drawNeedleSweepStyle(ArrayList<float[]> stroke, int gesture, float raw,
                                          float minDim, float drawSec, float seedA, float seedB, float seedC,
                                          float[] mid, float[] cyan, float[] hot, float alpha) {
            int n = stroke.size();
            float[] a = stroke.get(0), b = stroke.get(n - 1), m = stroke.get(n / 2);
            float hookX = lerp(a[0], b[0], 0.68f) + stableSigned(gesture, 9871) * minDim * 0.08f;
            float hookY = lerp(a[1], b[1], 0.68f) + stableSigned(gesture, 9877) * minDim * 0.08f;
            ArrayList<float[]> line = buildQuadraticCurve(a[0], a[1], hookX, hookY, b[0], b[1], cfg.powerSave ? 22 : 36);
            ArrayList<float[]> veil = new ArrayList<>();
            int ln = line.size();
            for (int i = 0; i < ln; i++) {
                float u = i / Math.max(1f, ln - 1f);
                float[] pPrev = line.get(Math.max(0, i - 1));
                float[] pNext = line.get(Math.min(ln - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float nx = -dy / dl, ny = dx / dl;
                float width = minDim * (0.004f + 0.032f * smoother(clamp((u - 0.12f) / 0.62f, 0f, 1f)) * (1f - 0.58f * u));
                veil.add(new float[]{line.get(i)[0] + nx * width, line.get(i)[1] + ny * width});
            }
            drawRuledSurfaceAgeFaded(line, veil, hot[0], hot[1], hot[2], alpha * 0.220f, 0.90f);
            drawAgeFadedStrip(line, Math.max(0.24f, minDim * 0.0024f), cyan[0], cyan[1], cyan[2], alpha * 0.185f, 0.82f, 0.55f);
            drawAgeFadedStrip(line, Math.max(0.10f, minDim * 0.0011f), 0.98f, 0.99f, 1.00f, alpha * 0.085f, 0.86f, 0.82f);
            float[] tip = line.get(line.size() - 1);
            ArrayList<float[]> flare = buildQuadraticCurve(tip[0] - (tip[0] - m[0]) * 0.16f, tip[1] - (tip[1] - m[1]) * 0.16f,
                    tip[0] + stableSigned(gesture, 9883) * minDim * 0.10f, tip[1] + stableSigned(gesture, 9889) * minDim * 0.10f,
                    tip[0] + stableSigned(gesture, 9899) * minDim * 0.18f, tip[1] + stableSigned(gesture, 9907) * minDim * 0.18f,
                    cfg.powerSave ? 12 : 18);
            drawAgeFadedStrip(flare, Math.max(0.10f, minDim * 0.0009f), mid[0], mid[1], mid[2], alpha * 0.145f, 0.80f, 0.16f);
        }

        private void drawHookBloomStyle(ArrayList<float[]> stroke, int gesture, float raw,
                                        float minDim, float drawSec, float seedA, float seedB, float seedC,
                                        float[] mid, float[] cyan, float[] hot, float alpha) {
            int n = stroke.size();
            float[] a = stroke.get(0), b = stroke.get(n - 1), m = stroke.get(n / 2);
            float rootX = lerp(a[0], m[0], 0.74f);
            float rootY = lerp(a[1], m[1], 0.74f);
            float tipX = b[0], tipY = b[1];
            float ctrlX = lerp(rootX, tipX, 0.36f) + stableSigned(gesture, 9919) * minDim * 0.14f;
            float ctrlY = lerp(rootY, tipY, 0.36f) + stableSigned(gesture, 9923) * minDim * 0.14f;
            ArrayList<float[]> stem = buildQuadraticCurve(rootX, rootY, ctrlX, ctrlY, tipX, tipY, cfg.powerSave ? 20 : 36);
            ArrayList<float[]> petalA = new ArrayList<>();
            ArrayList<float[]> petalB = new ArrayList<>();
            int sn = stem.size();
            for (int i = 0; i < sn; i++) {
                float u = i / Math.max(1f, sn - 1f);
                float[] pPrev = stem.get(Math.max(0, i - 1));
                float[] pNext = stem.get(Math.min(sn - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float nx = -dy / dl, ny = dx / dl;
                float bloom = smoother(clamp((u - 0.24f) / 0.56f, 0f, 1f));
                float width = minDim * (0.004f + 0.046f * bloom * (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.55f));
                petalA.add(new float[]{stem.get(i)[0] + nx * width, stem.get(i)[1] + ny * width});
                petalB.add(new float[]{stem.get(i)[0] - nx * width * (0.16f + 0.84f * u), stem.get(i)[1] - ny * width * (0.16f + 0.84f * u)});
            }
            drawRuledSurfaceAgeFaded(petalB, petalA, hot[0], hot[1], hot[2], alpha * 0.082f, 0.92f);
            drawAgeFadedStrip(stem, Math.max(0.16f, minDim * 0.0014f), cyan[0], cyan[1], cyan[2], alpha * 0.050f, 0.84f, 0.60f);
            drawAgeFadedStrip(petalA, Math.max(0.10f, minDim * 0.0010f), 0.98f, 0.99f, 1.00f, alpha * 0.060f, 0.88f, 0.56f);
            drawEllipse(tipX, tipY, Math.max(2.0f, minDim * 0.0065f), Math.max(1.1f, minDim * 0.0035f), seedA, hot[0], hot[1], hot[2], alpha * 0.12f, 18);
        }

        private void drawWingRibbonStyle(ArrayList<float[]> stroke, int gesture, float raw,
                                         float minDim, float drawSec, float seedA, float seedB, float seedC,
                                         float[] mid, float[] cyan, float[] hot, float alpha) {
            int n = stroke.size();
            float[] a = stroke.get(0), b = stroke.get(n - 1), m = stroke.get(n / 2);
            float ctrl1x = lerp(a[0], m[0], 0.42f) + stableSigned(gesture, 9931) * minDim * 0.12f;
            float ctrl1y = lerp(a[1], m[1], 0.42f) + stableSigned(gesture, 9937) * minDim * 0.16f;
            float ctrl2x = lerp(m[0], b[0], 0.36f) + stableSigned(gesture, 9943) * minDim * 0.20f;
            float ctrl2y = lerp(m[1], b[1], 0.36f) + stableSigned(gesture, 9949) * minDim * 0.20f;
            ArrayList<float[]> spine = buildCubicCurve(a[0], a[1], ctrl1x, ctrl1y, ctrl2x, ctrl2y, b[0], b[1], cfg.powerSave ? 22 : 38);
            ArrayList<float[]> outer = new ArrayList<>();
            int sn = spine.size();
            for (int i = 0; i < sn; i++) {
                float u = i / Math.max(1f, sn - 1f);
                float[] pPrev = spine.get(Math.max(0, i - 1));
                float[] pNext = spine.get(Math.min(sn - 1, i + 1));
                float dx = pNext[0] - pPrev[0], dy = pNext[1] - pPrev[1];
                float dl = (float)Math.sqrt(dx * dx + dy * dy); if (dl < 0.001f) dl = 1f;
                float nx = -dy / dl, ny = dx / dl;
                float width = minDim * (0.020f + 0.076f * smoother(clamp((u - 0.18f) / 0.60f, 0f, 1f)) * (1f - 0.72f * u));
                outer.add(new float[]{spine.get(i)[0] + nx * width, spine.get(i)[1] + ny * width});
            }
            drawRuledSurfaceAgeFaded(spine, outer, mid[0], mid[1], mid[2], alpha * 0.072f, 0.86f);
            drawAgeFadedStrip(spine, Math.max(0.30f, minDim * 0.0032f), hot[0], hot[1], hot[2], alpha * 0.060f, 0.80f, 0.55f);
            drawAgeFadedStrip(spine, Math.max(0.11f, minDim * 0.0011f), 0.98f, 0.99f, 1.00f, alpha * 0.220f, 0.86f, 0.70f);
            drawAgeFadedStrip(outer, Math.max(0.16f, minDim * 0.0014f), cyan[0], cyan[1], cyan[2], alpha * 0.145f, 0.82f, 0.42f);
        }

        private ArrayList<float[]> buildQuadraticCurve(float x0, float y0, float x1, float y1, float x2, float y2, int samples) {
            samples = Math.max(2, samples);
            ArrayList<float[]> out = new ArrayList<>(samples);
            for (int i = 0; i < samples; i++) {
                float u = i / Math.max(1f, samples - 1f);
                float one = 1f - u;
                out.add(new float[]{one * one * x0 + 2f * one * u * x1 + u * u * x2,
                        one * one * y0 + 2f * one * u * y1 + u * u * y2});
            }
            return out;
        }

        private ArrayList<float[]> buildCubicCurve(float x0, float y0, float x1, float y1, float x2, float y2, float x3, float y3, int samples) {
            samples = Math.max(2, samples);
            ArrayList<float[]> out = new ArrayList<>(samples);
            for (int i = 0; i < samples; i++) {
                float u = i / Math.max(1f, samples - 1f);
                float one = 1f - u;
                out.add(new float[]{
                        one * one * one * x0 + 3f * one * one * u * x1 + 3f * one * u * u * x2 + u * u * u * x3,
                        one * one * one * y0 + 3f * one * one * u * y1 + 3f * one * u * u * y2 + u * u * u * y3});
            }
            return out;
        }

        private int continuousPenArtStyleForGesture(int gesture) {
            int style = continuousPenArtStyleBase(gesture);
            int prev = gesture > 0 ? continuousPenArtStyleBase(gesture - 1) : -1;
            if (style == prev && (style == 1 || style == 3)) {
                style = (style + 1) % 6;
            }
            return style;
        }

        private int continuousPenArtStyleBase(int gesture) {
            float r = fract(gesture * 0.6180339887f + stableHash01(gesture / 2, 9959) * 0.44f + stableHash01(gesture, 9967) * 0.31f);
            if (r < 0.18f) return 0; // 扇形场线
            if (r < 0.30f) return 1; // 环绕网纱（降低频率）
            if (r < 0.56f) return 2; // 刀锋丝带（提高频率）
            if (r < 0.66f) return 3; // 针形光翼（降低频率）
            if (r < 0.82f) return 4; // 钩月花瓣
            return 5;                // 长弧流翼
        }

private float waveEnvelope(float u) {
            return (float)Math.pow(Math.max(0f, Math.sin(Math.PI * clamp(u, 0f, 1f))), 0.78f);
        }
private int continuousPenMotifForGesture(int gesture) {
            int motif = continuousPenMotifRaw(gesture);
            int prev = gesture > 0 ? continuousPenMotifRaw(gesture - 1) : -1;
            if (motif == prev || continuousPenShapeFamily(motif) == continuousPenShapeFamily(prev)) {
                motif = continuousPenMotifRaw(gesture + 7);
            }
            int prev2 = gesture > 1 ? continuousPenMotifRaw(gesture - 2) : -1;
            if (motif == prev2) {
                motif = continuousPenMotifRaw(gesture + 13);
            }
            return motif;
        }

        private int continuousPenShapeFamily(int motif) {
            if (motif == 14 || motif == 17) return 1; // 光幕 / 彗尾
            if (motif == 15 || motif == 23) return 2; // 冠瓣 / 新月瓣
            if (motif == 22 || motif == 12) return 3; // 大翼 / 展片
            if (motif == 13 || motif == 10) return 4; // 少量柔书写残留
            return 5;
        }

        private int continuousPenMotifRaw(int gesture) {
            // V111：方向 B 进一步偏向“流动光雕”，主打膜面、翼面、光幕与月瓣感。
            final int[] palette = new int[]{14, 15, 22, 23, 17, 12, 15, 22, 14, 23, 17, 22, 15, 12, 14, 23};
            float golden = fract(gesture * 0.6180339887f + stableHash01(gesture / 10, 8921) * 0.61f + stableHash01(gesture, 8927) * 0.16f);
            int idx = clampInt((int)Math.floor(golden * palette.length), 0, palette.length - 1);
            return palette[idx];
        }

        private float silkPenProgress(float raw) {
            raw = clamp(raw, 0f, 1f);
            // 保持端点准确，但不在端点刹停；同一只笔会以连续速度进入下一段。
            return clamp(raw + 0.026f * (float)Math.sin(2f * Math.PI * raw), 0f, 1f);
        }

        private float[][] continuousPenPalette(float hueDriver) {
            float t = clamp(hueDriver, 0f, 1f);
            float[][] p;
            switch (Math.floorMod(cfg.style, 5)) {
                case 1:
                    p = new float[][]{
                            {0.008f, 0.050f + 0.050f * t, 0.26f + 0.26f * t},
                            {0.020f, 0.34f + 0.18f * t, 0.78f + 0.12f * t},
                            {0.18f + 0.10f * t, 0.82f, 0.98f},
                            {0.74f + 0.12f * t, 0.96f, 1.00f}
                    };
                    break;
                case 2:
                    p = new float[][]{
                            {0.050f, 0.025f, 0.24f + 0.22f * t},
                            {0.34f + 0.16f * t, 0.26f + 0.08f * t, 0.82f + 0.08f * t},
                            {0.82f, 0.58f + 0.18f * t, 0.98f},
                            {0.96f, 0.90f, 1.00f}
                    };
                    break;
                case 3:
                    p = new float[][]{
                            {0.06f + 0.06f * t, 0.12f + 0.06f * t, 0.18f + 0.14f * t},
                            {0.46f + 0.16f * t, 0.60f + 0.12f * t, 0.84f + 0.08f * t},
                            {0.80f + 0.06f * t, 0.92f, 0.99f},
                            {0.98f, 1.00f, 0.98f}
                    };
                    break;
                case 4:
                    p = new float[][]{
                            {0.03f, 0.10f + 0.06f * t, 0.20f + 0.20f * t},
                            {0.12f + 0.10f * t, 0.52f + 0.12f * t, 0.74f + 0.10f * t},
                            {0.34f + 0.10f * t, 0.90f, 0.86f + 0.06f * t},
                            {0.84f, 0.98f, 0.94f + 0.04f * t}
                    };
                    break;
                default:
                    p = new float[][]{
                            {0.010f, 0.050f + 0.07f * t, 0.28f + 0.24f * t},
                            {0.030f + 0.04f * t, 0.36f + 0.18f * t, 0.82f + 0.10f * t},
                            {0.16f + 0.12f * t, 0.84f + 0.06f * (1f - t), 0.98f},
                            {0.78f + 0.10f * t, 0.98f, 1.00f}
                    };
                    break;
            }
            return p;
        }

        private float continuousPenMotifVariant(int motif) {
            return stableHash01(motif, 9517) * 2f - 1f;
        }

        private float[] wallpaperViewportProfile(float w, float h, float padX, float padTop, float padBottom) {
            // V115：超大主体需要更大的桌面舞台，但仍保留底部 Dock / 图标安全感。
            float aspect = h / Math.max(1f, w);
            float portraitBias = clamp((aspect - 1.55f) / 0.80f, 0f, 1f);
            float leftInset = Math.max(w * 0.014f, lerp(w * 0.020f, w * 0.038f, portraitBias));
            float topInset = Math.max(h * 0.020f, lerp(h * 0.026f, h * 0.044f, portraitBias));
            float bottomInset = Math.max(h * 0.090f, lerp(h * 0.102f, h * 0.140f, portraitBias));
            if (enginePreview) {
                leftInset *= 0.70f;
                topInset *= 0.74f;
                bottomInset *= 0.76f;
            }
            float safeLeft = leftInset;
            float safeRight = w - leftInset;
            float safeTop = topInset;
            float safeBottom = h - bottomInset;
            if (safeRight <= safeLeft) {
                safeLeft = w * 0.045f;
                safeRight = w * 0.955f;
            }
            if (safeBottom <= safeTop) {
                safeTop = h * 0.045f;
                safeBottom = h * 0.90f;
            }
            float xShift = enginePreview ? 0f : (wallpaperXOffset - 0.5f) * w * 0.16f;
            float yShift = enginePreview ? 0f : (wallpaperYOffset - 0.5f) * h * 0.06f;
            float focusX = clamp(w * 0.50f + xShift,
                    safeLeft + (safeRight - safeLeft) * 0.09f,
                    safeRight - (safeRight - safeLeft) * 0.09f);
            float focusY = clamp(lerp(h * 0.49f, h * 0.395f, portraitBias) + yShift,
                    safeTop + (safeBottom - safeTop) * 0.10f,
                    safeBottom - (safeBottom - safeTop) * 0.135f);
            return new float[]{safeLeft, safeRight, safeTop, safeBottom, focusX, focusY};
        }

        private float[] continuousPenLocalByFamily(int motif, float side, float scale, float u,
                                                    float body, float bodySoft, float bodyFine,
                                                    float wave, float swing, float edge,
                                                    float seedA, float seedB, float seedC) {
            int family = continuousPenShapeFamily(motif);
            float variant = continuousPenMotifVariant(motif);
            float xBias = 0f;
            float driftX = 0f;
            float yLocal = 0f;
            switch (family) {
                case 1: // 光幕 / 彗尾
                    yLocal = side * scale * ((0.14f + 0.03f * variant) * wave + (0.62f + 0.08f * variant) * u) * bodySoft;
                    driftX = scale * (0.12f + 0.04f * Math.abs(variant)) * (float)Math.sin(Math.PI * u + seedC) * body;
                    xBias = -0.06f * smoother(clamp((u - 0.52f) / 0.34f, 0f, 1f));
                    break;
                case 2: // 冠瓣 / 新月瓣
                    yLocal = side * scale * ((0.52f + 0.10f * variant) * wave + 0.12f * (float)Math.sin(6f * Math.PI * u + seedC)) * bodySoft;
                    driftX = scale * (0.05f + 0.04f * Math.abs(variant)) * (float)Math.sin(3.5f * Math.PI * u + seedA) * body;
                    xBias = 0.03f * (u - 0.44f) * body;
                    break;
                case 3: // 大翼 / 展片
                    yLocal = side * scale * ((0.64f + 0.10f * variant) * swing + 0.15f * (float)Math.sin(4f * Math.PI * u + seedA)) * bodySoft;
                    driftX = scale * (0.16f + 0.04f * Math.abs(variant)) * wave * (float)Math.sin(2f * Math.PI * u + seedB) * edge;
                    break;
                case 4: // 少量柔书写残留
                    yLocal = side * scale * (0.24f * swing + (0.16f + 0.06f * variant) * (float)Math.sin(3f * Math.PI * u + seedB)
                            + 0.08f * (float)Math.sin(5f * Math.PI * u + seedC)) * bodySoft;
                    driftX = scale * (0.04f + 0.04f * Math.abs(variant)) * (float)Math.sin(2f * Math.PI * u + seedA) * body;
                    break;
                default:
                    yLocal = side * scale * (0.30f * swing + 0.10f * (float)Math.sin(4f * Math.PI * u + seedA)) * bodySoft;
                    driftX = scale * 0.05f * (float)Math.sin(3f * Math.PI * u + seedB) * bodyFine;
                    break;
            }
            return new float[]{xBias, driftX, yLocal};
        }

        private float continuousPenAdaptiveScale(int gesture, int motif,
                                                 float safeLeft, float safeRight, float safeTop, float safeBottom,
                                                 float minDim) {
            // V115：进一步提高主体占屏比例，同时保留上限以避免完全失控裁切。
            float usableW = Math.max(1f, safeRight - safeLeft);
            float usableH = Math.max(1f, safeBottom - safeTop);
            float aspect = usableH / Math.max(1f, usableW);
            float portraitBias = clamp((aspect - 1.00f) / 1.22f, 0f, 1f);
            float base = minDim * (0.305f + 0.190f * stableHash01(gesture, 9449));
            float widthFit = usableW * lerp(0.80f, 0.98f, portraitBias);
            float heightFit = usableH * lerp(0.50f, 0.72f, portraitBias);
            float fit = Math.min(widthFit, heightFit);
            float motifBias = continuousPenShapeFamily(motif) <= 3 ? 1.12f : 1.04f;
            float scale = lerp(base, fit, 0.96f) * motifBias;
            float minScale = minDim * 0.30f;
            float maxScale = Math.min(usableW * 1.02f, usableH * 0.78f);
            return clamp(scale, minScale, Math.max(minScale, maxScale));
        }

        private float[] continuousPenAnchor(int gesture,
                                            float safeLeft, float safeRight, float safeTop, float safeBottom,
                                            float focusX, float focusY, float scale, float angle) {
            // V115：超大主体的锚点必须更靠近中心焦点，否则大尺度下容易严重裁切。
            float gx = 0.24f + 0.52f * stableHash01(gesture, 9411);
            float gy = 0.22f + 0.56f * stableHash01(gesture, 9419);
            float ax = Math.abs((float)Math.cos(angle));
            float ay = Math.abs((float)Math.sin(angle));
            float marginX = scale * (0.30f + 0.09f * ax + 0.10f * ay);
            float marginY = scale * (0.34f + 0.09f * ay + 0.12f * ax);
            float focusSpanX = (safeRight - safeLeft) * 0.98f;
            float focusSpanY = (safeBottom - safeTop) * 0.92f;
            float left = Math.max(safeLeft, focusX - focusSpanX * 0.5f) + marginX;
            float right = Math.min(safeRight, focusX + focusSpanX * 0.5f) - marginX;
            float top = Math.max(safeTop, focusY - focusSpanY * 0.5f) + marginY;
            float bottom = Math.min(safeBottom, focusY + focusSpanY * 0.5f) - marginY;
            if (right <= left) {
                left = lerp(safeLeft, focusX, 0.18f);
                right = lerp(safeRight, focusX, 0.18f);
            }
            if (bottom <= top) {
                top = lerp(safeTop, focusY, 0.18f);
                bottom = lerp(safeBottom, focusY, 0.18f);
            }
            float x = lerp(left, right, clamp(gx, 0f, 1f));
            float y = lerp(top, bottom, clamp(gy, 0f, 1f));
            return new float[]{x, y};
        }

        private float[] continuousPenPoint(int gesture, int motifA, int motifB, float motifMix, float formOpen, float u,
                                           float w, float h, float safeLeft, float safeRight, float safeTop, float safeBottom,
                                           float focusX, float focusY, float minDim, float drawSec, float seedA, float seedB, float seedC) {
            u = clamp(u, 0f, 1f);
            motifMix = clamp(motifMix, 0f, 1f);
            formOpen = clamp(formOpen, 0f, 1.2f);
            float angle = stableHash01(gesture, 9443) * 6.2831853f;
            float ex = (float)Math.cos(angle);
            float ey = (float)Math.sin(angle);
            float nx = -ey;
            float ny = ex;
            int dominantMotif = motifMix < 0.5f ? motifA : motifB;
            float scale = continuousPenAdaptiveScale(gesture, dominantMotif, safeLeft, safeRight, safeTop, safeBottom, minDim);
            float[] anchor = continuousPenAnchor(gesture, safeLeft, safeRight, safeTop, safeBottom, focusX, focusY, scale, angle);
            float side = stableHash01(gesture, 8861) < 0.5f ? -1f : 1f;
            float wave = (float)Math.sin(Math.PI * u);
            float swing = (float)Math.sin(2f * Math.PI * u);
            float edge = smoother(clamp(Math.min(u, 1f - u) / 0.16f, 0f, 1f));
            float body = wave * edge;
            float bodySoft = (float)Math.pow(Math.max(0f, body), 0.72f);
            float bodyFine = body * body;
            float xLocal = scale * (-0.51f + 1.04f * u);

            float[] localA = continuousPenLocalByFamily(motifA, side, scale, u, body, bodySoft, bodyFine, wave, swing, edge, seedA, seedB, seedC);
            float[] localB = continuousPenLocalByFamily(motifB, side, scale, u, body, bodySoft, bodyFine, wave, swing, edge, seedA + 0.37f, seedB + 0.23f, seedC + 0.19f);
            float xBias = lerp(localA[0], localB[0], motifMix);
            float driftX = lerp(localA[1], localB[1], motifMix);
            float yLocal = lerp(localA[2], localB[2], motifMix) * formOpen;

            float sentenceLift = smoother(clamp((u - 0.18f) / 0.54f, 0f, 1f));
            float settle = 1f - 0.12f * smoother(clamp((u - 0.84f) / 0.12f, 0f, 1f));
            yLocal *= (0.94f + 0.16f * sentenceLift) * settle;
            xLocal += scale * xBias;

            float breath = minDim * (0.0022f + 0.0030f * cfg.randomness) * (float)Math.sin(drawSec * (0.22f + 0.08f * cfg.randomness) + seedA + u * 2.0f) * bodySoft;
            float flutter = minDim * 0.0006f * (float)Math.sin(drawSec * 0.62f + seedB + u * 5.8f) * bodyFine;
            float x = anchor[0] + ex * (xLocal + driftX + flutter) + nx * (yLocal + breath);
            float y = anchor[1] + ey * (xLocal + driftX + flutter) + ny * (yLocal + breath);
            float edgeInsetX = Math.max((safeRight - safeLeft) * 0.008f, minDim * 0.006f);
            float edgeInsetY = Math.max((safeBottom - safeTop) * 0.010f, minDim * 0.007f);
            x = clamp(x, safeLeft + edgeInsetX, safeRight - edgeInsetX);
            y = clamp(y, safeTop + edgeInsetY, safeBottom - edgeInsetY);
            return new float[]{x, y};
        }

private ArrayList<float[]> slicePoints(ArrayList<float[]> pts, int start, int end) {
            ArrayList<float[]> out = new ArrayList<>();
            int n = pts.size();
            if (n <= 0) return out;
            start = clampInt(start, 0, n - 1);
            end = clampInt(end, 0, n - 1);
            if (end < start) return out;
            for (int i = start; i <= end; i++) out.add(pts.get(i));
            return out;
        }

        private void drawRuledSurfaceSegment(ArrayList<float[]> inner, ArrayList<float[]> outer, int start, int end,
                                             float r, float g, float b, float a) {
            if (inner.size() < 2 || outer.size() < 2 || a <= 0.001f) return;
            int n = Math.min(inner.size(), outer.size());
            start = clampInt(start, 0, n - 2);
            end = clampInt(end, start + 1, n - 1);
            float[] verts = new float[(end - start + 1) * 2 * 2];
            int vi = 0;
            for (int i = start; i <= end; i++) {
                float[] p0 = inner.get(i);
                float[] p1 = outer.get(i);
                putNdc(verts, vi, p0[0], p0[1]); vi += 2;
                putNdc(verts, vi, p1[0], p1[1]); vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_STRIP, r, g, b, a);
        }

        private void drawRuledSurfaceAgeFaded(ArrayList<float[]> inner, ArrayList<float[]> outer,
                                              float r, float g, float b, float baseA, float tailPower) {
            if (inner.size() < 3 || outer.size() < 3 || baseA <= 0.001f) return;
            int n = Math.min(inner.size(), outer.size());
            int slices = cfg.powerSave ? 10 : 18;
            for (int s = 0; s < slices; s++) {
                int start = clampInt((int)Math.floor(s * (n - 1f) / slices), 0, n - 2);
                int end = clampInt((int)Math.ceil((s + 1f) * (n - 1f) / slices), start + 1, n - 1);
                float u = ((start + end) * 0.5f) / Math.max(1f, n - 1f);
                float age = (float)Math.pow(clamp(u, 0f, 1f), tailPower);
                float wet = 1f + 0.22f * smoother(clamp((u - 0.82f) / 0.18f, 0f, 1f));
                float vanish = 1f - 0.28f * smoother(clamp((u - 0.965f) / 0.035f, 0f, 1f));
                float a = baseA * (0.09f + 0.91f * age) * wet * vanish;
                drawRuledSurfaceSegment(inner, outer, start, end, r, g, b, a);
            }
        }

        private void drawAgeFadedStrip(ArrayList<float[]> pts, float widthPx, float r, float g, float b,
                                       float baseA, float tailPower, float tipBoost) {
            if (pts.size() < 2 || baseA <= 0.001f || widthPx <= 0.04f) return;
            int n = pts.size();
            for (int i = 1; i < n; i++) {
                float u = (i - 0.5f) / Math.max(1f, n - 1f);
                float age = (float)Math.pow(clamp(u, 0f, 1f), tailPower);
                float midProfile = 0.42f + 0.58f * (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.25f);
                float head = 1f + tipBoost * smoother(clamp((u - 0.82f) / 0.18f, 0f, 1f));
                float a = baseA * (0.10f + 0.90f * age) * midProfile * head;
                ArrayList<float[]> seg = new ArrayList<>(2);
                seg.add(pts.get(i - 1));
                seg.add(pts.get(i));
                drawStrip(seg, widthPx * midProfile * head, r, g, b, a);
            }
        }
private static float smoother(float x) {
            x = clamp(x, 0f, 1f);
            return x * x * x * (x * (x * 6f - 15f) + 10f);
        }

        private static float stableHash01(int seed, int salt) {
            int x = seed * 0x45d9f3b + salt * 0x27d4eb2d;
            x ^= (x >>> 16);
            x *= 0x7feb352d;
            x ^= (x >>> 15);
            x *= 0x846ca68b;
            x ^= (x >>> 16);
            return (x & 0x7fffffff) / 2147483647f;
        }

        private static float stableSigned(int seed, int salt) {
            return stableHash01(seed, salt) * 2f - 1f;
        }


        private void drawObservedMembranePiece(float cx, float cy, float span, float rot, float sideSign, float openScale,
                                               float bodyR, float bodyG, float bodyB, float edgeR, float edgeG, float edgeB,
                                               float alpha, float sec, boolean drawStem, float ribScale) {
            int n = cfg.powerSave ? 34 : 52;
            float minDim = Math.max(1f, Math.min(width, height));
            float tx0 = (float)Math.cos(rot);
            float ty0 = (float)Math.sin(rot);
            float nx0 = -ty0;
            float ny0 = tx0;
            float curlSign = sideSign < 0f ? -1f : 1f;
            float flutter = 0.5f + 0.5f * (float)Math.sin(sec * 0.73f + span * 0.0021f);

            ArrayList<float[]> ridge = new ArrayList<>(n);
            ArrayList<float[]> outer = new ArrayList<>(n);
            ArrayList<float[]> outerGlow = new ArrayList<>(n);
            ArrayList<float[]> inner = new ArrayList<>(n);
            ArrayList<float[]> foldLine = new ArrayList<>(n);

            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float su = smooth(u);
                float hook = (float)Math.pow(clamp((su - 0.62f) / 0.38f, 0f, 1f), 1.72f);
                float shoulder = (float)Math.pow(Math.max(0f, 1f - su), 1.35f);
                float bend = span * curlSign * ((float)Math.sin(su * Math.PI) * (0.105f + 0.030f * openScale)
                        - hook * (0.085f + 0.045f * openScale)
                        + shoulder * 0.025f);
                float micro = span * 0.010f * (float)Math.sin(su * Math.PI * 2.4f + sec * 0.46f) * (float)Math.sin(su * Math.PI);
                float x = cx + tx0 * span * (su - 0.52f) + nx0 * (bend + micro);
                float y = cy + ty0 * span * (su - 0.52f) + ny0 * (bend + micro);

                float open = smooth(clamp(su / 0.10f, 0f, 1f));
                float close = 1f - smooth(clamp((su - 0.84f) / 0.16f, 0f, 1f));
                float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * su)), 0.52f);
                float shoulderWeight = 0.55f + 0.58f * (1f - smooth(clamp((su - 0.50f) / 0.42f, 0f, 1f)));
                float profile = clamp(open * close * body * shoulderWeight, 0f, 1f);
                float widthProfile = span * (0.030f + 0.185f * openScale) * profile;
                float shear = span * profile * (0.040f * (1f - su) - 0.030f * su) * (0.65f + 0.35f * flutter);

                float foldOffset = widthProfile * (0.055f + 0.035f * (float)Math.sin(su * Math.PI));
                ridge.add(new float[]{x - nx0 * sideSign * foldOffset, y - ny0 * sideSign * foldOffset});
                inner.add(new float[]{x + nx0 * sideSign * widthProfile * 0.34f + tx0 * shear * 0.36f,
                                      y + ny0 * sideSign * widthProfile * 0.34f + ty0 * shear * 0.36f});
                outer.add(new float[]{x + nx0 * sideSign * widthProfile + tx0 * shear,
                                      y + ny0 * sideSign * widthProfile + ty0 * shear});
                outerGlow.add(new float[]{x + nx0 * sideSign * widthProfile * 1.16f + tx0 * shear * 1.08f,
                                          y + ny0 * sideSign * widthProfile * 1.16f + ty0 * shear * 1.08f});
                foldLine.add(new float[]{x + nx0 * sideSign * widthProfile * (0.090f + 0.055f * (float)Math.sin(su * Math.PI)) + tx0 * shear * 0.16f,
                                         y + ny0 * sideSign * widthProfile * (0.090f + 0.055f * (float)Math.sin(su * Math.PI)) + ty0 * shear * 0.16f});
            }

            // 极暗半透明主体，靠外缘和轮廓显形；绝不生成宽白带。
            drawRuledSurface(ridge, outerGlow, bodyR, bodyG, bodyB, alpha * 0.010f);
            drawRuledSurface(ridge, outer, bodyR, bodyG, bodyB, alpha * 0.026f);
            drawRuledSurface(ridge, inner, edgeR, edgeG, edgeB, alpha * 0.014f);

            // 贴面等高线：沿膜面方向走的细密肋纹，替代旧版横向放射肋。
            int contours = cfg.powerSave ? 14 : Math.max(18, (int)(30f * ribScale));
            for (int j = 1; j <= contours; j++) {
                float f = j / (float)(contours + 1);
                if (f < 0.08f || f > 0.94f) continue;
                ArrayList<float[]> line = new ArrayList<>(n);
                float lineWave = 0.012f * (float)Math.sin(sec * 0.91f + j * 0.73f);
                for (int i = 0; i < n; i++) {
                    float u = i / Math.max(1f, n - 1f);
                    float localF = clamp(f + lineWave * (float)Math.sin(u * Math.PI), 0.02f, 0.98f);
                    float[] a = ridge.get(i);
                    float[] b = outer.get(i);
                    line.add(new float[]{lerp(a[0], b[0], localF), lerp(a[1], b[1], localF)});
                }
                float taper = 0.45f + 0.55f * (float)Math.sin(f * Math.PI);
                float rr = lerp(bodyR, edgeR, f);
                float gg = lerp(bodyG, edgeG, f);
                float bb = lerp(bodyB, edgeB, f);
                drawTaperedStrip(line, Math.max(0.035f, minDim * 0.00042f), rr, gg, bb, alpha * 0.0065f * taper);
            }

            // 外缘和折脊是视频主体的“形体边界”，但只画成冷色细线/窄亮边。
            drawTaperedStrip(outer, Math.max(0.28f, minDim * 0.00125f), edgeR, edgeG, edgeB, alpha * 0.105f);
            drawTaperedStrip(foldLine, Math.max(0.20f, minDim * 0.00082f), 0.55f, 1.00f, 0.78f, alpha * 0.185f);
            drawTaperedStrip(ridge, Math.max(0.16f, minDim * 0.00055f), bodyR, bodyG, bodyB, alpha * 0.038f);

            int start = Math.max(0, (int)(n * 0.80f));
            ArrayList<float[]> tip = new ArrayList<>(n - start);
            for (int i = start; i < n; i++) tip.add(outer.get(i));
            drawTaperedStrip(tip, Math.max(0.20f, minDim * 0.0010f), 0.70f, 1.00f, 0.88f, alpha * 0.115f);

            if (drawStem) {
                float[] base = ridge.get(Math.max(0, (int)(n * 0.82f)));
                ArrayList<float[]> stem = new ArrayList<>(9);
                for (int k = 0; k < 9; k++) {
                    float v = k / 8f;
                    float drop = span * (0.05f + 0.28f * v);
                    float side = span * sideSign * (0.018f * (float)Math.sin(v * Math.PI * 1.2f + sec * 0.40f) - 0.030f * v);
                    stem.add(new float[]{base[0] + ty0 * drop + nx0 * side, base[1] - tx0 * drop + ny0 * side});
                }
                drawTaperedStrip(stem, Math.max(0.42f, minDim * 0.0022f), 0.06f, 0.98f, 0.75f, alpha * 0.105f);
                drawTaperedStrip(stem, Math.max(0.18f, minDim * 0.0008f), 0.72f, 1.00f, 0.92f, alpha * 0.150f);
            }
        }

        private void drawObservedHairline(float cx, float cy, float span, float rot, float sideSign,
                                          float r, float g, float b, float alpha, float sec) {
            int n = cfg.powerSave ? 12 : 18;
            ArrayList<float[]> pts = new ArrayList<>(n);
            float tx = (float)Math.cos(rot);
            float ty = (float)Math.sin(rot);
            float nx = -ty;
            float ny = tx;
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float bend = sideSign * span * (0.10f * (float)Math.sin(u * Math.PI) - 0.055f * u * u);
                float wob = span * 0.010f * (float)Math.sin(sec * 0.66f + u * 5.2f);
                pts.add(new float[]{cx + tx * span * (u - 0.5f) + nx * (bend + wob),
                                    cy + ty * span * (u - 0.5f) + ny * (bend + wob)});
            }
            float minDim = Math.max(1f, Math.min(width, height));
            drawTaperedStrip(pts, Math.max(0.16f, minDim * 0.00075f), r, g, b, alpha);
        }

        private void drawVideoSilkBladeSubject(StrokeEvent s, ArrayList<float[]> pts, Phase phase, float baseWidth,
                                               float r, float g, float b, float alpha,
                                               float intensity, float tension, float release, boolean headLayer) {
            if (pts.size() < 4 || alpha <= 0.004f) return;
            int n = pts.size();
            float sideSign = s.asymmetry < 0f ? -1f : 1f;
            float minDim = Math.max(1f, Math.min(width, height));
            boolean subjectPhase = !phase.name.equals("释放") && !phase.name.equals("余韵");
            float phaseWide = phase.name.equals("分离") ? 0.56f
                    : (phase.name.equals("吸引") ? 0.70f
                    : (phase.name.equals("同步") ? 0.92f
                    : (phase.name.equals("临界") ? 1.08f : 0.82f)));
            float motifScale = s.motif == 15 ? 1.00f : (s.motif == 13 ? 0.74f : 0.58f);

            // 颜色按视频主体限定：绿/青/紫为主；暖色只做极细早期折线，不再出现黄色宽带。
            float cr, cg, cb, ar, ag, ab;
            if (phase.name.equals("同步")) { cr = 0.50f; cg = 0.10f; cb = 1.00f; ar = 0.16f; ag = 0.95f; ab = 0.48f; }
            else if (phase.name.equals("临界")) { cr = 0.08f; cg = 0.96f; cb = 0.26f; ar = 0.10f; ag = 0.96f; ab = 0.82f; }
            else if (phase.name.equals("吸引")) { cr = 0.10f; cg = 0.86f; cb = 0.34f; ar = 0.64f; ag = 0.13f; ab = 0.96f; }
            else if (phase.name.equals("分离")) { cr = 0.10f; cg = 0.80f; cb = 0.36f; ar = 0.90f; ag = 0.18f; ab = 0.36f; }
            else {
                int hue = Math.floorMod(s.variant, 4);
                if (hue == 0) { cr = 0.08f; cg = 0.96f; cb = 0.30f; ar = 0.60f; ag = 0.15f; ab = 1.00f; }
                else if (hue == 1) { cr = 0.12f; cg = 0.88f; cb = 0.45f; ar = 0.82f; ag = 0.12f; ab = 1.00f; }
                else if (hue == 2) { cr = 0.08f; cg = 0.82f; cb = 0.95f; ar = 0.22f; ag = 1.00f; ab = 0.50f; }
                else { cr = 0.55f; cg = 0.12f; cb = 1.00f; ar = 0.18f; ag = 0.95f; ab = 0.40f; }
            }

            // 真实视频观感：薄膜比截图中的彩带窄得多，亮度也低；形体靠轮廓和贴面肋纹显形。
            float sail = minDim * (0.048f + 0.046f * phaseWide) * motifScale * (0.92f + s.motifStrength * 0.10f);
            float fold = Math.max(0.22f, baseWidth * 0.10f);
            float layerScale = headLayer ? 1.0f : (subjectPhase ? 0.10f : 0.24f);

            ArrayList<float[]> ridge = new ArrayList<>(n);
            ArrayList<float[]> inner = new ArrayList<>(n);
            ArrayList<float[]> outer = new ArrayList<>(n);
            ArrayList<float[]> outerSoft = new ArrayList<>(n);
            ArrayList<float[]> caustic = new ArrayList<>(n);
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, n - 1f);
                float[] prev = pts.get(Math.max(0, i - 1));
                float[] next = pts.get(Math.min(n - 1, i + 1));
                float dx = next[0] - prev[0];
                float dy = next[1] - prev[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001f) len = 1f;
                float tx = dx / len;
                float ty = dy / len;
                float nx = -dy / len;
                float ny = dx / len;

                // 宽肩在前半段，尖端快速收束；这是视频“叶片/蝠翼/丝绸折片”的核心轮廓。
                float open = smooth(clamp(u / 0.12f, 0f, 1f));
                float body = (float)Math.pow(Math.max(0f, Math.sin(Math.PI * u)), 0.58f);
                float tipClose = 1f - smooth(clamp((u - 0.74f) / 0.26f, 0f, 1f)) * 0.985f;
                float shoulderBias = 0.62f + 0.38f * (float)Math.pow(Math.max(0f, 1f - u), 0.55f);
                float profile = clamp(open * body * tipClose * shoulderBias, 0f, 1f);
                float notch = (float)Math.sin(u * Math.PI * 2.15f + s.seed * 0.55f) * sail * 0.012f * profile;
                float shear = sail * profile * (0.10f * (1f - u) * (1f - u) - 0.045f * u * (1f - u));
                float x = pts.get(i)[0];
                float y = pts.get(i)[1];

                ridge.add(new float[]{x - nx * sideSign * fold * (0.10f + 0.18f * profile) + tx * notch * 0.10f,
                                      y - ny * sideSign * fold * (0.10f + 0.18f * profile) + ty * notch * 0.10f});
                inner.add(new float[]{x + nx * sideSign * sail * profile * 0.32f + tx * (shear * 0.38f + notch * 0.32f),
                                      y + ny * sideSign * sail * profile * 0.32f + ty * (shear * 0.38f + notch * 0.32f)});
                outer.add(new float[]{x + nx * sideSign * sail * profile + tx * (shear + notch),
                                      y + ny * sideSign * sail * profile + ty * (shear + notch)});
                outerSoft.add(new float[]{x + nx * sideSign * sail * profile * 1.12f + tx * (shear * 1.10f + notch * 1.18f),
                                          y + ny * sideSign * sail * profile * 1.12f + ty * (shear * 1.10f + notch * 1.18f)});
                caustic.add(new float[]{x + nx * sideSign * sail * profile * (0.055f + 0.040f * (float)Math.sin(u * Math.PI)) + tx * notch * 0.18f,
                                        y + ny * sideSign * sail * profile * (0.055f + 0.040f * (float)Math.sin(u * Math.PI)) + ty * notch * 0.18f});
            }

            drawRuledSurface(ridge, outerSoft, cr, cg, cb, alpha * layerScale * (subjectPhase ? 0.0045f : 0.009f));
            drawRuledSurface(ridge, outer, cr, cg, cb, alpha * layerScale * (subjectPhase ? 0.014f : 0.026f));
            drawRuledSurface(ridge, inner, ar, ag, ab, alpha * layerScale * (subjectPhase ? 0.0045f : 0.008f));

            if (!headLayer) {
                drawTaperedStrip(ridge, Math.max(0.05f, baseWidth * 0.006f), ar, ag, ab, alpha * 0.0025f);
                drawTaperedStrip(outer, Math.max(0.06f, baseWidth * 0.008f), cr, cg, cb, alpha * 0.006f);
                return;
            }

            // 贴面细肋：由外缘收束到折脊，不能沿中心线铺成另一条宽带。
            int ribs = phase.name.equals("临界") ? 44 : (phase.name.equals("同步") ? 34 : 24);
            if (cfg.powerSave) ribs = Math.min(ribs, 24);
            for (int j = 1; j <= ribs; j++) {
                float u = j / (float)(ribs + 1);
                if (u < 0.10f || u > 0.88f) continue;
                float pos = u * (n - 1);
                int i0 = clampInt((int)Math.floor(pos), 0, n - 1);
                int i1 = clampInt(i0 + 1, 0, n - 1);
                float f = pos - i0;
                float[] a = new float[]{lerp(outerSoft.get(i0)[0], outerSoft.get(i1)[0], f), lerp(outerSoft.get(i0)[1], outerSoft.get(i1)[1], f)};
                float[] cpt = new float[]{lerp(caustic.get(i0)[0], caustic.get(i1)[0], f), lerp(caustic.get(i0)[1], caustic.get(i1)[1], f)};
                float[] lpt = new float[]{lerp(ridge.get(i0)[0], ridge.get(i1)[0], f), lerp(ridge.get(i0)[1], ridge.get(i1)[1], f)};
                ArrayList<float[]> rib = new ArrayList<>(3);
                rib.add(a);
                rib.add(new float[]{lerp(a[0], cpt[0], 0.52f), lerp(a[1], cpt[1], 0.52f)});
                rib.add(lpt);
                float ribA = alpha * (subjectPhase ? 0.0055f : 0.010f) * (0.72f + 0.28f * (float)Math.sin(u * Math.PI));
                drawTaperedStrip(rib, Math.max(0.045f, baseWidth * 0.004f), cr, cg, cb, ribA);
            }

            drawTaperedStrip(outer, Math.max(0.055f, baseWidth * 0.010f), cr, cg, cb,
                    alpha * (subjectPhase ? 0.020f : 0.044f));
            drawTaperedStrip(ridge, Math.max(0.055f, baseWidth * 0.008f), ar, ag, ab,
                    alpha * (subjectPhase ? 0.022f : 0.048f));
            drawTaperedStrip(caustic, Math.max(0.045f, baseWidth * 0.006f), 0.58f, 1.00f, 0.78f,
                    alpha * (subjectPhase ? 0.014f : 0.032f));

            // 尖端只保留极短冷青亮钩/细茎，不再画长白柱。
            int start = Math.max(0, (int)(n * 0.82f));
            ArrayList<float[]> tipRidge = new ArrayList<>(n - start);
            for (int i = start; i < n; i++) tipRidge.add(ridge.get(i));
            drawTaperedStrip(tipRidge, Math.max(0.05f, baseWidth * 0.010f), 0.68f, 1.00f, 0.86f,
                    alpha * (subjectPhase ? 0.040f : 0.070f));
        }


        
private void drawArtMotifAccent(StrokeEvent s, ArrayList<float[]> pts, Phase phase, float baseWidth,
                                        float r, float g, float b, float alpha, float intensity,
                                        float tension, float release, boolean headLayer) {
            if (pts.size() < 3 || alpha <= 0.004f) return;
            float[] first = pts.get(0);
            float[] last = pts.get(pts.size() - 1);
            float dx = last[0] - first[0];
            float dy = last[1] - first[1];
            float len = (float)Math.sqrt(dx * dx + dy * dy);
            if (len < 0.001f) return;
            float tx = dx / len;
            float ty = dy / len;
            float nx = -ty;
            float ny = tx;

            if (s.motif == 13 || s.motif == 15 || s.motif == 17) {
                drawVideoSilkBladeSubject(s, pts, phase, baseWidth, r, g, b, alpha, intensity, tension, release, headLayer);
                return;
            }

            if (s.motif == 12) {
                // Liquid pod: large soft oval body with inner glow and a few broad rings.
                float[] mid = pts.get(pts.size() / 2);
                float rot = (float)Math.atan2(dy, dx);
                float rx = baseWidth * (8.0f + tension * 3.5f + s.motifStrength * 2.2f);
                float ry = baseWidth * (4.5f + release * 2.4f + s.motifStrength * 1.6f);
                drawEllipse(mid[0], mid[1], rx, ry, rot, r, g, b, alpha * (0.070f + intensity * 0.040f + release * 0.040f), 36);
                drawEllipse(mid[0] + nx * rx * 0.10f, mid[1] + ny * rx * 0.10f, rx * 0.54f, ry * 0.50f, rot + 0.22f * s.flowC, 1f, 1f, 1f, alpha * 0.145f, 28);
                drawRing(mid[0], mid[1], Math.max(1f, rx * 0.86f), Math.max(0.55f, baseWidth * 0.12f), r, g, b, alpha * 0.065f, 48);
                return;
            } else if (s.motif == 13) {
                // Luminous wing: two translucent lobes, no mesh ribs.
                drawAsymmetricRibbon(pts, baseWidth * (8.5f + tension * 2.8f), baseWidth * (2.8f + tension), r, g, b, alpha * (0.060f + intensity * 0.035f), 0.74f);
                drawAsymmetricRibbon(pts, baseWidth * (2.6f + tension), baseWidth * (7.6f + tension * 2.2f), r, g, b, alpha * (0.040f + intensity * 0.026f), 0.88f);
                drawTaperedStrip(pts, Math.max(0.38f, baseWidth * 0.16f), 1f, 1f, 1f, alpha * 0.32f);
                return;
            } else if (s.motif == 14) {
                // Blossom crown: visible petals as soft ellipses gathered around a curved center.
                float[] mid = pts.get(pts.size() / 2);
                float rot = (float)Math.atan2(dy, dx);
                int petals = headLayer ? 5 : 3;
                for (int k = 0; k < petals; k++) {
                    float a = rot + (k - (petals - 1) * 0.5f) * 0.58f;
                    float px = mid[0] + (float)Math.cos(a) * baseWidth * (2.6f + k * 0.18f);
                    float py = mid[1] + (float)Math.sin(a) * baseWidth * (2.6f + k * 0.18f);
                    drawEllipse(px, py, baseWidth * (4.7f + tension * 1.9f), baseWidth * (1.75f + intensity), a, r, g, b,
                            alpha * (0.045f + intensity * 0.030f) * (1f - k * 0.055f), 28);
                }
                drawCircle(mid[0], mid[1], baseWidth * (1.4f + release * 1.3f), 1f, 1f, 1f, alpha * 0.220f, 24);
                return;
            } else if (s.motif == 15) {
                // Silk banner: one continuous translucent cloth-like sheet plus a narrow gleaming fold.
                drawAsymmetricRibbon(pts, baseWidth * (7.8f + tension * 2.4f), baseWidth * (6.8f + release * 2.0f), r, g, b, alpha * (0.060f + intensity * 0.028f + release * 0.028f), 0.66f);
                drawAsymmetricRibbon(pts, baseWidth * (3.0f + tension), baseWidth * (2.2f + tension), 1f, 1f, 1f, alpha * 0.026f, 1.0f);
                return;
            } else if (s.motif == 16) {
                // Orbit halo: crescent arcs and one full diffuse ring.
                float[] mid = pts.get(pts.size() / 2);
                float radius = Math.max(baseWidth * 5.0f, Math.min(width, height) * (0.045f + 0.030f * s.motifStrength));
                float start = (float)Math.atan2(first[1] - mid[1], first[0] - mid[0]) + s.seed * 0.23f;
                drawArcStrip(mid[0], mid[1], radius, Math.max(0.75f, baseWidth * 0.62f), start, (float)Math.PI * (1.15f + 0.55f * s.motifStrength) * s.flowC, r, g, b, alpha * (0.15f + intensity * 0.06f), 44);
                drawRing(mid[0], mid[1], radius * 0.66f, Math.max(0.48f, baseWidth * 0.10f), r, g, b, alpha * 0.045f, 48);
                drawCircle(mid[0], mid[1], baseWidth * (1.2f + release), 1f, 1f, 1f, alpha * 0.055f, 18);
                return;
            } else if (s.motif == 17) {
                // Crystal shard: faceted polygon plate with a white edge, replacing net-like crosshatching.
                float[] mid = pts.get(pts.size() / 2);
                ArrayList<float[]> poly = new ArrayList<>(5);
                poly.add(new float[]{first[0], first[1]});
                poly.add(new float[]{mid[0] + nx * baseWidth * (5.2f + tension * 1.7f), mid[1] + ny * baseWidth * (5.2f + tension * 1.7f)});
                poly.add(new float[]{last[0], last[1]});
                poly.add(new float[]{mid[0] - nx * baseWidth * (2.4f + release * 1.4f), mid[1] - ny * baseWidth * (2.4f + release * 1.4f)});
                drawFilledPolygon(poly, r, g, b, alpha * (0.060f + release * 0.030f));
                ArrayList<float[]> edgeA = new ArrayList<>(2);
                edgeA.add(poly.get(0)); edgeA.add(poly.get(1));
                drawTaperedStrip(edgeA, Math.max(0.42f, baseWidth * 0.13f), 1f, 1f, 1f, alpha * 0.32f);
                ArrayList<float[]> edgeB = new ArrayList<>(2);
                edgeB.add(poly.get(1)); edgeB.add(poly.get(2));
                drawTaperedStrip(edgeB, Math.max(0.34f, baseWidth * 0.10f), r, g, b, alpha * 0.20f);
                return;
            }

            if (s.motif == 3 || phase.name.equals("释放")) {
                // Silver blade: a pale triangular face plus a very thin white cutting edge.
                float[] mid = pts.get(pts.size() / 2);
                ArrayList<float[]> blade = new ArrayList<>(3);
                blade.add(new float[]{first[0], first[1]});
                blade.add(new float[]{mid[0] + nx * baseWidth * (2.4f + tension * 1.8f), mid[1] + ny * baseWidth * (2.4f + tension * 1.8f)});
                blade.add(new float[]{last[0], last[1]});
                drawTaperedStrip(blade, baseWidth * (2.8f + release * 2.0f), 1f, 1f, 1f,
                        alpha * (0.028f + release * 0.050f));
                ArrayList<float[]> edge = new ArrayList<>(2);
                edge.add(new float[]{first[0], first[1]});
                edge.add(new float[]{last[0], last[1]});
                drawTaperedStrip(edge, Math.max(0.34f, baseWidth * 0.11f), 1f, 1f, 1f,
                        alpha * (0.40f + intensity * 0.22f));
            } else if (s.motif == 4 || s.motif == 6) {
                // Petal / vine: soft side curls so the body looks like a living leaf or flower edge.
                float side = strokeHash(s, 3, 930) < 0.5f ? -1f : 1f;
                int layers = headLayer ? 3 : 1;
                for (int layer = 0; layer < layers; layer++) {
                    ArrayList<float[]> petal = new ArrayList<>(pts.size());
                    for (int i = 0; i < pts.size(); i++) {
                        float u = i / Math.max(1f, pts.size() - 1f);
                        float feather = (float)Math.sin(Math.PI * clamp(u, 0f, 1f));
                        float curl = (float)Math.sin(u * Math.PI * 1.5f + layer * 0.52f + s.seed) * baseWidth * (0.9f + tension);
                        float off = side * baseWidth * (1.9f + layer * 0.86f) * feather;
                        float[] p = pts.get(i);
                        petal.add(new float[]{p[0] + nx * off + tx * curl * feather, p[1] + ny * off + ty * curl * feather});
                    }
                    float a = alpha * (0.022f + intensity * 0.042f + release * 0.028f) * (1f - layer * 0.18f);
                    drawTaperedStrip(petal, baseWidth * (0.24f + layer * 0.12f), r, g, b, a);
                }
            } else if (s.motif == 5) {
                // Prism polygon: a few offset echoes make the frame read as a tilted transparent sheet.
                for (int k = -2; k <= 2; k++) {
                    if (k == 0) continue;
                    float off = baseWidth * k * 1.15f;
                    ArrayList<float[]> copy = new ArrayList<>(pts.size());
                    for (int i = 0; i < pts.size(); i++) {
                        float[] p = pts.get(i);
                        copy.add(new float[]{p[0] + nx * off, p[1] + ny * off});
                    }
                    drawTaperedStrip(copy, Math.max(0.22f, baseWidth * 0.055f), r, g, b,
                            alpha * (0.016f + intensity * 0.028f));
                }
            } else if (s.motif == 7) {
                // Long bridge: a strong central bow plus faint parallel ghost line, like the magenta arc in the video.
                ArrayList<float[]> ghost = new ArrayList<>(pts.size());
                float side = strokeHash(s, 4, 941) < 0.5f ? -1f : 1f;
                for (int i = 0; i < pts.size(); i++) {
                    float u = i / Math.max(1f, pts.size() - 1f);
                    float feather = (float)Math.sin(Math.PI * clamp(u, 0f, 1f));
                    float[] p = pts.get(i);
                    ghost.add(new float[]{p[0] + nx * side * baseWidth * 3.1f * feather, p[1] + ny * side * baseWidth * 3.1f * feather});
                }
                drawTaperedStrip(ghost, Math.max(0.25f, baseWidth * 0.18f), r, g, b,
                        alpha * (0.018f + intensity * 0.022f));
            } else if (s.motif == 8) {
                // Jellyfish tendril: short hanging side filaments near the head, very dim and organic.
                int hairs = headLayer ? 5 : 2;
                for (int h = 0; h < hairs; h++) {
                    float u = 0.45f + strokeHash(s, h, 960) * 0.48f;
                    int idx = clampInt((int)(u * (pts.size() - 1)), 1, pts.size() - 2);
                    float[] p = pts.get(idx);
                    float side2 = strokeHash(s, h, 961) < 0.5f ? -1f : 1f;
                    ArrayList<float[]> hair = new ArrayList<>(3);
                    hair.add(new float[]{p[0], p[1]});
                    hair.add(new float[]{p[0] + nx * side2 * baseWidth * (2.0f + h), p[1] + ny * side2 * baseWidth * (2.0f + h)});
                    hair.add(new float[]{p[0] + nx * side2 * baseWidth * (2.7f + h) + tx * baseWidth * (1.2f + h * 0.2f), p[1] + ny * side2 * baseWidth * (2.7f + h) + ty * baseWidth * (1.2f + h * 0.2f)});
                    drawTaperedStrip(hair, Math.max(0.18f, baseWidth * 0.050f), r, g, b, alpha * (0.018f + intensity * 0.018f));
                }
            } else if (s.motif == 9) {
                // Nebula coil: offset echoes make the stroke read as a luminous smoke curl, not a simple arc.
                for (int k = 1; k <= 3; k++) {
                    ArrayList<float[]> echo = new ArrayList<>(pts.size());
                    float sign = k % 2 == 0 ? -1f : 1f;
                    for (int i = 0; i < pts.size(); i++) {
                        float u = i / Math.max(1f, pts.size() - 1f);
                        float feather = (float)Math.sin(Math.PI * clamp(u, 0f, 1f));
                        float swirl = (float)Math.sin(u * Math.PI * (1.0f + k * 0.35f) + s.seed) * baseWidth * (1.4f + k * 0.55f) * feather;
                        float[] p = pts.get(i);
                        echo.add(new float[]{p[0] + nx * sign * swirl, p[1] + ny * sign * swirl});
                    }
                    drawTaperedStrip(echo, Math.max(0.20f, baseWidth * (0.070f - k * 0.010f)), r, g, b,
                            alpha * (0.018f + intensity * 0.020f) * (1f - k * 0.18f));
                }
            } else if (s.motif == 10) {
                // Origami sheet: two fold lines and a faint translucent face.
                ArrayList<float[]> foldA = new ArrayList<>(pts.size());
                ArrayList<float[]> foldB = new ArrayList<>(pts.size());
                for (int i = 0; i < pts.size(); i++) {
                    float u = i / Math.max(1f, pts.size() - 1f);
                    float feather = (float)Math.sin(Math.PI * clamp(u, 0f, 1f));
                    float[] p = pts.get(i);
                    foldA.add(new float[]{p[0] + nx * baseWidth * 2.0f * feather, p[1] + ny * baseWidth * 2.0f * feather});
                    foldB.add(new float[]{p[0] - nx * baseWidth * 1.6f * feather, p[1] - ny * baseWidth * 1.6f * feather});
                }
                drawTaperedStrip(foldA, Math.max(0.22f, baseWidth * 0.060f), 1f, 1f, 1f, alpha * (0.090f + release * 0.045f));
                drawTaperedStrip(foldB, Math.max(0.20f, baseWidth * 0.045f), r, g, b, alpha * (0.030f + intensity * 0.020f));
            } else if (s.motif == 11) {
                // Constellation chain: sparse nodes welded into the moving line, avoiding random dust clutter.
                int nodes = Math.min(6, Math.max(3, pts.size() / 8));
                for (int k = 1; k <= nodes; k++) {
                    int idx = clampInt((int)(k / (float)(nodes + 1) * (pts.size() - 1)), 1, pts.size() - 2);
                    float[] p = pts.get(idx);
                    drawCircle(p[0], p[1], baseWidth * (0.42f + strokeHash(s, k, 980) * 0.44f), r, g, b,
                            alpha * (0.075f + intensity * 0.040f), 12);
                }
            } else if ((s.motif == 2 || s.motif == 10) && headLayer) {
                // Fan/sheet hinge glow, a dim focal phosphor dot that makes the structure appear intentional rather than random.
                float[] pivot = strokeHash(s, 5, 950) < 0.5f ? first : last;
                drawCircle(pivot[0], pivot[1], baseWidth * (10.0f + tension * 7.0f), r, g, b,
                        alpha * 0.105f, 24);
            }
        }

        private void drawFiberVeil(StrokeEvent s, ArrayList<float[]> pts, float baseWidth,
                                   float r, float g, float b, float alpha, float intensity,
                                   float tension, float release, boolean headLayer) {
            if (pts.size() < 4 || alpha <= 0.004f) return;
            float[] first = pts.get(0);
            float[] last = pts.get(pts.size() - 1);
            float dx = last[0] - first[0];
            float dy = last[1] - first[1];
            float len = (float)Math.sqrt(dx * dx + dy * dy);
            if (len < 0.001f) return;
            float nx = -dy / len;
            float ny = dx / len;

            int strands = 5 + (int)(cfg.randomness * 5f + intensity * 4f);
            if (s.actor == 1) strands = Math.max(3, strands - 2);
            if (s.actor == 2) strands += 2;
            if (!headLayer) strands = Math.max(3, strands / 2);
            float spread = baseWidth * (1.2f + tension * 1.9f + release * 1.7f) * (s.actor == 2 ? 1.20f : 0.92f);
            for (int j = 0; j < strands; j++) {
                float h = strokeHash(s, j, 701);
                float h2 = strokeHash(s, j, 709);
                float side = (j - (strands - 1) * 0.5f) / Math.max(1f, (strands - 1f));
                float off = side * spread * (0.55f + h * 0.90f);
                float along = (h2 - 0.5f) * baseWidth * (1.0f + tension);
                ArrayList<float[]> strand = new ArrayList<>(pts.size());
                for (int i = 0; i < pts.size(); i++) {
                    float u = i / Math.max(1f, pts.size() - 1f);
                    float feather = (float)Math.sin(Math.PI * clamp(u, 0f, 1f));
                    float wave = (float)Math.sin(u * Math.PI * 2.0f + s.seed + j * 0.77f) * baseWidth * 0.28f * feather;
                    float[] p = pts.get(i);
                    strand.add(new float[]{p[0] + nx * (off + wave) + dx / len * along * feather,
                                           p[1] + ny * (off + wave) + dy / len * along * feather});
                }
                float strandWidth = Math.max(0.24f, baseWidth * (0.030f + strokeHash(s, j, 719) * 0.070f));
                float strandAlpha = alpha * (0.025f + intensity * 0.035f + release * 0.035f) * (0.45f + h * 0.80f);
                drawTaperedStrip(strand, strandWidth, r, g, b, strandAlpha);
            }
        }

        private ArrayList<float[]> offsetPoints(ArrayList<float[]> src, float dx, float dy) {
            ArrayList<float[]> out = new ArrayList<>(src.size());
            for (int i = 0; i < src.size(); i++) {
                float[] p = src.get(i);
                out.add(new float[]{p[0] + dx, p[1] + dy});
            }
            return out;
        }


        private void drawActorHeadCluster(StrokeEvent s, ArrayList<float[]> pts, float baseWidth,
                                          float r, float g, float b, float alpha,
                                          float intensity, float tension, float release) {
            if (pts.size() < 3 || alpha <= 0.004f) return;
            float[] head = pts.get(pts.size() - 1);
            float[] prev = pts.get(Math.max(0, pts.size() - 4));
            float dx = head[0] - prev[0];
            float dy = head[1] - prev[1];
            float len = (float)Math.sqrt(dx * dx + dy * dy);
            if (len < 0.001f) len = 1f;
            float tx = dx / len;
            float ty = dy / len;
            float nx = -ty;
            float ny = tx;
            int dots = s.actor == 2 ? 5 : 3;
            float cluster = baseWidth * (s.actor == 2 ? 2.6f : 1.7f) * (0.80f + tension * 0.40f + release * 0.50f);
            for (int i = 0; i < dots; i++) {
                float h1 = strokeHash(s, i, 901);
                float h2 = strokeHash(s, i, 907);
                float along = (-0.18f + h1 * 0.36f) * cluster;
                float side = (h2 - 0.5f) * 2f * cluster * (s.actor == 2 ? 0.95f : 0.45f);
                float x = head[0] + tx * along + nx * side;
                float y = head[1] + ty * along + ny * side;
                float rr = Math.max(0.40f, baseWidth * (s.actor == 2 ? 0.20f : 0.13f) * (0.55f + h1));
                drawCircle(x, y, rr, r, g, b, alpha * (s.actor == 2 ? 0.050f : 0.034f) * (0.7f + intensity), 10);
            }
            if (s.actor == 2) {
                for (int k = -1; k <= 1; k += 2) {
                    ArrayList<float[]> ray = new ArrayList<>(2);
                    float side = k * cluster * 0.72f;
                    ray.add(new float[]{head[0] - tx * cluster * 0.20f, head[1] - ty * cluster * 0.20f});
                    ray.add(new float[]{head[0] + tx * cluster * 0.55f + nx * side, head[1] + ty * cluster * 0.55f + ny * side});
                    drawTaperedStrip(ray, Math.max(0.24f, baseWidth * 0.045f), r, g, b, alpha * 0.120f);
                }
            }
        }

        private void drawPointLineSpray(StrokeEvent s, ArrayList<float[]> pts, Phase phase, float baseWidth,
                                        float r, float g, float b, float alpha, float intensity, float tension, float release) {
            if (pts.size() < 3 || alpha <= 0.004f) return;
            int n = pts.size();
            float minDim = Math.min(width, height);
            float lifeProgress = clamp(s.age / Math.max(0.001f, s.life), 0f, 1f);
            float headBias = lifeProgress < 0.55f ? smooth(lifeProgress / 0.55f) : 1f;
            float grainBase = phase.name.equals("分离") ? 3f : phase.name.equals("吸引") ? 5f : phase.name.equals("同步") ? 6f : phase.name.equals("临界") ? 8f : 5f;
            if (s.actor == 1) grainBase *= 0.58f;
            if (s.actor == 2) grainBase *= 0.82f;
            int grains = (int)(grainBase + cfg.randomness * (s.actor == 2 ? 4f : 3f) + release * 4f);
            float spray = baseWidth * (1.35f + tension * 1.55f) * (s.actor == 2 ? 1.18f : 0.88f) + minDim * (0.0010f + cfg.randomness * 0.0035f);

            for (int i = 0; i < grains; i++) {
                float h1 = strokeHash(s, i, 11);
                float h2 = strokeHash(s, i, 17);
                float h3 = strokeHash(s, i, 23);
                // 大部分颗粒落在当前光迹前部，少部分散落在尾部，形成“喷洒”而非等宽线条。
                float u = h1 < 0.68f ? lerp(0.58f, 1.0f, h2) : h2;
                u = clamp(lerp(u, headBias, 0.18f * intensity), 0f, 1f);
                int idx = clampInt((int)(u * (n - 1)), 1, n - 2);
                float[] p = pts.get(idx);
                float[] prev = pts.get(idx - 1);
                float[] next = pts.get(idx + 1);
                float dx = next[0] - prev[0];
                float dy = next[1] - prev[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001f) len = 1f;
                float tx = dx / len;
                float ty = dy / len;
                float nx = -ty;
                float ny = tx;
                float side = (h2 - 0.5f) * 2f;
                float along = (strokeHash(s, i, 31) - 0.5f) * spray * 0.72f;
                float normal = side * spray * (0.35f + strokeHash(s, i, 37) * 1.25f);
                // 临界/释放更像飞溅；分离更淡、更远。
                float phaseBoost = phase.name.equals("临界") ? 1.30f : phase.name.equals("释放") ? 1.55f : phase.name.equals("分离") ? 0.72f : 1.0f;
                float x = p[0] + tx * along + nx * normal * phaseBoost;
                float y = p[1] + ty * along + ny * normal * phaseBoost;
                float radius = Math.max(0.32f, baseWidth * (0.018f + strokeHash(s, i, 41) * 0.070f) + minDim * 0.00028f);
                float dotAlpha = alpha * (0.014f + 0.060f * intensity + release * 0.055f) * (0.35f + h3 * 0.60f);
                if (phase.name.equals("分离")) dotAlpha *= 0.55f;
                if (s.actor == 1) dotAlpha *= 0.78f;
                if (s.actor == 2) dotAlpha *= 1.18f;
                drawCircle(x, y, radius, r, g, b, dotAlpha, 10);

                // 少量短促微线，形成“点线组成”的笔触纹理，而不是一根孤立线。
                if (strokeHash(s, i, 53) < 0.46f + intensity * 0.20f) {
                    float seg = radius * (5.0f + strokeHash(s, i, 59) * 9.0f);
                    ArrayList<float[]> mini = new ArrayList<>(2);
                    mini.add(new float[]{x - tx * seg * 0.45f, y - ty * seg * 0.45f});
                    mini.add(new float[]{x + tx * seg * 0.55f, y + ty * seg * 0.55f});
                    drawTaperedStrip(mini, Math.max(0.22f, radius * 0.50f), r, g, b, dotAlpha * 0.38f);
                }
            }
        }

        private float strokeHash(StrokeEvent s, int i, int salt) {
            double v = Math.sin(s.seed * 12.9898 + s.variant * 0.013579 + i * 78.233 + salt * 37.719) * 43758.5453;
            return (float)(v - Math.floor(v));
        }

        private ArrayList<float[]> sampleStroke(StrokeEvent s) {
            ArrayList<float[]> pts = new ArrayList<>();
            if (s.count == 2) {
                for (int i = 0; i <= 18; i++) {
                    float t = i / 18f;
                    pts.add(new float[]{lerp(s.x[0], s.x[1], t), lerp(s.y[0], s.y[1], t)});
                }
                return pts;
            }
            int samplesPerSegment = 12;
            for (int i = 0; i < s.count - 1; i++) {
                float x0 = s.x[Math.max(0, i - 1)], y0 = s.y[Math.max(0, i - 1)];
                float x1 = s.x[i], y1 = s.y[i];
                float x2 = s.x[i + 1], y2 = s.y[i + 1];
                float x3 = s.x[Math.min(s.count - 1, i + 2)], y3 = s.y[Math.min(s.count - 1, i + 2)];
                for (int k = 0; k < samplesPerSegment; k++) {
                    float t = k / (float)samplesPerSegment;
                    pts.add(new float[]{catmull(x0, x1, x2, x3, t), catmull(y0, y1, y2, y3, t)});
                }
            }
            pts.add(new float[]{s.x[s.count - 1], s.y[s.count - 1]});
            return pts;
        }

        private ArrayList<float[]> visibleSegment(ArrayList<float[]> all, StrokeEvent s) {
            return visibleSegmentAt(all, s, clamp(s.age / Math.max(0.001f, s.life), 0f, 1f));
        }

        private ArrayList<float[]> visibleSegmentAt(ArrayList<float[]> all, StrokeEvent s, float progress) {
            ArrayList<float[]> out = new ArrayList<>();
            if (all.size() < 2) return out;

            // V17：移动窗口。head 继续向前“写出”，tail 同步跟进；
            // 不再把整条线画出来再整体淡死。
            float eased = smooth(clamp(progress, 0f, 1f));
            float window = clamp(s.visibleWindow, 0.22f, 0.62f);
            float head = lerp(-s.headLead, 1.0f + window + s.headLead, eased);
            float tail = head - window;
            if (tail >= 1.0f || head <= 0.0f) return out;
            float startF = clamp(tail, 0f, 1f);
            float endF = clamp(head, 0f, 1f);
            int start = clampInt((int)(startF * (all.size() - 1)), 0, all.size() - 2);
            int end = clampInt((int)(endF * (all.size() - 1)), start + 1, all.size() - 1);
            for (int i = start; i <= end; i++) out.add(all.get(i));
            // V18：过滤过短可见片段。Mystify/Ribbons 的观感不是“短点线残片”，
            // 而是一笔有势能、有长度、有消失背影的光迹。
            // 开头和结尾如果窗口太短，直接不画，让旧 FBO 残影自然承担退场。
            float minLen = Math.min(width, height) * 0.18f;
            if (polylineLength(out) < minLen) out.clear();
            return out;
        }

        private float polylineLength(ArrayList<float[]> pts) {
            float len = 0f;
            for (int i = 1; i < pts.size(); i++) {
                float[] a = pts.get(i - 1);
                float[] b = pts.get(i);
                float dx = b[0] - a[0];
                float dy = b[1] - a[1];
                len += (float)Math.sqrt(dx * dx + dy * dy);
            }
            return len;
        }

        private void drawTaperedStrip(ArrayList<float[]> pts, float widthPx, float r, float g, float b, float a) {
            if (pts.size() < 2 || a <= 0.001f || widthPx <= 0.05f) return;
            int n = pts.size();
            float[] verts = new float[n * 2 * 2];
            int vi = 0;
            for (int i = 0; i < n; i++) {
                float u = i / Math.max(1f, (n - 1f));
                float profile = (float)Math.pow(Math.max(0.0, Math.sin(Math.PI * u)), 1.22);
                float half = widthPx * 0.5f * (0.004f + 0.996f * profile);
                float[] prev = pts.get(Math.max(0, i - 1));
                float[] next = pts.get(Math.min(n - 1, i + 1));
                float dx = next[0] - prev[0];
                float dy = next[1] - prev[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float x = pts.get(i)[0];
                float y = pts.get(i)[1];
                putNdc(verts, vi, x + nx * half, y + ny * half); vi += 2;
                putNdc(verts, vi, x - nx * half, y - ny * half); vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_STRIP, r, g, b, a);
        }

        private void drawStrip(ArrayList<float[]> pts, float widthPx, float r, float g, float b, float a) {
            if (pts.size() < 2 || a <= 0.001f || widthPx <= 0.05f) return;
            int n = pts.size();
            float[] verts = new float[n * 2 * 2];
            int vi = 0;
            float half = widthPx * 0.5f;
            for (int i = 0; i < n; i++) {
                float[] prev = pts.get(Math.max(0, i - 1));
                float[] next = pts.get(Math.min(n - 1, i + 1));
                float dx = next[0] - prev[0];
                float dy = next[1] - prev[1];
                float len = (float)Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001f) len = 1f;
                float nx = -dy / len;
                float ny = dx / len;
                float x = pts.get(i)[0];
                float y = pts.get(i)[1];
                putNdc(verts, vi, x + nx * half, y + ny * half); vi += 2;
                putNdc(verts, vi, x - nx * half, y - ny * half); vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_STRIP, r, g, b, a);
        }


        private void drawAfterglowBubbleAquarium(float sec, float after, Phase phase) {
            if (!cfg.bubbles || !phase.name.equals("余韵") || after <= 0.006f) return;
            float appear = smooth(Math.min(1f, after / 0.070f));
            float fadeOut = 1f - smooth(Math.max(0f, (after - 0.90f) / 0.10f));
            float aBase = clamp(appear * fadeOut, 0f, 1f);
            if (aBase <= 0.002f) return;
            float minDim = Math.max(1f, Math.min(width, height));
            float cx = pulseX * width;
            float cy = pulseY * height;

            // V36：余韵气泡逐帧清绘；这里给一层干净、稳定的深蓝玻璃水域，
            // 不依靠历史残影叠亮，因此透明泡移动时不会拖成长筒。
            drawSolidRect(0.004f, 0.030f, 0.105f, aBase * 0.155f);
            drawSolidRect(0.000f, 0.110f, 0.220f, aBase * 0.055f);

            // 左下到右上的青绿水光：较亮但很细，模拟参考视频里的斜向光束，不再形成大面积白色斜面。
            for (int k = 0; k < 5; k++) {
                float off = minDim * (-0.16f + k * 0.055f + 0.024f * (float)Math.sin(sec * 0.045f + k * 1.9f));
                float y0 = height * (1.02f + 0.010f * k) + off;
                float y1 = height * (0.36f + 0.036f * k) + off * 0.14f;
                ArrayList<float[]> beam = new ArrayList<>(4);
                beam.add(new float[]{-width * 0.22f, y0});
                beam.add(new float[]{width * 0.18f, lerp(y0, y1, 0.33f)});
                beam.add(new float[]{width * 0.64f, lerp(y0, y1, 0.72f)});
                beam.add(new float[]{width * 1.14f, y1});
                drawTaperedStrip(beam, minDim * (0.014f + k * 0.0022f), 0.07f, 0.74f, 1.00f, aBase * (0.010f - k * 0.0009f));
                drawTaperedStrip(beam, Math.max(0.55f, minDim * (0.0017f + k * 0.00045f)), 0.72f, 1.00f, 0.90f, aBase * (0.040f - k * 0.0040f));
            }

            // 透明肥皂泡爆散：每轮释放使用 afterglowSeed，确保每次出现的数量、方向、大小、薄膜色都不同。
            int count = cfg.powerSave ? 18 : 30;
            for (int i = 0; i < count; i++) {
                int key = afterglowSeed + i * 131;
                float h0 = hash01(key, 3301);
                float h1 = hash01(key, 3303);
                float h2 = hash01(key, 3307);
                float h3 = hash01(key, 3313);
                float h4 = hash01(key, 3319);
                float born = h0 * 0.11f;
                float life = 0.92f + h1 * 0.46f;
                float u = clamp((after - born) / Math.max(0.001f, life), 0f, 1f);
                float live = smooth(Math.min(1f, u / 0.060f)) * (1f - smooth(Math.max(0f, (u - 0.86f) / 0.14f)));
                if (live <= 0.002f) continue;

                float ang = (float)(h2 * Math.PI * 2.0 + 0.16f * Math.sin(sec * 0.10f + i * 0.7f));
                float burst = smooth(Math.min(1f, u / 0.18f));
                float far = minDim * (0.30f + h3 * 0.78f);
                float drift = minDim * (0.060f + h1 * 0.145f) * u;
                float swirl = minDim * (0.012f + h0 * 0.036f) * (float)Math.sin(u * Math.PI * 1.9f + i * 1.3f);
                float nx = (float)Math.cos(ang);
                float ny = (float)Math.sin(ang);
                float tx = -ny;
                float ty = nx;
                float bx = cx + nx * (minDim * 0.012f + far * burst + drift) + tx * swirl;
                float by = cy + ny * (minDim * 0.012f + far * burst + drift) + ty * swirl;
                // 后半段轻微斜向上浮，像水里漂移，而不是固定在释放中心周围转圈。
                bx += minDim * (0.018f + h4 * 0.080f) * u;
                by -= minDim * (0.060f + h1 * 0.150f) * u;

                float radius = minDim * (0.024f + h4 * 0.050f) * (0.90f + 0.18f * (float)Math.sin(Math.PI * u));
                if (i % 9 == 0) radius *= 1.18f;
                radius = Math.min(radius, minDim * 0.088f);
                drawIridescentBubble(bx, by, radius, key, aBase * live, sec);
            }
        }

        private void drawIridescentBubble(float cx, float cy, float radius, int index, float alpha, float sec) {
            if (alpha <= 0.002f || radius <= 0.5f) return;
            // V33：水晶泡泡 = 极淡蓝色内部 + 双层薄膜边缘 + 局部彩虹弧 + 白色椭圆高光。
            // 中心保持透明，不再画成黑珠或实心彩圈。
            drawCircle(cx, cy, radius * 0.98f, 0.020f, 0.210f, 0.410f, alpha * 0.018f, 44);
            drawCircle(cx - radius * 0.13f, cy - radius * 0.18f, radius * 0.62f, 0.32f, 0.86f, 1.00f, alpha * 0.008f, 36);

            float spin = sec * (0.10f + 0.003f * (index & 15)) + index * 0.0137f;
            float w = Math.max(0.55f, radius * 0.030f);
            drawRing(cx, cy, radius * 1.010f, Math.max(0.38f, radius * 0.015f), 0.92f, 0.99f, 1.00f, alpha * 0.24f, 72);
            drawRing(cx, cy, radius * 0.930f, Math.max(0.28f, radius * 0.007f), 0.22f, 0.76f, 1.00f, alpha * 0.045f, 64);
            drawArcStrip(cx, cy, radius * 1.015f, w * 1.36f, spin, (float)Math.PI * 0.50f, 0.96f, 0.30f, 0.78f, alpha * 0.22f, 18);
            drawArcStrip(cx, cy, radius * 1.020f, w * 1.22f, spin + 1.54f, (float)Math.PI * 0.54f, 0.26f, 0.94f, 1.00f, alpha * 0.24f, 20);
            drawArcStrip(cx, cy, radius * 1.015f, w * 1.12f, spin + 2.76f, (float)Math.PI * 0.46f, 0.60f, 1.00f, 0.36f, alpha * 0.18f, 18);
            drawArcStrip(cx, cy, radius * 1.005f, w * 0.96f, spin + 3.86f, (float)Math.PI * 0.38f, 1.00f, 0.86f, 0.34f, alpha * 0.12f, 16);

            float hiAng = -0.98f + 0.16f * (float)Math.sin(spin * 0.8f);
            float hx = cx + (float)Math.cos(hiAng) * radius * 0.44f;
            float hy = cy + (float)Math.sin(hiAng) * radius * 0.44f;
            drawEllipse(hx, hy, radius * 0.155f, radius * 0.052f, hiAng + 0.54f, 1f, 1f, 1f, alpha * 0.50f, 16);
            drawEllipse(cx - radius * 0.26f, cy - radius * 0.18f, radius * 0.40f, radius * 0.014f, hiAng + 0.16f, 0.72f, 0.96f, 1f, alpha * 0.105f, 16);
            drawEllipse(cx + radius * 0.30f, cy + radius * 0.23f, radius * 0.34f, radius * 0.010f, hiAng + 0.12f, 1.0f, 0.55f, 0.94f, alpha * 0.050f, 14);
        }

        private void drawSolidRect(float r, float g, float b, float a) {
            if (a <= 0f) return;
            float[] verts = new float[]{-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f};
            drawColorVertices(verts, GLES20.GL_TRIANGLE_STRIP, r, g, b, a);
        }

        private float hash01(int i, int salt) {
            double v = Math.sin((i + 1) * 12.9898 + salt * 78.233 + cfg.style * 37.719) * 43758.5453;
            return (float)(v - Math.floor(v));
        }

        private void drawReleaseEruption(float local, float release, Phase phase) {
            float baseX = pulseX * width;
            float baseY = pulseY * height;
            float minDim = Math.max(1f, Math.min(width, height));
            float t = clamp(local, 0f, 1f);
            float releaseDurSec = Math.max(0.30f, phase.end - phase.start);
            float elapsed = t * releaseDurSec;

            // V37：震颤按“真实秒数”而不是归一化进度驱动。
            // 这样无论释放阶段被设置为 8 秒还是 24 秒，开头 0.5 秒都会出现肉眼可见的硬抖动。
            float quakeRise = smooth(Math.min(1f, elapsed / 0.020f));
            float quakeDrop = 1f - smooth(Math.max(0f, (elapsed - 0.36f) / 0.18f));
            float preQuake = quakeRise * quakeDrop;
            float quakeStrobe = (((int)Math.floor(elapsed * 34.0f + (releaseSeed & 7)) & 1) == 0) ? 1.0f : 0.18f;
            float quakeSnap = (((int)Math.floor(elapsed * 23.0f + ((releaseSeed >> 4) & 7)) & 1) == 0) ? 1.0f : -1.0f;

            float impactFlash = smooth(Math.min(1f, elapsed / 0.055f)) * (1f - smooth(Math.max(0f, (elapsed - 0.46f) / 0.22f)));
            float beamSurgeTime = smooth(Math.min(1f, (elapsed - 0.12f) / 0.22f)) * (1f - smooth(Math.max(0f, (elapsed - 1.50f) / 0.62f)));
            float beamSurgeNorm = smooth(Math.min(1f, (t - 0.055f) / 0.145f)) * (1f - smooth(Math.max(0f, (t - 0.72f) / 0.28f)));
            float beamSurge = Math.max(beamSurgeTime, beamSurgeNorm * 0.82f);
            float floodSurge = smooth(Math.min(1f, (t - 0.15f) / 0.18f)) * (1f - smooth(Math.max(0f, (t - 0.88f) / 0.12f)));
            float finalClean = 1f - smooth(Math.max(0f, (t - 0.84f) / 0.16f));
            float visibleRelease = Math.max(release, Math.min(1f, preQuake * 0.62f + impactFlash * 0.86f));
            float a = clamp((visibleRelease * 0.82f + impactFlash * 0.55f + preQuake * 0.26f) * (0.90f + 0.38f * cfg.intimacy), 0f, 1.60f);

            // 大幅、非正弦、跳变式偏移：比 V36 更像“画面被猛地撞了几下”，而不是柔和晃动。
            float tremor = preQuake * (0.42f + 0.58f * (float)Math.abs(Math.sin(elapsed * 132.0f + releaseSeed * 0.0017f)));
            float snap = preQuake * (0.55f + 0.45f * quakeStrobe);
            float jx = minDim * (0.026f + 0.108f * tremor) * (float)Math.sin(elapsed * 96.0f + releaseSeed * 0.0023f)
                    + minDim * 0.075f * snap * quakeSnap;
            float jy = minDim * (0.024f + 0.102f * tremor) * (float)Math.cos(elapsed * 117.0f + releaseSeed * 0.0031f)
                    - minDim * 0.058f * snap * ((((int)Math.floor(elapsed * 29.0f)) & 1) == 0 ? 1f : -1f);
            float x = baseX + jx;
            float y = baseY + jy;

            // 明确的“颤抖可见层”：短促白闪 + 橙红热闪 + 撕裂光带。
            drawSolidRect(1.00f, 1.00f, 0.94f, a * preQuake * (0.100f + 0.070f * quakeStrobe));
            drawSolidRect(1.00f, 0.22f, 0.00f, a * preQuake * (0.050f + 0.032f * (1f - quakeStrobe)) * finalClean);
            drawQuakeTearBands(baseX, baseY, minDim, preQuake, quakeStrobe, elapsed, a);

            // 0.00-0.20：突然白化/热红升温，短促、刺激，但不长期烙屏。
            drawSolidRect(1.00f, 0.98f, 0.78f, a * (impactFlash * 0.088f + snap * 0.060f));
            drawSolidRect(1.00f, 0.39f, 0.02f, a * (beamSurge * 0.036f + snap * 0.030f) * finalClean);
            drawSolidRect(0.62f, 0.02f, 0.10f, a * (0.058f * preQuake + 0.020f * floodSurge) * finalClean);

            float coreR = minDim * (0.055f + 0.210f * beamSurge + 0.185f * impactFlash + 0.060f * visibleRelease);

            // V37：多重错帧核心。早期用明显分离的白金光心告诉眼睛“它在抖”。
            if (preQuake > 0.01f) {
                for (int q = 0; q < 7; q++) {
                    int key = releaseSeed + q * 761;
                    float angQ = (float)(hash01(key, 3901) * Math.PI * 2.0 + elapsed * (38.0f + q * 6.5f));
                    float ampQ = minDim * (0.040f + 0.092f * hash01(key, 3903)) * preQuake * (0.55f + 0.45f * quakeStrobe);
                    float qx = baseX + (float)Math.cos(angQ) * ampQ + (q % 2 == 0 ? jx * 0.45f : -jx * 0.36f);
                    float qy = baseY + (float)Math.sin(angQ) * ampQ + (q % 2 == 0 ? jy * 0.45f : -jy * 0.36f);
                    drawCircle(qx, qy, coreR * (0.58f + 0.20f * q), 1.00f, 1.00f, 0.96f, a * preQuake * (0.085f - q * 0.007f), 34);
                    drawCircle(qx, qy, coreR * (1.45f + 0.16f * q), 1.00f, 0.55f, 0.02f, a * preQuake * (0.040f - q * 0.0038f), 42);
                }
            }

            // 颤抖重影核心：白、金、橙、玫红多层错位，形成参考视频那种“强光把细节吞掉”的瞬间。
            for (int g = 0; g < 5; g++) {
                float gh = hash01(releaseSeed + g * 97, 3951);
                float gx = x + (gh - 0.5f) * minDim * 0.130f * preQuake;
                float gy = y + (hash01(releaseSeed + g * 101, 3957) - 0.5f) * minDim * 0.130f * preQuake;
                drawCircle(gx, gy, coreR * (2.65f + g * 0.34f), 1.00f, 0.48f, 0.03f, a * Math.max(0.004f, (0.040f - g * 0.0050f)) * finalClean, 64);
                drawCircle(gx, gy, coreR * (1.55f + g * 0.16f), 1.00f, 0.82f, 0.10f, a * Math.max(0.006f, (0.100f - g * 0.012f)) * finalClean, 64);
            }
            drawCircle(x, y, coreR * 0.88f, 1.00f, 1.00f, 0.96f, a * 0.270f * finalClean, 56);
            drawCircle(x + jx * 0.55f, y - jy * 0.55f, coreR * 0.48f, 1.00f, 1.00f, 1.00f, a * 0.230f * impactFlash, 40);

            // 宽幅冲击楔面：从中心突然推开，模拟视频里的大面积金白爆光与舞台追光，而非单个机械大圆盘。
            int wedges = cfg.powerSave ? 7 : 13;
            for (int w = 0; w < wedges; w++) {
                int key = releaseSeed + w * 137;
                float h0 = hash01(key, 4001);
                float h1 = hash01(key, 4003);
                float ang = (float)(h0 * Math.PI * 2.0 + 0.18f * Math.sin(t * 28.0f + h1 * 6.28f) + preQuake * quakeSnap * 0.20f);
                float sweep = 0.20f + h1 * 0.30f;
                float len = minDim * (0.52f + h1 * 0.90f) * (0.52f + beamSurge * 0.80f + preQuake * 0.22f);
                float inner = minDim * (0.018f + h1 * 0.020f);
                ArrayList<float[]> poly = new ArrayList<>(4);
                poly.add(new float[]{x + (float)Math.cos(ang - sweep) * inner, y + (float)Math.sin(ang - sweep) * inner});
                poly.add(new float[]{x + (float)Math.cos(ang - sweep * 0.72f) * len, y + (float)Math.sin(ang - sweep * 0.72f) * len});
                poly.add(new float[]{x + (float)Math.cos(ang + sweep * 0.72f) * len * (0.92f + h0 * 0.18f), y + (float)Math.sin(ang + sweep * 0.72f) * len * (0.92f + h0 * 0.18f)});
                poly.add(new float[]{x + (float)Math.cos(ang + sweep) * inner, y + (float)Math.sin(ang + sweep) * inner});
                float wa = a * Math.max(beamSurge, preQuake * 0.72f) * (0.035f + h0 * 0.030f) * finalClean;
                drawFilledPolygon(poly, 1.00f, 0.54f + h1 * 0.22f, 0.03f, wa * 0.58f);
                drawFilledPolygon(poly, 1.00f, 0.96f, 0.54f, wa * 0.22f);
            }

            // 粗大放射光柱：数量更密、宽窄交替、中心白芯更亮；加上横向/斜向扫光增强“冲屏”感。
            int beams = cfg.powerSave ? 16 : 32;
            for (int i = 0; i < beams; i++) {
                int key = releaseSeed + i * 193;
                float h0 = hash01(key, 4101);
                float h1 = hash01(key, 4103);
                float h2 = hash01(key, 4107);
                float h3 = hash01(key, 4111);
                float trem = preQuake * (h2 - 0.5f) * 1.10f;
                float ang = (float)(h0 * Math.PI * 2.0 + trem + 0.28f * Math.sin(t * 10.0f + h1 * 6.28f));
                float len = minDim * (0.70f + h1 * 1.18f) * (0.34f + beamSurge * 0.98f + preQuake * 0.20f);
                float sx = x + (float)Math.cos(ang) * minDim * (0.012f + h2 * 0.030f);
                float sy = y + (float)Math.sin(ang) * minDim * (0.012f + h2 * 0.030f);
                float ex = x + (float)Math.cos(ang) * len;
                float ey = y + (float)Math.sin(ang) * len;
                float tx = (float)Math.cos(ang + Math.PI * 0.5f);
                float ty = (float)Math.sin(ang + Math.PI * 0.5f);
                float bend = minDim * (h2 - 0.5f) * 0.24f * (0.35f + beamSurge + preQuake * 0.30f);
                ArrayList<float[]> beam = new ArrayList<>(4);
                beam.add(new float[]{sx, sy});
                beam.add(new float[]{lerp(sx, ex, 0.25f) + tx * bend * 0.22f, lerp(sy, ey, 0.25f) + ty * bend * 0.22f});
                beam.add(new float[]{lerp(sx, ex, 0.67f) + tx * bend, lerp(sy, ey, 0.67f) + ty * bend});
                beam.add(new float[]{ex, ey});
                float beamAlpha = a * (0.046f + h2 * 0.048f) * Math.max(beamSurge, preQuake * 0.52f) * finalClean;
                float beamWidth = minDim * (0.024f + h3 * 0.070f) * (0.72f + 1.12f * visibleRelease + 0.86f * impactFlash + 0.75f * snap);
                drawTaperedStrip(beam, beamWidth * 5.40f, 1.00f, 0.24f + h1 * 0.18f, 0.00f, beamAlpha * 0.36f);
                drawTaperedStrip(beam, beamWidth * 2.45f, 1.00f, 0.70f + h1 * 0.20f, 0.10f, beamAlpha * 0.78f);
                drawTaperedStrip(beam, Math.max(1.10f, beamWidth * 0.25f), 1.00f, 1.00f, 0.92f, beamAlpha * 1.45f);
            }

            // 扫屏光带：参考视频中粗黄光柱横穿画面，加入少量斜切光带，避免只有中心圆爆。
            int sweeps = cfg.powerSave ? 4 : 7;
            for (int sIdx = 0; sIdx < sweeps; sIdx++) {
                int key = releaseSeed + sIdx * 313;
                float h0 = hash01(key, 4161);
                float angle = (float)(-0.54f + h0 * 1.08f + 0.24f * Math.sin(t * 9.0f + sIdx) + preQuake * quakeSnap * 0.16f);
                float dx = (float)Math.cos(angle);
                float dy = (float)Math.sin(angle);
                float nx = -dy;
                float ny = dx;
                float off = minDim * (-0.40f + sIdx * 0.14f + (hash01(key, 4167) - 0.5f) * 0.30f + quakeSnap * preQuake * 0.18f);
                ArrayList<float[]> sweep = new ArrayList<>(4);
                sweep.add(new float[]{x - dx * width * 1.35f + nx * off, y - dy * width * 1.35f + ny * off});
                sweep.add(new float[]{x - dx * width * 0.45f + nx * (off + minDim * 0.03f), y - dy * width * 0.45f + ny * (off + minDim * 0.03f)});
                sweep.add(new float[]{x + dx * width * 0.45f + nx * (off - minDim * 0.02f), y + dy * width * 0.45f + ny * (off - minDim * 0.02f)});
                sweep.add(new float[]{x + dx * width * 1.35f + nx * off, y + dy * width * 1.35f + ny * off});
                float sw = minDim * (0.032f + 0.022f * hash01(key, 4171)) * (0.8f + 1.2f * beamSurge + 0.44f * preQuake);
                drawTaperedStrip(sweep, sw * 3.3f, 1.00f, 0.33f, 0.00f, a * Math.max(beamSurge, preQuake * 0.65f) * 0.028f * finalClean);
                drawTaperedStrip(sweep, sw * 1.05f, 1.00f, 0.95f, 0.42f, a * Math.max(beamSurge, preQuake * 0.65f) * 0.090f * finalClean);
                drawTaperedStrip(sweep, Math.max(0.8f, sw * 0.15f), 1.00f, 1.00f, 0.93f, a * Math.max(beamSurge, preQuake * 0.65f) * 0.140f * finalClean);
            }

            // 热浪/冲击环：只保留断续弧线与外推空气波，避免形成单调大圆盘。
            for (int j = 0; j < 8; j++) {
                float h = hash01(releaseSeed + j * 271, 4201);
                float r = minDim * (0.08f + 0.105f * j + beamSurge * (0.18f + h * 0.20f));
                float start = (float)(h * Math.PI * 2.0 + t * 2.5f + tremor * 0.3f);
                float sweep = (float)Math.PI * (0.26f + hash01(releaseSeed + j, 4207) * 0.74f);
                float alpha = a * (0.078f - j * 0.006f) * beamSurge * finalClean;
                drawArcStrip(x, y, r, Math.max(1.0f, minDim * (0.0060f + j * 0.0009f)), start, sweep,
                        1.00f, 0.64f + h * 0.20f, 0.05f, alpha, 44);
                drawArcStrip(x, y, r * 1.018f, Math.max(0.65f, minDim * 0.0016f), start + 0.07f, sweep * 0.58f,
                        1.00f, 1.00f, 0.80f, alpha * 0.78f, 34);
            }

            drawReleaseParticleFlood(x, y, t, visibleRelease, a, minDim, preQuake, floodSurge);
        }

        private void drawQuakeTearBands(float cx, float cy, float minDim, float quake, float strobe, float elapsed, float alpha) {
            if (quake <= 0.005f || alpha <= 0f) return;
            int bands = cfg.powerSave ? 5 : 9;
            for (int i = 0; i < bands; i++) {
                int key = releaseSeed + i * 881;
                float h0 = hash01(key, 3841);
                float h1 = hash01(key, 3847);
                float angle = (float)(-0.42f + h0 * 0.84f + quake * (((i & 1) == 0) ? 0.16f : -0.16f));
                float dx = (float)Math.cos(angle);
                float dy = (float)Math.sin(angle);
                float nx = -dy;
                float ny = dx;
                float gate = (((int)Math.floor(elapsed * (26f + i * 1.7f) + h1 * 9f)) & 1) == 0 ? 1f : -1f;
                float off = minDim * (-0.46f + i * 0.12f + (h1 - 0.5f) * 0.16f + gate * quake * 0.20f);
                float widthPx = minDim * (0.010f + h0 * 0.024f) * (1.0f + quake * 1.6f);
                ArrayList<float[]> band = new ArrayList<>(4);
                band.add(new float[]{cx - dx * width * 1.35f + nx * off, cy - dy * width * 1.35f + ny * off});
                band.add(new float[]{cx - dx * width * 0.40f + nx * (off + gate * minDim * 0.045f), cy - dy * width * 0.40f + ny * (off + gate * minDim * 0.045f)});
                band.add(new float[]{cx + dx * width * 0.52f + nx * (off - gate * minDim * 0.035f), cy + dy * width * 0.52f + ny * (off - gate * minDim * 0.035f)});
                band.add(new float[]{cx + dx * width * 1.35f + nx * off, cy + dy * width * 1.35f + ny * off});
                float a = alpha * quake * (0.048f + h1 * 0.054f) * (0.55f + 0.45f * strobe);
                drawTaperedStrip(band, widthPx * 5.2f, 1.00f, 0.18f, 0.00f, a * 0.30f);
                drawTaperedStrip(band, widthPx * 1.8f, 1.00f, 0.88f, 0.32f, a * 0.66f);
                drawTaperedStrip(band, Math.max(0.9f, widthPx * 0.28f), 1.00f, 1.00f, 0.96f, a * 1.10f);
            }
        }

        private void drawReleaseParticleFlood(float cx, float cy, float local, float release, float alpha, float minDim, float quake, float floodSurge) {
            int count = cfg.powerSave ? 110 : 230;
            for (int i = 0; i < count; i++) {
                int key = releaseSeed + i * 307;
                float h0 = hash01(key, 4301);
                float h1 = hash01(key, 4303);
                float h2 = hash01(key, 4307);
                float h3 = hash01(key, 4311);
                float h4 = hash01(key, 4319);
                float born = h0 * 0.22f;
                float life = 0.46f + h1 * 0.46f;
                float u = clamp((local - born) / Math.max(0.001f, life), 0f, 1f);
                float live = smooth(Math.min(1f, u / 0.045f)) * (1f - smooth(Math.max(0f, (u - 0.78f) / 0.22f))) * release * (0.55f + 0.85f * floodSurge);
                if (live <= 0.002f) continue;
                float ang = (float)(h2 * Math.PI * 2.0 + 0.18f * Math.sin(u * 9.0f + h3 * 6.28f) + quake * (h4 - 0.5f) * 0.92f);
                float dist = minDim * (0.030f + (0.35f + h3 * 1.30f) * (float)Math.pow(u, 0.50f));
                float drift = minDim * (h4 - 0.5f) * 0.18f * u * u;
                float nx = (float)Math.cos(ang);
                float ny = (float)Math.sin(ang);
                float tx = -ny;
                float ty = nx;
                float x = cx + nx * dist + tx * drift;
                float y = cy + ny * dist + ty * drift;
                float sz = minDim * (0.0030f + h4 * 0.0125f) * (1.12f - u * 0.46f) * (0.90f + floodSurge * 0.32f);
                float rot = ang + h0 * 2.8f + local * (1.2f + h1 * 2.0f);
                float a = alpha * live * (0.22f + h1 * 0.34f);
                if ((i & 3) == 0) {
                    ArrayList<float[]> poly = new ArrayList<>(4);
                    float co = (float)Math.cos(rot), si = (float)Math.sin(rot);
                    float rx = sz * (1.6f + h3 * 2.4f);
                    float ry = sz * (0.38f + h2 * 0.60f);
                    poly.add(new float[]{x + co * rx, y + si * rx});
                    poly.add(new float[]{x - si * ry, y + co * ry});
                    poly.add(new float[]{x - co * rx * 0.68f, y - si * rx * 0.68f});
                    poly.add(new float[]{x + si * ry, y - co * ry});
                    drawFilledPolygon(poly, 1.00f, 0.65f + h1 * 0.28f, 0.04f, a * 0.72f);
                    drawCircle(x, y, Math.max(0.6f, sz * 0.30f), 1f, 1f, 0.90f, a * 0.78f, 10);
                } else if ((i & 3) == 1) {
                    drawEllipse(x, y, sz * (1.8f + h2 * 1.8f), sz * (0.28f + h1 * 0.34f), rot,
                            1.00f, 0.42f + h1 * 0.30f, 0.00f, a * 0.98f, 10);
                    drawEllipse(x, y, sz * 0.80f, Math.max(0.35f, sz * 0.11f), rot, 1f, 1f, 0.86f, a * 0.76f, 8);
                } else if ((i & 3) == 2) {
                    ArrayList<float[]> comet = new ArrayList<>(3);
                    float tail = sz * (3.6f + h1 * 5.0f);
                    comet.add(new float[]{x - nx * tail, y - ny * tail});
                    comet.add(new float[]{x - nx * tail * 0.42f + tx * sz * 0.35f, y - ny * tail * 0.42f + ty * sz * 0.35f});
                    comet.add(new float[]{x, y});
                    drawTaperedStrip(comet, Math.max(0.55f, sz * (0.65f + h2)), 1.00f, 0.92f, 0.26f, a * 0.54f);
                    drawCircle(x, y, Math.max(0.5f, sz * 0.34f), 1f, 1f, 1f, a * 0.56f, 8);
                } else {
                    drawCircle(x, y, sz * (0.40f + h2 * 0.55f), 1.00f, 0.88f, 0.20f, a * 0.42f, 10);
                    drawEllipse(x + tx * sz * 0.20f, y + ty * sz * 0.20f, sz * (0.72f + h1), sz * 0.16f, rot, 1f, 1f, 0.94f, a * 0.66f, 8);
                }
            }
        }

        private void drawCircle(float cx, float cy, float radius, float r, float g, float b, float a, int segments) {
            if (a <= 0f || radius <= 0f) return;
            float[] verts = new float[(segments + 2) * 2];
            putNdc(verts, 0, cx, cy);
            int vi = 2;
            for (int i = 0; i <= segments; i++) {
                float ang = i / (float)segments * (float)Math.PI * 2f;
                putNdc(verts, vi, cx + (float)Math.cos(ang) * radius, cy + (float)Math.sin(ang) * radius);
                vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_FAN, r, g, b, a);
        }

        private void drawRing(float cx, float cy, float radius, float widthPx, float r, float g, float b, float a, int segments) {
            if (a <= 0f || radius <= 0f || widthPx <= 0f) return;
            float[] verts = new float[(segments + 1) * 2 * 2];
            int vi = 0;
            for (int i = 0; i <= segments; i++) {
                float ang = i / (float)segments * (float)Math.PI * 2f;
                float co = (float)Math.cos(ang);
                float si = (float)Math.sin(ang);
                putNdc(verts, vi, cx + co * (radius + widthPx), cy + si * (radius + widthPx)); vi += 2;
                putNdc(verts, vi, cx + co * Math.max(0f, radius - widthPx), cy + si * Math.max(0f, radius - widthPx)); vi += 2;
            }
            drawColorVertices(verts, GLES20.GL_TRIANGLE_STRIP, r, g, b, a);
        }

        private void putNdc(float[] verts, int idx, float x, float y) {
            verts[idx] = x / Math.max(1f, width) * 2f - 1f;
            verts[idx + 1] = 1f - y / Math.max(1f, height) * 2f;
        }

        private void drawColorVertices(float[] verts, int mode, float r, float g, float b, float a) {
            GLES20.glUseProgram(colorProgram);
            int aPos = GLES20.glGetAttribLocation(colorProgram, "aPosition");
            int uColor = GLES20.glGetUniformLocation(colorProgram, "uColor");
            FloatBuffer buf = makeFloatBuffer(verts);
            GLES20.glEnableVertexAttribArray(aPos);
            GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 0, buf);
            GLES20.glUniform4f(uColor, r, g, b, clamp(a, 0f, 1f));
            GLES20.glDrawArrays(mode, 0, verts.length / 2);
            GLES20.glDisableVertexAttribArray(aPos);
        }

        private void drawTexture(int textureId, float fade) {
            float[] verts = new float[]{
                    -1f, -1f, 0f, 0f,
                     1f, -1f, 1f, 0f,
                    -1f,  1f, 0f, 1f,
                     1f,  1f, 1f, 1f
            };
            GLES20.glUseProgram(textureProgram);
            int aPos = GLES20.glGetAttribLocation(textureProgram, "aPosition");
            int aTex = GLES20.glGetAttribLocation(textureProgram, "aTexCoord");
            int uTex = GLES20.glGetUniformLocation(textureProgram, "uTexture");
            int uFade = GLES20.glGetUniformLocation(textureProgram, "uFade");
            FloatBuffer buf = makeFloatBuffer(verts);
            buf.position(0);
            GLES20.glEnableVertexAttribArray(aPos);
            GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 16, buf);
            buf.position(2);
            GLES20.glEnableVertexAttribArray(aTex);
            GLES20.glVertexAttribPointer(aTex, 2, GLES20.GL_FLOAT, false, 16, buf);
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId);
            GLES20.glUniform1i(uTex, 0);
            GLES20.glUniform1f(uFade, fade);
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4);
            GLES20.glDisableVertexAttribArray(aPos);
            GLES20.glDisableVertexAttribArray(aTex);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0);
        }

        private int createProgram(String vs, String fs) {
            int v = compileShader(GLES20.GL_VERTEX_SHADER, vs);
            int f = compileShader(GLES20.GL_FRAGMENT_SHADER, fs);
            int p = GLES20.glCreateProgram();
            GLES20.glAttachShader(p, v);
            GLES20.glAttachShader(p, f);
            GLES20.glLinkProgram(p);
            int[] ok = new int[1];
            GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, ok, 0);
            GLES20.glDeleteShader(v);
            GLES20.glDeleteShader(f);
            if (ok[0] == 0) {
                GLES20.glDeleteProgram(p);
                return 0;
            }
            return p;
        }

        private int compileShader(int type, String source) {
            int s = GLES20.glCreateShader(type);
            GLES20.glShaderSource(s, source);
            GLES20.glCompileShader(s);
            int[] ok = new int[1];
            GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, ok, 0);
            if (ok[0] == 0) {
                GLES20.glDeleteShader(s);
                return 0;
            }
            return s;
        }

        private FloatBuffer makeFloatBuffer(float[] data) {
            ByteBuffer bb = ByteBuffer.allocateDirect(data.length * 4);
            bb.order(ByteOrder.nativeOrder());
            FloatBuffer fb = bb.asFloatBuffer();
            fb.put(data);
            fb.position(0);
            return fb;
        }

        private void deleteFbos() {
            if (fbo[0] != 0 || fbo[1] != 0) GLES20.glDeleteFramebuffers(2, fbo, 0);
            if (tex[0] != 0 || tex[1] != 0) GLES20.glDeleteTextures(2, tex, 0);
            fbo[0] = fbo[1] = tex[0] = tex[1] = 0;
            fboReady = false;
        }

        private void releaseGl() {
            try {
                deleteFbos();
                if (textureProgram != 0) GLES20.glDeleteProgram(textureProgram);
                if (colorProgram != 0) GLES20.glDeleteProgram(colorProgram);
                if (egl != null && eglDisplay != null) {
                    egl.eglMakeCurrent(eglDisplay, EGL10.EGL_NO_SURFACE, EGL10.EGL_NO_SURFACE, EGL10.EGL_NO_CONTEXT);
                    if (eglSurface != null && eglSurface != EGL10.EGL_NO_SURFACE) egl.eglDestroySurface(eglDisplay, eglSurface);
                    if (eglContext != null && eglContext != EGL10.EGL_NO_CONTEXT) egl.eglDestroyContext(eglDisplay, eglContext);
                    egl.eglTerminate(eglDisplay);
                }
            } catch (Throwable ignored) {}
        }

        private void ensureCycleState(boolean force) {
            long wallNow = System.currentTimeMillis();
            String sig = cycleConfigSignature();
            long savedStart = prefs.getLong("cycleStartWallMs", 0L);
            float savedDuration = prefs.getFloat("cycleDurationSec", 0f);
            String savedSig = prefs.getString("cycleConfigSignature", "");
            boolean missing = savedStart <= 0L || savedDuration <= 0f;
            boolean configChanged = !sig.equals(savedSig);
            boolean completed = !missing && wallNow - savedStart >= (long)(savedDuration * 1000f);
            if (force || missing || configChanged || completed) {
                beginNewCycle(wallNow);
            } else {
                cycleStartWallMs = savedStart;
                cycleDurationSec = savedDuration;
                cycleCriticalStartSec = prefs.getFloat("cycleCriticalStartSec", 0f);
                cycleReleaseStartSec = prefs.getFloat("cycleReleaseStartSec", Math.max(0f, savedDuration - 60f));
                cycleReleaseDurationSec = prefs.getFloat("cycleReleaseDurationSec", 12f);
                cycleAfterglowDurationSec = prefs.getFloat("cycleAfterglowDurationSec", 24f);
                cycleCriticalDurationSec = prefs.getFloat("cycleCriticalDurationSec", 60f);
                cycleSignature = savedSig;
            }
        }

        private void beginNewCycle(long wallNow) {
            cycleStartWallMs = wallNow;
            cycleDurationSec = chooseCycleDurationSec();
            cycleSignature = cycleConfigSignature();
            CyclePlan plan = randomPlanForDuration(cycleDurationSec);
            cycleCriticalStartSec = plan.criticalStartSec;
            cycleReleaseStartSec = plan.releaseStartSec;
            cycleReleaseDurationSec = plan.releaseDurationSec;
            cycleAfterglowDurationSec = plan.afterglowDurationSec;
            cycleCriticalDurationSec = plan.criticalDurationSec;
            prefs.edit()
                    .putLong("cycleStartWallMs", cycleStartWallMs)
                    .putFloat("cycleDurationSec", cycleDurationSec)
                    .putFloat("cycleCriticalStartSec", cycleCriticalStartSec)
                    .putFloat("cycleReleaseStartSec", cycleReleaseStartSec)
                    .putFloat("cycleReleaseDurationSec", cycleReleaseDurationSec)
                    .putFloat("cycleAfterglowDurationSec", cycleAfterglowDurationSec)
                    .putFloat("cycleCriticalDurationSec", cycleCriticalDurationSec)
                    .putString("cycleConfigSignature", cycleSignature)
                    .apply();
            startMs = SystemClock.elapsedRealtime();
            nextSpawnSec = 0f;
            nextHardClearSec = 6f + random.nextFloat() * 12f;
            lastVisualSec = -1f;
            releasePulseArmed = true;
            releaseSeed = random.nextInt();
            strokes.clear();
            resetSpawnHeat();
            clearFbos();
        }

        private void clearFbos() {
            if (!fboReady) return;
            for (int i = 0; i < 2; i++) {
                GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, fbo[i]);
                GLES20.glClearColor(0f, 0f, 0f, 1f);
                GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
            }
            GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0);
        }

        private float currentCycleElapsedSec() {
            if (cycleStartWallMs <= 0L) return (SystemClock.elapsedRealtime() - startMs) / 1000f;
            return Math.max(0f, (System.currentTimeMillis() - cycleStartWallMs) / 1000f);
        }

        private CyclePlan storedCyclePlan(float durationSec) {
            CyclePlan p = new CyclePlan();
            p.durationSec = durationSec;
            p.criticalStartSec = cycleCriticalStartSec;
            p.releaseStartSec = cycleReleaseStartSec;
            p.releaseDurationSec = cycleReleaseDurationSec;
            p.afterglowDurationSec = cycleAfterglowDurationSec;
            p.criticalDurationSec = cycleCriticalDurationSec;
            return p.sanitized();
        }

        private CyclePlan previewPlan(float durationSec) {
            // 预览模式仍遵守“只出现一次释放/余韵”，但把真实天级周期压缩到几分钟。
            CyclePlan p = new CyclePlan();
            p.durationSec = durationSec;
            float seedLike = stable01("preview-release");
            p.releaseDurationSec = durationFromRatioAndRange(durationSec, cfg.ratioRelease, cfg.releaseMinSec, cfg.releaseMaxSec, false);
            p.afterglowDurationSec = durationFromRatioAndRange(durationSec, cfg.ratioAfterglow, cfg.afterglowMinSec, cfg.afterglowMaxSec, false);
            p.criticalDurationSec = durationFromRatioAndRange(durationSec, cfg.ratioCritical, cfg.criticalMinSec, cfg.criticalMaxSec, false);
            float latest = Math.max(1f, durationSec - p.releaseDurationSec - p.afterglowDurationSec - 1f);
            float earliest = Math.min(latest, Math.max(1f, durationSec * 0.34f));
            p.releaseStartSec = earliest + (latest - earliest) * seedLike;
            p.criticalStartSec = Math.max(0f, p.releaseStartSec - p.criticalDurationSec);
            return p.sanitized();
        }

        private CyclePlan randomPlanForDuration(float durationSec) {
            CyclePlan p = new CyclePlan();
            p.durationSec = durationSec;
            p.releaseDurationSec = durationFromRatioAndRange(durationSec, cfg.ratioRelease, cfg.releaseMinSec, cfg.releaseMaxSec, true);
            p.afterglowDurationSec = durationFromRatioAndRange(durationSec, cfg.ratioAfterglow, cfg.afterglowMinSec, cfg.afterglowMaxSec, true);
            p.criticalDurationSec = durationFromRatioAndRange(durationSec, cfg.ratioCritical, cfg.criticalMinSec, cfg.criticalMaxSec, true);
            float minPre = Math.max(60f, Math.min(3600f, durationSec * 0.035f));
            float latest = Math.max(minPre, durationSec - p.releaseDurationSec - p.afterglowDurationSec - 60f);
            p.releaseStartSec = minPre + random.nextFloat() * Math.max(0f, latest - minPre);
            p.criticalStartSec = Math.max(0f, p.releaseStartSec - p.criticalDurationSec);
            return p.sanitized();
        }

        private float durationFromRatioAndRange(float totalSec, float ratio, float minSec, float maxSec, boolean randomize) {
            float min = Math.min(minSec, maxSec);
            float max = Math.max(minSec, maxSec);
            // 阶段比例给出该阶段在本轮周期中的目标长度；用户设置的秒级范围是硬边界。
            // 如果目标超出范围，就被钳制到范围内，因此“短阶段持续时间范围”一定真实生效。
            // 若目标位于范围内，随机项只做轻微扰动，避免每轮完全机械一致。
            float target = clamp(totalSec * Math.max(0.0001f, ratio), min, max);
            float jitter = randomize ? randRange(min, max) : stableRange(min, max, "dur-" + Math.round(totalSec) + ":" + Math.round(ratio * 10000f));
            return clamp(lerp(target, jitter, 0.22f), min, max);
        }

        private float stableRange(float a, float b, String salt) {
            float min = Math.min(a, b);
            float max = Math.max(a, b);
            return min + stable01(salt) * Math.max(0f, max - min);
        }

        private float stable01(String salt) {
            int h = (cycleSignature + ":" + salt).hashCode();
            long v = h & 0x7fffffffL;
            return (v % 1000000L) / 1000000f;
        }

        private float randRange(float a, float b) {
            float min = Math.min(a, b);
            float max = Math.max(a, b);
            return min + random.nextFloat() * Math.max(0f, max - min);
        }

        private float chooseCycleDurationSec() {
            float minDays = clamp(cfg.cycleMinDays, 1f, 365f);
            float maxDays = clamp(cfg.cycleMaxDays, minDays, 365f);
            float days;
            if (cfg.randomCycle) days = minDays + random.nextFloat() * Math.max(0f, maxDays - minDays);
            else days = clamp(cfg.fixedCycleDays, minDays, maxDays);
            return Math.max(86400f, days * 86400f);
        }

        private String cycleConfigSignature() {
            return cfg.randomCycle + ":" + Math.round(cfg.cycleMinDays * 10f) + ":" + Math.round(cfg.cycleMaxDays * 10f)
                    + ":" + Math.round(cfg.fixedCycleDays * 10f) + ":" + Math.round(cfg.ratioSeparation * 1000f)
                    + ":" + Math.round(cfg.ratioAttraction * 1000f) + ":" + Math.round(cfg.ratioSync * 1000f)
                    + ":" + Math.round(cfg.ratioCritical * 1000f) + ":" + Math.round(cfg.ratioRelease * 1000f)
                    + ":" + Math.round(cfg.ratioAfterglow * 1000f) + ":" + Math.round(cfg.criticalMinSec) + ":" + Math.round(cfg.criticalMaxSec)
                    + ":" + Math.round(cfg.releaseMinSec) + ":" + Math.round(cfg.releaseMaxSec)
                    + ":" + Math.round(cfg.afterglowMinSec) + ":" + Math.round(cfg.afterglowMaxSec);
        }

        private void readConfig(boolean force) {
            long now = SystemClock.elapsedRealtime();
            if (!force && !configDirty && now - lastConfigRead < 500L) return;
            lastConfigRead = now;
            configDirty = false;
            String oldVisualSignature = visualConfigSignature;
            cfg.style = prefs.getInt("style", 0);
            cfg.intimacy = prefs.getFloat("intimacy", 0.72f);
            cfg.randomness = prefs.getFloat("randomness", 0.66f);
            cfg.ribbonWidth = prefs.getFloat("ribbonWidth", 0.62f);
            cfg.trail = prefs.getFloat("trail", 0.90f);
            cfg.fullScreenCoverage = prefs.getFloat("fullScreenCoverage", 0.96f);
            cfg.strokeDensity = prefs.getFloat("strokeDensity", 0.24f);
            cfg.previewAccelerated = prefs.getBoolean("previewAccelerated", false);
            cfg.previewCycleMinutes = clamp(prefs.getFloat("previewCycleMinutes", 3f), 0.5f, 60f);
            cfg.debugLoopEnabled = prefs.getBoolean("debugLoopEnabled", false);
            cfg.debugCycleMinutes = clamp(prefs.getFloat("debugCycleMinutes", 3f), 1f, 60f);
            cfg.bubbles = prefs.getBoolean("bubbles", true);
            cfg.powerSave = prefs.getBoolean("powerSave", false);
            cfg.cycleMinDays = clamp(prefs.getFloat("cycleMinDays", 1f), 1f, 365f);
            cfg.cycleMaxDays = clamp(prefs.getFloat("cycleMaxDays", 365f), cfg.cycleMinDays, 365f);
            cfg.fixedCycleDays = clamp(prefs.getFloat("fixedCycleDays", 30f), cfg.cycleMinDays, cfg.cycleMaxDays);
            cfg.randomCycle = prefs.getBoolean("randomCycle", true);
            cfg.ratioSeparation = prefs.getFloat("ratioSeparation", 0.46f);
            cfg.ratioAttraction = prefs.getFloat("ratioAttraction", 0.22f);
            cfg.ratioSync = prefs.getFloat("ratioSync", 0.22f);
            cfg.ratioCritical = prefs.getFloat("ratioCritical", 0.06f);
            cfg.ratioRelease = prefs.getFloat("ratioRelease", 0.02f);
            cfg.ratioAfterglow = prefs.getFloat("ratioAfterglow", 0.02f);
            cfg.criticalMinSec = clamp(prefs.getFloat("criticalMinSec", 30f), 5f, 3600f);
            cfg.criticalMaxSec = clamp(prefs.getFloat("criticalMaxSec", 180f), cfg.criticalMinSec, 7200f);
            cfg.releaseMinSec = clamp(prefs.getFloat("releaseMinSec", 8f), 2f, 600f);
            cfg.releaseMaxSec = clamp(prefs.getFloat("releaseMaxSec", 24f), cfg.releaseMinSec, 1200f);
            cfg.afterglowMinSec = clamp(prefs.getFloat("afterglowMinSec", 20f), 3f, 1800f);
            cfg.afterglowMaxSec = clamp(prefs.getFloat("afterglowMaxSec", 90f), cfg.afterglowMinSec, 3600f);
            normalizeRatios(cfg);
            visualConfigSignature = buildVisualConfigSignature();
            if (force || !visualConfigSignature.equals(oldVisualSignature)) {
                strokes.clear();
                resetSpawnHeat();
                nextSpawnSec = 0f;
                nextHardClearSec = 6f + random.nextFloat() * 12f;
                startMs = SystemClock.elapsedRealtime();
                lastVisualSec = -1f;
                releasePulseArmed = true;
                if (fboReady) clearFbos();
            }
            ensureCycleState(force);
        }

        private String buildVisualConfigSignature() {
            return cfg.style + ":" + Math.round(cfg.intimacy * 1000f)
                    + ":" + Math.round(cfg.randomness * 1000f)
                    + ":" + Math.round(cfg.ribbonWidth * 1000f)
                    + ":" + Math.round(cfg.trail * 1000f)
                    + ":" + Math.round(cfg.fullScreenCoverage * 1000f)
                    + ":" + Math.round(cfg.strokeDensity * 1000f)
                    + ":" + cfg.debugLoopEnabled + ":" + Math.round(cfg.debugCycleMinutes * 1000f)
                    + ":" + cfg.bubbles + ":" + cfg.powerSave;
        }

        private void normalizeRatios(Config c) {
            c.ratioSeparation = Math.max(0.01f, c.ratioSeparation);
            c.ratioAttraction = Math.max(0.01f, c.ratioAttraction);
            c.ratioSync = Math.max(0.01f, c.ratioSync);
            c.ratioCritical = Math.max(0.005f, c.ratioCritical);
            c.ratioRelease = Math.max(0.002f, c.ratioRelease);
            c.ratioAfterglow = Math.max(0.002f, c.ratioAfterglow);
            float sum = c.ratioSeparation + c.ratioAttraction + c.ratioSync + c.ratioCritical + c.ratioRelease + c.ratioAfterglow;
            if (sum <= 0f) {
                c.ratioSeparation = 0.46f; c.ratioAttraction = 0.22f; c.ratioSync = 0.22f;
                c.ratioCritical = 0.06f; c.ratioRelease = 0.02f; c.ratioAfterglow = 0.02f;
                return;
            }
            c.ratioSeparation /= sum;
            c.ratioAttraction /= sum;
            c.ratioSync /= sum;
            c.ratioCritical /= sum;
            c.ratioRelease /= sum;
            c.ratioAfterglow /= sum;
        }

        private int[] palette(int style) {
            switch (Math.floorMod(style, 5)) {
                case 1: return new int[]{0xFF34D399, 0xFF67E8F9, 0xFF93C5FD, 0xFFFDE68A, 0xFF020617};
                case 2: return new int[]{0xFFA78BFA, 0xFFD8B4FE, 0xFFF472B6, 0xFFFFFFFF, 0xFF050316};
                case 3: return new int[]{0xFFE5E7EB, 0xFFFFFFFF, 0xFF93C5FD, 0xFFD1D5DB, 0xFF000000};
                case 4: return new int[]{0xFFFDE68A, 0xFFFFF7ED, 0xFFFB7185, 0xFFF97316, 0xFF06030A};
                default: return new int[]{0xFF7DD3FC, 0xFFC4B5FD, 0xFFF472B6, 0xFFFDE68A, 0xFF030712};
            }
        }

        private int pickColor(int[] colors) { return colors[random.nextInt(4)]; }
        private static float catmull(float p0, float p1, float p2, float p3, float t) {
            float t2 = t * t;
            float t3 = t2 * t;
            return 0.5f * ((2f * p1) + (-p0 + p2) * t + (2f*p0 - 5f*p1 + 4f*p2 - p3) * t2 + (-p0 + 3f*p1 - 3f*p2 + p3) * t3);
        }
        private float distance(float x0, float y0, float x1, float y1) {
            float dx = x1 - x0, dy = y1 - y0;
            return (float)Math.sqrt(dx * dx + dy * dy);
        }
        private float[] color4(int color, float alpha) {
            return new float[]{Color.red(color)/255f, Color.green(color)/255f, Color.blue(color)/255f, clamp(alpha, 0f, 1f)};
        }
        private static int clampInt(int v, int a, int b) { return Math.max(a, Math.min(b, v)); }
        private static float clamp(float v, float a, float b) { return Math.max(a, Math.min(b, v)); }
        private static float fract(float v) { return v - (float)Math.floor(v); }
        private static float lerp(float a, float b, float t) { return a + (b - a) * t; }
        private static float smooth(float x) { x = clamp(x, 0f, 1f); return x * x * (3f - 2f * x); }
        private static void sleepQuiet(long ms) { try { Thread.sleep(ms); } catch (InterruptedException ignored) {} }

        private static final String TEXTURE_VERTEX =
                "attribute vec2 aPosition;\n" +
                "attribute vec2 aTexCoord;\n" +
                "varying vec2 vTexCoord;\n" +
                "void main(){ gl_Position = vec4(aPosition, 0.0, 1.0); vTexCoord = aTexCoord; }";
        private static final String TEXTURE_FRAGMENT =
                "precision mediump float;\n" +
                "uniform sampler2D uTexture;\n" +
                "uniform float uFade;\n" +
                "varying vec2 vTexCoord;\n" +
                // V29 phosphor decay：不是简单乘 fade，而是每帧轻微扣黑，
                // 让尾迹像参考视频那样先失彩、再变细、最后被黑场吞没。
                "void main(){ vec4 c = texture2D(uTexture, vTexCoord); vec3 rgb = max(c.rgb * uFade - vec3(0.00235), vec3(0.0)); rgb = pow(rgb, vec3(1.010)); gl_FragColor = vec4(rgb, 1.0); }";
        private static final String COLOR_VERTEX =
                "attribute vec2 aPosition;\n" +
                "void main(){ gl_Position = vec4(aPosition, 0.0, 1.0); }";
        private static final String COLOR_FRAGMENT =
                "precision mediump float;\n" +
                "uniform vec4 uColor;\n" +
                "void main(){ gl_FragColor = uColor; }";
    }

    static final class StrokeEvent {
        final int count;
        final float[] x, y, vx, vy;
        RectF bounds = new RectF();
        StrokeEvent partner;
        float age = 0f;
        float life = 3f;
        float seed = 0f;
        float widthScale = 1f;
        float speed = 80f;
        float turn = 0.4f;
        float relation = 0f;
        float visibleWindow = 0.26f;
        float headLead = 0.10f;
        float attractX = 0f;
        float attractY = 0f;
        int colorA = Color.WHITE;
        int colorB = Color.WHITE;
        int actor = 0;
        // V29 art motif: 0 comet arc, 1 veil ribbon, 2 electronic fan, 3 silver blade,
        // 4 petal hook, 5 prism polygon, 6 falling leaf, 7 long bridge,
        // 8 jellyfish tendril, 9 nebula coil, 10 origami sheet, 11 constellation chain,
        // 12 liquid pod, 13 wing, 14 blossom, 15 silk banner, 16 orbit halo, 17 crystal shard.
        int motif = 0;
        int variant = 0;
        float motifStrength = 1f;
        float flowA = 1f;
        float flowB = 1f;
        float flowC = 1f;
        float asymmetry = 0f;
        boolean fan = false;
        int fanLines = 0;
        float fanGapPx = 3f;

        StrokeEvent(int count) {
            this.count = Math.max(2, count);
            x = new float[this.count]; y = new float[this.count];
            vx = new float[this.count]; vy = new float[this.count];
        }
    }

    static final class Config {
        int style = 0;
        float intimacy = 0.72f;
        float randomness = 0.66f;
        float ribbonWidth = 0.62f;
        float trail = 0.90f;
        float fullScreenCoverage = 0.96f;
        float strokeDensity = 0.24f;
        boolean previewAccelerated = false;
        float previewCycleMinutes = 3f;
        boolean debugLoopEnabled = false;
        float debugCycleMinutes = 3f;
        boolean bubbles = false;
        boolean powerSave = false;
        boolean randomCycle = true;
        float cycleMinDays = 1f;
        float cycleMaxDays = 365f;
        float fixedCycleDays = 30f;
        float ratioSeparation = 0.46f;
        float ratioAttraction = 0.22f;
        float ratioSync = 0.22f;
        float ratioCritical = 0.06f;
        float ratioRelease = 0.02f;
        float ratioAfterglow = 0.02f;
        float criticalMinSec = 30f;
        float criticalMaxSec = 180f;
        float releaseMinSec = 8f;
        float releaseMaxSec = 24f;
        float afterglowMinSec = 20f;
        float afterglowMaxSec = 90f;
    }

    static final class CyclePlan {
        float durationSec = 86400f;
        float criticalStartSec = 0f;
        float releaseStartSec = 3600f;
        float releaseDurationSec = 12f;
        float afterglowDurationSec = 24f;
        float criticalDurationSec = 60f;
        private static float cpClamp(float v, float a, float b) { return Math.max(a, Math.min(b, v)); }
        CyclePlan sanitized() {
            durationSec = Math.max(30f, durationSec);
            releaseDurationSec = cpClamp(releaseDurationSec, 1f, Math.max(1f, durationSec * 0.20f));
            afterglowDurationSec = cpClamp(afterglowDurationSec, 1f, Math.max(1f, durationSec * 0.20f));
            criticalDurationSec = cpClamp(criticalDurationSec, 1f, Math.max(1f, durationSec * 0.35f));
            releaseStartSec = cpClamp(releaseStartSec, 1f, Math.max(1f, durationSec - releaseDurationSec - afterglowDurationSec));
            criticalStartSec = cpClamp(releaseStartSec - criticalDurationSec, 0f, releaseStartSec);
            return this;
        }
    }

    static final class Phase {
        final String name;
        final float start, end, intensity, closeness, tension, relation, pairChance, fanChance;
        Phase(String name, float start, float end, float intensity, float closeness, float tension, float relation, float pairChance, float fanChance) {
            this.name = name;
            this.start = start;
            this.end = end;
            this.intensity = intensity;
            this.closeness = closeness;
            this.tension = tension;
            this.relation = relation;
            this.pairChance = pairChance;
            this.fanChance = fanChance;
        }
        static Phase of(float sec, float durationSec, Config cfg, CyclePlan plan) {
            float releaseStart = plan.releaseStartSec;
            float releaseEnd = releaseStart + plan.releaseDurationSec;
            float afterEnd = releaseEnd + plan.afterglowDurationSec;
            float criticalStart = plan.criticalStartSec;

            if (sec >= releaseStart && sec < releaseEnd) {
                return new Phase("释放", releaseStart, releaseEnd, 1.00f, 1.00f, 0.46f, 1.00f, 0.04f, 0.006f);
            }
            if (sec >= releaseEnd && sec < afterEnd) {
                return new Phase("余韵", releaseEnd, afterEnd, 0.22f, 0.54f, 0.08f, 0.12f, 0.02f, 0.004f);
            }
            if (sec >= criticalStart && sec < releaseStart) {
                return new Phase("临界", criticalStart, releaseStart, 0.96f, 0.92f, 1.00f, 0.92f, 0.16f, 0.025f);
            }
            if (sec >= afterEnd) {
                return new Phase("分离", afterEnd, durationSec, 0.08f, 0.00f, 0.04f, 0.00f, 0.00f, 0.004f);
            }

            float pre = Math.max(1f, criticalStart);
            float sum = Math.max(0.001f, cfg.ratioSeparation + cfg.ratioAttraction + cfg.ratioSync);
            float sepDur = pre * (cfg.ratioSeparation / sum);
            float attrDur = pre * (cfg.ratioAttraction / sum);
            float syncDur = Math.max(0f, pre - sepDur - attrDur);
            float sepEnd = sepDur;
            float attrEnd = sepEnd + attrDur;
            float syncEnd = attrEnd + syncDur;
            if (sec < sepEnd) return new Phase("分离", 0f, sepEnd, 0.08f, 0.00f, 0.04f, 0.00f, 0.00f, 0.004f);
            if (sec < attrEnd) return new Phase("吸引", sepEnd, attrEnd, 0.24f, 0.16f, 0.16f, 0.06f, 0.010f, 0.004f);
            return new Phase("同步", attrEnd, Math.max(attrEnd + 0.001f, syncEnd), 0.56f, 0.58f, 0.52f, 0.58f, 0.11f, 0.010f);
        }
    }
}
