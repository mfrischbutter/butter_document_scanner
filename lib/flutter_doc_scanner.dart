import 'package:flutter/foundation.dart';

import 'flutter_doc_scanner_platform_interface.dart';
import 'models/scanner_result.dart';

class FlutterDocScanner {
  Future<String?> getPlatformVersion() {
    return FlutterDocScannerPlatform.instance.getPlatformVersion();
  }

  Future<ScannerResult> getScanDocuments({int page = 4, String? locale}) {
    return FlutterDocScannerPlatform.instance.getScanDocuments(page, locale);
  }

  Future<ScannerResult> getScannedDocumentAsImages(
      {int page = 4, String? locale}) {
    return FlutterDocScannerPlatform.instance
        .getScannedDocumentAsImages(page, locale);
  }

  Future<ScannerResult> getScannedDocumentAsPdf(
      {int page = 4, String? locale}) {
    return FlutterDocScannerPlatform.instance
        .getScannedDocumentAsPdf(page, locale);
  }

  Future<ScannerResult> getScanDocumentsUri({int page = 4, String? locale}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return FlutterDocScannerPlatform.instance
          .getScanDocumentsUri(page, locale);
    } else {
      return Future.value(ScannerResult(pdfPath: null));
    }
  }

  Future<ScannerResult> pickDocuments(
      {String? locale,
      bool allowMultipleSelection = true,
      List<String>? allowedTypeIdentifiers}) {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      return FlutterDocScannerPlatform.instance.pickDocuments(
        locale: locale,
        allowMultipleSelection: allowMultipleSelection,
        allowedTypeIdentifiers: allowedTypeIdentifiers,
      );
    } else {
      return Future.value(ScannerResult(pickedFilePaths: null));
    }
  }

  Future<ScannerResult> pickImagesAndConvertToPdf(
      {required int maxImages, String? locale}) {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      return FlutterDocScannerPlatform.instance
          .pickImagesAndConvertToPdf(maxImages: maxImages, locale: locale);
    } else {
      return Future.value(ScannerResult(pdfPath: null));
    }
  }
}
