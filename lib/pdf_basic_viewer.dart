import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class PdfViewer extends StatefulWidget {
  @override
  _PdfViewerState createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  bool isAsset = true;
  String? filePath;
  Uint8List? pdfData;
  bool isLoading = false;

  Uint8List? currentPdfBytes;  // ← Guardar datos actuales para descargar

  @override
  void initState() {
    super.initState();
    loadAsset(); // Carga asset por defecto
  }

  Future<void> loadAsset() async {
    setState(() => isLoading = true);
    
    // ← CARGAR ASSET COMO BYTES
    final ByteData data = await rootBundle.load('assets/sample.pdf');
    final Uint8List bytes = data.buffer.asUint8List();
    
    setState(() {
      isAsset = true;
      currentPdfBytes = bytes;
      pdfData = bytes;  // ← Usar pdfData para assets
      filePath = null;
      isLoading = false;
    });
  }

  Future<void> loadUrl() async {
    setState(() => isLoading = true);
    
    try {
      //final url = 'https://ontheline.trincoll.edu/images/bookdown/sample-local-pdf.pdf';
      final url = 'https://pdfobject.com/pdf/sample.pdf';
      final response = await http.get(Uri.parse(url));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/sample.pdf');
      await file.writeAsBytes(response.bodyBytes);
      
      setState(() {
        isAsset = false;
        isLoading = false;
        currentPdfBytes = response.bodyBytes;
        pdfData = null;
        filePath = file.path;
      });
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> downloadToDownloads() async {
  if (currentPdfBytes == null) return;
  
  // ← PERMISOS CORRECTOS por versión Android
  if (Platform.isAndroid) {
    PermissionStatus status;
    
    // Android 13+ (API 33+)
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      // Solo necesita permisos de notificación/media para Downloads
      status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
    } else {
      // Android 12 y anteriores
      status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
    }
    
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permiso denegado')),
      );
      return;
    }
  }
  
  // ← DESCARGA DIRECTA (sin DownloadsPathProvider problemático)
  final downloadsDir = Directory('/storage/emulated/0/Download');
  final file = File('${downloadsDir.path}/pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
  await file.writeAsBytes(currentPdfBytes!);
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('✅ Descargado: ${file.path}')),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PDF Viewer Básico"),
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz),
            onPressed: isLoading ? null : () {
              if (isAsset) loadUrl();
              else loadAsset();
            },
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: downloadToDownloads,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!isLoading)
            PDFView(
              filePath: filePath,
              pdfData: pdfData,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: false,
              pageFling: true,
              pageSnap: true,
            ),
          if (isLoading)
            Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}