import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final fullName = TextEditingController(),
      email = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController();
  bool loading = false;
  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final user = await AuthService().register(
          fullName: fullName.text.trim(),
          email: email.text.trim(),
          username: username.text.trim(),
          password: password.text);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
            (_) => false);
      }
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
      appBar: AppBar(
          title: const Text('Criar conta'),
          backgroundColor: Colors.transparent),
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                      key: formKey,
                      child: Column(children: [
                        Text('Sua carteira pessoal',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text(
                            'Cada conta possui dados financeiros totalmente separados.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF8D9BB1))),
                        const SizedBox(height: 26),
                        TextFormField(
                            controller: fullName,
                            decoration: const InputDecoration(
                                labelText: 'Nome completo'),
                            validator: (v) => (v?.trim().length ?? 0) < 5
                                ? 'Informe seu nome completo.'
                                : null),
                        const SizedBox(height: 14),
                        TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'E-mail'),
                            validator: (v) => !(v ?? '').contains('@')
                                ? 'Informe um e-mail vÃ¡lido.'
                                : null),
                        const SizedBox(height: 14),
                        TextFormField(
                            controller: username,
                            decoration:
                                const InputDecoration(labelText: 'UsuÃ¡rio'),
                            validator: (v) => (v?.trim().length ?? 0) < 3
                                ? 'Use pelo menos 3 caracteres.'
                                : null),
                        const SizedBox(height: 14),
                        TextFormField(
                            controller: password,
                            obscureText: true,
                            decoration:
                                const InputDecoration(labelText: 'Senha'),
                            validator: (v) => (v?.length ?? 0) < 8
                                ? 'Use pelo menos 8 caracteres.'
                                : null),
                        const SizedBox(height: 22),
                        FilledButton(
                            onPressed: loading ? null : submit,
                            child: loading
                                ? const CircularProgressIndicator()
                                : const Text('Criar conta segura'))
                      ]))))));
}
