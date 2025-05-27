//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <butter_document_scanner/flutter_doc_scanner_plugin.h>
#include <open_file_linux/open_file_linux_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) butter_document_scanner_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterDocScannerPlugin");
  flutter_doc_scanner_plugin_register_with_registrar(butter_document_scanner_registrar);
  g_autoptr(FlPluginRegistrar) open_file_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "OpenFileLinuxPlugin");
  open_file_linux_plugin_register_with_registrar(open_file_linux_registrar);
}
