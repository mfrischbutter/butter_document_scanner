import 'package:butter_document_scanner/flutter_doc_scanner.dart';
import 'package:butter_document_scanner/flutter_doc_scanner_method_channel.dart';
import 'package:butter_document_scanner/flutter_doc_scanner_platform_interface.dart';
import 'package:butter_document_scanner/models/scanner_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterDocScannerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterDocScannerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<ScannerResult> getScanDocuments([int page = 5, String? locale]) =>
      Future.value(ScannerResult(imagePaths: ['dummy/path/to/image1.jpg']));

  @override
  Future<ScannerResult> getScannedDocumentAsImages(
          [int page = 5, String? locale]) =>
      Future.value(ScannerResult(imagePaths: [
        'dummy/path/to/image1.jpg',
        'dummy/path/to/image2.jpg'
      ]));

  @override
  Future<ScannerResult> getScannedDocumentAsPdf(
          [int page = 5, String? locale]) =>
      Future.value(ScannerResult(pdfPath: 'dummy/path/to/document.pdf'));

  @override
  Future<ScannerResult> getScanDocumentsUri([int page = 5, String? locale]) =>
      Future.value(ScannerResult(pdfPath: 'content://dummy.uri/document.pdf'));

  @override
  Future<ScannerResult> pickDocuments(
          {String? locale,
          bool allowMultipleSelection = true,
          List<String>? allowedTypeIdentifiers}) =>
      Future.value(allowMultipleSelection
          ? ScannerResult(pickedFilePaths: [
              'dummy/path/to/picked1.pdf',
              'dummy/path/to/picked2.jpg'
            ])
          : ScannerResult(
              pickedFilePaths: ['dummy/path/to/picked_single.pdf']));

  @override
  Future<ScannerResult> pickImagesAndConvertToPdf(
          {required int maxImages, String? locale}) =>
      Future.value(
          ScannerResult(pdfPath: "dummy/path/to/converted_from_images.pdf"));
}

void main() {
  final FlutterDocScannerPlatform initialPlatform =
      FlutterDocScannerPlatform.instance;

  test('$MethodChannelFlutterDocScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterDocScanner>());
  });

  test('getPlatformVersion', () async {
    FlutterDocScanner flutterDocScannerPlugin = FlutterDocScanner();
    MockFlutterDocScannerPlatform fakePlatform =
        MockFlutterDocScannerPlatform();
    FlutterDocScannerPlatform.instance = fakePlatform;

    expect(await flutterDocScannerPlugin.getPlatformVersion(), '42');
  });

  test('getScannedDocumentAsPdf returns ScannerResult with pdfPath', () async {
    FlutterDocScanner flutterDocScannerPlugin = FlutterDocScanner();
    MockFlutterDocScannerPlatform fakePlatform =
        MockFlutterDocScannerPlatform();
    FlutterDocScannerPlatform.instance = fakePlatform;

    final result = await flutterDocScannerPlugin.getScannedDocumentAsPdf();
    expect(result, isA<ScannerResult>());
    expect(result.pdfPath, 'dummy/path/to/document.pdf');
    expect(result.imagePaths, isNull);
    expect(result.androidScanResult, isNull);
    expect(result.pickedFilePaths, isNull);
  });

  test('pickDocuments with allowMultipleSelection true', () async {
    FlutterDocScanner flutterDocScannerPlugin = FlutterDocScanner();
    MockFlutterDocScannerPlatform fakePlatform =
        MockFlutterDocScannerPlatform();
    FlutterDocScannerPlatform.instance = fakePlatform;

    final result = await flutterDocScannerPlugin.pickDocuments(
        allowMultipleSelection: true);
    expect(result, isA<ScannerResult>());
    expect(result.pickedFilePaths, hasLength(2));
    expect(
        result.pickedFilePaths,
        containsAll(
            ['dummy/path/to/picked1.pdf', 'dummy/path/to/picked2.jpg']));
  });

  test('pickDocuments with allowMultipleSelection false', () async {
    FlutterDocScanner flutterDocScannerPlugin = FlutterDocScanner();
    MockFlutterDocScannerPlatform fakePlatform =
        MockFlutterDocScannerPlatform();
    FlutterDocScannerPlatform.instance = fakePlatform;

    final result = await flutterDocScannerPlugin.pickDocuments(
        allowMultipleSelection: false);
    expect(result, isA<ScannerResult>());
    expect(result.pickedFilePaths, hasLength(1));
    expect(result.pickedFilePaths, contains('dummy/path/to/picked_single.pdf'));
  });
}
