# 🖥️ OptiDesk - System Monitor & Optimizer

Monitor de rendimiento y optimizador de sistemas para Windows desarrollado en Flutter. Visualiza en tiempo real el consumo de hardware, limpia archivos temporales y organiza tus directorios de manera inteligente.

## 🚀 Características principales
* **Monitoreo en Tiempo Real**: Visualización de CPU, RAM y GPU (NVIDIA) mediante comandos optimizados de PowerShell.
* **Limpieza de Sistema**: Analiza y elimina archivos temporales para recuperar espacio en disco.
* **Organizador Inteligente**: Agrupa archivos automáticamente por nombre o extensión en carpetas específicas.
* **Monitoreo de Red**: Visualización detallada de puertos y conexiones TCP activas.

## ⚠️ Requisito Importante
Para que la aplicación pueda leer correctamente los sensores de la **GPU (Nvidia)** y ciertos datos del sistema, **debe ejecutarse como Administrador**. De lo contrario, los indicadores podrían mostrar 0%.

## 🛠️ Tecnologías utilizadas
* **Flutter** (UI & Lógica de la aplicación).
* **PowerShell** (Consultas de hardware profundas).
* **Dart Isolate** (Búsquedas de archivos en segundo plano para no congelar la interfaz).

## 👥 Equipo de Desarrollo
Este proyecto fue desarrollado con orgullo por:

* **Beder Edison Achiri Sillo** - Lead Developer & AI Enthusiast :v
* **Carlos Eduardo Loaiza Martinez** - Core Developer
* **Saul Adain Huillca Rodriguez** - Core Developer

---
Proyecto desarrollado como parte de las iniciativas de innovación tecnológica <|:v
