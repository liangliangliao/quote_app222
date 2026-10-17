# v2.8 Android 首次打开失败修复

基线：`codex/will-mirror-v28-rebuild@c94151a1`，承接 PR #173。用户反馈为覆盖安装后第一次从发现之旅打开模块即显示“暂时无法打开加密资料，原文件已保留”。本轮没有切换到无关的最新功能分支，没有修改 main。

## 原因与修复

`SqliteMirrorStore.open` 在 `onConfigure` 中用 `execute` 执行 `PRAGMA secure_delete = ON`。该 PRAGMA 返回结果行；sqflite 的 Android 实现将 `execute` 交给 `SQLiteDatabase.execSQL`，后者不接受返回结果的查询。异常发生在读取课题和调用 Keystore 之前。页面原先把所有非 `MirrorProblem` 启动异常都显示为加密资料失败，误导了问题定位。

改为 `rawQuery`，继续启用安全删除。撤回、撤销跨课题引用和删除后的 `wal_checkpoint(TRUNCATE)` 同样返回结果，也改为 `rawQuery`，防止打开后在这些路径再次失败。桌面 sqflite FFI 可以接受原来的调用，因此原有 FFI 测试没有发现 Android 差异。

数据库文件名、schemaVersion 1、表结构、密文 envelope、AAD 和 Android Keystore alias 均保持不变。修复不清除数据库、不换空库、不重新生成解密密钥，也不迁入旧版推论。读取更新的资料版本时明确拒绝降级并保留原文件。

错误界面区分数据库打开、存储服务、资料版本、密钥缺失、密文认证失败和加密服务不可用；只显示固定的安全文案及问题代码，不输出原生异常正文、密文、私人记录或凭据。支持重试和大字体滚动。

AI 配置和提醒同步是可选能力：它们失败时继续开放已成功读取的本地账本，并显示降级说明。真正的存储/解密失败仍阻止进入，绝不把不可读资料当作空数据。

## 验证

- `flutter analyze --no-pub lib/will_mirror test/will_mirror integration_test/will_mirror_storage_test.dart`。
- `flutter test --no-pub --reporter expanded test/will_mirror`：新增启动分类、重试、大字体、可选服务降级、关闭重开保留密文及历史、Android SQL 调用契约回归。
- `android_sqlite_contract_test.dart` 先让原 `execute` 调用在 Android 通道约束下失败，再验证修复后的首次建库及撤回/删除。它是平台契约模拟，不能冒充真机测试。
- `integration_test/will_mirror_storage_test.dart` 使用实际 Android sqflite 和 Keystore；覆盖首次打开 UI、加密写入、关闭重开、AAD 不匹配时保留记录、撤回历史和删除。使用独立测试数据库，绝不删除正式数据库或 Keystore alias。
- CI 新增 Android API 26 / 35，先运行原生存储测试，再运行 `MIRROR_UPGRADE_PHASE=seed` 与 `verify` 两次测试 APK 安装，验证同签名覆盖安装后的密钥、课题、历史及设置。其数据格式与原 v2.8 相同；不等同于用户那台真机和原发布签名的验收。
- 覆盖安装通过 `bash tools/will_mirror/android_storage_probe.sh emulator-5554` 执行，使用 `flutter drive --keep-app-running` 并在各阶段 force-stop。不能连续使用 `flutter test` 模拟升级，因为 Flutter 3.35 的该测试运行器会在每次结束时卸载应用；初轮 CI 已据此暴露并修正测试方案。seed 后另检查测试库仍存在，verify 再读出真实密文与设置。只在独立测试模拟器执行。

实际执行结果继续记录在 [VALIDATION.md](VALIDATION.md)。完整 T1–T366、真实模型质量、通知/省电/重启和厂商设备矩阵仍按原验收索引分别执行，不因本次修复全部标记通过。

## 真机复测

1. 使用与原 APK 相同 applicationId 和签名的修复包直接覆盖安装；保留应用数据。
2. 发现之旅 → 意志之镜，应出现课题输入与三个模块内导航；返回发现页再进入仍可打开。
3. 新建一条本地课题，暂不发送 AI；结束进程并重新打开，核对课题与设置保留。
4. 对测试课题执行补充事实、撤回和删除，确认没有再次出现资料打开异常；其他课题与宿主模块仍保留。
5. 若仍失败，记录页面的问题代码、机型和 Android 版本；无需提交私人课题正文或数据库。

已确认存在 Android PRAGMA 调用缺陷；没有用户设备日志时，不把截图本身当作密钥损坏或所有设备原因都已排除的证据。
