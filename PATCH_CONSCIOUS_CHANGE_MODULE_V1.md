# PATCH_CONSCIOUS_CHANGE_MODULE_V1

本补丁新增“有意识的改变”模块，并挂载到首页左侧 Drawer 菜单。

## 新增能力

1. 首页左侧菜单新增“有意识的改变”入口。
2. 新增学习模块：
   - 展示固定核心主题思想文案；
   - 支持导入 txt / docx 学习文档；
   - 自动识别章、小节并按顺序展示；
   - 导入内容保存到本地 sqflite 数据库；
   - 支持全文搜索，结果显示匹配句；
   - 点击搜索结果进入章节详情页并自动滚动到匹配段落，高亮查询文字；
   - 章节详情页展示小节标题、关键词与完整课程内容。

## 主要文件

- `lib/conscious_change/conscious_change_home_page.dart`
- `lib/conscious_change/conscious_change_dao.dart`
- `lib/conscious_change/conscious_change_import_parser.dart`
- `lib/main.dart`
- `pubspec.yaml`

## 依赖

- `archive`：读取 docx zip 包中的 `word/document.xml`
- `xml`：解析 Word 文档 XML 正文
