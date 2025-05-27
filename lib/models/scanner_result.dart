/// Represents the result of a document scanning or picking operation.
class ScannerResult {
  /// A list of file paths, typically for images.
  /// Used by:
  /// - `getScannedDocumentAsImages` (scan result)
  final List<String>? imagePaths;

  /// The file path to a PDF document.
  /// Used by:
  /// - `getScannedDocumentAsPdf` (scan result)
  /// - `getScanDocumentsUri` (Android scan result, PDF URI)
  /// - `pickImagesAndConvertToPdf` (conversion result)
  final String? pdfPath;

  /// The result from Android's `getScanDocuments` which includes PDF URI and page count.
  /// Map keys: "pdfUri" (String), "pageCount" (int).
  final Map<String, dynamic>? androidScanResult;

  /// A list of file paths for documents selected via a picker.
  /// Used by:
  /// - `pickDocuments`
  final List<String>? pickedFilePaths;

  /// The number of pages in the scanned document (primarily from Android `getScanDocuments`).
  final int? pageCount;

  ScannerResult({
    this.imagePaths,
    this.pdfPath,
    this.androidScanResult,
    this.pickedFilePaths,
  }) : pageCount = (androidScanResult?['pageCount'] as int?);

  /// Returns true if any of the result fields contain data, suggesting a successful operation.
  /// This is a basic check; more specific checks might be needed depending on the method called.
  bool get isSuccess =>
      (imagePaths?.isNotEmpty ?? false) ||
      (pdfPath?.isNotEmpty ?? false) ||
      (androidScanResult?.isNotEmpty ?? false) ||
      (pickedFilePaths?.isNotEmpty ?? false);

  @override
  String toString() {
    return 'ScannerResult('
        'imagePaths: $imagePaths, '
        'pdfPath: $pdfPath, '
        'androidScanResult: $androidScanResult, '
        'pickedFilePaths: $pickedFilePaths, '
        'pageCount: $pageCount'
        ')';
  }
}
