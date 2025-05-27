import Flutter
import UIKit
import Vision
import VisionKit
import PDFKit
import MobileCoreServices // Import MobileCoreServices for UTType
import UniformTypeIdentifiers // Import for UTType
import PhotosUI // For PHPickerViewController

@available(iOS 13.0, *)
public class SwiftFlutterDocScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate, UIDocumentPickerDelegate, PHPickerViewControllerDelegate {
   var resultChannel: FlutterResult?
   var presentingController: UIViewController? // Changed to UIViewController to handle both camera and picker
   var currentMethod: String?
   var maxImagesToPick: Int = 0

   public static func register(with registrar: FlutterPluginRegistrar) {
       let channel = FlutterMethodChannel(name: "flutter_doc_scanner", binaryMessenger: registrar.messenger())
       let instance = SwiftFlutterDocScannerPlugin()
       registrar.addMethodCallDelegate(instance, channel: channel)
   }

   public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       let arguments = call.arguments as? [String: Any]
       let localeString = arguments?["locale"] as? String

       let localeToUse: String
       if let explicitLocale = localeString {
           localeToUse = explicitLocale
       } else {
           localeToUse = Locale.current.identifier
       }
       print("Using locale: \(localeToUse) for method: \(call.method)") // Log the locale

       guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
           result(FlutterError(code: "NO_ROOT_VIEW_CONTROLLER", message: "Could not get root view controller", details: nil))
           return
       }
       self.presentingController = rootViewController
       self.resultChannel = result
       self.currentMethod = call.method

       if call.method == "getScanDocuments" || call.method == "getScannedDocumentAsImages" || call.method == "getScannedDocumentAsPdf" {
           let docCameraViewController = VNDocumentCameraViewController()
           docCameraViewController.delegate = self
           self.presentingController?.present(docCameraViewController, animated: true)
       } else if call.method == "pickDocuments" {
           let allowMultipleSelection = arguments?["allowMultipleSelection"] as? Bool ?? true
           let rawTypeIdentifiers = arguments?["allowedTypeIdentifiers"] as? [String]
           let resolvedTypeIdentifiers: [String]

           if let identifiers = rawTypeIdentifiers, !identifiers.isEmpty {
               resolvedTypeIdentifiers = identifiers
           } else {
               if #available(iOS 14.0, *) {
                   resolvedTypeIdentifiers = [UTType.item.identifier]
               } else {
                   resolvedTypeIdentifiers = [kUTTypeItem as String]
               }
           }

           let documentPicker = UIDocumentPickerViewController(documentTypes: resolvedTypeIdentifiers, in: .import)
           documentPicker.delegate = self
           documentPicker.allowsMultipleSelection = allowMultipleSelection
           self.presentingController?.present(documentPicker, animated: true, completion: nil)
       } else if call.method == "pickImagesAndConvertToPdf" {
           self.maxImagesToPick = arguments?["maxImages"] as? Int ?? 0
           if #available(iOS 14, *) {
               var config = PHPickerConfiguration()
               config.filter = .images
               config.selectionLimit = self.maxImagesToPick
               let picker = PHPickerViewController(configuration: config)
               picker.delegate = self
               self.presentingController?.present(picker, animated: true, completion: nil)
           } else {
               result(FlutterError(code: "UNSUPPORTED_OS_VERSION", message: "Multi-image picking from gallery requires iOS 14+. For iOS 13, consider a single image picker or the document scanner's import feature.", details: nil))
           }
       } else {
           result(FlutterMethodNotImplemented)
           return
       }
   }

   func getDocumentsDirectory() -> URL {
       let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
       let documentsDirectory = paths[0]
       return documentsDirectory
   }

   public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
       var imagePaths: [String]? = nil
       var pdfPath: String? = nil
       let androidScanResult: [String: Any]? = nil

       if currentMethod == "getScanDocuments" {
           if scan.pageCount > 0 {
               imagePaths = saveScannedImagesAndGetPaths(scan: scan)
           } else {
               imagePaths = []
           }
       } else if currentMethod == "getScannedDocumentAsImages" {
           if scan.pageCount > 0 {
               imagePaths = saveScannedImagesAndGetPaths(scan: scan)
           } else {
               imagePaths = []
           }
       } else if currentMethod == "getScannedDocumentAsPdf" {
           if scan.pageCount > 0 {
               pdfPath = saveScannedPdfAndGetPath(scan: scan)
           }
       }

       let scanResult = FlutterScannerResult(imagePaths: imagePaths, pdfPath: pdfPath, androidScanResult: androidScanResult, pickedFilePaths: nil)
       resultChannel?(scanResult.toDictionary())
       presentingController?.dismiss(animated: true)
   }

   private func saveScannedImagesAndGetPaths(scan: VNDocumentCameraScan) -> [String]? {
       let tempDirPath = getDocumentsDirectory()
       let currentDateTime = Date()
       let df = DateFormatter()
       df.dateFormat = "yyyyMMdd-HHmmss"
       let formattedDate = df.string(from: currentDateTime)
       var filenames: [String] = []
       if scan.pageCount == 0 {
           return nil
       }
       for i in 0 ..< scan.pageCount {
           let page = scan.imageOfPage(at: i)
           let url = tempDirPath.appendingPathComponent("\(formattedDate)-\(i).png")
           do {
               try page.pngData()?.write(to: url)
               filenames.append(url.path)
           } catch {
               print("Error saving image \(i): \(error.localizedDescription)")
           }
       }
       return filenames.isEmpty ? nil : filenames
   }

   private func saveScannedPdfAndGetPath(scan: VNDocumentCameraScan) -> String? {
       if scan.pageCount == 0 {
           return nil
       }
       let tempDirPath = getDocumentsDirectory()
       let currentDateTime = Date()
       let df = DateFormatter()
       df.dateFormat = "yyyyMMdd-HHmmss"
       let formattedDate = df.string(from: currentDateTime)
       let pdfFilePath = tempDirPath.appendingPathComponent("\(formattedDate).pdf")

       let pdfDocument = PDFDocument()
       for i in 0 ..< scan.pageCount {
           let pageImage = scan.imageOfPage(at: i)
           if let pdfPage = PDFPage(image: pageImage) {
               pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
           }
       }

       do {
           try pdfDocument.write(to: pdfFilePath)
           return pdfFilePath.path
       } catch {
           print("Error creating PDF: \(error.localizedDescription)")
           return nil
       }
   }

   public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
       resultChannel?(FlutterScannerResult(imagePaths: nil, pdfPath: nil, androidScanResult: nil, pickedFilePaths: nil).toDictionary())
       presentingController?.dismiss(animated: true)
   }

   public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
       resultChannel?(FlutterError(code: "SCAN_ERROR", message: "Failed to scan documents: \(error.localizedDescription)", details: error.localizedDescription))
       controller.dismiss(animated: true)
   }

   // MARK: - UIDocumentPickerDelegate
   @available(iOS 13.0, *)
   public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
       var accessibleUrls: [String] = []
       for url in urls {
           let shouldStopAccessing = url.startAccessingSecurityScopedResource()
           defer {
               if shouldStopAccessing {
                   url.stopAccessingSecurityScopedResource()
               }
           }
           accessibleUrls.append(url.path)
       }
       let result = FlutterScannerResult(imagePaths: nil, pdfPath: nil, androidScanResult: nil, pickedFilePaths: accessibleUrls.isEmpty ? nil : accessibleUrls)
       resultChannel?(result.toDictionary())
       controller.dismiss(animated: true)
   }

   @available(iOS 13.0, *)
   public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
       resultChannel?(FlutterScannerResult(imagePaths: nil, pdfPath: nil, androidScanResult: nil, pickedFilePaths: nil).toDictionary())
       controller.dismiss(animated: true)
   }

   // MARK: - PHPickerViewControllerDelegate
   @available(iOS 14, *)
   public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
       picker.dismiss(animated: true, completion: nil)

       if results.isEmpty {
           resultChannel?(FlutterScannerResult(imagePaths: nil, pdfPath: nil, androidScanResult: nil, pickedFilePaths: nil).toDictionary())
           return
       }

       var selectedImages: [UIImage] = []
       let group = DispatchGroup()

       for result in results {
           group.enter()
           if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
               result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                   if let image = image as? UIImage {
                       selectedImages.append(image)
                   } else if let error = error {
                       print("Error loading image: \(error.localizedDescription)")
                   }
                   group.leave()
               }
           } else {
               print("Cannot load UIImage from item provider")
               group.leave()
           }
       }

       group.notify(queue: .main) {
           if selectedImages.isEmpty {
               self.resultChannel?(FlutterError(code: "NO_IMAGES_SELECTED", message: "No images were successfully loaded.", details: nil))
               return
           }
           let pdfPath = self.convertImagesToPdfAndGetPath(images: selectedImages)
           let result = FlutterScannerResult(imagePaths: nil, pdfPath: pdfPath, androidScanResult: nil, pickedFilePaths: nil)
           self.resultChannel?(result.toDictionary())
       }
   }

   private func convertImagesToPdfAndGetPath(images: [UIImage]) -> String? {
       let pdfDocument = PDFDocument()
       for (index, image) in images.enumerated() {
           if let pdfPage = PDFPage(image: image) {
               pdfDocument.insert(pdfPage, at: index)
           }
       }

       let tempDirPath = getDocumentsDirectory()
       let currentDateTime = Date()
       let df = DateFormatter()
       df.dateFormat = "yyyyMMdd-HHmmss-gallery"
       let formattedDate = df.string(from: currentDateTime)
       let pdfFilePath = tempDirPath.appendingPathComponent("\(formattedDate).pdf")

       do {
           try pdfDocument.write(to: pdfFilePath)
           return pdfFilePath.path
       } catch {
           print("Error creating PDF from gallery images: \(error.localizedDescription)")
           return nil
       }
   }
}

struct FlutterScannerResult {
    let imagePaths: [String]?
    let pdfPath: String?
    let androidScanResult: [String: Any]?
    let pickedFilePaths: [String]?

    init(imagePaths: [String]? = nil, pdfPath: String? = nil, androidScanResult: [String: Any]? = nil, pickedFilePaths: [String]? = nil) {
        self.imagePaths = imagePaths
        self.pdfPath = pdfPath
        self.androidScanResult = androidScanResult
        self.pickedFilePaths = pickedFilePaths
    }

    func toDictionary() -> [String: Any?]? {
        if imagePaths == nil && pdfPath == nil && androidScanResult == nil && pickedFilePaths == nil {
            return nil
        }
        return [
            "imagePaths": imagePaths,
            "pdfPath": pdfPath,
            "androidScanResult": androidScanResult,
            "pickedFilePaths": pickedFilePaths
        ]
    }
}
