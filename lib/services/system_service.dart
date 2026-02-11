import 'dart:io';
import 'dart:convert'; // Necesario para jsonDecode
import 'package:process_run/shell.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Importación para debugPrint

class SystemService {
  final shell = Shell();

  // ==========================================
  // 1. MONITOR DE HARDWARE UNIFICADO (JSON)
  // ==========================================
  
  /// Obtiene CPU, RAM y GPU en una sola llamada de PowerShell
  Future<Map<String, dynamic>> getFullHardwareData() async {
    try {
      // 1. Obtener CPU
      var cpuRes = await shell.run(r"powershell -Command (Get-CimInstance Win32_Processor).LoadPercentage");
      int cpu = int.tryParse(cpuRes.outText.trim()) ?? 0;

      // 2. Obtener RAM
      var ramRes = await shell.run(r"powershell -Command Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json");
      var ramData = jsonDecode(ramRes.outText);
      double totalMem = (ramData['TotalVisibleMemorySize'] ?? 1.0).toDouble();
      double freeMem = (ramData['FreePhysicalMemory'] ?? 1.0).toDouble();

      // 3. Obtener GPU (SINTAXIS DE ESCAPE MEJORADA)
      double gpu = 0;
      try {
        // Envolvemos todo el comando de PowerShell en comillas dobles y la ruta en comillas simples
        var gpuRes = await shell.run("powershell -Command \"(Get-Counter '\\GPU Engine(*)\\Utilization Percentage' -ErrorAction SilentlyContinue).CounterSamples | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum\"");
        
        String rawGpu = gpuRes.outText.trim();
        gpu = double.tryParse(rawGpu) ?? 0;
        
        if (gpu > 100) gpu = 100;
      } catch (e) { 
        debugPrint("Error específico GPU: $e");
        gpu = 0; 
      }

      return {
        'cpu': cpu,
        'totalMem': totalMem,
        'freeMem': freeMem,
        'gpu': gpu.round(),
      };
    } catch (e) {
      debugPrint("Error obteniendo hardware: $e");
      return {'cpu': 0, 'totalMem': 1, 'freeMem': 1, 'gpu': 0};
    }
  }

  /// Mantenemos este para el reporte de texto detallado si lo necesitas
  Future<String> getHardwareInfo() async {
    final now = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    String output = "🖥️ Monitor del Sistema Windows - $now\n" + "=" * 60 + "\n";
    try {
      final data = await getFullHardwareData();
      output += "\n⚡ CPU: ${data['cpu']}%\n";
      output += "💾 RAM: \${((data['totalMem'] - data['freeMem']) / 1024 / 1024).toStringAsFixed(2)} GB usados\n";
      output += "🎮 GPU: \${data['gpu']}%\n";
      
      var disks = await shell.run("wmic logicaldisk get caption,freespace,size");
      output += "\n💽 Almacenamiento:\n\${disks.outText.trim()}";
    } catch (e) {
      output += "Error: $e";
    }
    return output;
  }

