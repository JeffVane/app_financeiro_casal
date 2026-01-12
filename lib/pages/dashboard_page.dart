import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;

  // Mês selecionado
  late DateTime mesSelecionado;

  // Dados do casal
  double seusGanhos = 0;
  double seusGastos = 0;
  double seuSaldo = 0;
  double seuDizimo = 0;

  double ganhosEla = 0;
  double gastosEla = 0;
  double saldoEla = 0;
  double dizimoEla = 0;

  double totalDoCasal = 0;
  double saldoDisponivelCasal = 0; // ← NOVO: Saldo disponível para guardar

  // Identificação dinâmica
  String labelVoce = "VOCÊ";
  String labelParceiro = "PARCEIRO(A)";

  // Abas (VOCÊ | PARCEIRO | CASAL)
  int abaSelecionada = 0;

  // Extratos
  List incomesVoce = [];
  List incomesEla = [];
  List expensesVoce = [];
  List expensesEla = [];

  // Totais por categoria
  Map<String, double> totaisGanhosVoce = {};
  Map<String, double> totaisGastosVoce = {};
  Map<String, double> totaisGanhosEla = {};
  Map<String, double> totaisGastosEla = {};

  // Totais combinados do casal
  Map<String, double> totaisGanhosCasal = {};
  Map<String, double> totaisGastosCasal = {};
  List<Map<String, dynamic>> cofrinhos = [];

  List incomesCasal = [];
  List expensesCasal = [];

  // Flag para indicar se há parceiro cadastrado
  bool temParceiro = false;

  @override
  void initState() {
    super.initState();
    mesSelecionado = DateTime(DateTime.now().year, DateTime.now().month);
    carregarDashboard();
    carregarCofrinhos();
  }

  String nomeMes(DateTime dt) {
    return DateFormat("MMMM yyyy", "pt_BR").format(dt);
  }

  DateTime primeiroDiaMes(DateTime dt) {
    return DateTime(dt.year, dt.month, 1);
  }

  void mudarMes(int delta) {
    setState(() {
      mesSelecionado = DateTime(mesSelecionado.year, mesSelecionado.month + delta);
      loading = true;
    });
    carregarDashboard();
  }

  // ✅ MODIFICADO: Busca cofrinhos COMPARTILHADOS (sem user_id)
  Future<void> carregarCofrinhos() async {
    try {
      final resp = await Supabase.instance.client
          .from('savings_jars')
          .select('id, name, balance')
          .order('created_at');

      setState(() {
        cofrinhos = List<Map<String, dynamic>>.from(resp);
      });

      print("🪙 COFRINHOS CARREGADOS: $cofrinhos");
    } catch (e) {
      print("❌ ERRO AO BUSCAR COFRINHOS: $e");
    }
  }

  Future<double> somaValores(String tabela, String userId, String inicioMes) async {
  // Calcula o último dia do mês
  final DateTime inicioMesDate = DateTime.parse(inicioMes);
  final DateTime fimMes = DateTime(inicioMesDate.year, inicioMesDate.month + 1, 1).subtract(const Duration(days: 1));
  final String fimMesStr = fimMes.toIso8601String();

  final resp = await Supabase.instance.client
      .from(tabela)
      .select('value')
      .eq('user_id', userId)
      .gte('date', inicioMes)  // ✅ A partir do dia 1 do mês
      .lte('date', fimMesStr);  // ✅ Até o último dia do mês

  double total = 0.0;
  for (var item in resp) {
    total += (item["value"] as num).toDouble();
  }
  return total;
}

  Future<List<Map<String, dynamic>>> extrato(
    String tabela, String userId, String inicioMes) async {
  final DateTime inicioMesDate = DateTime.parse(inicioMes);
  final DateTime fimMes = DateTime(inicioMesDate.year, inicioMesDate.month + 1, 1).subtract(const Duration(days: 1));
  final String fimMesStr = fimMes.toIso8601String();

  return await Supabase.instance.client
      .from(tabela)
      .select("id, type, value, date, description")
      .eq("user_id", userId)
      .gte("date", inicioMes)
      .lte("date", fimMesStr)
      .order("date", ascending: false);
}

