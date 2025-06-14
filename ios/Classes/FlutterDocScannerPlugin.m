#import "FlutterDocScannerPlugin.h"
#if __has_include(<butter_document_scanner/butter_document_scanner-Swift.h>)
#import <butter_document_scanner/butter_document_scanner-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "butter_document_scanner-Swift.h"
#endif

@implementation FlutterDocScannerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterDocScannerPlugin registerWithRegistrar:registrar];
}
@end