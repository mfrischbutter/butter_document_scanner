import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_doc_scanner_method_channel.dart';
import 'models/scanner_result.dart';

abstract class FlutterDocScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterDocScannerPlatform.
  FlutterDocScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterDocScannerPlatform _instance = MethodChannelFlutterDocScanner();

  /// The default instance of [FlutterDocScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterDocScanner].
  static FlutterDocScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterDocScannerPlatform] when
  /// they register themselves.
  static set instance(FlutterDocScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<ScannerResult> getScanDocuments([int page = 4, String? locale]) {
    throw UnimplementedError('getScanDocuments() has not been implemented.');
  }

  Future<ScannerResult> getScannedDocumentAsImages(
      [int page = 4, String? locale]) {
    throw UnimplementedError(
        'getScannedDocumentAsImages() has not been implemented.');
  }

  Future<ScannerResult> getScannedDocumentAsPdf(
      [int page = 4, String? locale]) {
    throw UnimplementedError(
        'getScannedDocumentAsPdf() has not been implemented.');
  }

  Future<ScannerResult> getScanDocumentsUri([int page = 4, String? locale]) {
    throw UnimplementedError('getScanDocumentsUri() has not been implemented.');
  }

  Future<ScannerResult> pickDocuments(
      {String? locale,
      bool allowMultipleSelection = true,
      List<String>? allowedTypeIdentifiers}) {
    throw UnimplementedError('pickDocuments() has not been implemented.');
  }

  Future<ScannerResult> pickImagesAndConvertToPdf(
      {required int maxImages, String? locale}) {
    throw UnimplementedError(
        'pickImagesAndConvertToPdf() has not been implemented.');
  }
}
