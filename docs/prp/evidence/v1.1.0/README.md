# PRP v1.1.0 Android 验收证据

源码 `4f61139112ac4e68036242a8626653aa53640c13`；[设备工作流](https://github.com/liangliangliao/quote_app222/actions/runs/42220803343)。每系统完整 UI 流程通过、20 项原生检查、17 张实际截图；共 40 项原生检查、34 张图。设备为 disposable emulator，非物理手机，所有报告 `physical_device=false`。

| 编号 | 操作/预期 | Android 8 / API 26 | Android 15 / API 35 |
| --- | --- | --- | --- |
| android_01_off | 设置默认关闭，AI 授权关闭 | [图](android-api-26/android_01_off.png) | [图](android-api-35/android_01_off.png) |
| android_02_enabled | 设置开启及可见快捷入口 | [图](android-api-26/android_02_enabled.png) | [图](android-api-35/android_02_enabled.png) |
| android_03_pause | 缓一缓，分析控件尚不出现 | [图](android-api-26/android_03_pause.png) | [图](android-api-35/android_03_pause.png) |
| android_04_seal_preview | 盖印前的结构化教训 | [图](android-api-26/android_04_seal_preview.png) | [图](android-api-35/android_04_seal_preview.png) |
| android_05_sealed | 长按盖印后的拉远与情绪评分 | [图](android-api-26/android_05_sealed.png) | [图](android-api-35/android_05_sealed.png) |
| android_06_forecast | 预测与实际曲线 | [图](android-api-26/android_06_forecast.png) | [图](android-api-35/android_06_forecast.png) |
| android_07_particles_pressed | 按压时粒子分散 | [图](android-api-26/android_07_particles_pressed.png) | [图](android-api-35/android_07_particles_pressed.png) |
| android_08_particles_released | 松手后回落静止 | [图](android-api-26/android_08_particles_released.png) | [图](android-api-35/android_08_particles_released.png) |
| android_09_draft_quotes | 原创废稿短句 | [图](android-api-26/android_09_draft_quotes.png) | [图](android-api-35/android_09_draft_quotes.png) |
| android_10_playbook_audio | 手册及本地录音/播放 | [图](android-api-26/android_10_playbook_audio.png) | [图](android-api-35/android_10_playbook_audio.png) |
| android_11_observations | 本地观察 | [图](android-api-26/android_11_observations.png) | [图](android-api-35/android_11_observations.png) |
| android_12_own_quote | 原首页画框中的自己的名言 | [图](android-api-26/android_12_own_quote.png) | [图](android-api-35/android_12_own_quote.png) |
| android_13_safety | 危机求助退场 | [图](android-api-26/android_13_safety.png) | [图](android-api-35/android_13_safety.png) |
| android_14_off_retained | 关闭后数据保留 | [图](android-api-26/android_14_off_retained.png) | [图](android-api-35/android_14_off_retained.png) |
| native_01_on | 实际原生闹钟表单显示教训 | [图](android-api-26/native_01_on.png) | [图](android-api-35/native_01_on.png) |
| native_02_off | 关闭后同一表单撤下教训 | [图](android-api-26/native_02_off.png) | [图](android-api-35/native_02_off.png) |
| native_03_overlay | 原生响铃/浮层阶段（API 26 含系统通知条） | [图](android-api-26/native_03_overlay.png) | [图](android-api-35/native_03_overlay.png) |

每个系统的 `acceptance-report.json` 保存源码 SHA、API、逐图 SHA-256 和原生检查名，`flutter-results.json` 保存完整 UI 断言的结果，`native-results.json` 保存原生检查及截图方法。PNG 均核对哈希和尺寸，原始 GitHub artifact ZIP 均验证 CRC；下载校验记录见 `artifact-verification.json`。

- [Android 8 汇总](android-api-26/acceptance-report.json)、[UI 结果](android-api-26/flutter-results.json)、[原生结果](android-api-26/native-results.json)。
- [Android 15 汇总](android-api-35/acceptance-report.json)、[UI 结果](android-api-35/flutter-results.json)、[原生结果](android-api-35/native-results.json)。
- [Dart CI 结果](ci-summary.json)、[发布包与设备源码溯源](production-source-provenance.json)。

API 26 的 `native_03_overlay` 截图包含系统提醒通知条及原生表单；浮层附着、教训文字和可见范围另由实际 View 断言核对。API 35 的第三张图直接显示浮层。两系统的卡片开启/关闭截图均已目视复核，未被系统错误弹窗遮挡。

清除数据和原生结果的判断由数据库、实际 View、MediaPlayer 和服务断言共同完成，截图仅用于核对外观。实际 60 秒暂停、3 秒盖印和 15 秒本地录音均在 UI 流程中执行。测试数据不进入发布 APK。
