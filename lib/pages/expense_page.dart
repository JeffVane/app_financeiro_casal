import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';


class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove tudo que não é número
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '0.00',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    // Converte para inteiro (centavos)
    int value = int.parse(newText);
    
    // Divide por 100 para ter os centavos
    double amount = value / 100.0;
    
    // Formata com 2 casas decimais
    String formatted = amount.toStringAsFixed(2);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final valueController = TextEditingController();
  
  bool loading = false;
  String errorMessage = '';
  String? selectedCategory;
  bool showSuccessResult = false;
  double? savedExpenseValue;

  List<String> categories = [];

// Cores Temáticas – GASTOS
static const Color _primaryColor = Color(0xFFFF1744); // Vermelho forte
static const Color _backgroundColor = Color(0xFF000000); // Preto
static const Color _cardColor = Color(0xFF121212); // Preto elevado
static const Color _successColor = Color(0xFF2E7D32); // Verde discreto (se precisar)
static const Color _warningColor = Color(0xFFD50000); // Vermelho alerta


  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  
@override
void dispose() {
  valueController.dispose();
  descricaoController.dispose();
  super.dispose();
}

  Future<void> loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('expense_categories')
          .select('name')
          .order('name');

      setState(() {
        categories = response.map<String>((e) => e['name'] as String).toList();
      });
    } catch (e) {
      print("Erro ao carregar categorias: $e");
    }
  }

  // Adicionar controlador para descrição
final descricaoController = TextEditingController();


// Atualização do saveExpense
Future<void> saveExpense() async {
  setState(() {
    loading = true;
    errorMessage = '';
  });

  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    setState(() {
      errorMessage = "Usuário não encontrado!";
      loading = false;
    });
    return;
  }

  if (selectedCategory == null) {
    setState(() {
      errorMessage = "Selecione uma categoria!";
      loading = false;
    });
    return;
  }

  double? valor = double.tryParse(valueController.text);
  if (valor == null || valor <= 0) {
    setState(() {
      errorMessage = "Valor inválido!";
      loading = false;
    });
    return;
  }

  final descricao = descricaoController.text.trim();

  try {
    await Supabase.instance.client.from('expenses').insert({
      'type': selectedCategory,
      'value': valor,
      'description': descricao, // ✅ novo campo
      'user_id': user.id,
    });

    setState(() {
      savedExpenseValue = valor;
      showSuccessResult = true;
      loading = false;
    });

    print('✅ Gasto salvo: R\$ ${valor.toStringAsFixed(2)}');
    print('📁 Categoria: $selectedCategory');
    print('📝 Descrição: $descricao');

  } catch (e) {
    setState(() {
      errorMessage = 'Erro ao salvar: $e';
      loading = false;
    });
  }
}



  void _goToHome() {
    Navigator.pop(context);
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _backgroundColor,
    appBar: AppBar(
      title: const Text(
        'Registrar Gasto',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: _primaryColor, // VERMELHO AQUI
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
    ),
    body: showSuccessResult
        ? _buildSuccessResult()
        : _buildExpenseForm(),
  );
}


  // Formulário de entrada de gasto
  Widget _buildExpenseForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Categoria
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Categoria do Gasto',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: _cardColor,
            style: const TextStyle(color: Colors.white),
            value: selectedCategory,
            items: categories
                .map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value;
              });
            },
          ),

          const SizedBox(height: 20),

          // Valor
          TextField(
  controller: valueController,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    CurrencyInputFormatter(), // ← ADICIONE AQUI
  ],
  style: const TextStyle(color: Colors.white, fontSize: 18),
  decoration: InputDecoration(
    labelText: 'Valor (ex: 120.00)',
    labelStyle: const TextStyle(color: Colors.white70),
    prefixIcon: const Icon(Icons.attach_money, color: Colors.white70),
    filled: true,
    fillColor: _cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _primaryColor, width: 2),
    ),
  ),
),
          const SizedBox(height: 30),

          // Mensagem de erro
          if (errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent, width: 1),
              ),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),

            // Descrição
          TextField(
            controller: descricaoController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Descrição do Gasto',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.description, color: Colors.white70),
              filled: true,
              fillColor: _cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _primaryColor, width: 2),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),


          // Botão Salvar
          ElevatedButton(
            onPressed: loading ? null : saveExpense,
            style: ElevatedButton.styleFrom(
              backgroundColor: _warningColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Text(
                    'SALVAR GASTO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Tela de resultado de sucesso
  Widget _buildSuccessResult() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone de sucesso
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _successColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _successColor, width: 3),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: _successColor,
                size: 80,
              ),
            ),

            const SizedBox(height: 30),

            // Título
            const Text(
              'GASTO REGISTRADO!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Card com informações
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Categoria
                  _buildInfoRow(
                    icon: Icons.category,
                    label: 'Categoria',
                    value: selectedCategory ?? '-',
                    valueColor: Colors.white,
                  ),

                  const Divider(height: 30, color: Colors.white24),

                  // Valor gasto
                  _buildInfoRow(
                    icon: Icons.money_off,
                    label: 'Valor Gasto',
                    value: 'R\$ ${savedExpenseValue!.toStringAsFixed(2)}',
                    valueColor: _warningColor,
                    highlight: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Mensagem motivacional
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: const Text(
                '💡 Controle seus gastos e mantenha suas finanças saudáveis!',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 30),

            // Botão Voltar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _goToHome,
                icon: const Icon(Icons.home, size: 22),
                label: const Text(
                  'VOLTAR PARA HOME',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: highlight ? 28 : 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}