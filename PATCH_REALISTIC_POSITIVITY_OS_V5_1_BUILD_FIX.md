# PATCH_REALISTIC_POSITIVITY_OS_V5_1_BUILD_FIX

## 修复目的
根据 GitHub Actions / Flutter release APK 构建日志修复 RPO 模块编译错误。

## 修复内容

### 1. 修复 coverage audit 页面括号不匹配
文件：`lib/realistic_positivity_os/realistic_positivity_os_coverage_audit_page.dart`

错误：
`Error: Can't find ')' to match '('.`

原因：`Expanded(child: Column(...))` 少了一个右括号，导致 Row/Column/Expanded 嵌套无法闭合。

修复：补齐 `Expanded` 的关闭括号。

### 2. 修复 loading 分支 const Scaffold 使用非 const 变量
文件：
- `lib/realistic_positivity_os/realistic_positivity_os_coverage_page.dart`
- `lib/realistic_positivity_os/realistic_positivity_os_experiment_page.dart`
- `lib/realistic_positivity_os/realistic_positivity_os_system_page.dart`

错误：
`Error: Not a constant expression.`

原因：代码中写了 `const Scaffold(body: body)`，但 `body` 是局部变量，不是 const 表达式。

修复：改为 `Scaffold(body: body)`。

## 验证
当前运行环境没有 Flutter / Dart SDK，无法执行 `flutter analyze`。已完成源码级括号平衡检查和错误日志对应修复。
