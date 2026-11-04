import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'session.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// API client adapted to the MEMORA v2 backend (/api/v1).
class Api {
  static const _prefix = '/api/v1';

  static Map<String, String> get _auth =>
      {if (Session.token != null) 'Authorization': 'Bearer ${Session.token}'};
  static Map<String, String> get _authJson =>
      {'Content-Type': 'application/json', ..._auth};
  static Map<String, String> get imageHeaders => _auth;

  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${ApiConfig.baseUrl}$_prefix$path')
          .replace(queryParameters: q);

  static dynamic _decode(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = (body is Map && body['detail'] != null)
        ? body['detail'].toString()
        : 'Request failed (${r.statusCode})';
    throw ApiException(r.statusCode, msg);
  }

  /// Build an absolute URL for an evidence/frame path returned by the API.
  static String frameUrl(String? path) =>
      (path == null || path.isEmpty) ? '' : '${ApiConfig.baseUrl}$path';

  // ---------- auth ----------
  static Future<Map<String, dynamic>> signup(
      String email, String name, String password) async {
    final d = _decode(await http.post(_u('/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body:
            jsonEncode({'email': email, 'name': name, 'password': password})));
    Session.token = d['access_token'];
    Session.userName = name;
    Session.rememberMe = true;
    Session.rememberedEmail = email.trim();
    await Session.save();
    return {'token': d['access_token'], 'user_id': d['user_id']};
  }

  static Future<Map<String, dynamic>> login(String email, String password,
      {bool rememberMe = false}) async {
    final d = _decode(await http.post(_u('/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'remember_me': rememberMe,
        })));
    Session.token = d['access_token'];
    Session.rememberMe = rememberMe;
    Session.rememberedEmail = rememberMe ? email.trim() : null;
    await Session.save();
    return {'token': d['access_token'], 'user_id': d['user_id']};
  }

