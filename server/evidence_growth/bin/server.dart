import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../lib/evidence_growth/evidence_growth_api.dart';
import '../../../lib/evidence_growth/evidence_growth_dao.dart';
import '../../../lib/evidence_growth/evidence_growth_kb_store.dart';

Future<void> main() async {
  // Values are SHA-256(token) -> user ID. Tokens are provisioned out of band;
  // this service never prints, persists, or accepts credentials via query strings.
  final raw=Platform.environment['EG_TOKEN_USERS'];
  if(raw==null || raw.isEmpty) throw StateError('Set EG_TOKEN_USERS to a JSON map of token SHA-256 digests to user IDs.');
  final users=Map<String,String>.from(jsonDecode(raw) as Map);
  if(users.isEmpty || users.keys.any((key)=>!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) || users.values.any((id)=>id.isEmpty)) {
    throw StateError('Invalid token digest/user configuration.');
  }
  final directory=Directory(Platform.environment['EG_DATA_DIR'] ?? './data');
  await directory.create(recursive:true);
  sqfliteFfiInit();
  final databases=<String,Database>{};
  final knowledge=await databaseFactoryFfi.openDatabase('${directory.path}/public-knowledge.sqlite');
  await EvidenceGrowthKbStore(() async=>knowledge).initialize();
  final api=EvidenceGrowthApi(userForTokenDigest:users,daoForUser:(id) async {
    final fileId=sha256.convert(utf8.encode(id)).toString();
    final db=databases[fileId] ??= await databaseFactoryFfi.openDatabase('${directory.path}/$fileId.sqlite');
    return EvidenceGrowthDao(database:() async=>db);
  });
  // Default bind is loopback. Put an authenticated TLS reverse proxy in front
  // of this port for remote devices; tokens must never travel over public HTTP.
  final server=await HttpServer.bind(Platform.environment['EG_BIND']??InternetAddress.loopbackIPv4.address,
    int.parse(Platform.environment['EG_PORT']??'8787'));
  stdout.writeln('Evidence Growth API listening on ${server.address.address}:${server.port}');
  await for(final request in server) { await api.serve(request); }
}
