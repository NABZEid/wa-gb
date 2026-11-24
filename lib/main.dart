import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'api.dart';

const kGreen = Color(0xFF25D366);
const kTint = Color(0xFF00A884);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.restore();
  runApp(const WaApp());
}

String fmt(dynamic t) {
  if (t == null) return '';
  try {
    final d = DateTime.parse(t.toString()).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return t.toString();
  }
}

String ini(String n) {
  final p = n.trim().split(' ').where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return p.take(2).map((e) => e[0]).join().toUpperCase();
}

Color colorOf(String s) {
  const c = [
    Color(0xFFE4572E), Color(0xFF2E86AB), Color(0xFFA23B72),
    Color(0xFF3A7D44), Color(0xFFF18F01), Color(0xFF6A4C93), Color(0xFF1982C4)
  ];
  return c[s.codeUnits.fold(0, (a, b) => a + b) % c.length];
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colorOf(name), shape: BoxShape.circle),
        child: Text(ini(name),
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: size * .38)),
      );
}

class WaApp extends StatelessWidget {
  const WaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WhatsApp iOS',
        themeMode: ThemeMode.system,
        theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: kTint,
            scaffoldBackgroundColor: Colors.white),
        darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: kTint,
            scaffoldBackgroundColor: const Color(0xFF0B141A)),
        home: Api.token == null ? const LoginPage() : const HomePage(),
      );
}

