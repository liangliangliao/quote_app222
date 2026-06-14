# 书法动态壁纸笔顺数据

书法动态壁纸使用 Hanzi Writer Data 的逐字 JSON 数据：

- 数据入口：`https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1/{汉字}.json`
- 上游项目：<https://github.com/chanind/hanzi-writer-data>
- 原始数据：<https://github.com/skishore/makemeahanzi>

每个字符使用 `medians` 数组作为真实运笔中线。数组顺序就是笔画顺序，
每一笔中的坐标顺序就是起笔到收笔的方向。应用只在用户保存书法壁纸时下载
当前文本涉及的字符，并把结果缓存到 Android 动态壁纸偏好中，因此桌面壁纸
后续可以离线播放。

为降低偶发下载失败，客户端会在 jsDelivr 与 unpkg 两个镜像之间切换，按
4 字一组限流并进行三轮退避重试；已经成功的单字采用增量缓存，不会被一次
不完整的网络请求覆盖。全部汉字获取成功的句子会加入最多 12 条的本地轮播
队列，真实壁纸按保存顺序循环书写，设置页可一键清空队列与笔顺缓存。

Flutter 预览和 Android 真实壁纸统一绘制 `medians` 运笔中线并使用相同笔锋
宽度。Android 不再通过宽蒙版揭示 SVG 外轮廓，因为部分厂商的 Canvas/GPU
会把该离屏混合层错误呈现为白色粗线条。

Hanzi Writer 源码使用 MIT License。Hanzi Writer Data / Make Me a Hanzi
图形数据来自 Arphic PL KaitiM GB 与 Arphic PL UKai，并按 Arphic Public
License 再分发。具体许可说明以两个上游仓库中的许可证文件为准。

## 行书与草书边界

Hanzi Writer Data 提供的是标准汉字笔顺和楷体笔画数据，不是书法家的行书、
草书运笔数据库。行书和草书在连写、省笔、字形变体上可能改变普通楷书笔顺，
因此不能通过随机旋转、倾斜或连线冒充“标准行书/草书”。

当前产品中的“行书笔意”和“草书笔意”只在标准笔顺基础上调整笔锋粗细、圆角
和速度，并在界面中明确标注。若未来接入具有明确授权且包含逐笔轨迹的行草
书法数据集，应为每种书体分别存储路径与笔顺。
