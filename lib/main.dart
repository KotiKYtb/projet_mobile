import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'token_storage.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JWT Auth',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      initialRoute: '/debug-users',
      routes: {
        '/register': (_) => const RegisterPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const HomePage(),
        '/debug-users': (_) => const DebugUsersPage(),
        '/mod': (_) => const ModPage(),
        '/admin': (_) => const AdminPage(),
      },
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}
class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final userCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { loading = true; error = null; });
    final http.Response resp = await ApiClient.signup(
      username: userCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      password: passCtrl.text,
      // Optionnel: roles: ['user'] (sinon le backend mettra le role id=1)
    );
    setState(() { loading = false; });
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inscription réussie, connectez-vous.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() { error = resp.body; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              TextFormField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: loading ? null : _submit,
                child: loading ? const CircularProgressIndicator() : const Text('Register'),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Déjà un compte ? Login'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() { loading = true; error = null; });
    final resp = await ApiClient.signin(
      username: userCtrl.text.trim(),
      password: passCtrl.text,
    );
    setState(() { loading = false; });
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final token = data['accessToken'] as String?;
      if (token == null) { setState(() => error = 'Token manquant'); return; }
      await TokenStorage.save(token);
      final roles = (data['roles'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      await TokenStorage.saveRoles(roles);
      if (!mounted) return;
      // Détermine la destination via les endpoints protégés (fiable côté serveur)
      try {
        final adminResp = await ApiClient.getAdmin(token: token);
        if (adminResp.statusCode == 200) {
          Navigator.pushReplacementNamed(context, '/admin');
          return;
        }
      } catch (_) {}
      try {
        final modResp = await ApiClient.getModerator(token: token);
        if (modResp.statusCode == 200) {
          Navigator.pushReplacementNamed(context, '/mod');
          return;
        }
      } catch (_) {}
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() { error = resp.body; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: ListView(
            children: [
              TextFormField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: loading ? null : _login,
                child: loading ? const CircularProgressIndicator() : const Text('Login'),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                child: const Text("Pas de compte ? Register"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  String result = '...';

  Future<void> _fetch() async {
    final token = await TokenStorage.read();
    if (token == null) { setState(() => result = 'Pas de token'); return; }
    try {
      final resp = await ApiClient.getUser(token: token);
      setState(() => result = '${resp.statusCode}: ${resp.body}');
    } catch (e) {
      setState(() => result = 'Erreur: $e');
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    await TokenStorage.clearRoles();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home'), actions: [
        IconButton(onPressed: _logout, icon: const Icon(Icons.logout))
      ]),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(result),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetch, child: const Text('Recharger'))
        ]),
      ),
    );
  }
}

class DebugUsersPage extends StatefulWidget {
  const DebugUsersPage({super.key});
  @override
  State<DebugUsersPage> createState() => _DebugUsersPageState();
}

class _DebugUsersPageState extends State<DebugUsersPage> {
  bool loading = true;
  String? error;
  List<dynamic> users = const [];

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final resp = await ApiClient.getDebugUsers();
      if (resp.statusCode == 200) {
        users = jsonDecode(resp.body) as List<dynamic>;
      } else {
        error = 'HTTP ${resp.statusCode}: ${resp.body}';
      }
    } catch (e) {
      error = 'Erreur: $e';
    }
    setState(() { loading = false; });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Users')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                  child: const Text('Register'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Login'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            Expanded(
              child: ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final u = users[index] as Map<String, dynamic>;
                  final roles = (u['roles'] as List<dynamic>? ?? const []).join(', ');
                  return ListTile(
                    title: Text(u['username']?.toString() ?? ''),
                    subtitle: Text('email: ${u['email']}\npassword(plain): ${u['password_plain']}\npassword(hash): ${u['password']}\nroles: $roles'),
                    isThreeLine: true,
                  );
                },
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _load,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class ModPage extends StatefulWidget {
  const ModPage({super.key});
  @override
  State<ModPage> createState() => _ModPageState();
}

class _ModPageState extends State<ModPage> {
  String result = '...';

  Future<void> _fetch() async {
    final token = await TokenStorage.read();
    if (token == null) { setState(() => result = 'Pas de token'); return; }
    try {
      final resp = await ApiClient.getModerator(token: token);
      setState(() => result = '${resp.statusCode}: ${resp.body}');
    } catch (e) {
      setState(() => result = 'Erreur: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderator')),
      body: Center(child: Text(result)),
    );
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String result = '...';

  Future<void> _fetch() async {
    final token = await TokenStorage.read();
    if (token == null) { setState(() => result = 'Pas de token'); return; }
    try {
      final resp = await ApiClient.getAdmin(token: token);
      setState(() => result = '${resp.statusCode}: ${resp.body}');
    } catch (e) {
      setState(() => result = 'Erreur: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Center(child: Text(result)),
    );
  }
}