// ---------------------------------------------------------- LOGIN
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final key = TextEditingController();
  bool busy = false;
  String? err;

  Future<void> go() async {
    final k = key.text.trim();
    if (k.isEmpty) {
      setState(() => err = 'Masukkan userkey dulu.');
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await Api.login(k);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      setState(() =>
          err = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                      color: kGreen, shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.chat_bubble_fill,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 22),
                const Text('Masuk',
                    style:
                        TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                    'Masukkan userkey yang kamu dapat dari bot Telegram.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 26),
                CupertinoTextField(
                  controller: key,
                  placeholder: 'Userkey',
                  autocorrect: false,
                  padding: const EdgeInsets.all(14),
                  onSubmitted: (_) => go(),
                  prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.lock_fill,
                          size: 18, color: Colors.grey)),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(.15),
                      borderRadius: BorderRadius.circular(12)),
                ),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(err!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFE5342F))),
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: busy ? null : go,
                    child: busy
                        ? const CupertinoActivityIndicator()
                        : const Text('Masuk'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------- HOME
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
            index: tab, children: const [ChatsPage(), SettingsPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(CupertinoIcons.chat_bubble_2), label: 'Chat'),
            NavigationDestination(
                icon: Icon(CupertinoIcons.settings), label: 'Pengaturan'),
          ],
        ),
      );
}

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});
  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  List chats = [];
  String q = '';
  String? err;
  bool loading = true;
  Timer? t;

  @override
  void initState() {
    super.initState();
    load();
    t = Timer.periodic(const Duration(seconds: 4), (_) => load());
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final c = await Api.chats();
      if (mounted) {
        setState(() {
          chats = c;
          err = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          err = e.toString().replaceFirst('Exception: ', '');
          loading = false;
        });
      }
    }
  }

  void open(String id, String name) async {
    await Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => ChatPage(chatId: id, title: name)));
    load();
  }

  void newChat() async {
    try {
      final us = await Api.users();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => ListView(
          children: [
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chat baru',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            for (final u in us.where((u) => '${u['id']}' != Api.uid))
              ListTile(
                leading: Avatar('${u['name']}', size: 40),
                title: Text('${u['name']}'),
                onTap: () {
                  Navigator.pop(context);
                  open('${u['id']}', '${u['name']}');
                },
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = chats
        .where((c) => '${c['name']}'.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
          backgroundColor: kGreen,
          foregroundColor: Colors.white,
          onPressed: newChat,
          child: const Icon(CupertinoIcons.square_pencil)),
      body: SafeArea(
        child: Column(children: [
          const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text('Chat',
                      style: TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CupertinoSearchTextField(
                placeholder: 'Cari', onChanged: (v) => setState(() => q = v)),
          ),
          if (err != null)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text(err!,
                    style: const TextStyle(color: Color(0xFFE5342F)))),
          Expanded(
            child: loading
                ? const Center(child: CupertinoActivityIndicator())
                : list.isEmpty
                    ? const Center(
                        child: Text('Belum ada chat. Ketuk tombol di kanan bawah.',
                            style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final c = list[i];
                            final un = int.tryParse('${c['unread'] ?? 0}') ?? 0;
                            return ListTile(
                              leading: Avatar('${c['name']}'),
                              title: Text('${c['name']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text('${c['last'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(fmt(c['time']),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: un > 0 ? kTint : Colors.grey)),
                                  if (un > 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: kGreen,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Text('$un',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                              onTap: () => open('${c['id']}', '${c['name']}'),
                            );
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------- CHAT
class ChatPage extends StatefulWidget {
  final String chatId, title;
  const ChatPage({super.key, required this.chatId, required this.title});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List msgs = [];
  final txt = TextEditingController();
  final sc = ScrollController();
  Timer? t;
  int lastLen = 0;

  @override
  void initState() {
    super.initState();
    load();
    t = Timer.periodic(const Duration(seconds: 2), (_) => load());
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final m = await Api.messages(widget.chatId);
      if (!mounted) return;
      setState(() => msgs = m);
      if (m.length != lastLen) {
        lastLen = m.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (sc.hasClients) sc.jumpTo(sc.position.maxScrollExtent);
        });
      }
    } catch (_) {}
  }

  Future<void> send() async {
    final v = txt.text.trim();
    if (v.isEmpty) return;
    txt.clear();
    setState(() => msgs = [
          ...msgs,
          {'mine': true, 'text': v, 'time': DateTime.now().toIso8601String()}
        ]);
    try {
      await Api.send(widget.chatId, v);
      load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          Avatar(widget.title, size: 36),
          const SizedBox(width: 10),
          Text(widget.title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: sc,
            padding: const EdgeInsets.all(10),
            itemCount: msgs.length,
            itemBuilder: (_, i) {
              final m = msgs[i] as Map;
              final mine = m['mine'] == true || '${m['from']}' == Api.uid;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * .78),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                  decoration: BoxDecoration(
                    color: mine
                        ? (dark
                            ? const Color(0xFF005C4B)
                            : const Color(0xFFD9FDD3))
                        : (dark ? const Color(0xFF202C33) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(mine ? 12 : 4),
                      topRight: Radius.circular(mine ? 4 : 12),
                      bottomLeft: const Radius.circular(12),
                      bottomRight: const Radius.circular(12),
                    ),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text('${m['text'] ?? ''}',
                                style: const TextStyle(fontSize: 16))),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(fmt(m['time']),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          if (mine)
                            const Padding(
                                padding: EdgeInsets.only(left: 3),
                                child: Icon(Icons.done_all,
                                    size: 15, color: Color(0xFF53BDEB))),
                        ]),
                      ]),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(children: [
              Expanded(
                child: CupertinoTextField(
                  controller: txt,
                  placeholder: 'Pesan',
                  minLines: 1,
                  maxLines: 4,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onSubmitted: (_) => send(),
                  decoration: BoxDecoration(
                      color: dark ? const Color(0xFF202C33) : Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: send,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: kGreen, shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.arrow_up,
                      color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------- SETTINGS
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text('Pengaturan',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Avatar(Api.name, size: 60),
            title: Text(Api.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Text('ID: ${Api.uid}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(CupertinoIcons.square_arrow_right,
                color: Color(0xFFE5342F)),
            title: const Text('Keluar',
                style: TextStyle(color: Color(0xFFE5342F))),
            onTap: () async {
              await Api.logout();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushReplacement(
                    CupertinoPageRoute(builder: (_) => const LoginPage()));
              }
            },
          ),
        ]),
      );
}
