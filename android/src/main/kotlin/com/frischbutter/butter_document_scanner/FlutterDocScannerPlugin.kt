package com.frischbutter.butter_document_scanner


import android.app.Activity
import android.app.Application
import android.app.Application.ActivityLifecycleCallbacks
import android.content.Intent
import android.content.IntentSender
import android.os.Bundle
import android.util.Log
import androidx.activity.result.IntentSenderRequest
import androidx.core.app.ActivityCompat.startIntentSenderForResult
import androidx.core.app.ActivityCompat.startActivityForResult
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

class FlutterDocScannerPlugin : MethodCallHandler, ActivityResultListener,
    FlutterPlugin, ActivityAware {
    private var channel: MethodChannel? = null
    private var pluginBinding: FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var applicationContext: Application? = null
    private var activity: Activity? = null
    private val TAG = FlutterDocScannerPlugin::class.java.simpleName

    private val REQUEST_CODE_SCAN = 213312
    private val REQUEST_CODE_SCAN_URI = 214412
    private val REQUEST_CODE_SCAN_IMAGES = 215512
    private val REQUEST_CODE_SCAN_PDF = 216612
    private val REQUEST_CODE_PICK_DOCUMENTS = 217712
    private lateinit var resultChannel: MethodChannel.Result


    override fun onMethodCall(call: MethodCall, result: Result) {
        resultChannel = result
        val locale = call.argument<String>("locale") ?: java.util.Locale.getDefault().toLanguageTag()
        Log.d(TAG, "Using locale: $locale for method: ${call.method}")

        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getScanDocuments" -> {
                val page = call.argument<Int>("page")?.coerceAtLeast(1) ?: 4
                startDocumentScan(page, REQUEST_CODE_SCAN)
            }
            "getScannedDocumentAsImages" -> {
                val page = call.argument<Int>("page")?.coerceAtLeast(1) ?: 4
                startDocumentScan(page, REQUEST_CODE_SCAN_IMAGES)
            }
            "getScannedDocumentAsPdf" -> {
                val page = call.argument<Int>("page")?.coerceAtLeast(1) ?: 4
                startDocumentScan(page, REQUEST_CODE_SCAN_PDF)
            }
            "getScanDocumentsUri" -> {
                val page = call.argument<Int>("page")?.coerceAtLeast(1) ?: 4
                startDocumentScan(page, REQUEST_CODE_SCAN_URI)
            }
            "pickDocuments" -> {
                val allowMultipleSelection = call.argument<Boolean>("allowMultipleSelection") ?: true
                val allowedTypeIdentifiers = call.argument<List<String>>("allowedTypeIdentifiers")
                Log.d(TAG, "allowMultipleSelection: $allowMultipleSelection, types: $allowedTypeIdentifiers for pickDocuments")
                startPickDocuments(allowedTypeIdentifiers, allowMultipleSelection)
            }
            "pickImagesAndConvertToPdf" -> {
                val maxImages = call.argument<Int>("maxImages") ?: 1
                Log.d(TAG, "maxImages: $maxImages for pickImagesAndConvertToPdf (Android - Not Implemented)")
                result.notImplemented()
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startDocumentScan(page: Int, requestCode: Int) {
        val builder =
            GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(true).setPageLimit(page)
                .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)

        when (requestCode) {
            REQUEST_CODE_SCAN -> builder.setResultFormats(
                GmsDocumentScannerOptions.RESULT_FORMAT_JPEG,
                GmsDocumentScannerOptions.RESULT_FORMAT_PDF
            )
            REQUEST_CODE_SCAN_IMAGES -> builder.setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            REQUEST_CODE_SCAN_PDF, REQUEST_CODE_SCAN_URI -> builder.setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_PDF)
        }
        val options = builder.build()
        
        val scanner = GmsDocumentScanning.getClient(options)
        activity?.let {
            scanner.getStartScanIntent(it)
                .addOnSuccessListener { intentSender ->
                    try {
                        startIntentSenderForResult(
                            activity!!,
                            intentSender,
                            requestCode,
                            null,
                            0,
                            0,
                            0,
                            null
                        )
                    } catch (e: IntentSender.SendIntentException) {
                        Log.e(TAG, "Failed to start document scan (request code: $requestCode)", e)
                        resultChannel.error("SCAN_FAILED", "Failed to start document scan activity.", e.localizedMessage)
                    }
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "Failed to get start scan intent (request code: $requestCode)", e)
                    resultChannel.error("SCAN_INIT_FAILED", "Failed to initialize document scanner.", e.localizedMessage)
                }
        } ?: resultChannel.error("ACTIVITY_UNAVAILABLE", "Activity is not available to start scan.", null)
    }

    private fun startPickDocuments(allowedMimeTypes: List<String>?, allowMultipleSelection: Boolean) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            
            val actualMimeTypes = if (allowedMimeTypes.isNullOrEmpty()) {
                arrayOf("image/*", "application/pdf")
            } else {
                allowedMimeTypes.toTypedArray()
            }
            type = if (actualMimeTypes.size == 1) actualMimeTypes[0] else "*/*"
            if (actualMimeTypes.size > 1) {
                putExtra(Intent.EXTRA_MIME_TYPES, actualMimeTypes)
            }
            
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultipleSelection) 
        }
        activity?.let {
            try {
                startActivityForResult(it, intent, REQUEST_CODE_PICK_DOCUMENTS, null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start document picker", e)
                resultChannel.error("PICKER_FAILED", "Failed to start document picker activity.", e.localizedMessage)
            }
        } ?: resultChannel.error("ACTIVITY_UNAVAILABLE", "Activity is not available to pick documents.", null)
    }


    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (resultCode == Activity.RESULT_OK) {
            val resultData = GmsDocumentScanningResult.fromActivityResultIntent(data)
            
            when (requestCode) {
                REQUEST_CODE_SCAN -> {
                    resultData?.getPdf()?.let {
                        val resultMap = mapOf("pdfUri" to it.uri.toString(), "pageCount" to it.pageCount)
                        resultChannel.success(resultMap)
                    } ?: resultChannel.success(null)
                }
                REQUEST_CODE_SCAN_IMAGES -> {
                    resultData?.pages?.let {
                        val imageUris = it.map { page -> page.imageUri.toString() }
                        resultChannel.success(mapOf("imagePaths" to imageUris))
                    } ?: resultChannel.success(null)
                }
                REQUEST_CODE_SCAN_PDF -> {
                    resultData?.getPdf()?.let {
                        resultChannel.success(mapOf("pdfPath" to it.uri.toString()))
                    } ?: resultChannel.success(null)
                }
                REQUEST_CODE_SCAN_URI -> {
                    resultData?.getPdf()?.let {
                        resultChannel.success(mapOf("pdfPath" to it.uri.toString()))
                    } ?: resultChannel.success(null)
                }
                REQUEST_CODE_PICK_DOCUMENTS -> {
                    val uris = mutableListOf<String>()
                    data?.clipData?.let { clipData ->
                        for (i in 0 until clipData.itemCount) {
                            uris.add(clipData.getItemAt(i).uri.toString())
                        }
                    } ?: data?.data?.let { uri ->
                        uris.add(uri.toString())
                    }
                    resultChannel.success(if (uris.isNotEmpty()) mapOf("pickedFilePaths" to uris) else null)
                }
                else -> return false
            }
            return true
        } else if (resultCode == Activity.RESULT_CANCELED) {
            resultChannel.success(null)
            return true
        }
        return false
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        pluginBinding = binding
        channel = MethodChannel(binding.binaryMessenger, "flutter_doc_scanner")
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        pluginBinding = null
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }
}