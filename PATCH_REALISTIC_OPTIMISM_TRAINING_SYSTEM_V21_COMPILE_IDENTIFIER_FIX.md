# PATCH_REALISTIC_OPTIMISM_TRAINING_SYSTEM_V21_COMPILE_IDENTIFIER_FIX

## 修复目标
根据 CI 编译日志修复 v20 版本中的 Dart 编译失败。

## 根因
v20 为了把界面英文术语改为中文时，使用了过宽的文本替换规则，误把 Dart 标识符里的 `App` 替换成了中文“应用”，导致 Dart 编译器报错：

- `应用Bar` 应为 Flutter 组件 `AppBar`
- `应用Database` 应为数据库类 `AppDatabase`
- `small应用reciationAction` 应为模型字段 `smallAppreciationAction`

Dart 标识符不能包含这些中文字符，因此 release 编译失败。

## 已修复文件
- `lib/realistic_optimism_training/realistic_optimism_training_home_page.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_flow_page.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_experience_pages.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_dao.dart`
- `lib/realistic_optimism_training/realistic_optimism_training_models.dart`

## 修复内容
- `应用Bar` → `AppBar`
- `应用Database` → `AppDatabase`
- `small应用reciationAction` → `smallAppreciationAction`

## 保留内容
用户可见文案中的中文“应用”“注意力启动线索”“消极启动源”等保持不变。
本次只修复代码标识符，不回退 v20 的中文化产品改造。

## 验证
已在源码中确认以下错误标识符不存在：

- `应用Bar`
- `应用Database`
- `small应用reciationAction`

