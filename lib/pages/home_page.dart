import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Cor principal do tema, mais rica
  static const Color _primaryColor = Color(0xFF5E35B1);
  // Cor para elementos secundários
  static const Color _lightPurple = Color(0xFF8E6DE3);

  @override
  Widget build(BuildContext context) {
    // Busca o usuário logado apenas para pegar o ID e Email
    final user = Supabase.instance.client.auth.currentUser;
    final userEmail = user?.email ?? 'Nenhum e-mail registrado';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F9),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 0,
        backgroundColor: _primaryColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header de Boas-Vindas (Agora busca o nome no banco) ---
            _buildWelcomeHeader(user, userEmail, context),

            const SizedBox(height: 24),

            // --- Seção de Ações Rápidas ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ações Rápidas',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Grid de ações principais
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          context,
                          icon: Icons.add_circle_outline,
                          label: 'Novo Ganho',
                          cor: Colors.green.shade600,
                          rota: '/income',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildQuickActionCard(
                          context,
                          icon: Icons.remove_circle_outline,
                          label: 'Novo Gasto',
                          cor: Colors.red.shade600,
                          rota: '/expense',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // Card Dashboard
                  _buildFeaturedCard(
                    context,
                    icon: Icons.analytics_outlined,
                    titulo: 'Dashboard Completo',
                    descricao: 'Veja o balanço e performance do mês',
                    cor: _primaryColor,
                    rota: '/dashboard',
                  ),

                  const SizedBox(height: 35),

                  // --- Seção de Configurações ---
                  const Text(
                    'Configurações',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Itens de configuração
                  _buildSettingsItem(
                    context,
                    icon: Icons.category_outlined,
                    titulo: 'Gerenciar Categorias',
                    descricao: 'Receitas e despesas do casal',
                    rota: '/manage_categories',
                  ),

                  const SizedBox(height: 12),

                  _buildSettingsItem(
                    context,
                    icon: Icons.settings_suggest_outlined,
                    titulo: 'Preferências do App',
                    descricao: 'Moeda, alertas e tema',
                    rota: '/settings',
                  ),

                  const SizedBox(height: 30),

                  // Botão de Sair
                  _buildLogoutButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para o Header de Boas-Vindas
  // Alterado para receber o Objeto User inteiro e buscar o nome
  Widget _buildWelcomeHeader(User? user, String userEmail, BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bem-vindos! 🏡',
                    style: TextStyle(
                      color: Color(0xFFD1C4E9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // AQUI ESTÁ A MÁGICA: FutureBuilder para buscar o nome
                  user == null 
                  ? const Text('E aí, Visitante!', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))
                  : FutureBuilder<Map<String, dynamic>>(
                      // Query otimizada no Supabase
                      future: Supabase.instance.client
                          .from('profiles')
                          .select('name')
                          .eq('id', user.id)
                          .single(), // .single() pois esperamos apenas 1 registro por ID
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          // Estado de carregamento suave
                          return const Text(
                            'E aí, ...', 
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        
                        // Fallback se der erro ou campo vier vazio
                        String displayName = 'Parceiro(a)';
                        
                        if (snapshot.hasData && snapshot.data != null) {
                           // Pega o valor da coluna 'name', se for nulo usa o fallback
                           displayName = snapshot.data!['name'] ?? displayName;
                        }

                        return Text(
                          'E aí, $displayName!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            userEmail,
            style: const TextStyle(
              color: Color(0xFFD1C4E9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Card de ação rápida
  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color cor,
    required String rota,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, rota),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 130,
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: cor),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card de destaque (dashboard)
  Widget _buildFeaturedCard(
    BuildContext context, {
    required IconData icon,
    required String titulo,
    required String descricao,
    required Color cor,
    required String rota,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, rota),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cor, cor.withOpacity(0.8)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cor.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 38, color: Colors.white),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descricao,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // Item de Configuração
  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String titulo,
    required String descricao,
    required String rota,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, rota),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _lightPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 26, color: _primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      descricao,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Botão de Logout
  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextButton.icon(
        icon: const Icon(Icons.exit_to_app, color: Colors.grey),
        label: const Text(
          'Encerrar Sessão (Logout)',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () async {
          await Supabase.instance.client.auth.signOut();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
      ),
    );
  }
}