Future<Map<String, double>> totaisPorCategoria(
    String tabela, String userId, String inicioMes) async {
  final DateTime inicioMesDate = DateTime.parse(inicioMes);
  final DateTime fimMes = DateTime(inicioMesDate.year, inicioMesDate.month + 1, 1).subtract(const Duration(days: 1));
  final String fimMesStr = fimMes.toIso8601String();

  final resp = await Supabase.instance.client
      .from(tabela)
      .select("type, value")
      .eq("user_id", userId)
      .gte("date", inicioMes)
      .lte("date", fimMesStr);

  Map<String, double> mapa = {};
  for (var e in resp) {
    final cat = e["type"];
    final val = (e["value"] as num).toDouble();
    mapa[cat] = (mapa[cat] ?? 0) + val;
  }
  return mapa;
}

  Map<String, double> combinarCategorias(Map<String, double> map1, Map<String, double> map2) {
    Map<String, double> resultado = {};
    
    map1.forEach((key, value) {
      resultado[key] = value;
    });
    
    map2.forEach((key, value) {
      resultado[key] = (resultado[key] ?? 0) + value;
    });
    
    return resultado;
  }

  // ✅ MODIFICADO: Calcula total guardado nos cofrinhos no mês
  Future<double> somaDepositosCofrinhosMes(String inicioMes) async {
  try {
    if (cofrinhos.isEmpty) return 0.0;

    double totalLiquido = 0.0;

    for (var jar in cofrinhos) {
      final transactions = await Supabase.instance.client
          .from('savings_transactions')
          .select('amount, type')
          .eq('jar_id', jar['id'])
          .gte('created_at', inicioMes);

      for (var t in transactions) {
        if (t['type'] == 'deposit') {
          // Adiciona depósitos
          totalLiquido += (t['amount'] as num).toDouble();
        } else if (t['type'] == 'withdraw') {
          // Subtrai retiradas (que voltaram para conta)
          totalLiquido -= (t['amount'] as num).toDouble();
        }
      }
    }

    return totalLiquido;
  } catch (e) {
    print("❌ ERRO AO SOMAR LÍQUIDO COFRINHOS: $e");
    return 0.0;
  }
}

  Future<void> criarCofrinho(String nome) async {
  try {
    final supabase = Supabase.instance.client;

    if (nome.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Digite um nome válido para o cofrinho")),
        );
      }
      return;
    }

    // Insere novo cofrinho na tabela
    await supabase.from('savings_jars').insert({
      'name': nome.trim(),
      'balance': 0.0, // saldo inicial
      'created_at': DateTime.now().toIso8601String(),
    });

    // Recarrega cofrinhos
    await carregarCofrinhos();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🪙 Cofrinho '$nome' criado!")),
      );
    }
  } catch (e) {
    print("❌ ERRO AO CRIAR COFRINHO: $e");
  }
}

void abrirDialogCriarCofrinho() {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Novo Cofrinho"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: "Nome do cofrinho",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {
            final nome = controller.text;
            if (nome.isNotEmpty) {
              criarCofrinho(nome);
              Navigator.pop(context);
            }
          },
          child: const Text("Criar"),
        ),
      ],
    ),
  );
}
Future<void> excluirCofrinho(String jarId, String nome) async {
  try {
    final supabase = Supabase.instance.client;

    // Exclui o cofrinho da tabela
    await supabase.from('savings_jars').delete().eq('id', jarId);

    // Opcional: excluir também transações associadas
    await supabase.from('savings_transactions').delete().eq('jar_id', jarId);

    // Recarrega cofrinhos
    await carregarCofrinhos();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🗑️ Cofrinho '$nome' excluído!")),
      );
    }
  } catch (e) {
    print("❌ ERRO AO EXCLUIR COFRINHO: $e");
  }
}
void abrirDialogExcluirCofrinho(String jarId, String nome) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Confirmar exclusão"),
      content: Text("Tem certeza que deseja excluir o cofrinho '$nome'? Esta ação não pode ser desfeita."),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {
            excluirCofrinho(jarId, nome);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text("Excluir"),
        ),
      ],
    ),
  );
}



  // ✅ NOVO: Guardar no cofrinho descontando do saldo disponível
  Future<void> guardarNoCofrinho({
    required String jarId,
    required double valor,
  }) async {
    try {
      // Verifica se há saldo disponível
      if (valor > saldoDisponivelCasal) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Saldo insuficiente! Disponível: R\$ ${saldoDisponivelCasal.toStringAsFixed(2)}"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final supabase = Supabase.instance.client;

      await supabase.from('savings_transactions').insert({
        'jar_id': jarId,
        'type': 'deposit',
        'amount': valor,
      });

      await supabase.rpc('increment_jar_balance', params: {
        'p_jar_id': jarId,
        'p_amount': valor,
      });

      await carregarCofrinhos();
      await carregarDashboard(); // ← Recarrega para atualizar o saldo disponível

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("💰 R\$ ${valor.toStringAsFixed(2)} guardado!")),
        );
      }

    } catch (e) {
      print("❌ ERRO AO GUARDAR NO COFRINHO: $e");
    }
  }

  Future<void> retirarDoCofrinho({
    required String jarId,
    required double valor,
    required bool voltarParaConta,
    String? descricaoGasto,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user == null) {
        print("❌ Nenhum usuário logado!");
        return;
      }

     
      // Registra a transação do cofrinho com descrição
        await supabase.from('savings_transactions').insert({
          'jar_id': jarId,
          'type': 'withdraw',
          'amount': valor,
          'description': voltarParaConta 
              ? 'Voltou para conta' 
              : 'Gasto: $descricaoGasto',
        });

      // Decrementa saldo do cofrinho
      await supabase.rpc('decrement_jar_balance', params: {
        'p_jar_id': jarId,
        'p_amount': valor,
      });

      // Se NÃO voltou para conta, registra como gasto
      if (!voltarParaConta && descricaoGasto != null) {
        await supabase.from('expenses').insert({
          'user_id': user.id,
          'type': 'Retirada de Cofrinho',
          'value': valor,
          'date': DateTime.now().toIso8601String(),
          'description': descricaoGasto,
        });
      }

      await carregarCofrinhos();
      await carregarDashboard();

      if (mounted) {
        final mensagem = voltarParaConta
            ? "💰 R\$ ${valor.toStringAsFixed(2)} voltou para conta!"
            : "💸 R\$ ${valor.toStringAsFixed(2)} registrado como gasto!";
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagem)),
        );
      }

    } catch (e) {
      print("❌ ERRO AO RETIRAR DO COFRINHO: $e");
    }
  }

  // ✅ MODIFICADO: Mostra saldo disponível no dialog
  void abrirDialogGuardar(String jarId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Guardar no cofrinho"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "💰 Saldo disponível: R\$ ${saldoDisponivelCasal.toStringAsFixed(2)}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Valor",
                prefixText: "R\$ ",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final valor = double.tryParse(controller.text);
              if (valor != null && valor > 0) {
                guardarNoCofrinho(jarId: jarId, valor: valor);
                Navigator.pop(context);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void abrirDialogRetirar(String jarId, num saldoAtual) {
  final valorController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Retirar do cofrinho"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Saldo disponível: R\$ ${saldoAtual.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: valorController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Valor",
              prefixText: "R\$ ",
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {
            final valor = double.tryParse(valorController.text);
            
            if (valor == null || valor <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Digite um valor válido!")),
              );
              return;
            }
            
            if (valor > saldoAtual) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Saldo insuficiente!")),
              );
              return;
            }

            Navigator.pop(context);
            _escolherDestinoRetirada(jarId, valor);
          },
          child: const Text("Continuar"),
        ),
      ],
    ),
  );
}

