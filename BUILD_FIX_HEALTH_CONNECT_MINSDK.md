# Build Fix: Health Connect minSdkVersion

## 问题
GitHub Actions 构建失败：

```text
uses-sdk:minSdkVersion 24 cannot be smaller than version 26 declared in library
[androidx.health.connect:connect-client:1.1.0]
```

## 原因
第四阶段接入了 AndroidX Health Connect：

```gradle
implementation "androidx.health.connect:connect-client:1.1.0"
```

该库的 `AndroidManifest.xml` 声明最低支持 API 26。因此 App 的 `minSdk` 不能低于 26，否则 Android Manifest Merge 阶段会直接失败。

## 修复
已修改：

```text
android/app/build.gradle
```

将：

```gradle
minSdk = 21
```

调整为：

```gradle
minSdk = 26
```

并增加注释说明 Health Connect 的最低 API 要求。

## 影响
- Android 8.0（API 26）及以上可安装。
- Android 7.x 及以下不再支持安装。
- 这是直接接入 `androidx.health.connect:connect-client:1.1.0` 的必要代价。

## 备选方案
如果后续必须继续支持 Android 7.x，可以把 Health Connect 独立成动态插件/构建变体，或移除编译期依赖，改为更复杂的运行时能力降级方案。但当前为了保证第四阶段功能可构建，采用 `minSdk = 26` 是最稳定方案。
