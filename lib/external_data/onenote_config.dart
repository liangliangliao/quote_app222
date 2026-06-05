class OneNoteConfig {
  const OneNoteConfig._();

  static const String clientId = 'dccf2bf4-0571-4abe-a303-bf07fb967147';
  static const String packageName = 'com.example.quote_app';
  static const String releaseBase64Sha1 = 'IrBkHKitYXzfCoV0Uuv6d8eBJ5Q=';
  static const String defaultRedirectUri = 'msauth://$packageName/$releaseBase64Sha1';
  static const String defaultCallbackScheme = 'msauth';

  // 同一个 Microsoft 登录同时用于 OneNote 与 Microsoft To Do。
  // To Do 的完整本地增删改查 + 可选写回 Graph 需要 Tasks.ReadWrite。
  static const List<String> scopes = <String>[
    'User.Read',
    'Notes.Read',
    'Tasks.Read',
    'Tasks.ReadWrite',
    'offline_access',
  ];
}