  Future<List<Map<String, String>>> getTopProcesses() async {
    try {
      var result = await shell.run("powershell \"Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, WorkingSet\"");
      List<String> lines = result.outLines.where((l) => l.trim().isNotEmpty).toList();
      List<Map<String, String>> processes = [];
      for (var i = 2; i < lines.length; i++) {
        var parts = lines[i].trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          processes.add({
            'name': parts[0],
            'cpu': parts[1],
            'ram': (double.parse(parts[2]) / (1024 * 1024)).toStringAsFixed(1) + " MB"
          });
        }
      }
      return processes;
    } catch (e) { return []; }
  }

  // ==========================================
  // 2. GESTIÓN DE ARCHIVOS Y RED
  // ==========================================

  Future<List<Map<String, dynamic>>> searchFiles(String directoryPath, String query, {String? extensionFilter}) async {
    // Esta función ahora se apoya en backgroundSearch a través de compute en el main.dart
    return []; 
  }

  // === ORGANIZADOR INTELIGENTE ASÍNCRONO (STREAM) ===
  Future<void> smartOrganize(
    String sourcePath, 
    String targetFolderName, 
    {String? extensionFilter}
  ) async {
    final targetDir = Directory(p.join(sourcePath, targetFolderName));

    // Creamos la carpeta de destino si no existe
    if (!await targetDir.exists()) await targetDir.create();

    // Cambiamos listSync() por list() para obtener un Stream
    final Stream<FileSystemEntity> entityStream = Directory(sourcePath).list(recursive: false);

    await for (var entity in entityStream) {
      if (entity is File) {
        String fileName = p.basename(entity.path);
        String ext = p.extension(entity.path).toLowerCase();
        
        // Evitamos mover la carpeta de destino a sí misma
        if (fileName.toLowerCase() == targetFolderName.toLowerCase()) continue;

        bool matchesName = fileName.toLowerCase().contains(targetFolderName.toLowerCase());
        bool matchesExt = extensionFilter == null || ext == extensionFilter.toLowerCase();

        if (matchesName && matchesExt) {
          try {
            // Movimiento asíncrono: se procesa conforme se encuentra
            await entity.rename(p.join(targetDir.path, fileName));
            print("Movido: $fileName");
          } catch (e) {
            // Si el archivo está en uso, simplemente pasamos al siguiente
            print("No se pudo mover $fileName: $e");
          }
        }
      }
    }
  }

  Future<double> getCacheSize() async {
    double totalSize = 0;
    // Corregido: Eliminada la barra \ que causaba el error en ${Platform...}
    List<String> paths = [Platform.environment['TEMP'] ?? '', 'C:\\Windows\\Temp'];
    
    for (var path in paths) {
      if (path.isEmpty) continue;
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await for (var entity in dir.list(recursive: true)) {
            if (entity is File) totalSize += await entity.length();
          }
        } catch (_) {}
      }
    }
    return totalSize / (1024 * 1024);
  }

  Future<void> clearSystemCache() async {
    try {
      String userTemp = Platform.environment['TEMP'] ?? '';
      
      if (userTemp.isNotEmpty) {
        // Usamos comillas simples para el comando de Dart para evitar conflictos con el $ de Windows
        await shell.run('cmd /c "del /s /f /q $userTemp\\*.*"');
        await shell.run('cmd /c "for /d %i in ($userTemp\\*) do rd /s /q "%i""');
      }
      
      await shell.run('cmd /c "del /s /f /q C:\\Windows\\Temp\\*.*"');
      await shell.run('cmd /c "for /d %i in (C:\\Windows\\Temp\\*) do rd /s /q "%i""');
      
      print("Limpieza profunda de caché completada.");
    } catch (e) { 
      print("Error en limpieza: $e"); 
    }
  }

  Future<String> getNetworkPorts() async {
    try {
      var result = await shell.run(
        "powershell \"Get-NetTCPConnection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess | ForEach-Object { "
        "  \$processName = (Get-Process -Id \$_.OwningProcess -ErrorAction SilentlyContinue).Name; "
        "  if (\$null -eq \$processName) { \$processName = 'Sistema' }; "
        "  [PSCustomObject]@{ 'Proto'='TCP'; 'Dir_Local'=\$_.LocalAddress; 'Puerto'=\$_.LocalPort; 'Dir_Remota'=\$_.RemoteAddress; 'P_Remoto'=\$_.RemotePort; 'Estado'=\$_.State; 'Proceso'=\$processName; 'PID'=\$_.OwningProcess } "
        "} | Format-Table -AutoSize\""
      );
      return "🔍 MONITOREO DE RED DEFINITIVO\n" + "=" * 115 + "\n\n" + result.outText;
    } catch (e) { return "Error: \$e"; }
  }

  Future<void> openInExplorer(String path) async {
    try { await shell.run('explorer.exe "\$path"'); } 
    catch (e) { print("Error: $e"); }
  }
}

// ==========================================
// 3. PARÁMETROS Y BÚSQUEDA EN SEGUNDO PLANO
// ==========================================

class SearchParams {
  final String path;
  final String query;
  final String? extension;
  SearchParams(this.path, this.query, this.extension);
}

Future<List<Map<String, dynamic>>> backgroundSearch(SearchParams params) async {
  List<Map<String, dynamic>> results = [];
  final dir = Directory(params.path);
  try {
    final List<FileSystemEntity> entities = dir.listSync(recursive: true, followLinks: false);
    for (var entity in entities) {
      String fileName = entity.path.split(Platform.pathSeparator).last.toLowerCase();
      if (fileName.contains(params.query.toLowerCase())) {
        String ext = entity.path.contains('.') ? '.' + entity.path.split('.').last.toLowerCase() : '';
        if (params.extension == null || ext == params.extension!.toLowerCase()) {
          results.add({
            'name': entity.path.split(Platform.pathSeparator).last,
            'path': entity.path,
            'type': entity is Directory ? 'Carpeta' : 'Archivo',
            'extension': ext.isEmpty ? 'N/A' : ext,
          });
        }
      }
    }
  } catch (e) { print("Error Isolate: $e"); }
  return results;
}