void _escolherDestinoRetirada(String jarId, double valor) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Para onde vai o dinheiro?"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "R\$ ${valor.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text(
            "Escolha o destino da retirada:",
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            retirarDoCofrinho(
              jarId: jarId,
              valor: valor,
              voltarParaConta: true,
            );
          },
          icon: const Icon(Icons.account_balance_wallet),
          label: const Text("Voltar p/ Conta"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _pedirDescricaoGasto(jarId, valor);
          },
          icon: const Icon(Icons.shopping_cart),
          label: const Text("Registrar Gasto"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        ),
      ],
    ),
  );
}

void _pedirDescricaoGasto(String jarId, double valor) {
  final descricaoController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Descreva o gasto"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "R\$ ${valor.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descricaoController,
            decoration: const InputDecoration(
              labelText: "Descrição do gasto *",
              hintText: "Ex: Jantar em restaurante",
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {
            final descricao = descricaoController.text.trim();
            
            if (descricao.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("⚠️ A descrição é obrigatória!")),
              );
              return;
            }

            Navigator.pop(context);
            retirarDoCofrinho(
              jarId: jarId,
              valor: valor,
              voltarParaConta: false,
              descricaoGasto: descricao,
            );
          },
          child: const Text("Confirmar Gasto"),
        ),
      ],
    ),
  );
}

