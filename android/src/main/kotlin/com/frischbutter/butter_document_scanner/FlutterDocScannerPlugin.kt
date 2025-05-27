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
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfDocument
import android.net.Uri
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import android.os.Build
import android.provider.MediaStore

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
    private val REQUEST_CODE_PICK_IMAGES_FOR_PDF = 218812
    private lateinit var resultChannel: MethodChannel.Result
    private var currentMaxImages: Int = 0 // To store maxImages for onActivityResult


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
                currentMaxImages = call.argument<Int>("maxImages") ?: 0 
                Log.d(TAG, "maxImages: $currentMaxImages for pickImagesAndConvertToPdf")
                startPickImagesForPdf(currentMaxImages)
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

    private fun startPickImagesForPdf(maxImages: Int) {
        val intent: Intent
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && maxImages > 0) {
            Log.d(TAG, "Using MediaStore.ACTION_PICK_IMAGES with maxImages: $maxImages")
            intent = Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                type = "image/*"
                if (maxImages > 0) {
                    putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, maxImages)
                }
            }
        } else {
            Log.d(TAG, "Using Intent.ACTION_GET_CONTENT. Max images ($maxImages) will be enforced post-selection if > 0.")
            intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        }

        activity?.let {
            try {
                startActivityForResult(it, intent, REQUEST_CODE_PICK_IMAGES_FOR_PDF, null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start image picker for PDF conversion", e)
                resultChannel.error("PICKER_FAILED", "Failed to start image picker activity.", e.localizedMessage)
            }
        } ?: resultChannel.error("ACTIVITY_UNAVAILABLE", "Activity is not available to pick images.", null)
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
                        val resultMap = mapOf("pdfUri" to it.uri.toString(), "pageCount" to it.pageCount)
                        resultChannel.success(resultMap)
                    } ?: resultChannel.success(null)
                }
                REQUEST_CODE_SCAN_URI -> {
                    resultData?.getPdf()?.let {
                        val resultMap = mapOf("pdfUri" to it.uri.toString(), "pageCount" to it.pageCount)
                        resultChannel.success(resultMap)
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
                REQUEST_CODE_PICK_IMAGES_FOR_PDF -> {
                    val imageUris = mutableListOf<Uri>()
                    data?.clipData?.let { clipData ->
                        for (i in 0 until clipData.itemCount) {
                            imageUris.add(clipData.getItemAt(i).uri)
                        }
                    } ?: data?.data?.let { uri ->
                        imageUris.add(uri)
                    }

                    if (imageUris.isEmpty()) {
                        resultChannel.success(null)
                        return true
                    }

                    val selectedImageUris = if (currentMaxImages > 0 && imageUris.size > currentMaxImages) {
                        imageUris.take(currentMaxImages)
                    } else {
                        imageUris
                    }

                    try {
                        val pdfPath = convertImageUrisToPdf(selectedImageUris)
                        if (pdfPath != null) {
                            resultChannel.success(mapOf("pdfPath" to pdfPath))
                        } else {
                            resultChannel.error("PDF_CONVERSION_FAILED", "Could not convert images to PDF.", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error converting images to PDF", e)
                        resultChannel.error("PDF_CONVERSION_ERROR", "Error during PDF conversion: ${e.localizedMessage}", null)
                    }
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
        applicationContext = binding.applicationContext as Application
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        pluginBinding = null
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
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

    private fun convertImageUrisToPdf(imageUris: List<Uri>): String? {
        if (applicationContext == null) {
            Log.e(TAG, "Application context is null, cannot convert to PDF")
            return null
        }
        val pdfDocument = PdfDocument()
        try {
            for (imageUri in imageUris) {
                applicationContext!!.contentResolver.openInputStream(imageUri)?.use { inputStream ->
                    val bitmap = BitmapFactory.decodeStream(inputStream)
                    if (bitmap != null) {
                        val pageInfo = PdfDocument.PageInfo.Builder(bitmap.width, bitmap.height, pdfDocument.pages.size + 1).create()
                        val page = pdfDocument.startPage(pageInfo)
                        val canvas = page.canvas
                        canvas.drawBitmap(bitmap, 0f, 0f, null)
                        pdfDocument.finishPage(page)
                        bitmap.recycle() // Recycle bitmap to free memory
                    } else {
                        Log.e(TAG, "Failed to decode bitmap from URI: $imageUri")
                    }
                }
            }

            if (pdfDocument.pages.isEmpty()) {
                 Log.w(TAG, "No images were successfully converted to PDF pages.")
                return null
            }

            val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val fileName = "images_to_pdf_$timeStamp.pdf"
            val cacheDir = applicationContext!!.cacheDir
            val pdfFile = File(cacheDir, fileName)

            FileOutputStream(pdfFile).use { outputStream ->
                pdfDocument.writeTo(outputStream)
            }
            return pdfFile.absolutePath
        } catch (e: IOException) {
            Log.e(TAG, "IOException during PDF conversion", e)
            return null
        } catch (e: Exception) {
            Log.e(TAG, "Generic exception during PDF conversion", e)
            return null
        } finally {
            pdfDocument.close()
        }
    }
}