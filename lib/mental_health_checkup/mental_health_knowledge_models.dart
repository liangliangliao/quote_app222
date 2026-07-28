enum CheckupKnowledgeResourceStatus {
  uploading,
  ready,
  stale,
  failed,
  detached,
}

class CheckupKnowledgeCorpus {
  final String courseVersion;
  final String sourceSha256;
  final String fileName;
  final List<int> bytes;
  final int courseLocationCount;
  final int evidenceRelationCount;
  final int indicatorCount;

  const CheckupKnowledgeCorpus({
    required this.courseVersion,
    required this.sourceSha256,
    required this.fileName,
    required this.bytes,
    required this.courseLocationCount,
    required this.evidenceRelationCount,
    required this.indicatorCount,
  });
}

class CheckupProviderKnowledgeResource {
  final String id;
  final String provider;
  final String providerLabel;
  final String accountFingerprint;
  final String providerFileId;
  final String providerResourceId;
  final String courseVersion;
  final String sourceSha256;
  final String fileName;
  final int byteCount;
  final CheckupKnowledgeResourceStatus status;
  final bool enabled;
  final int uploadedAtMs;
  final int lastVerifiedAtMs;
  final String failureReason;

  const CheckupProviderKnowledgeResource({
    required this.id,
    required this.provider,
    required this.providerLabel,
    required this.accountFingerprint,
    required this.providerFileId,
    required this.providerResourceId,
    required this.courseVersion,
    required this.sourceSha256,
    required this.fileName,
    required this.byteCount,
    required this.status,
    required this.enabled,
    required this.uploadedAtMs,
    required this.lastVerifiedAtMs,
    this.failureReason = '',
  });

  bool get ready =>
      enabled &&
      status == CheckupKnowledgeResourceStatus.ready &&
      providerFileId.trim().isNotEmpty;

  bool matchesCourse({required String version, required String sha256}) =>
      courseVersion == version &&
      sourceSha256.toLowerCase() == sha256.toLowerCase();

  CheckupProviderKnowledgeResource copyWith({
    String? providerLabel,
    String? providerFileId,
    String? providerResourceId,
    String? courseVersion,
    String? sourceSha256,
    String? fileName,
    int? byteCount,
    CheckupKnowledgeResourceStatus? status,
    bool? enabled,
    int? uploadedAtMs,
    int? lastVerifiedAtMs,
    String? failureReason,
  }) =>
      CheckupProviderKnowledgeResource(
        id: id,
        provider: provider,
        providerLabel: providerLabel ?? this.providerLabel,
        accountFingerprint: accountFingerprint,
        providerFileId: providerFileId ?? this.providerFileId,
        providerResourceId: providerResourceId ?? this.providerResourceId,
        courseVersion: courseVersion ?? this.courseVersion,
        sourceSha256: sourceSha256 ?? this.sourceSha256,
        fileName: fileName ?? this.fileName,
        byteCount: byteCount ?? this.byteCount,
        status: status ?? this.status,
        enabled: enabled ?? this.enabled,
        uploadedAtMs: uploadedAtMs ?? this.uploadedAtMs,
        lastVerifiedAtMs: lastVerifiedAtMs ?? this.lastVerifiedAtMs,
        failureReason: failureReason ?? this.failureReason,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'provider': provider,
        'provider_label': providerLabel,
        'account_fingerprint': accountFingerprint,
        'provider_file_id': providerFileId,
        'provider_resource_id': providerResourceId,
        'course_version': courseVersion,
        'source_sha256': sourceSha256,
        'file_name': fileName,
        'byte_count': byteCount,
        'status': status.name,
        'enabled': enabled,
        'uploaded_at_ms': uploadedAtMs,
        'last_verified_at_ms': lastVerifiedAtMs,
        'failure_reason': failureReason,
      };

  factory CheckupProviderKnowledgeResource.fromJson(
    Map<String, dynamic> json,
  ) =>
      CheckupProviderKnowledgeResource(
        id: (json['id'] ?? '').toString(),
        provider: (json['provider'] ?? '').toString(),
        providerLabel: (json['provider_label'] ?? '').toString(),
        accountFingerprint: (json['account_fingerprint'] ?? '').toString(),
        providerFileId: (json['provider_file_id'] ?? '').toString(),
        providerResourceId: (json['provider_resource_id'] ?? '').toString(),
        courseVersion: (json['course_version'] ?? '').toString(),
        sourceSha256: (json['source_sha256'] ?? '').toString(),
        fileName: (json['file_name'] ?? '').toString(),
        byteCount: (json['byte_count'] as num?)?.toInt() ?? 0,
        status: CheckupKnowledgeResourceStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => CheckupKnowledgeResourceStatus.failed,
        ),
        enabled: json['enabled'] == true,
        uploadedAtMs: (json['uploaded_at_ms'] as num?)?.toInt() ?? 0,
        lastVerifiedAtMs: (json['last_verified_at_ms'] as num?)?.toInt() ?? 0,
        failureReason: (json['failure_reason'] ?? '').toString(),
      );
}
