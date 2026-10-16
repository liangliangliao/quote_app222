# Flutter Widget 实际渲染预览

从 `test/will_mirror/widget_flow_test.dart` 的 Flutter 渲染树导出，390×844 逻辑像素、2 倍截图。不是设计稿或真实用户数据，也没有伪装成真实模型结果。

- `home.png`：独立模块首页，一次自由输入与三个目的地。
- `top5-synthetic.png`：5 条手写测试候选，仅用于检查手机布局、来源标签与正反理由；不是声称完成了线上 50–70 条生成验收。
- `life-synthetic.png`：两次虚构的本人观察，检查真实道路连接与时间标签；不导入用户个人账本。

生成方式：安装 Noto CJK 字体，运行 `WM_PREVIEW_DIR=/tmp/wm-previews flutter test --no-pub test/will_mirror/widget_flow_test.dart`。

2026-10-16 渐进工作台的实际渲染由 `intent_visual_test.dart` 补充：`intent-understanding.png`、`intent-conflict.png`、`intent-recognition.png`、`intent-routes.png`。它们使用同一个明确标注的虚构 Case，供检查关系、阅读顺序与布局。CI 的 `will-mirror-intent-previews` artifact 会保存这些截图和原有预览；没有把手写候选当作真实模型运行结果。
