import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool loading = false;
  String errorMessage = '';

  Future<void> signup() async {
    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      // 1. Cria o usuário no Supabase Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = response.user;

      if (user == null) {
        setState(() {
          errorMessage = "Não foi possível criar o usuário.";
          loading = false;
        });
        return;
      }

      // 2. Cria o profile na tabela "profiles"
      await Supabase.instance.client.from('profiles').insert({
        'id': user.id,
        'name': nameController.text.trim(),
      });

      // 3. Voltar para o login
      if (mounted) {
        Navigator.pop(context);
      }

    } on AuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Erro inesperado: $e';
      });
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Seu nome'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 20),

            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),

            ElevatedButton(
              onPressed: loading ? null : signup,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }
}
