# 书法动态壁纸笔顺数据

书法动态壁纸使用 Hanzi Writer Data 的逐字 JSON 数据：

- 数据入口：`https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1/{汉字}.json`
- 上游项目：<https://github.com/chanind/hanzi-writer-data>
- 原始数据：<https://github.com/skishore/makemeahanzi>

每个字符使用 `medians` 数组作为真实运笔中线。数组顺序就是笔画顺序，
每一笔中的坐标顺序就是起笔到收笔的方向。应用只在用户保存书法壁纸时下载
当前文本涉及的字符，并把结果缓存到 Android 动态壁纸偏好中，因此桌面壁纸
后续可以离线播放。

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
