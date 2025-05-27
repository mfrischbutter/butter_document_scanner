import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_doc_scanner_platform_interface.dart';
import 'models/scanner_result.dart';

/// An implementation of [FlutterDocScannerPlatform] that uses method channels.
class MethodChannelFlutterDocScanner extends FlutterDocScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_doc_scanner');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<ScannerResult> getScanDocuments([int page = 1, String? locale]) async {
    final dynamic data = await methodChannel.invokeMethod<dynamic>(
      'getScanDocuments',
      {'page': page, 'locale': locale},
    );
    if (data is Map) {
      return ScannerResult(androidScanResult: Map<String, dynamic>.from(data));
    } else if (data is List) {
      return ScannerResult(imagePaths: List<String>.from(data.cast<String>()));
    } else if (data == null) {
      // Handle null return explicitly
      return ScannerResult(); // Represents no data or cancellation
    }
    // If data is not null, Map, or List, it's an unexpected type.
    // Consider logging this or throwing an error based on how strict you want to be.
    print(
        "flutter_doc_scanner: Unexpected data type from getScanDocuments: ${data.runtimeType}");
    return ScannerResult(); // Fallback for unexpected data types
  }

  @override
  Future<ScannerResult> getScannedDocumentAsImages(
      [int page = 1, String? locale]) async {
    final dynamic data = await methodChannel.invokeMethod<dynamic>(
      'getScannedDocumentAsImages',
      {'page': page, 'locale': locale},
    );
    if (data is Map) {
      final List<dynamic>? imagePathsDynamic =
          data['imagePaths'] as List<dynamic>?;
      if (imagePathsDynamic != null) {
        return ScannerResult(
            imagePaths: imagePathsDynamic.cast<String>().toList());
      }
    } else if (data is List) {
      // Fallback for very old behavior or direct list return (less likely now)
      print(
          "flutter_doc_scanner: Warning - getScannedDocumentAsImages received a direct List. Expected a Map.");
      return ScannerResult(imagePaths: data.cast<String>().toList());
    }
    print(
        "flutter_doc_scanner: Unexpected data type or missing 'imagePaths' from getScannedDocumentAsImages: ${data?.runtimeType}");
    return ScannerResult();
  }

  @override
  Future<ScannerResult> getScannedDocumentAsPdf(
      [int page = 1, String? locale]) async {
    final dynamic data = await methodChannel.invokeMethod<dynamic>(
      'getScannedDocumentAsPdf',
      {'page': page, 'locale': locale},
    );
    if (data is Map) {
      // iOS returns a map like FlutterScannerResult.toDictionary(),
      // which might contain pdfPath directly.
      // Android returns a map like {"pdfUri": "...", "pageCount": ...}
      if (data.containsKey('pdfPath') && data['pdfPath'] is String) {
        return ScannerResult(pdfPath: data['pdfPath'] as String);
      } else {
        // Assume it's an Android-style result or an iOS result without a direct pdfPath
        // but other potentially useful info.
        return ScannerResult(
            androidScanResult: Map<String, dynamic>.from(data));
      }
    } else if (data is String) {
      // Fallback for older behavior or if a direct path string is somehow returned
      return ScannerResult(pdfPath: data);
    }
    print(
        "flutter_doc_scanner: Unexpected data type from getScannedDocumentAsPdf: ${data?.runtimeType}");
    return ScannerResult();
  }

  @override
  Future<ScannerResult> getScanDocumentsUri(
      [int page = 1, String? locale]) async {
    final dynamic data = await methodChannel.invokeMethod<dynamic>(
      'getScanDocumentsUri',
      {'page': page, 'locale': locale},
    );
    if (data is Map) {
      // Android returns a map {"pdfUri": "...", "pageCount": ...}
      // iOS does not have a direct equivalent for "getScanDocumentsUri",
      // but if it were to return something, it would likely be a map.
      return ScannerResult(androidScanResult: Map<String, dynamic>.from(data));
    } else if (data is String) {
      // Unlikely, but handle for robustness
      return ScannerResult(pdfPath: data);
    }
    print(
        "flutter_doc_scanner: Unexpected data type from getScanDocumentsUri: ${data?.runtimeType}");
    return ScannerResult();
  }

  @override
  Future<ScannerResult> pickDocuments(
      {String? locale,
      bool allowMultipleSelection = true, // Changed from maxDocuments
      List<String>? allowedTypeIdentifiers}) async {
    final dynamic resultData = await methodChannel.invokeMethod<dynamic>(
      // Changed to dynamic for inspection
      'pickDocuments',
      {
        'locale': locale,
        'allowMultipleSelection': allowMultipleSelection, // Pass new param
        'allowedTypeIdentifiers': allowedTypeIdentifiers,
      },
    );
    print(
        "flutter_doc_scanner (pickDocuments): Received data of type: ${resultData.runtimeType}, value: $resultData");

    if (resultData == null) return ScannerResult();

    if (resultData is Map) {
      // This is the expected path
      return ScannerResult(
        pickedFilePaths: (resultData['pickedFilePaths'] as List<dynamic>?)
            ?.cast<String>()
            .toList(),
      );
    } else if (resultData is List) {
      // This is the problematic path, if iOS is sending a direct list for picked documents
      print(
          "flutter_doc_scanner (pickDocuments): Warning - received a List directly, expected a Map. Processing as a list of paths.");
      return ScannerResult(pickedFilePaths: resultData.cast<String>().toList());
    }

    print(
        "flutter_doc_scanner (pickDocuments): Error - received unexpected data type: ${resultData.runtimeType}. Returning empty ScannerResult.");
    return ScannerResult();
  }

  @override
  Future<ScannerResult> pickImagesAndConvertToPdf(
      {required int maxImages, String? locale}) async {
    final dynamic resultData = await methodChannel.invokeMethod<dynamic>(
      // Changed to dynamic for inspection
      'pickImagesAndConvertToPdf',
      {'maxImages': maxImages, 'locale': locale},
    );
    print(
        "flutter_doc_scanner (pickImagesAndConvertToPdf): Received data of type: ${resultData.runtimeType}, value: $resultData");

    if (resultData == null) return ScannerResult();

    if (resultData is Map) {
      // This is the expected path
      return ScannerResult(pdfPath: resultData['pdfPath'] as String?);
    } else if (resultData is String) {
      // Fallback if iOS is sending a direct String for this method (older behavior)
      print(
          "flutter_doc_scanner (pickImagesAndConvertToPdf): Warning - received a String directly, expected a Map. Processing as pdfPath.");
      return ScannerResult(pdfPath: resultData);
    }

    print(
        "flutter_doc_scanner (pickImagesAndConvertToPdf): Error - received unexpected data type: ${resultData.runtimeType}. Returning empty ScannerResult.");
    return ScannerResult();
  }
}
