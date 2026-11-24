import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// CATATAN: endpoint di bawah adalah ASUMSI karena kode server
/// belum dilihat. Sesuaikan path dan nama field di file ini saja,
/// tampilan aplikasi tidak perlu diubah.
///
///  POST /api/login        {userkey}            -> {token, user:{id,name}}
///  GET  /api/chats                             -> [{id,name,last,time,unread}]
///  GET  /api/users                             -> [{id,name}]
///  GET  /api/messages/:chatId                  -> [{id,from,text,time}]
///  POST /api/messages     {chatId,text}        -> pesan baru
/// Header setelah login: Authorization: Bearer <token>
/// ============================================================
class Api {
  static const base = 'https://srvwagb.duckdns.org:3001';
  static String? token;
  static String uid = '';
  static String name = '';

  static Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static dynamic _body(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      String msg = 'Gagal (${r.statusCode})';
      try {
        final j = jsonDecode(r.body);
        msg = (j['error'] ?? j['message'] ?? msg).toString();
      } catch (_) {}
      throw Exception(msg);
    }
    return r.body.isEmpty ? {} : jsonDecode(r.body);
  }

  static List _list(dynamic d, String key) =>
      d is List ? d : (d[key] ?? d['data'] ?? []) as List;

  static Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    uid = p.getString('uid') ?? '';
    name = p.getString('name') ?? '';
  }

  static Future<void> login(String key) async {
    final r = await http
        .post(Uri.parse('$base/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userkey': key}))
        .timeout(const Duration(seconds: 15));
    final j = _body(r);
    final u = (j['user'] ?? {}) as Map;
    token = (j['token'] ?? j['accessToken'] ?? key).toString();
    uid = '${u['id'] ?? j['id'] ?? ''}';
    name = '${u['name'] ?? j['name'] ?? 'Saya'}';
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token!);
    await p.setString('uid', uid);
    await p.setString('name', name);
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    token = null;
    uid = '';
    name = '';
  }

  static Future<List> chats() async => _list(
      _body(await http.get(Uri.parse('$base/api/chats'), headers: _h)),
      'chats');

  static Future<List> users() async => _list(
      _body(await http.get(Uri.parse('$base/api/users'), headers: _h)),
      'users');

  static Future<List> messages(String chatId) async => _list(
      _body(await http.get(Uri.parse('$base/api/messages/$chatId'),
          headers: _h)),
      'messages');

  static Future<void> send(String chatId, String text) async {
    _body(await http.post(Uri.parse('$base/api/messages'),
        headers: _h, body: jsonEncode({'chatId': chatId, 'text': text})));
  }
}
