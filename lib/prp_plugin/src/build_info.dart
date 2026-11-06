/// Supplied by the APK workflow so an installed build can be identified.
abstract final class PrpBuildInfo {
  static const version = '1.1.0';
  static const sourceSha = String.fromEnvironment('APP_SOURCE_SHA');
  static const sourceRef = String.fromEnvironment('APP_SOURCE_REF');

  static String get label {
    final revision = sourceSha.isEmpty
        ? '本地构建'
        : '构建 ${sourceSha.substring(0, sourceSha.length.clamp(0, 8))}';
    return 'PRP v$version · $revision';
  }
}