Future<void> verHistoricoCofrinho(String jarId, String nomeCofrinho) async {
  try {
    final transactions = await Supabase.instance.client
        .from('savings_transactions')
        .select('amount, type, description, created_at')
        .eq('jar_id', jarId)
        .order('created_at', ascending: false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Histórico: $nomeCofrinho"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: transactions.isEmpty
              ? const Center(child: Text("Nenhuma transação encontrada"))
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, i) {
                    final t = transactions[i];
                    final isDeposit = t['type'] == 'deposit';
                    final valor = (t['amount'] as num).toDouble();
                    final descricao = t['description'] ?? '';
                    final data = DateTime.parse(t['created_at']).toLocal();

                    return ListTile(
                      leading: Icon(
                        isDeposit ? Icons.add_circle : Icons.remove_circle,
                        color: isDeposit ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        '${isDeposit ? '+' : '-'} R\$ ${valor.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDeposit ? Colors.green : Colors.red,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (descricao.isNotEmpty)
                            Text(descricao, style: const TextStyle(fontStyle: FontStyle.italic)),
                          Text(
                            '${DateFormat('dd/MM/yyyy').format(data)} às ${DateFormat('HH:mm').format(data)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );
  } catch (e) {
    print("❌ Erro ao buscar histórico: $e");
  }
}

// ✅ ADICIONE ESTAS 2 FUNÇÕES ANTES DO carregarDashboard()

Future<double> calcularSaldoAcumulado(String userId, String ateData) async {
  try {
    // Soma todos os ganhos até a data
    final respGanhos = await Supabase.instance.client
        .from('incomes')
        .select('value')
        .eq('user_id', userId)
        .lte('date', ateData);

    double totalGanhos = 0.0;
    for (var item in respGanhos) {
      totalGanhos += (item["value"] as num).toDouble();
    }

    // Soma todos os gastos até a data
    final respGastos = await Supabase.instance.client
        .from('expenses')
        .select('value')
        .eq('user_id', userId)
        .lte('date', ateData);

    double totalGastos = 0.0;
    for (var item in respGastos) {
      totalGastos += (item["value"] as num).toDouble();
    }

    // Calcula dízimo acumulado
    final dizimo = totalGanhos * 0.10;

    // Calcula quanto foi guardado nos cofrinhos até essa data
    final guardadoAntigo = await somaDepositosCofrinhosMesAte(ateData);

    // Saldo = ganhos - gastos - dízimo - guardado
    final saldo = totalGanhos - totalGastos - dizimo - guardadoAntigo;

    print("💰 Saldo acumulado até $ateData: R\$ ${saldo.toStringAsFixed(2)}");
    
    return saldo > 0 ? saldo : 0.0;
  } catch (e) {
    print("❌ Erro ao calcular saldo acumulado: $e");
    return 0.0;
  }
}

Future<double> somaDepositosCofrinhosMesAte(String ateData) async {
  try {
    if (cofrinhos.isEmpty) return 0.0;

    double totalLiquido = 0.0;

    for (var jar in cofrinhos) {
      final transactions = await Supabase.instance.client
          .from('savings_transactions')
          .select('amount, type')
          .eq('jar_id', jar['id'])
          .lte('created_at', ateData);

      for (var t in transactions) {
        if (t['type'] == 'deposit') {
          totalLiquido += (t['amount'] as num).toDouble();
        } else if (t['type'] == 'withdraw') {
          totalLiquido -= (t['amount'] as num).toDouble();
        }
      }
    }

    return totalLiquido;
  } catch (e) {
    print("❌ ERRO AO SOMAR LÍQUIDO COFRINHOS ATÉ DATA: $e");
    return 0.0;
  }
}

  Future<void> carregarDashboard() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    print("❌ Nenhum usuário logado!");
    return;
  }

  final inicioMes = primeiroDiaMes(mesSelecionado).toIso8601String();
  final fimMesAnterior = primeiroDiaMes(mesSelecionado).subtract(const Duration(days: 1)).toIso8601String();

  try {
    print("🔍 Buscando perfil do usuário logado: ${user.id}");

    final perfilLogadoResp = await Supabase.instance.client
        .from("profiles")
        .select("id, role, name") 
        .eq("id", user.id);

    if (perfilLogadoResp.isEmpty) {
      print("❌ Perfil não encontrado para o usuário logado!");
      setState(() => loading = false);
      return;
    }

    final perfilLogado = perfilLogadoResp[0];
    final String seuId = perfilLogado["id"];
    final String? role = perfilLogado["role"];

    print("✅ Perfil encontrado - ID: $seuId, Role: $role");

    // ✅ Calcula saldo acumulado até o mês ANTERIOR
    final saldoAnteriorVoce = await calcularSaldoAcumulado(seuId, fimMesAnterior);
    
    // ✅ Ganhos e gastos APENAS DO MÊS SELECIONADO
    seusGanhos = await somaValores("incomes", seuId, inicioMes);
    seusGastos = await somaValores("expenses", seuId, inicioMes);
    seuDizimo = seusGanhos * 0.10;
    
    // ✅ Saldo = acumulado anterior + movimentação do mês
    seuSaldo = saldoAnteriorVoce + seusGanhos - seusGastos - seuDizimo;

    incomesVoce = await extrato("incomes", seuId, inicioMes);
    expensesVoce = await extrato("expenses", seuId, inicioMes);
    totaisGanhosVoce = await totaisPorCategoria("incomes", seuId, inicioMes);
    totaisGastosVoce = await totaisPorCategoria("expenses", seuId, inicioMes);

    // Lógica para descobrir parceiro
    String? roleParaBuscar;

    if (role == null || role.isEmpty) {
      roleParaBuscar = null;
    } else if (role == "voce") {
      roleParaBuscar = "ela";
    } else if (role == "ela") {
      roleParaBuscar = "voce";
    } else {
      roleParaBuscar = null;
    }

    List outrosPerfis;

    if (roleParaBuscar != null) {
      outrosPerfis = await Supabase.instance.client
          .from("profiles")
          .select("id, role, name")
          .eq("role", roleParaBuscar);
    } else {
      outrosPerfis = await Supabase.instance.client
          .from("profiles")
          .select("id, role, name")
          .neq("id", seuId);
    }

    // Verificar se existe parceiro cadastrado
    if (outrosPerfis.isNotEmpty) {
      temParceiro = true;
      final dadosParceiro = outrosPerfis[0];
      final String elaId = dadosParceiro["id"];
      
      final String nomeBanco = dadosParceiro["name"] ?? "PARCEIRO(A)";
      labelParceiro = nomeBanco.toUpperCase();

      // ✅ Calcula saldo acumulado até o mês ANTERIOR do parceiro
      final saldoAnteriorEla = await calcularSaldoAcumulado(elaId, fimMesAnterior);

      // ✅ Ganhos e gastos APENAS DO MÊS SELECIONADO do parceiro
      ganhosEla = await somaValores("incomes", elaId, inicioMes);
      gastosEla = await somaValores("expenses", elaId, inicioMes);
      dizimoEla = ganhosEla * 0.10;
      
      // ✅ Saldo = acumulado anterior + movimentação do mês
      saldoEla = saldoAnteriorEla + ganhosEla - gastosEla - dizimoEla;

      incomesEla = await extrato("incomes", elaId, inicioMes);
      expensesEla = await extrato("expenses", elaId, inicioMes);
      totaisGanhosEla = await totaisPorCategoria("incomes", elaId, inicioMes);
      totaisGastosEla = await totaisPorCategoria("expenses", elaId, inicioMes);

      totalDoCasal = seuSaldo + saldoEla;

      // CASAL - Combinar dados
      totaisGanhosCasal = combinarCategorias(totaisGanhosVoce, totaisGanhosEla);
      totaisGastosCasal = combinarCategorias(totaisGastosVoce, totaisGastosEla);
      incomesCasal = [...incomesVoce, ...incomesEla]..sort((a, b) =>
          DateTime.parse(b["date"]).compareTo(DateTime.parse(a["date"])));
      expensesCasal = [...expensesVoce, ...expensesEla]..sort((a, b) =>
          DateTime.parse(b["date"]).compareTo(DateTime.parse(a["date"])));

    } else {
      // Não há parceiro
      temParceiro = false;
      labelParceiro = "PARCEIRO(A)";
      totalDoCasal = seuSaldo;

      ganhosEla = 0; gastosEla = 0; dizimoEla = 0; saldoEla = 0;
      incomesEla = []; expensesEla = [];
      totaisGanhosEla = {}; totaisGastosEla = {};

      totaisGanhosCasal = Map.from(totaisGanhosVoce);
      totaisGastosCasal = Map.from(totaisGastosVoce);
      incomesCasal = List.from(incomesVoce);
      expensesCasal = List.from(expensesVoce);
    }

    // ✅ Calcula saldo disponível descontando o que foi guardado nos cofrinhos NO MÊS ATUAL
    final double guardadoNoMes = await somaDepositosCofrinhosMes(inicioMes);

    // Atualiza saldo disponível do casal
    saldoDisponivelCasal = totalDoCasal - guardadoNoMes;
    if (saldoDisponivelCasal < 0) saldoDisponivelCasal = 0;

    print("💰 Total do casal: R\$ ${totalDoCasal.toStringAsFixed(2)}");
    print("🪙 Guardado nos cofrinhos este mês: R\$ ${guardadoNoMes.toStringAsFixed(2)}");
    print("✅ Saldo disponível: R\$ ${saldoDisponivelCasal.toStringAsFixed(2)}");

    setState(() => loading = false);
  } catch (e, stackTrace) {
    print("❌ ERRO NO DASHBOARD: $e");
    print("📍 Stack trace: $stackTrace");
    setState(() => loading = false);
  }
}


  Widget iconeAcao({required IconData icon, required String label, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, size: 32, color: Colors.black),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
  Widget graficoPizza(Map<String, double> dados) {
  if (dados.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        "Sem dados para exibir",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: dados.entries.map((e) {
        final porcentagem = (e.value / dados.values.reduce((a, b) => a + b) * 100);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.primaries[dados.keys.toList().indexOf(e.key) % Colors.primaries.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.key,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Text(
                "${porcentagem.toStringAsFixed(1)}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}
  Widget cardAbas() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF000000), // PRETO DIRETO
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        // Abas VOCÊ | PARCEIRO | CASAL
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            abaBotao(labelVoce, 0),
            abaBotao(labelParceiro, 1),
            abaBotao("CASAL", 2),
          ],
        ),
        const SizedBox(height: 12),

        // Conteúdo da aba
        if (abaSelecionada == 0)
          dadosPessoa(
            labelVoce,
            seusGanhos,
            seusGastos,
            seuDizimo,
            seuSaldo,
          )
        else if (abaSelecionada == 1)
          temParceiro
              ? dadosPessoa(
                  labelParceiro,
                  ganhosEla,
                  gastosEla,
                  dizimoEla,
                  saldoEla,
                )
              : const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Parceiro não encontrado no sistema",
                    style: TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                )
        else
          temParceiro
              ? dadosCasal()
              : const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Cadastre um parceiro para ver dados do casal",
                    style: TextStyle(color: Colors.orangeAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
      ],
    ),
  );
}


Widget cardCofrinhos() {
  double totalCofrinhos =
      cofrinhos.fold(0.0, (sum, c) => sum + (c["balance"] as num).toDouble());

  return Container(
    margin: const EdgeInsets.only(top: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black, // 🔥 PRETO TOTAL (CARD)
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.8),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + total + botão criar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "💰 Cofrinhos do Casal",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white, // texto claro
              ),
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "R\$ ${totalCofrinhos.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.add_circle, color: Colors.greenAccent),
                  onPressed: abrirDialogCriarCofrinho,
                  tooltip: "Criar cofrinho",
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Disponível: R\$ ${saldoDisponivelCasal.toStringAsFixed(2)}",
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),

        // Lista de cofrinhos
        if (cofrinhos.isNotEmpty)
          ...cofrinhos.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D), // ⚫ QUASE PRETO (COFRINHO)
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome e valor do cofrinho
                  Row(
                    children: [
                      const Icon(Icons.savings,
                          color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c["name"],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "R\$ ${(c["balance"] as num).toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Botões de ação
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _botaoCofrinho(
                        icone: Icons.history,
                        label: "Histórico",
                        cor: Colors.purpleAccent,
                        onTap: () =>
                            verHistoricoCofrinho(c["id"], c["name"]),
                      ),
                      _botaoCofrinho(
                        icone: Icons.add_circle,
                        label: "Guardar",
                        cor: Colors.greenAccent,
                        onTap: () => abrirDialogGuardar(c["id"]),
                      ),
                      _botaoCofrinho(
                        icone: Icons.remove_circle,
                        label: "Retirar",
                        cor: Colors.redAccent,
                        onTap: () =>
                            abrirDialogRetirar(c["id"], c["balance"]),
                      ),
                      _botaoCofrinho(
                        icone: Icons.edit,
                        label: "Editar",
                        cor: Colors.blueAccent,
                        onTap: () => abrirDialogRenomearCofrinho(
                            c["id"], c["name"]),
                      ),
                      _botaoCofrinho(
                        icone: Icons.delete,
                        label: "Excluir",
                        cor: Colors.grey,
                        onTap: () => abrirDialogExcluirCofrinho(
                            c["id"], c["name"]),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList()
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                "Nenhum cofrinho cadastrado.\nClique no '+' para criar um.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    ),
  );
}


// Widget auxiliar para botões do cofrinho
Widget _botaoCofrinho({
  required IconData icone,
  required String label,
  required Color cor,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: cor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}


void abrirDialogRenomearCofrinho(String jarId, String nomeAtual) {
  final controller = TextEditingController(text: nomeAtual);

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Renomear Cofrinho"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: "Novo nome"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () async {
            final novoNome = controller.text.trim();
            if (novoNome.isEmpty) return;

            try {
              await Supabase.instance.client
                  .from('savings_jars')
                  .update({'name': novoNome})
                  .eq('id', jarId);

              await carregarCofrinhos();
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Cofrinho renomeado para '$novoNome'!")),
              );
            } catch (e) {
              print("❌ Erro ao renomear cofrinho: $e");
            }
          },
          child: const Text("Salvar"),
        ),
      ],
    ),
  );
}


  Widget abaBotao(String label, int index) {
    final ativo = abaSelecionada == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          abaSelecionada = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: ativo ? Colors.deepPurple : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: ativo ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            )),
      ),
    );
  }

  Widget dadosPessoa(String nome, double g, double s, double d, double saldo) {
  return Column(
    children: [
      // Grid 2x2 (Ganhos, Gastos, Dízimo, Saldo)
      Row(
        children: [
          Expanded(child: _cardValor("Ganhos", g, Colors.green, Icons.trending_up)),
          const SizedBox(width: 8),
          Expanded(child: _cardValor("Gastos", s, Colors.red, Icons.trending_down)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _cardValor("Dízimo", d, Colors.orange, Icons.favorite)),
          const SizedBox(width: 8),
          Expanded(child: _cardValor("Saldo", saldo, Colors.blue, Icons.account_balance_wallet)),
        ],
      ),
    ],
  );
}

