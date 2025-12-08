import 'package:flutter/material.dart';
import 'dart:async'; // Essencial para Future.delayed

class WelcomePage extends StatefulWidget {
  final String loginRoute = '/login'; 
  final int durationInSeconds = 8; // Duração total do splash
  
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  // Cores constantes
  static const Color _primaryColor = Color(0xFF5E35B1);
  static const Color _lightPurple = Color(0xFF8E6DE3);
  
  // Variáveis para Animação (Fade In)
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // 1. Configuração da Animação
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Duração do efeito de "aparecer"
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn, 
      ),
    );
    
    // Iniciar a animação de Fade In
    _animationController.forward();
    
    // 2. Configurar o Temporizador para Navegação
    _startAutoNavigation();
  }

  void _startAutoNavigation() {
    // Navega após o tempo total definido (8 segundos)
    Future.delayed(Duration(seconds: widget.durationInSeconds), () {
      if (mounted) {
        // Usa pushReplacementNamed para ir para a tela de login sem volta
        Navigator.of(context).pushReplacementNamed(widget.loginRoute);
      }
    });
  }

  @override
  void dispose() {
    // Liberar o controller da animação
    _animationController.dispose();
    super.dispose();
  }

  // Widget para cada feature/benefício (Mantido para o layout visual)
  Widget _buildFeature(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // O FadeTransition aplica o efeito de opacidade a todo o conteúdo
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation, // Usa a animação de opacidade
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _lightPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Centraliza tudo
                children: [
                  // Conteúdo principal centralizado
                  // Ícone/Logo do App
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Título
                  const Text(
                    'Finanças do Casal',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Subtítulo
                  Text(
                    'Gerenciem juntos as finanças\nde forma simples e organizada',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 50),

                  // Features/Benefícios
                  _buildFeature(
                    Icons.trending_up,
                    'Acompanhe ganhos e gastos',
                  ),
                  const SizedBox(height: 16),
                  _buildFeature(
                    Icons.pie_chart_outline,
                    'Visualize relatórios detalhados',
                  ),
                  const SizedBox(height: 16),
                  _buildFeature(
                    Icons.category_outlined,
                    'Organize por categorias',
                  ),

                  const SizedBox(height: 40), // Espaço para equilibrar a tela
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}