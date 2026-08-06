import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final identity = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool loading = false, obscure = true;

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final user =
          await AuthService().login(identity.text.trim(), password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DashboardScreen(user: user)));
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.message),
            backgroundColor: const Color(0xFF7F1D2D)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Form(
                          key: formKey,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _Brand(),
                                const SizedBox(height: 48),
                                Text('Acesse sua carteira',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Entre com seu usuÃ¡rio ou e-mail para continuar.',
                                    style: TextStyle(color: Color(0xFF8D9BB1))),
                                const SizedBox(height: 28),
                                TextFormField(
                                    controller: identity,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                        labelText: 'UsuÃ¡rio ou e-mail',
                                        prefixIcon: Icon(Icons.person_outline)),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Informe seu acesso.'
                                            : null),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: password,
                                    obscureText: obscure,
                                    onFieldSubmitted: (_) => submit(),
                                    decoration: InputDecoration(
                                        labelText: 'Senha',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                            onPressed: () => setState(
                                                () => obscure = !obscure),
                                            icon: Icon(obscure
                                                ? Icons.visibility_outlined
                                                : Icons
                                                    .visibility_off_outlined))),
                                    validator: (value) => (value?.length ?? 0) <
                                            8
                                        ? 'A senha possui pelo menos 8 caracteres.'
                                        : null),
                                const SizedBox(height: 22),
                                FilledButton(
                                    onPressed: loading ? null : submit,
                                    child: loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Text('Entrar com seguranÃ§a')),
                                const SizedBox(height: 14),
                                TextButton(
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreen())),
                                    child: const Text('Criar uma nova conta')),
                                const SizedBox(height: 28),
                                const Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    children: [
                                      Icon(Icons.shield_outlined,
                                          size: 16, color: Color(0xFF41D69B)),
                                      Text(
                                          'ConexÃ£o protegida Â· Dados separados por usuÃ¡rio',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B)))
                                    ])
                              ])),
                    )))),
      );
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const Row(children: [
        FlutterLogo(size: 46),
        SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nexo',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          Text('FINANÃ‡AS PESSOAIS',
              style: TextStyle(
                  fontSize: 9, letterSpacing: 1.4, color: Color(0xFF8D9BB1)))
        ])
      ]);
}
