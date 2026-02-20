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
  Uint8List? currentPdfBytes;  // ← Ahora se actualiza correctamente

  @override
  void initState() {
    super.initState();
    loadAsset();
  }

  Future<void> loadAsset() async {
    setState(() => isLoading = true);
    
    try {
      final ByteData data = await rootBundle.load('assets/sample.pdf');
      final Uint8List bytes = data.buffer.asUint8List();
      
      setState(() {
        isAsset = true;
        pdfData = bytes;
        filePath = null;
        currentPdfBytes = bytes;  // ← ¡GUARDAR BYTES!
        isLoading = false;
      });
    } catch (e) {
      print('Error asset: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> loadUrl() async {
    setState(() => isLoading = true);
    
    try {
      final url = 'https://pdfobject.com/pdf/sample.pdf';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/sample.pdf');
        await file.writeAsBytes(response.bodyBytes);
        
        setState(() {
          isAsset = false;
          pdfData = null;
          filePath = file.path;
          currentPdfBytes = response.bodyBytes;  // ← ¡GUARDAR BYTES!
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error URL: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> downloadToDownloads() async {
  if (currentPdfBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay PDF para descargar')),
      );
      return;
    }
  
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
        title: Text("PDF Viewer ${isAsset ? "(Asset)" : "(URL)"}"),
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
            onPressed: currentPdfBytes != null ? downloadToDownloads : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!isLoading && (pdfData != null || filePath != null))
            PDFView(
              key: ValueKey('pdf_${isAsset}_${filePath ?? 'asset'}'),  // ← KEY ÚNICA
              filePath: filePath,
              pdfData: pdfData,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: false,
              pageFling: true,
              pageSnap: true,
              onError: (error) {
                print('PDF Error: $error');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error PDF: $error')),
                );
              },
              onRender: (_) {
                print('PDF cargado correctamente');
              },
            ),
          if (isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando PDF...'),
                ],
              ),
            ),
          if (!isLoading && pdfData == null && filePath == null)
            Center(child: Text('Error al cargar PDF')),
        ],
      ),
    );
  }
}