// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'package:butter_document_scanner/models/scanner_result.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'flutter_doc_scanner_platform_interface.dart';

/// A web implementation of the FlutterDocScannerPlatform of the FlutterDocScanner plugin.
class FlutterDocScannerWeb extends FlutterDocScannerPlatform {
  /// Constructs a FlutterDocScannerWeb
  FlutterDocScannerWeb();

  static void registerWith(Registrar registrar) {
    FlutterDocScannerPlatform.instance = FlutterDocScannerWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = html.window.navigator.userAgent;
    return version;
  }

  @override
  Future<ScannerResult> getScanDocuments([int page = 5, String? locale]) async {
    // locale is unused in web implementation
    final data = html.window.navigator.userAgent;
    return ScannerResult(imagePaths: [data]);
  }

  @override
  Future<ScannerResult> getScanDocumentsUri(
      [int page = 5, String? locale]) async {
    // locale is unused in web implementation
    final data = html.window.navigator.userAgent;
    return ScannerResult(imagePaths: [data]);
  }

  // TODO: Implement other methods from FlutterDocScannerPlatform for web if needed,
  // or throw UnimplementedError.
  // For example:
  // @override
  // Future<dynamic> getScannedDocumentAsImages([int page = 4, String? locale]) async {
  //   throw UnimplementedError('getScannedDocumentAsImages() has not been implemented for web.');
  // }
  //
  // @override
  // Future<dynamic> getScannedDocumentAsPdf([int page = 4, String? locale]) async {
  //   throw UnimplementedError('getScannedDocumentAsPdf() has not been implemented for web.');
  // }
  //
  // @override
  // Future<List<String>?> pickDocuments({String? locale, int? maxDocuments, List<String>? allowedTypeIdentifiers}) async {
  //   throw UnimplementedError('pickDocuments() has not been implemented for web.');
  // }
  //
  // @override
  // Future<String?> pickImagesAndConvertToPdf({required int maxImages, String? locale}) async {
  //   throw UnimplementedError('pickImagesAndConvertToPdf() has not been implemented for web.');
  // }
}
