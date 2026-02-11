import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/system_service.dart';

class HardwareView extends StatelessWidget {
  final double cpuValue;
  final double gpuValue;
  final double ramValue; 
  final double cacheSize;
  final List<Map<String, String>> topProcesses;
  final SystemService service;
  final VoidCallback onRefreshCache;

  const HardwareView({
    super.key,
    required this.cpuValue,
    required this.gpuValue,
    required this.ramValue, 
    required this.cacheSize,
    required this.topProcesses,
    required this.service,
    required this.onRefreshCache,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Dashboard de Rendimiento", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          
          // FILA DE 3 GRÁFICOS: CPU, GPU y RAM
          Row(
            children: [
              Expanded(child: _StatCard(title: "CPU", content: _buildCircularChart(cpuValue, Colors.blue))),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(title: "GPU", content: _buildCircularChart(gpuValue, Colors.greenAccent))),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(title: "RAM", content: _buildCircularChart(ramValue, Colors.purpleAccent))), 
            ],
          ),
          
          const SizedBox(height: 16),

          // Tarjeta de Limpieza con actualización real
          _StatCard(
            title: "Limpieza de Sistema",
            content: _buildCacheSection(context),
          ),
          
          const SizedBox(height: 16),
          
          // Tabla de Procesos
          _StatCard(
            title: "Procesos con mayor consumo (CPU/RAM)",
            content: _buildProcessTable(),
          ),
        ],
      ),
    );
  }

  // === WIDGET DE GRÁFICO CIRCULAR AJUSTADO PARA EVITAR EL GRIS ===
  Widget _buildCircularChart(double value, Color color) {
    // Aseguramos que el valor nunca sea 0 absoluto para que no desaparezca el color
    double displayValue = value < 0.1 ? 0.1 : value;
    if (displayValue > 100) displayValue = 100;

    return SizedBox(
      height: 120,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 35,
          sections: [
            // Sección de Uso (Colorida)
            PieChartSectionData(
              value: displayValue,
              color: color,
              title: '${value.toInt()}%',
              radius: 14,
              titleStyle: const TextStyle(
                fontWeight: FontWeight.bold, 
                color: Colors.white, 
                fontSize: 11
              ),
            ),
            // Sección de Fondo (Gris oscuro)
            PieChartSectionData(
              value: (100 - displayValue) < 0 ? 0 : 100 - displayValue,
              color: Colors.grey[800],
              title: '',
              radius: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheSection(BuildContext context) {
    bool isEmpty = cacheSize <= 0.05;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cleaning_services, color: isEmpty ? Colors.green : Colors.orange, size: 30),
            const SizedBox(width: 12),
            Text(
              "${cacheSize.toStringAsFixed(2)} MB",
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold, 
                color: isEmpty ? Colors.green : Colors.orange
              ),
            ),
          ],
        ),
        Text(isEmpty ? "Sistema optimizado" : "Basura temporal detectada"),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: onRefreshCache,
              icon: const Icon(Icons.search),
              label: const Text("Analizar"),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Limpiando archivos temporales..."), duration: Duration(milliseconds: 800)),
                );
                await service.clearSystemCache();
                onRefreshCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("¡Limpieza completada!"), backgroundColor: Colors.green),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], foregroundColor: Colors.white),
              icon: const Icon(Icons.delete_sweep),
              label: const Text("Limpiar Ahora"),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildProcessTable() {
    return SizedBox(
      width: double.infinity,
      child: DataTable(
        columnSpacing: 12,
        horizontalMargin: 10,
        columns: const [
          DataColumn(label: Text("Aplicación")),
          DataColumn(label: Text("CPU %")),
          DataColumn(label: Text("RAM")),
        ],
        rows: topProcesses.map((p) => DataRow(cells: [
          DataCell(Text(p['name'] ?? 'Desconocido', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w500))),
          DataCell(Text("${p['cpu']}%", style: const TextStyle(fontSize: 12))),
          DataCell(Text(p['ram'] ?? '0 MB', style: const TextStyle(fontSize: 12))),
        ])).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Widget content;
  const _StatCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
            const Divider(height: 20),
            content,
          ],
        ),
      ),
    );
  }
}