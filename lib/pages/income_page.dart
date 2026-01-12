import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

// ✅ Adicione a classe CurrencyInputFormatter
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '0.00',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    int value = int.parse(newText);
    double amount = value / 100.0;
    String formatted = amount.toStringAsFixed(2);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  final valueController = TextEditingController();

  bool loading = false;
  String errorMessage = '';
  String? selectedCategory;
  double? calculatedTithe;
  bool showTitheResult = false;

  List<String> categories = [];

  static const Color _primaryColor = Color(0xFF00E676);
  static const Color _backgroundColor = Color(0xFF000000);
  static const Color _cardColor = Color(0xFF121212);
  static const Color _successColor = Color(0xFF00C853);

  @override
  void initState() {
    super.initState();
    loadCategories();
  }

  @override
  void dispose() {
    valueController.dispose();
    super.dispose();
  }

  Future<void> loadCategories() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('income_categories')
          .select('name');

      setState(() {
        categories = response.map<String>((e) => e['name'] as String).toList();
      });
    } catch (e) {
      print("Erro ao carregar categorias: $e");
    }
  }

  Future<void> saveIncome() async {
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

    // ✅ Simplificado - agora já vem formatado
    double? valor = double.tryParse(valueController.text);

    if (valor == null || valor <= 0) {
      setState(() {
        errorMessage = "Valor inválido!";
        loading = false;
      });
      return;
    }

    try {
      await Supabase.instance.client.from('incomes').insert({
        'type': selectedCategory,
        'value': valor,
        'user_id': user.id,
      });

      final tithe = valor * 0.10;

      setState(() {
        calculatedTithe = tithe;
        showTitheResult = true;
        loading = false;
      });

      print('✅ Ganho salvo: R\$ ${valor.toStringAsFixed(2)}');
      print('📊 Dízimo (10%): R\$ ${tithe.toStringAsFixed(2)}');

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
          'Registrar Ganho',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: showTitheResult ? _buildTitheResult() : _buildIncomeForm(),
    );
  }

  Widget _buildIncomeForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Categoria do Ganho',
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

          // ✅ TextField com formatação automática
          TextField(
            controller: valueController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Valor (ex: 2500.00)',
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

          ElevatedButton(
            onPressed: loading ? null : saveIncome,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
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
                    'SALVAR GANHO',
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

  Widget _buildTitheResult() {
    // ✅ Simplificado
    final income = double.tryParse(valueController.text) ?? 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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

            const Text(
              'GANHO REGISTRADO!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

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
                  _buildInfoRow(
                    icon: Icons.account_balance_wallet,
                    label: 'Valor Total',
                    value: 'R\$ ${income.toStringAsFixed(2)}',
                    valueColor: Colors.white,
                  ),

                  const Divider(height: 30, color: Colors.white24),

                  _buildInfoRow(
                    icon: Icons.volunteer_activism,
                    label: 'Dízimo (10%)',
                    value: 'R\$ ${calculatedTithe!.toStringAsFixed(2)}',
                    valueColor: _successColor,
                    highlight: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: const Text(
                '"Honra ao Senhor com teus bens e com as primícias de toda a tua renda"\n— Provérbios 3:9',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 30),

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
                  fontSize: highlight ? 28 : 24,
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