Widget dadosCasal() {
  final ganhosTotal = seusGanhos + ganhosEla;
  final gastosTotal = seusGastos + gastosEla;
  final dizimoTotal = seuDizimo + dizimoEla;
  
  return Column(
    children: [
      // Linha 1: 3 cards (Ganhos, Gastos, Dízimo)
      Row(
        children: [
          Expanded(child: _cardValor("Ganhos", ganhosTotal, Colors.green, Icons.trending_up)),
          const SizedBox(width: 8),
          Expanded(child: _cardValor("Gastos", gastosTotal, Colors.red, Icons.trending_down)),
          const SizedBox(width: 8),
          Expanded(child: _cardValor("Dízimo", dizimoTotal, Colors.orange, Icons.favorite)),
        ],
      ),
      const SizedBox(height: 8),
      
      // Linha 2: 2 cards (Total e Disponível)
      Row(
        children: [
          Expanded(child: _cardValor("Total Mês", totalDoCasal, Colors.blue, Icons.account_balance)),
          const SizedBox(width: 8),
          Expanded(child: _cardValor("Disponível", saldoDisponivelCasal, Colors.purple, Icons.savings)),
        ],
      ),
    ],
  );
}

// Card individual para cada valor
Widget _cardValor(String titulo, double valor, Color cor, IconData icone) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black, // ✅ FUNDO PRETO
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cor.withOpacity(0.3), width: 1), // borda sutil colorida
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, color: cor, size: 24), // ✅ ÍCONE COLORIDO
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                color: cor, // ✅ TÍTULO COLORIDO
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'R\$ ${valor.toStringAsFixed(2)}',
          style: TextStyle(
            color: cor, // ✅ VALOR COLORIDO
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

  Widget textoNegrito(String txt, Color cor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        txt,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor),
      ),
    );
  }

  Widget tituloSecao(String txt) {
  return Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Text(
      txt.toUpperCase(),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.2,
      ),
    ),
  );
}

  Widget listaExtrato(List lista) {
  if (lista.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        "Nenhum registro encontrado",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: lista.length,
    itemBuilder: (context, i) {
      final item = lista[i];
      return ListTile(
        title: Text(
          item["type"],
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((item["description"] ?? "").isNotEmpty)
              Text(
                item["description"],
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white60,
                ),
              ),
            Text(
              DateFormat("dd/MM").format(DateTime.parse(item["date"])),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        trailing: Text(
          "R\$ ${(item["value"] as num).toStringAsFixed(2)}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    },
  );
}


  Widget totaisCategoria(Map<String, double> mapa) {
  if (mapa.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        "Nenhuma categoria encontrada",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  return Column(
    children: mapa.entries.map((e) {
      return ListTile(
        title: Text(
          e.key,
          style: const TextStyle(color: Colors.white),
        ),
        trailing: Text(
          "R\$ ${e.value.toStringAsFixed(2)}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }).toList(),
  );
}

  List getIncomes() {
    if (abaSelecionada == 0) return incomesVoce;
    if (abaSelecionada == 1) return incomesEla;
    return incomesCasal;
  }

  List getExpenses() {
    if (abaSelecionada == 0) return expensesVoce;
    if (abaSelecionada == 1) return expensesEla;
    return expensesCasal;
  }

  Map<String, double> getTotaisGanhos() {
    if (abaSelecionada == 0) return totaisGanhosVoce;
    if (abaSelecionada == 1) return totaisGanhosEla;
    return totaisGanhosCasal;
  }

  Map<String, double> getTotaisGastos() {
    if (abaSelecionada == 0) return totaisGastosVoce;
    if (abaSelecionada == 1) return totaisGastosEla;
    return totaisGastosCasal;
  }

  String getLabelAtual() {
    if (abaSelecionada == 0) return labelVoce;
    if (abaSelecionada == 1) return labelParceiro;
    return "CASAL";
  }

  @override
Widget build(BuildContext context) {
  if (loading) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text("Dashboard do Casal"),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: Theme(
      data: ThemeData.dark().copyWith(
        cardColor: Colors.grey[900],
        dividerColor: Colors.grey[700],
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // SELETOR DE MÊS COM SETAS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => mudarMes(-1),
                icon: const Icon(Icons.chevron_left, size: 32, color: Colors.white),
              ),
              Text(
                nomeMes(mesSelecionado).toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => mudarMes(1),
                icon: const Icon(Icons.chevron_right, size: 32, color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // CARD COM ABAS VOCÊ/PARCEIRO/CASAL
          cardAbas(),
          cardCofrinhos(),

          const SizedBox(height: 20),

          // AÇÕES RÁPIDAS (ÍCONES REDONDOS)
          Center(
            child: Wrap(
              spacing: 22,
              runSpacing: 22,
              children: [
                iconeAcao(
                  icon: Icons.list,
                  label: "Extrato\nGanhos",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: Text("${getLabelAtual()} - Ganhos", style: const TextStyle(color: Colors.white)),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: listaExtrato(getIncomes()),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Fechar", style: TextStyle(color: Colors.blue)),
                          )
                        ],
                      ),
                    );
                  },
                ),
                iconeAcao(
                  icon: Icons.money_off,
                  label: "Extrato\nGastos",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: Text("${getLabelAtual()} - Gastos", style: const TextStyle(color: Colors.white)),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: listaExtrato(getExpenses()),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Fechar", style: TextStyle(color: Colors.blue)),
                          )
                        ],
                      ),
                    );
                  },
                ),
                iconeAcao(
                  icon: Icons.bar_chart,
                  label: "Totais\nGanhos",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: Text("${getLabelAtual()} - Ganhos por Categoria", style: const TextStyle(color: Colors.white)),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: totaisCategoria(getTotaisGanhos()),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Fechar", style: TextStyle(color: Colors.blue)),
                          )
                        ],
                      ),
                    );
                  },
                ),
                iconeAcao(
                  icon: Icons.stacked_line_chart,
                  label: "Totais\nGastos",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: Text("${getLabelAtual()} - Gastos por Categoria", style: const TextStyle(color: Colors.white)),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: totaisCategoria(getTotaisGastos()),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Fechar", style: TextStyle(color: Colors.blue)),
                          )
                        ],
                      ),
                    );
                  },
                ),
                iconeAcao(
                  icon: Icons.pie_chart,
                  label: "Pizza\nGanhos",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: Text("${getLabelAtual()} - Ganhos", style: const TextStyle(color: Colors.white)),
                        content: graficoPizza(getTotaisGanhos()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Fechar", style: TextStyle(color: Colors.blue)),
                          )
                        ],
                      ),
                    );
                  },
                ),
                iconeAcao(
                  icon: Icons.pie_chart_outline,
                  label: "Pizza\nGastos",
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: Text("${getLabelAtual()} - Gastos", style: const TextStyle(color: Colors.white)),
                        content: graficoPizza(getTotaisGastos()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Fechar", style: TextStyle(color: Colors.blue)),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // EXPANSOR: EXTRATOS
          tituloSecao("Extratos do Mês"),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("$labelVoce - Ganhos", style: const TextStyle(color: Colors.white)),
            children: [listaExtrato(incomesVoce)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("$labelParceiro - Ganhos", style: const TextStyle(color: Colors.white)),
            children: [listaExtrato(incomesEla)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: const Text("CASAL - Ganhos", style: TextStyle(color: Colors.white)),
            children: [listaExtrato(incomesCasal)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("$labelVoce - Gastos", style: const TextStyle(color: Colors.white)),
            children: [listaExtrato(expensesVoce)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("$labelParceiro - Gastos", style: const TextStyle(color: Colors.white)),
            children: [listaExtrato(expensesEla)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: const Text("CASAL - Gastos", style: TextStyle(color: Colors.white)),
            children: [listaExtrato(expensesCasal)],
          ),

          // EXPANSOR: TOTAIS POR CATEGORIA
          tituloSecao("Totais por Categoria"),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("$labelVoce - Ganhos por Categoria", style: const TextStyle(color: Colors.white)),
            children: [totaisCategoria(totaisGanhosVoce)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("$labelParceiro - Ganhos por Categoria", style: const TextStyle(color: Colors.white)),
            children: [totaisCategoria(totaisGanhosEla)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: const Text("CASAL - Ganhos por Categoria", style: TextStyle(color: Colors.white)),
            children: [totaisCategoria(totaisGanhosCasal)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("$labelVoce - Gastos por Categoria", style: const TextStyle(color: Colors.white)),
            children: [totaisCategoria(totaisGastosVoce)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("$labelParceiro - Gastos por Categoria", style: const TextStyle(color: Colors.white)),
            children: [totaisCategoria(totaisGastosEla)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: const Text("CASAL - Gastos por Categoria", style: TextStyle(color: Colors.white)),
            children: [totaisCategoria(totaisGastosCasal)],
          ),

          // EXPANSOR: GRÁFICOS
          tituloSecao("Gráficos de Pizza"),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("Pizza — $labelVoce Ganhos", style: const TextStyle(color: Colors.white)),
            children: [graficoPizza(totaisGanhosVoce)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("Pizza — $labelParceiro Ganhos", style: const TextStyle(color: Colors.white)),
            children: [graficoPizza(totaisGanhosEla)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: const Text("Pizza — CASAL Ganhos", style: TextStyle(color: Colors.white)),
            children: [graficoPizza(totaisGanhosCasal)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("Pizza — $labelVoce Gastos", style: const TextStyle(color: Colors.white)),
            children: [graficoPizza(totaisGastosVoce)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Text("Pizza — $labelParceiro Gastos", style: const TextStyle(color: Colors.white)),
            children: [graficoPizza(totaisGastosEla)],
          ),
          ExpansionTile(
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: const Text("Pizza — CASAL Gastos", style: TextStyle(color: Colors.white)),
            children: [graficoPizza(totaisGastosCasal)],
          ),
        ],
      ),
    ),
  );
}}

// FIM DO MÉTODO build - Certifique-se de que não há código depois desta chave
// Se houver outros métodos na classe, eles devem vir DEPOIS desta linha