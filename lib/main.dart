import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart'; 
import 'package:path/path.dart' as p; 
import 'services/system_service.dart';
import 'views/hardware_view.dart';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const OptiDeskApp());
}

class OptiDeskApp extends StatelessWidget {
  const OptiDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OptiDesk - System Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final SystemService _service = SystemService();
  
  // Variables de Hardware
  double _cpuValue = 0;
  double _gpuValue = 0; 
  double _ramValue = 0; 
  double _cacheSize = 0;
  List<Map<String, String>> _topProcesses = [];
  String _networkInfo = "Cargando...";
  Timer? _timer;

  // Variables de Archivos
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _organizeController = TextEditingController();
  String? _selectedExtension; 
  String? _orgExtension;      
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _selectedPath = "No se ha seleccionado ninguna carpeta";

  // --- NUEVO: MAPA DE CACHÉ ---
  final Map<String, List<Map<String, dynamic>>> _searchCache = {};

  @override
  void initState() {
    super.initState();
    _startLiveUpdates();
  }

  void _startLiveUpdates() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_selectedIndex == 0) {
        try {
          // 1. Obtenemos los datos (CPU, RAM, GPU) por comandos separados
          final Map<String, dynamic> data = await _service.getFullHardwareData();
          
          debugPrint("DATOS RECIBIDOS: $data");

          // 2. Obtenemos los procesos
          final processes = await _service.getTopProcesses();

          // 3. Cálculos de RAM usando totalMem y freeMem (minúsculas)
          double total = (data['totalMem'] ?? 1.0).toDouble();
          double free = (data['freeMem'] ?? 1.0).toDouble();
          
          // Fórmula: ((Total - Libre) / Total) * 100
          double ramPercent = total > 0 ? ((total - free) / total) * 100 : 0.0;

          if (mounted) {
            setState(() {
              // Ajustamos los círculos: forzamos rango 0-100
              _cpuValue = (data['cpu'] ?? 0.0).toDouble().clamp(0.0, 100.0);
              _gpuValue = (data['gpu'] ?? 0.0).toDouble().clamp(0.0, 100.0);
              _ramValue = ramPercent.clamp(0.0, 100.0);

              // LIMPIEZA DE TABLA: "Domamos" los números gigantes de Windows
              _topProcesses = processes.map((p) {
                double rawCpu = double.tryParse(p['cpu'] ?? '0') ?? 0.0;
                
                // Si el número es absurdo (como 334.0), lo limitamos a 100 
                // para que no rompa el diseño de la tabla.
                double cleanCpu = rawCpu > 100 ? 100.0 : rawCpu;
                
                return {
                  'name': p['name'] ?? 'Desconocido',
                  'cpu': cleanCpu.toStringAsFixed(1),
                  'ram': p['ram'] ?? '0 MB',
                };
              }).toList();
            });
          }
        } catch (e) {
          debugPrint("Error actualizando hardware: $e");
        }
      } else if (_selectedIndex == 2) {
        final data = await _service.getNetworkPorts();
        if (mounted) setState(() => _networkInfo = data);
      }
    });
  }

  Future<void> _selectFolder() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _selectedPath = result;
        // OPTIMIZACIÓN: Al cambiar de carpeta, limpiamos el caché viejo
        _searchCache.clear();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _organizeController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN DE BÚSQUEDA OPTIMIZADA CON CACHÉ e ISOLATE ---
  Future<void> _performSearch() async {
    if (_selectedPath == "No se ha seleccionado ninguna carpeta") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Debes elegir una carpeta primero")),
      );
      return;
    }

    final String query = _searchController.text.trim();
    final String ext = _selectedExtension ?? "todas";
    // Generamos una clave única para identificar esta búsqueda en el mapa
    final String cacheKey = "${_selectedPath}_${query}_$ext";

    // 1. Verificar si ya tenemos esto en memoria (Caché)
    if (_searchCache.containsKey(cacheKey)) {
      setState(() {
        _searchResults = _searchCache[cacheKey]!;
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚡ Resultados cargados desde el caché"),
          duration: Duration(milliseconds: 500),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults = []; 
    });

    // 2. Si no está en caché, ejecutar en Isolate para no congelar la UI
    final params = SearchParams(_selectedPath, query, _selectedExtension);
    final results = await compute(backgroundSearch, params);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
        // 3. Guardar el resultado en el caché para la próxima vez
        _searchCache[cacheKey] = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.monitor), label: Text('Hardware')),
              NavigationRailDestination(icon: Icon(Icons.manage_search), label: Text('Archivos')),
              NavigationRailDestination(icon: Icon(Icons.lan), label: Text('Red')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildCurrentView()),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 0: 
        return HardwareView(
          cpuValue: _cpuValue,
          gpuValue: _gpuValue, 
          ramValue: _ramValue, 
          cacheSize: _cacheSize,
          topProcesses: _topProcesses,
          service: _service,
          onRefreshCache: () async {
            final size = await _service.getCacheSize();
            setState(() => _cacheSize = size);
          },
        );
      case 1: return _buildAdvancedFileView();
      case 2: return _buildMonitorView("Puertos de Red", _networkInfo);
      default: return const Center(child: Text("Seleccione una opción"));
    }
  }

  Widget _buildCard(String title, Widget content) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            if (content is Expanded) content else Flexible(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFileView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildCard(
            "Configuración de Búsqueda y Ruta",
            Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_open, color: Colors.blue),
                  title: Text(_selectedPath, style: const TextStyle(fontSize: 13, overflow: TextOverflow.ellipsis)),
                  trailing: ElevatedButton.icon(
                    onPressed: _selectFolder,
                    icon: const Icon(Icons.folder_shared),
                    label: const Text("Elegir Carpeta"),
                  ),
                ),
                const Divider(),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Nombre del archivo o carpeta...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [".zip", ".rar", ".exe", ".pdf", ".xlsx", ".txt"].map((ext) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(ext),
                          selected: _selectedExtension == ext,
                          onSelected: (selected) => setState(() => _selectedExtension = selected ? ext : null),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isSearching ? null : _performSearch,
                  icon: const Icon(Icons.manage_search),
                  label: Text(_isSearching ? "Buscando..." : "Iniciar Búsqueda"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded( 
            child: _buildCard(
              "Resultados encontrados (${_searchResults.length})",
              _searchResults.isEmpty
                  ? const Center(child: Text("No hay resultados. Selecciona una carpeta e inicia la búsqueda."))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        return ListTile(
                          onTap: () => _service.openInExplorer(item['path']),
                          hoverColor: Colors.blue.withOpacity(0.1),
                          leading: Icon(
                            item['type'] == 'Carpeta' ? Icons.folder_rounded : Icons.insert_drive_file_rounded, 
                            color: item['type'] == 'Carpeta' ? Colors.amber[700] : Colors.blueAccent
                          ),
                          title: Text(item['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(item['path'], style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),

          _buildCard(
            "Organizador Inteligente (Case-Insensitive)",
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _organizeController,
                  decoration: const InputDecoration(
                    labelText: "Nombre de la carpeta para agrupar:",
                    hintText: "Ej: 'Inca' (detectará INCA, inca, etc.)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                
                const Text("Solo organizar archivos de tipo:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [".zip", ".rar", ".exe", ".pdf", ".jpg", ".txt"].map((ext) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(ext),
                          selected: _orgExtension == ext,
                          onSelected: (selected) {
                            setState(() => _orgExtension = selected ? ext : null);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 15),
                
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[800],
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.folder_shared),
                    label: const Text("Ir a Carpeta y Organizar"),
                    onPressed: () async {
                      if (_organizeController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("⚠️ Escribe primero el nombre del grupo (Ej: Inca)")),
                        );
                        return;
                      }

                      String? selectedDir = await FilePicker.platform.getDirectoryPath();

                      if (selectedDir != null) {
                        setState(() => _selectedPath = selectedDir);

                        await _service.smartOrganize(
                          selectedDir, 
                          _organizeController.text,
                          extensionFilter: _orgExtension,
                        );

                        String finalPath = p.join(selectedDir, _organizeController.text);
                        await _service.openInExplorer(finalPath);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("✅ Archivos agrupados en: $finalPath")),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorView(String title, String content) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lan, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Container(
              width: double.infinity, 
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal, 
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SelectableText(
                          content,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 12, 
                            color: Color(0xFF58A6FF),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}