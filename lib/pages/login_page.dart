import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool loading = false;
  String errorMessage = '';
  bool _biometricAvailable = false;
  bool _hasStoredCredentials = false;

  // Cores Temáticas
  static const Color _primaryColor = Color(0xFF2962FF);
  static const Color _backgroundColor = Color(0xFF1A202C);
  static const Color _cardColor = Color(0xFF2D3748);
  static const Color _lightTextColor = Color(0xFFE2E8F0);
  static const Color _hintColor = Color(0xFF90A4AE);

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Verifica se biometria está disponível no dispositivo
  Future<void> _checkBiometricAvailability() async {
    bool canCheckBiometrics = false;
    bool hasCredentials = false;

    try {
      // Verifica se dispositivo suporta biometria
      canCheckBiometrics = await _localAuth.canCheckBiometrics;
      
      // Verifica se há biometrias cadastradas
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      canCheckBiometrics = canCheckBiometrics && availableBiometrics.isNotEmpty;

      // Verifica se há credenciais salvas
      final storedEmail = await _secureStorage.read(key: 'user_email');
      hasCredentials = storedEmail != null && storedEmail.isNotEmpty;

      print('═════════════════════════════════════');
      print('🔐 Biometria disponível: $canCheckBiometrics');
      print('📱 Biometrias cadastradas: ${availableBiometrics.length}');
      print('💾 Credenciais salvas: $hasCredentials');
      print('✨ Botão biométrico ativo: ${canCheckBiometrics && hasCredentials}');
      print('═════════════════════════════════════');

    } on Exception catch (e) {
      print('❌ Erro ao verificar biometria: $e');
    }

    if (!mounted) return;

    setState(() {
      _biometricAvailable = canCheckBiometrics;
      _hasStoredCredentials = hasCredentials;
    });
  }

  /// Login com biometria (usa credenciais armazenadas)
  Future<void> _biometricLogin() async {
    setState(() {
      errorMessage = '';
      loading = true;
    });

    try {
      // 1. Autentica com biometria
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Use sua biometria para acessar',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated) {
        throw Exception('Autenticação cancelada');
      }

      // 2. Recupera credenciais salvas
      final email = await _secureStorage.read(key: 'user_email');
      final password = await _secureStorage.read(key: 'user_password');

      if (email == null || password == null) {
        throw Exception('Credenciais não encontradas. Faça login novamente.');
      }

      // 3. Faz login no Supabase
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('✅ Login biométrico bem-sucedido: ${response.user!.email}');
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }

    } catch (e) {
      print('❌ Erro no login biométrico: $e');
      setState(() {
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
        loading = false;
      });
    }

    setState(() => loading = false);
  }

  /// Login com email/senha e salva credenciais
  Future<void> login() async {
    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Preencha email e senha');
      }

      // 1. Faz login no Supabase
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        print('✅ Login bem-sucedido: ${response.user!.email}');

        // 2. Salva credenciais de forma segura (se biometria disponível)
        if (_biometricAvailable) {
          await _secureStorage.write(key: 'user_email', value: email);
          await _secureStorage.write(key: 'user_password', value: password);
          setState(() => _hasStoredCredentials = true);
          print('💾 Credenciais salvas para próximo acesso biométrico');
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }

    } on AuthException catch (e) {
      print('❌ Erro de autenticação: ${e.message}');
      setState(() {
        errorMessage = e.message;
        loading = false;
      });
    } catch (e) {
      print('❌ Erro: $e');
      setState(() {
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
        loading = false;
      });
    }

    setState(() => loading = false);
  }

  /// Limpa credenciais salvas
  Future<void> _clearStoredCredentials() async {
    await _secureStorage.delete(key: 'user_email');
    await _secureStorage.delete(key: 'user_password');
    setState(() => _hasStoredCredentials = false);
    print('🗑️ Credenciais removidas');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              Text(
                'ACESSO AO SISTEMA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 50),

              // ✅ Botão Biométrico (sempre aparece se biometria disponível)
              if (_biometricAvailable && _hasStoredCredentials && !loading)
                _buildBiometricButton(),

              // Campo Email
              _buildInputField(
                controller: emailController,
                label: 'EMAIL DE USUÁRIO',
                icon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Campo Senha
              _buildInputField(
                controller: passwordController,
                label: 'SENHA DE ACESSO',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 30),

              // Mensagem de Erro
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.shade400, width: 1.0),
                    ),
                    child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

              // Botão Login
              _buildButton(
                onPressed: loading ? null : login,
                label: 'INICIAR SESSÃO',
                isLoading: loading,
              ),
              const SizedBox(height: 15),

              // Link Cadastro
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/signup');
                },
                style: TextButton.styleFrom(
                  foregroundColor: _hintColor,
                ),
                child: const Text(
                  'Novo acesso? Cadastrar',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.underline,
                    decorationColor: _hintColor,
                  ),
                ),
              ),

              // Aviso se biometria não estiver disponível
              if (!_biometricAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    '⚠️ Configure biometria no seu dispositivo para acesso rápido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _hintColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),

              // Botão para limpar credenciais (útil para testes)
              if (_hasStoredCredentials)
                TextButton(
                  onPressed: _clearStoredCredentials,
                  child: Text(
                    '🗑️ Esquecer credenciais biométricas',
                    style: TextStyle(
                      color: _hintColor.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: _lightTextColor,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.5,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: _hintColor,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: _hintColor, size: 20),
        filled: true,
        fillColor: _cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: _cardColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: _primaryColor, width: 2.0),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return Column(
      children: [
        Container(
          height: 55,
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: _hintColor.withOpacity(0.5), width: 1.0),
          ),
          child: OutlinedButton.icon(
            icon: Icon(
              Icons.fingerprint,
              color: _lightTextColor,
              size: 28,
            ),
            label: const Text(
              'ACESSAR COM BIOMETRIA',
              style: TextStyle(
                color: _lightTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: _biometricLogin,
            style: OutlinedButton.styleFrom(
              backgroundColor: _cardColor.withOpacity(0.7),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const Text(
          'OU',
          textAlign: TextAlign.center,
          style: TextStyle(color: _hintColor, fontSize: 12),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildButton({
    required VoidCallback? onPressed,
    required String label,
    required bool isLoading,
  }) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? _cardColor.withOpacity(0.6) : _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        )
            : Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}