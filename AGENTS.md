# Reglas Universales para el Proyecto Lingmo OS

## Prohibición Absoluta de Servicios Externos de Archivos (Gofile, etc.)
- Queda **estrictamente prohibido** usar, sugerir, mencionar, enlazar o subir archivos a **Gofile**, SourceForge, Hugging Face o cualquier plataforma externa similar.
- La distribución y entrega de las imágenes ISO se realiza **única y exclusivamente** mediante:
  1. Partes binarias (`.part-aa` y `.part-ab`) publicadas en el GitHub Release oficial del repositorio.
  2. Descarga directa en PowerShell con GitHub CLI (`gh release download`).
  3. Fusión binaria instantánea local con `copy /b` directamente a la carpeta de Descargas del usuario (`C:\Users\Hetzell\Downloads\lingmo-os-3.0.5-cutefish-amd64.iso`).
