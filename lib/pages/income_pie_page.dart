import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomePiePage extends StatefulWidget {
  const IncomePiePage({super.key});

  @override
  State<IncomePiePage> createState() => _IncomePiePageState();
}

class _IncomePiePageState extends State<IncomePiePage> {
  bool loading = true;
  Map<String, double> totais = {};

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1).toIso8601String();

    final data = await Supabase.instance.client
    .from("incomes")
    .select("type, value")
    .gte("created_at", inicioMes);

Map<String, double> mapa = {};

for (var item in data) {
  final cat = item["type"];
  final val = (item["value"] as num).toDouble();

  mapa[cat] = (mapa[cat] ?? 0) + val;
}


    setState(() {
      totais = mapa;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.red,
      Colors.brown,
      Colors.pink,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Gráfico de Ganhos por Categoria")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : totais.isEmpty
              ? const Center(child: Text("Nenhum dado encontrado"))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sections: [
                              for (int i = 0; i < totais.length; i++)
                                PieChartSectionData(
                                  title:
                                      totais.values.elementAt(i).toStringAsFixed(2),
                                  value: totais.values.elementAt(i),
                                  color: colors[i % colors.length],
                                  radius: 80,
                                  titleStyle: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Categorias",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...totais.entries.map((e) => ListTile(
                            leading: Container(
                              width: 20,
                              height: 20,
                              color: colors[
                                  totais.keys.toList().indexOf(e.key) %
                                      colors.length],
                            ),
                            title: Text(e.key),
                            trailing:
                                Text("R\$ ${e.value.toStringAsFixed(2)}"),
                          )),
                    ],
                  ),
                ),
    );
  }
}
