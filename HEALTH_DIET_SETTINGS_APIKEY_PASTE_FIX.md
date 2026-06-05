# 健康饮食配置页 API Key 粘贴能力修复

## 修复内容

健康饮食配置页中的敏感密钥字段仍然默认隐藏，但现在支持更方便地直接粘贴密钥。

## 具体改动

修改文件：

- `lib/health_diet/pages/health_diet_settings_page.dart`

新增能力：

1. 每个敏感密钥输入框右侧新增“粘贴”按钮。
2. 点击粘贴按钮后，会读取系统剪贴板文本并直接写入当前密钥框。
3. 粘贴后会自动把光标移动到文本末尾。
4. 剪贴板为空时会显示提示，不会覆盖原有内容。
5. 密钥输入框仍支持长按输入框后使用系统粘贴菜单。
6. 密钥默认隐藏，仍可通过右侧眼睛按钮或“临时显示密钥内容”开关查看。

## 涉及字段

- USDA FoodData Central API Key
- 薄荷健康 API Key
- Edamam App ID
- Edamam App Key
- Spoonacular API Key

Open Food Facts User-Agent 不是密钥，仍保持普通明文输入框。