  static Future<void> requestPasswordReset(String email) async {
    _decode(await http.post(_u('/auth/password-reset/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email})));
  }

  static Future<void> confirmPasswordReset(
      String email, String code, String newPassword) async {
    _decode(await http.post(_u('/auth/password-reset/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password': newPassword,
        })));
  }

  static Future<Map<String, dynamic>> me() async {
    final d = Map<String, dynamic>.from(
        _decode(await http.get(_u('/auth/me'), headers: _auth)));
    if (d['name'] != null) {
      Session.userName = d['name'];
      await Session.save();
    }
    return d;
  }

  // ---------- workspace ----------
  static Future<List> workspaces() async =>
      _decode(await http.get(_u('/workspaces'), headers: _auth))['workspaces']
          as List;

  static Future<Map<String, dynamic>> createWorkspace(
      String name, String type) async {
    final d = Map<String, dynamic>.from(_decode(await http.post(
        _u('/workspaces'),
        headers: _authJson,
        body: jsonEncode({'name': name, 'tier': type}))));
    return {
      'id': d['id'],
      'name': d['name'],
      'type': d['tier'],
      'tier': d['tier'],
      'domain': d['domain']
    };
  }

  static Future<Map<String, dynamic>> joinWorkspace(String code) async =>
      throw ApiException(
          501, 'Joining a shared workspace is not available yet');

  static Future<Map<String, dynamic>> invite(String wid) async =>
      {'invite_code': ''};

  static Future<List> members(String wid) async => const [];

  static Future<List> spaces(String wid) async {
    final locs = _decode(await http.get(_u('/workspaces/$wid/locations'),
        headers: _auth))['locations'] as List;
    return locs
        .map((l) => {
              'space_id': l['id'],
              'id': l['id'],
              'name': l['name'],
              'type': l['type']
            })
        .toList();
  }

  static Future<Map<String, dynamic>> createSpace(String wid, String name,
      {String type = 'room'}) async {
    final d = Map<String, dynamic>.from(_decode(await http.post(
        _u('/workspaces/$wid/locations'),
        headers: _authJson,
        body: jsonEncode({'name': name, 'location_type': type}))));
    return {'space_id': d['id'], 'id': d['id'], 'name': d['name']};
  }

  static Future<Map<String, dynamic>> stats(String wid) async =>
      Map<String, dynamic>.from(_decode(await http.get(
          _u('/workspaces/$wid/overview', {
            '_refresh': DateTime.now().microsecondsSinceEpoch.toString(),
          }),
          headers: _auth)));

  static Future<List> roomsSummary(String wid) async =>
      _decode(await http.get(
          _u('/workspaces/$wid/rooms-summary', {
            '_refresh': DateTime.now().microsecondsSinceEpoch.toString(),
          }),
          headers: _auth))['rooms'] as List;

  static Future<List<Map<String, dynamic>>> timelines(String wid) async {
    final d = Map<String, dynamic>.from(_decode(
        await http.get(_u('/workspaces/$wid/timelines'), headers: _auth)));
    return ((d['timelines'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createTimeline(
      String wid, String locationId, String name) async {
    return Map<String, dynamic>.from(_decode(await http.post(
      _u('/workspaces/$wid/timelines'),
      headers: _authJson,
      body: jsonEncode({'location_id': locationId, 'name': name}),
    )));
  }

  static Future<void> uploadTimelineMedia({
    required String timelineId,
    required String locationId,
    required String name,
    required Uint8List bytes,
    required String filename,
  }) async {
    final wid = Session.workspaceId;
    if (wid == null) {
      throw ApiException(401, 'Sign in to upload timeline media.');
    }
    final extension = filename.split('.').last.toLowerCase();
    const videoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
    final mediaType = videoExtensions.contains(extension) ? 'video' : 'photo';
    final capture = Map<String, dynamic>.from(_decode(await http.post(
      _u('/captures'),
      headers: _authJson,
      body: jsonEncode({
        'workspace_id': wid,
        'location_id': locationId,
        'timeline_id': timelineId,
        'label': name,
        'domain': Session.workspaceType == 'business' ? 'business' : 'home',
        'media_type': mediaType,
      }),
    )));
    final captureId = capture['capture_id'].toString();
    final request = http.MultipartRequest(
      'POST',
      _u('/captures/$captureId/media'),
    )
      ..headers.addAll(_auth)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));
    _decode(await http.Response.fromStream(await request.send()));
    _decode(
        await http.post(_u('/captures/$captureId/process'), headers: _auth));
  }

  static Future<void> uploadSpaceMedia({
    required String locationId,
    required String name,
    required Uint8List bytes,
    required String filename,
  }) async {
    final wid = Session.workspaceId;
    if (wid == null) {
      throw ApiException(401, 'Sign in to upload space media.');
    }
    final extension = filename.split('.').last.toLowerCase();
    const videoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
    final mediaType = videoExtensions.contains(extension) ? 'video' : 'photo';
    final capture = Map<String, dynamic>.from(_decode(await http.post(
      _u('/captures'),
      headers: _authJson,
      body: jsonEncode({
        'workspace_id': wid,
        'location_id': locationId,
        'label': name,
        'domain': Session.workspaceType == 'business' ? 'business' : 'home',
        'media_type': mediaType,
      }),
    )));
    final captureId = capture['capture_id'].toString();
    final request = http.MultipartRequest(
      'POST',
      _u('/captures/$captureId/media'),
    )
      ..headers.addAll(_auth)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));
    _decode(await http.Response.fromStream(await request.send()));
    _decode(
        await http.post(_u('/captures/$captureId/process'), headers: _auth));
  }

  // ---------- scan: v2 composite (capture -> media -> process -> poll) ----------
  static Future<Map<String, dynamic>> scan(
      String sid, String label, Uint8List bytes, String filename) async {
    final wid = Session.workspaceId;
    final domain = (Session.workspaceType == 'business') ? 'business' : 'home';
    final cap =
        Map<String, dynamic>.from(_decode(await http.post(_u('/captures'),
            headers: _authJson,
            body: jsonEncode({
              'workspace_id': wid,
              'label': label,
              'domain': domain,
              'media_type': 'photo',
              'location_id': sid
            }))));
    final cid = cap['capture_id'];
    var fn = filename;
    final low = fn.toLowerCase();
    if (!(low.endsWith('.jpg') ||
        low.endsWith('.jpeg') ||
        low.endsWith('.png') ||
        low.endsWith('.webp'))) {
      fn = '$fn.jpg';
    }
    final req = http.MultipartRequest('POST', _u('/captures/$cid/media'))
      ..headers.addAll(_auth)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fn));
    _decode(await http.Response.fromStream(await req.send()));
    _decode(await http.post(_u('/captures/$cid/process'), headers: _auth));
    int count = 0;
    String status = 'queued';
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      final c = Map<String, dynamic>.from(
          _decode(await http.get(_u('/captures/$cid'), headers: _auth)));
      status = (c['status'] ?? '').toString();
      count = (c['observation_count'] as int?) ?? 0;
      if (status == 'completed' ||
          status == 'completed_with_warnings' ||
          status == 'failed') break;
    }
    if (status == 'failed') throw ApiException(500, 'Processing failed');
    return {
      'status': status,
      'objects': List.generate(count, (_) => <String, dynamic>{})
    };
  }

  static Future<Map<String, dynamic>> scanMulti(String sid, String label,
      List<Uint8List> files, List<String> names) async {
    if (files.isEmpty) return {'status': 'empty', 'objects': const []};
    // Each photo becomes its own scan so it can be shown and deleted on its own.
    String status = 'completed';
    for (int k = 0; k < files.length; k++) {
      final fn = (k < names.length) ? names[k] : 'photo_$k.jpg';
      final r = await scan(sid, label, files[k], fn);
      final st = (r['status'] ?? '').toString();
      if (st == 'failed') status = 'failed';
    }
    return {'status': status, 'objects': const []};
  }

  static Future<Map<String, dynamic>> compare(String sid) async =>
      throw ApiException(501, 'Change comparison is not available yet');

  // ---------- ask (workspace-level in v2) ----------
  static Future<Map<String, dynamic>> ask(String question,
      {String? conversationId}) async {
    final wid = Session.workspaceId;
    final d = Map<String, dynamic>.from(_decode(await http.post(_u('/ask'),
        headers: _authJson,
        body: jsonEncode({
          'workspace_id': wid,
          'query': question,
          if (conversationId != null) 'conversation_id': conversationId,
        }))));
    final ev = (d['evidence'] as List?) ?? const [];
    return {
      'answer': d['answer'] ?? '',
      'confidence': d['confidence'] ?? 0.0,
      'language': d['language'] ?? '',
      'evidence':
          ev.map((e) => '/api/v1/evidence/${e.toString()}/file').toList(),
    };
  }

  static Future<List<Map<String, dynamic>>> chatHistory(
      String wid, String? conversationId) async {
    final d = Map<String, dynamic>.from(_decode(await http.get(
        _u('/workspaces/$wid/chat-history', {
          if (conversationId != null) 'conversation_id': conversationId,
        }),
        headers: _auth)));
    final messages = (d['messages'] as List?) ?? const [];
    return messages.map((message) {
      final item = Map<String, dynamic>.from(message as Map);
      item['evidence'] = ((item['evidence'] as List?) ?? const [])
          .map((id) => '/api/v1/evidence/${id.toString()}/file')
          .toList();
      return item;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> chatConversations(
      String wid) async {
    final d = Map<String, dynamic>.from(_decode(await http
        .get(_u('/workspaces/$wid/chat-conversations'), headers: _auth)));
    return ((d['conversations'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> clearChat(String wid, String? conversationId) async {
    _decode(await http.delete(
        _u('/workspaces/$wid/chat-history', {
          if (conversationId != null) 'conversation_id': conversationId,
        }),
        headers: _auth));
  }

  static Future<List> objects(String sid) async {
    final wid = Session.workspaceId;
    final list = _decode(await http.get(
        _u('/objects', {'workspace_id': wid ?? ''}),
        headers: _auth))['objects'] as List;
    return list.map((o) {
      final m = Map<String, dynamic>.from(o as Map);
      final eid = m['evidence_id'];
      m['frame'] = (eid != null) ? '/api/v1/evidence/$eid/file' : null;
      return m;
    }).toList();
  }

  static Future<List> scanImages(String sid) async {
    final wid = Session.workspaceId;
    final r = _decode(await http.get(
        _u('/workspaces/$wid/scan-images', {'location_id': sid}),
        headers: _auth));
    return (r['images'] as List?) ?? const [];
  }

  static Future<void> deleteScan(String captureId) async {
    _decode(await http.delete(_u('/captures/$captureId'), headers: _auth));
  }

  static Future<List> timeline({String? timelineId}) async {
    final wid = Session.workspaceId;
    final r = _decode(await http.get(
        _u('/workspaces/$wid/timeline', {
          if (timelineId != null) 'timeline_id': timelineId,
        }),
        headers: _auth));
    return (r['entries'] as List?) ?? const [];
  }

  static Future<void> deleteTimelineEntry(String captureId) async {
    _decode(await http.delete(_u('/captures/$captureId'), headers: _auth));
  }

  static Future<List> scans(String sid) async => const [];
  static Future<List> events(String sid) async => const [];

  static Future<Map<String, dynamic>> lastSeen(String oid) async =>
      Map<String, dynamic>.from(
          _decode(await http.get(_u('/objects/$oid/history'), headers: _auth)));

  // ---------- MoveMate / Home Guardian (not in v2 yet; graceful empty) ----------
  static Future<List> movingProjects(String wid) async => const [];
  static Future<Map<String, dynamic>> createMoving(
          String wid, String name) async =>
      throw ApiException(501, 'MoveMate is not available yet');
  static Future<List> boxes(String pid) async => const [];
  static Future<Map<String, dynamic>> createBox(
          String pid, String name) async =>
      throw ApiException(501, 'MoveMate is not available yet');
  static Future<Map<String, dynamic>> addBoxItem(
          String bid, String label, String room) async =>
      throw ApiException(501, 'MoveMate is not available yet');
  static Future<List> findItems(String wid, String q) async => const [];
  // ---------- Upkeep (care & records) ----------
  static Future<List> careItems() async {
    final wid = Session.workspaceId;
    final r = _decode(await http
        .get(_u('/care-items', {'workspace_id': wid ?? ''}), headers: _auth));
    return (r['items'] as List?) ?? const [];
  }

  static Future<void> addCareItem(
      String name, String note, String location) async {
    final wid = Session.workspaceId;
    _decode(await http.post(_u('/care-items'),
        headers: _authJson,
        body: jsonEncode({
          'workspace_id': wid,
          'name': name,
          'note': note,
          'location': location
        })));
  }

  static Future<void> deleteCareItem(String id) async {
    _decode(await http.delete(_u('/care-items/$id'), headers: _auth));
  }

  // ---------- connected camera registry ----------
  static Future<List> cameras() async {
    final wid = Session.workspaceId;
    if (wid == null) return const [];
    final d = _decode(
        await http.get(_u('/cameras', {'workspace_id': wid}), headers: _auth));
    return (d['cameras'] as List?) ?? const [];
  }

  static Future<Map<String, dynamic>> addCamera({
    required String name,
    required String protocol,
    String? locationId,
    String connectionRef = '',
    int retentionDays = 7,
  }) async {
    final wid = Session.workspaceId;
    if (wid == null) throw ApiException(400, 'Choose a workspace first');
    return Map<String, dynamic>.from(_decode(await http.post(_u('/cameras'),
        headers: _authJson,
        body: jsonEncode({
          'workspace_id': wid,
          'name': name,
          'protocol': protocol,
          'location_id': locationId,
          'connection_ref': connectionRef,
          'retention_days': retentionDays,
        }))));
  }

  static Future<void> setCameraPaused(String id, bool paused) async {
    _decode(await http.post(_u('/cameras/$id/pause', {'paused': '$paused'}),
        headers: _auth));
  }

  static Future<void> deleteCamera(String id) async {
    _decode(await http.delete(_u('/cameras/$id'), headers: _auth));
  }

  static Future<void> startCamera(String id) async {
    _decode(await http.post(_u('/cameras/$id/start'), headers: _auth));
  }

  static Future<void> stopCamera(String id) async {
    _decode(await http.post(_u('/cameras/$id/stop'), headers: _auth));
  }

  static Future<Map<String, dynamic>> cameraStatus(String id) async {
    return Map<String, dynamic>.from(
        _decode(await http.get(_u('/cameras/$id/status'), headers: _auth)));
  }
}
