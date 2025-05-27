import 'package:butter_document_scanner/flutter_doc_scanner.dart';
import 'package:butter_document_scanner/models/scanner_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Scanner Example',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16.0),
          titleMedium: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
      ),
      home: const ScanPage(),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  ScannerResult? _scannerResult;
  String _currentAction = "No action yet";

  Future<void> _handlePlatformException(
      PlatformException e, String action) async {
    if (!mounted) return;
    setState(() {
      _scannerResult = null;
      _currentAction = '$action failed: ${e.message}';
    });
  }

  Future<void> _handleGenericError(dynamic e, String action) async {
    if (!mounted) return;
    setState(() {
      _scannerResult = null;
      _currentAction = '$action failed: $e';
    });
  }

  Future<void> _updateResult(ScannerResult? newResult, String action) async {
    if (!mounted) return;
    print('$action Result: ${newResult?.toString()}');
    setState(() {
      _scannerResult = newResult;
      _currentAction = action;
      if (newResult == null || !newResult.isSuccess) {
        _currentAction +=
            " (No data returned or operation not fully successful)";
      }
    });
  }

  // --- Action Methods (all now call _updateResult with ScannerResult) ---
  Future<void> scanDocument() async {
    const String action = "Scan Documents (Default)";
    try {
      final result = await FlutterDocScanner().getScanDocuments(page: 4);
      await _updateResult(result, action);
    } on PlatformException catch (e) {
      await _handlePlatformException(e, action);
    } catch (e) {
      await _handleGenericError(e, action);
    }
  }

  Future<void> scanDocumentAsImages() async {
    const String action = "Scan as Images";
    try {
      final result =
          await FlutterDocScanner().getScannedDocumentAsImages(page: 4);
      await _updateResult(result, action);
    } on PlatformException catch (e) {
      await _handlePlatformException(e, action);
    } catch (e) {
      await _handleGenericError(e, action);
    }
  }

  Future<void> scanDocumentAsPdf() async {
    const String action = "Scan as PDF";
    try {
      final result = await FlutterDocScanner().getScannedDocumentAsPdf(page: 4);
      await _updateResult(result, action);
    } on PlatformException catch (e) {
      await _handlePlatformException(e, action);
    } catch (e) {
      await _handleGenericError(e, action);
    }
  }

  Future<void> scanDocumentUri() async {
    const String action = "Scan Document URI (Android)";
    try {
      final result = await FlutterDocScanner().getScanDocumentsUri(page: 4);
      await _updateResult(result, action);
    } on PlatformException catch (e) {
      await _handlePlatformException(e, action);
    } catch (e) {
      await _handleGenericError(e, action);
    }
  }

  Future<void> pickDocuments({required bool allowMultiple}) async {
    final String action =
        "Pick Documents (${allowMultiple ? 'Multiple' : 'Single'})";
    try {
      final result = await FlutterDocScanner().pickDocuments(
        allowMultipleSelection: allowMultiple,
        allowedTypeIdentifiers: [
          // Example UTIs for iOS:
          'com.adobe.pdf', // PDF
          'public.image', // All image types
          // 'public.text',     // Plain text
          // 'com.microsoft.word.doc', // Older Word doc
          // 'org.openxmlformats.wordprocessingml.document' // Newer Word docx
          // Example MIME types for Android (use if targeting Android specifically):
          // 'application/pdf',
          // 'image/*',
          // 'text/plain'
        ],
      );
      await _updateResult(result, action);
    } on PlatformException catch (e) {
      await _handlePlatformException(e, action);
    } catch (e) {
      await _handleGenericError(e, action);
    }
  }

  Future<void> pickImagesAndConvertToPdf() async {
    const String action = "Pick Images & Convert to PDF (iOS)";
    try {
      final result =
          await FlutterDocScanner().pickImagesAndConvertToPdf(maxImages: 3);
      await _updateResult(result, action);
    } on PlatformException catch (e) {
      await _handlePlatformException(e, action);
    } catch (e) {
      await _handleGenericError(e, action);
    }
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildPreviewButtonsWidget() {
    List<Widget> previewButtons = [];
    final currentResult = _scannerResult;

    Future<void> openFile(String filePath, String itemLabel) async {
      try {
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Could not open $itemLabel: ${result.message}')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        print('Error opening $itemLabel: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening $itemLabel: $e')),
        );
      }
    }

    if (currentResult != null) {
      if (currentResult.pdfPath != null && currentResult.pdfPath!.isNotEmpty) {
        previewButtons.add(
          _buildButton(
              "Preview PDF", () => openFile(currentResult.pdfPath!, "PDF")),
        );
      }
      if (currentResult.imagePaths != null &&
          currentResult.imagePaths!.isNotEmpty) {
        for (int i = 0; i < currentResult.imagePaths!.length; i++) {
          final path = currentResult.imagePaths![i];
          if (i < 3) {
            previewButtons.add(
              _buildButton("Preview Image ${i + 1}",
                  () => openFile(path, "Image ${i + 1}")),
            );
          } else {
            if (i == 3) {
              previewButtons.add(Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                    "${currentResult.imagePaths!.length - 3} more image(s)...",
                    textAlign: TextAlign.center),
              ));
            }
            break;
          }
        }
      }
      if (currentResult.pickedFilePaths != null &&
          currentResult.pickedFilePaths!.isNotEmpty) {
        for (int i = 0; i < currentResult.pickedFilePaths!.length; i++) {
          final path = currentResult.pickedFilePaths![i];
          if (i < 3) {
            previewButtons.add(
              _buildButton("Preview Picked File ${i + 1}",
                  () => openFile(path, "Picked File ${i + 1}")),
            );
          } else {
            if (i == 3) {
              previewButtons.add(Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                    "${currentResult.pickedFilePaths!.length - 3} more picked file(s)...",
                    textAlign: TextAlign.center),
              ));
            }
            break;
          }
        }
      }
      if (currentResult.androidScanResult != null &&
          currentResult.androidScanResult!['pdfUri'] is String) {
        final pdfUri = currentResult.androidScanResult!['pdfUri'] as String;
        if (pdfUri.isNotEmpty &&
            (previewButtons
                .where((btn) =>
                    btn is ElevatedButton &&
                    (btn.child as Text).data!.contains("PDF"))
                .isEmpty)) {
          previewButtons.add(
            _buildButton("Preview Scanned PDF (Android)",
                () => openFile(pdfUri, "Scanned PDF")),
          );
        }
      }
    }

    if (previewButtons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: previewButtons,
    );
  }

  @override
  Widget build(BuildContext context) {
    String resultText = "No results yet. Perform an action.";
    if (_scannerResult != null) {
      resultText = _scannerResult.toString();
    } else if (_currentAction.contains("failed")) {
      resultText = _currentAction;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doc Scanner Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Last Action: $_currentAction',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SingleChildScrollView(
                    child: SelectableText(resultText),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildPreviewButtonsWidget(),
            const SizedBox(height: 10),
            Expanded(
              flex: 2,
              child: ListView(
                children: <Widget>[
                  _buildButton("Scan Documents (Default)", scanDocument),
                  _buildButton("Scan as Images", scanDocumentAsImages),
                  _buildButton("Scan as PDF", scanDocumentAsPdf),
                  _buildButton("Scan Document URI (Android)", scanDocumentUri),
                  _buildButton("Pick Single Document",
                      () => pickDocuments(allowMultiple: false)),
                  _buildButton("Pick Multiple Documents",
                      () => pickDocuments(allowMultiple: true)),
                  _buildButton("Pick Images & Convert to PDF (iOS)",
                      pickImagesAndConvertToPdf),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
