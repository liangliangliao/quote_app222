# PRP 界面快照

以下由 `test/prp_plugin/visual_test.dart` 在 Flutter 测试环境生成，尺寸 480 × 1100。为显示中文，测试显式加载仓库自带的楷体、行书及拉丁字体；不代表实际系统字体效果，也不是手机或模拟器截图。对应交互另有 widget 测试覆盖。

| 图片 | 内容 |
| --- | --- |
| [PRP_01_settings_off.png](PRP_01_settings_off.png) | v1.0.1 初始总开关关闭、直接开始入口及版本 |
| [PRP_02_settings_on.png](PRP_02_settings_on.png) | v1.0.1 开启后的开始按钮、盖印数量和调用点条件 |
| [PRP_03_pause.png](PRP_03_pause.png) | 缓一缓，无分析控件 |
| [PRP_04_seal_preview.png](PRP_04_seal_preview.png) | 双栏摘要、如果—那么、自己的名言同意和盖印预览 |
| [PRP_05_playbook.png](PRP_05_playbook.png) | 已盖印手册和自己的名言同意 |
| [PRP_06_recall.png](PRP_06_recall.png) | 下次回访及显式结果反馈 |
| [PRP_07_dark_host.png](PRP_07_dark_host.png) | 深色敌人宿主中浅色卡片的文字对比 |
| [PRP_08_safety_exit.png](PRP_08_safety_exit.png) | 危机输入后的安全提示及求助入口 |
| [PRP_09_settings_entry.png](PRP_09_settings_entry.png) | v1.0.1 设置首页直达 PRP 的卡片 |

复验：`flutter test --no-pub test/prp_plugin/visual_test.dart`。经人工检查后重新生成：`flutter test --no-pub --update-goldens test/prp_plugin/visual_test.dart`。真机检查清单见根目录审计文档。
