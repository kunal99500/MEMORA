import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight in-memory + persisted session (token, current workspace & space).
class Session {
  static String? token;
  static String? userName;
  static String? rememberedEmail;
  static String? workspaceId;
  static String? workspaceType; // personal | family | business
  static String? spaceId;
  static String? chatConversationId;
  static bool rememberMe = false;

  static bool get isLoggedIn => token != null;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final storedToken = p.getString('token');
    rememberMe = p.getBool('rememberMe') ?? storedToken != null;
    token = rememberMe ? storedToken : null;
    userName = p.getString('userName');
    rememberedEmail = p.getString('rememberedEmail');
    workspaceId = p.getString('workspaceId');
    workspaceType = p.getString('workspaceType');
    spaceId = p.getString('spaceId');
    chatConversationId = p.getString('chatConversationId');
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    Future<void> set(String k, String? v) async =>
        v == null ? p.remove(k) : p.setString(k, v);
    await p.setBool('rememberMe', rememberMe);
    await set('token', rememberMe ? token : null);
    await set('userName', userName);
    await set('rememberedEmail', rememberedEmail);
    await set('workspaceId', workspaceId);
    await set('workspaceType', workspaceType);
    await set('spaceId', spaceId);
    await set('chatConversationId', chatConversationId);
  }

  static Future<void> clear() async {
    token = userName =
        rememberedEmail =
            workspaceId = workspaceType = spaceId = chatConversationId = null;
    rememberMe = false;
    await save();
  }
}
