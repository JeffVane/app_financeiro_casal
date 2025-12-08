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
  List incomesCasal = [];
  List expensesCasal = [];

  // Flag para indicar se há parceiro cadastrado
  bool temParceiro = false;

  @override
  void initState() {
    super.initState();
    mesSelecionado = DateTime(DateTime.now().year, DateTime.now().month);
    carregarDashboard();
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

  Future<double> somaValores(String tabela, String userId, String inicioMes) async {
    final resp = await Supabase.instance.client
        .from(tabela)
        .select('value')
        .eq('user_id', userId)
        .gte('date', inicioMes);

    double total = 0.0;
    for (var item in resp) {
      total += (item["value"] as num).toDouble();
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> extrato(
      String tabela, String userId, String inicioMes) async {
    return await Supabase.instance.client
        .from(tabela)
        .select("id, type, value, date")
        .eq("user_id", userId)
        .gte("date", inicioMes)
        .order("date", ascending: false);
  }

  Future<Map<String, double>> totaisPorCategoria(
      String tabela, String userId, String inicioMes) async {
    final resp = await Supabase.instance.client
        .from(tabela)
        .select("type, value")
        .eq("user_id", userId)
        .gte("date", inicioMes);

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

  Future<void> carregarDashboard() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print("❌ Nenhum usuário logado!");
      return;
    }

    final inicioMes = primeiroDiaMes(mesSelecionado).toIso8601String();

    try {
      print("🔍 Buscando perfil do usuário logado: ${user.id}");

      // 1. Buscando perfil logado (Adicionei 'name' no select)
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
      // Opcional: Se quiser mudar o "VOCÊ" pelo nome do usuário, descomente abaixo:
      // labelVoce = (perfilLogado["name"] as String?)?.toUpperCase() ?? "VOCÊ";

      print("✅ Perfil encontrado - ID: $seuId, Role: $role");

      // VOCÊ
      seusGanhos = await somaValores("incomes", seuId, inicioMes);
      seusGastos = await somaValores("expenses", seuId, inicioMes);
      seuDizimo = seusGanhos * 0.10;
      seuSaldo = seusGanhos - seusGastos - seuDizimo;

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

      // 2. Buscando perfil do parceiro (Adicionei 'name' nos selects também)
      if (roleParaBuscar != null) {
        outrosPerfis = await Supabase.instance.client
            .from("profiles")
            .select("id, role, name") // <--- AQUI
            .eq("role", roleParaBuscar);
      } else {
        outrosPerfis = await Supabase.instance.client
            .from("profiles")
            .select("id, role, name") // <--- E AQUI
            .neq("id", seuId);
      }

      // Verificar se existe parceiro cadastrado
      if (outrosPerfis.isNotEmpty) {
        temParceiro = true;
        final dadosParceiro = outrosPerfis[0];
        final String elaId = dadosParceiro["id"];
        
        // 3. Atualizando o Label com o nome do banco
        // Se vier nulo, usa o padrão "PARCEIRO(A)"
        final String nomeBanco = dadosParceiro["name"] ?? "PARCEIRO(A)";
        
        // Atualiza a variável que é usada na UI
        labelParceiro = nomeBanco.toUpperCase();

        // PARCEIRO(a) - Cálculos
        ganhosEla = await somaValores("incomes", elaId, inicioMes);
        gastosEla = await somaValores("expenses", elaId, inicioMes);
        dizimoEla = ganhosEla * 0.10;
        saldoEla = ganhosEla - gastosEla - dizimoEla;

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
        labelParceiro = "PARCEIRO(A)"; // Reseta para o padrão se não achar
        totalDoCasal = seuSaldo;

        // Limpa dados
        ganhosEla = 0; gastosEla = 0; dizimoEla = 0; saldoEla = 0;
        incomesEla = []; expensesEla = [];
        totaisGanhosEla = {}; totaisGastosEla = {};

        totaisGanhosCasal = Map.from(totaisGanhosVoce);
        totaisGastosCasal = Map.from(totaisGastosVoce);
        incomesCasal = List.from(incomesVoce);
        expensesCasal = List.from(expensesVoce);
      }

      setState(() => loading = false);
    } catch (e, stackTrace) {
      print("❌ ERRO NO DASHBOARD: $e");
      print("📍 Stack trace: $stackTrace");
      setState(() => loading = false);
    }
  }

  Widget iconeAcao({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color cor = Colors.deepPurple,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor.withOpacity(0.15),
            ),
            child: Icon(icon, size: 32, color: cor),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget graficoPizza(Map<String, double> totais) {
    if (totais.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("Sem dados para exibir", style: TextStyle(fontSize: 16)),
        ),
      );
    }

    final colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.brown,
    ];

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sections: [
            for (int i = 0; i < totais.length; i++)
              PieChartSectionData(
                title: totais.values.elementAt(i).toStringAsFixed(2),
                value: totais.values.elementAt(i),
                color: colors[i % colors.length],
                radius: 60,
                titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 0,
        ),
      ),
    );
  }

  Widget cardAbas() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.1), blurRadius: 8)
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
            dadosPessoa(labelVoce, seusGanhos, seusGastos, seuDizimo, seuSaldo)
          else if (abaSelecionada == 1)
            temParceiro 
              ? dadosPessoa(labelParceiro, ganhosEla, gastosEla, dizimoEla, saldoEla)
              : const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Parceiro não encontrado no sistema", 
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
          else
            temParceiro
              ? dadosCasal()
              : const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("Cadastre um parceiro para ver dados do casal", 
                    style: TextStyle(color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textoNegrito("Ganhos: R\$ ${g.toStringAsFixed(2)}", Colors.green),
        textoNegrito("Gastos: R\$ ${s.toStringAsFixed(2)}", Colors.red),
        textoNegrito("Dízimo (10%): R\$ ${d.toStringAsFixed(2)}", Colors.orange),
        textoNegrito("Saldo: R\$ ${saldo.toStringAsFixed(2)}", Colors.blue),
      ],
    );
  }

  Widget dadosCasal() {
    final ganhosTotal = seusGanhos + ganhosEla;
    final gastosTotal = seusGastos + gastosEla;
    final dizimoTotal = seuDizimo + dizimoEla;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        textoNegrito("Ganhos: R\$ ${ganhosTotal.toStringAsFixed(2)}", Colors.green),
        textoNegrito("Gastos: R\$ ${gastosTotal.toStringAsFixed(2)}", Colors.red),
        textoNegrito("Dízimo (10%): R\$ ${dizimoTotal.toStringAsFixed(2)}", Colors.orange),
        textoNegrito("Saldo: R\$ ${totalDoCasal.toStringAsFixed(2)}", Colors.blue),
      ],
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
        txt,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget listaExtrato(List lista) {
    if (lista.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Nenhum registro encontrado", textAlign: TextAlign.center),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final item = lista[i];
        return ListTile(
          title: Text(item["type"]),
          subtitle: Text(DateFormat("dd/MM").format(DateTime.parse(item["date"]))),
          trailing: Text(
            "R\$ ${(item["value"] as num).toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget totaisCategoria(Map<String, double> mapa) {
    if (mapa.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Nenhuma categoria encontrada", textAlign: TextAlign.center),
      );
    }

    return Column(
      children: mapa.entries.map((e) {
        return ListTile(
          title: Text(e.key),
          trailing: Text("R\$ ${e.value.toStringAsFixed(2)}"),
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard do Casal")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // SELETOR DE MÊS COM SETAS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: () => mudarMes(-1), icon: const Icon(Icons.chevron_left, size: 32)),
              Text(nomeMes(mesSelecionado).toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => mudarMes(1), icon: const Icon(Icons.chevron_right, size: 32)),
            ],
          ),

          const SizedBox(height: 20),

          // CARD COM ABAS VOCÊ/PARCEIRO/CASAL
          cardAbas(),

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
                        title: Text("${getLabelAtual()} - Ganhos"),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: listaExtrato(getIncomes()),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar"))],
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
                        title: Text("${getLabelAtual()} - Gastos"),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: listaExtrato(getExpenses()),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar"))],
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
                        title: Text("${getLabelAtual()} - Ganhos por Categoria"),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: totaisCategoria(getTotaisGanhos()),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar"))],
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
                        title: Text("${getLabelAtual()} - Gastos por Categoria"),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: totaisCategoria(getTotaisGastos()),
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar"))],
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
                        title: Text("${getLabelAtual()} - Ganhos"),
                        content: graficoPizza(getTotaisGanhos()),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar"))],
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
                        title: Text("${getLabelAtual()} - Gastos"),
                        content: graficoPizza(getTotaisGastos()),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar"))],
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
            title: Text("$labelVoce - Ganhos"),
            children: [listaExtrato(incomesVoce)],
          ),
          ExpansionTile(
            title: Text("$labelParceiro - Ganhos"),
            children: [listaExtrato(incomesEla)],
          ),
          ExpansionTile(
            title: const Text("CASAL - Ganhos"),
            children: [listaExtrato(incomesCasal)],
          ),
          ExpansionTile(
            title: Text("$labelVoce - Gastos"),
            children: [listaExtrato(expensesVoce)],
          ),
          ExpansionTile(
            title: Text("$labelParceiro - Gastos"),
            children: [listaExtrato(expensesEla)],
          ),
          ExpansionTile(
            title: const Text("CASAL - Gastos"),
            children: [listaExtrato(expensesCasal)],
          ),

          // EXPANSOR: TOTAIS POR CATEGORIA
          tituloSecao("Totais por Categoria"),
          ExpansionTile(
            title: Text("$labelVoce - Ganhos por Categoria"),
            children: [totaisCategoria(totaisGanhosVoce)],
          ),
          ExpansionTile(
            title: Text("$labelParceiro - Ganhos por Categoria"),
            children: [totaisCategoria(totaisGanhosEla)],
          ),
          ExpansionTile(
            title: const Text("CASAL - Ganhos por Categoria"),
            children: [totaisCategoria(totaisGanhosCasal)],
          ),
          ExpansionTile(
            title: Text("$labelVoce - Gastos por Categoria"),
            children: [totaisCategoria(totaisGastosVoce)],
          ),
          ExpansionTile(
            title: Text("$labelParceiro - Gastos por Categoria"),
            children: [totaisCategoria(totaisGastosEla)],
          ),
          ExpansionTile(
            title: const Text("CASAL - Gastos por Categoria"),
            children: [totaisCategoria(totaisGastosCasal)],
          ),

          // EXPANSOR: GRÁFICOS
          tituloSecao("Gráficos de Pizza"),
          ExpansionTile(
            title: Text("Pizza — $labelVoce Ganhos"),
            children: [graficoPizza(totaisGanhosVoce)],
          ),
          ExpansionTile(
            title: Text("Pizza — $labelParceiro Ganhos"),
            children: [graficoPizza(totaisGanhosEla)],
          ),
          ExpansionTile(
            title: const Text("Pizza — CASAL Ganhos"),
            children: [graficoPizza(totaisGanhosCasal)],
          ),
          ExpansionTile(
            title: Text("Pizza — $labelVoce Gastos"),
            children: [graficoPizza(totaisGastosVoce)],
          ),
          ExpansionTile(
            title: Text("Pizza — $labelParceiro Gastos"),
            children: [graficoPizza(totaisGastosEla)],
          ),
          ExpansionTile(
            title: const Text("Pizza — CASAL Gastos"),
            children: [graficoPizza(totaisGastosCasal)],
          ),
        ],
      ),
    );
  }
}