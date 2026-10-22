# Reglas Universales para el Proyecto Lingmo OS y Proyectos de Linux

## 1. Prohibición Absoluta de Servicios Externos de Archivos (Gofile, etc.)
- Queda **estrictamente prohibido** usar, sugerir, mencionar, enlazar o subir archivos a **Gofile**, SourceForge, Hugging Face o cualquier plataforma externa similar.
- La distribución y entrega de las imágenes ISO se realiza **única y exclusivamente** mediante:
  1. Partes binarias (`.part-aa` y `.part-ab`) publicadas en el GitHub Release oficial del repositorio.
  2. Descarga directa en PowerShell con GitHub CLI (`gh release download --clobber`) a máxima velocidad de la conexión del usuario (~40 MB/s).
  3. Verificación exacta de tamaño en bytes de cada una de las partes.
  4. Fusión binaria instantánea local con `copy /b` directamente a la carpeta de Descargas del usuario (`C:\Users\Hetzell\Downloads\<nombre>.iso`).
  5. Eliminación automática de las partes temporales, entregando únicamente el archivo `.iso` final listo.
  6. El usuario jamás debe realizar pasos manuales para descargar o unir partes.
