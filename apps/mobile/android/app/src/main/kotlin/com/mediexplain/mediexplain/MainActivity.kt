package com.mediexplain.mediexplain

import android.app.Activity
import android.net.Uri
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import android.util.Base64
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

class MainActivity : FlutterFragmentActivity() {
    private var pendingScan: MethodChannel.Result? = null
    private val scannerLauncher = registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { response ->
        val callback = pendingScan ?: return@registerForActivityResult
        pendingScan = null
        if (response.resultCode != Activity.RESULT_OK) {
            callback.success(emptyList<String>())
        } else {
            val files = mutableListOf<File>()
            try {
                val scan = GmsDocumentScanningResult.fromActivityResultIntent(response.data)
                val directory = File(cacheDir, "prescription_work").apply { mkdirs() }
                for (page in scan?.pages.orEmpty()) {
                    val file = File(directory, "${UUID.randomUUID()}.jpg")
                    files.add(file)
                    val input = contentResolver.openInputStream(page.imageUri)
                        ?: error("Unreadable scan")
                    input.use { source -> file.outputStream().use { source.copyTo(it) } }
                }
                callback.success(files.map { it.absolutePath })
            } catch (_: Exception) {
                files.forEach { it.delete() }
                callback.error("scan_failed", "Could not read the scanned pages.", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mediexplain/local_server")
            .setMethodCallHandler { call, result ->
                if (call.method != "verifyIdentity") result.notImplemented()
                else try {
                    val publicKey = Base64.decode(call.argument<String>("public_key"), Base64.DEFAULT)
                    val signature = Base64.decode(call.argument<String>("signature"), Base64.DEFAULT)
                    val challenge = call.argument<String>("challenge") ?: ""
                    if (!Regex("[0-9a-f]{64}").matches(challenge)) result.success(false)
                    else {
                        val verifier = Signature.getInstance("SHA256withECDSA")
                        verifier.initVerify(KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(publicKey)))
                        verifier.update(("mediexplain-local-server-v1\n" + challenge).toByteArray(Charsets.UTF_8))
                        result.success(verifier.verify(signature))
                    }
                } catch (_: Exception) { result.success(false) }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mediexplain/document_capture")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanDocument" -> scan(result)
                    "recognizeText" -> {
                        val path = call.argument<String>("path")
                        if (path == null) result.error("invalid_image", "Image path is required.", null)
                        else recognize(path, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun scan(result: MethodChannel.Result) {
        if (pendingScan != null) {
            result.error("capture_busy", "A scanner is already open.", null)
            return
        }
        pendingScan = result
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true).setPageLimit(10)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL).build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(this)
            .addOnSuccessListener { intent ->
                try {
                    scannerLauncher.launch(IntentSenderRequest.Builder(intent).build())
                } catch (_: Exception) {
                    pendingScan = null
                    result.error("scan_unavailable", "Document scanner is unavailable.", null)
                }
            }
            .addOnFailureListener {
                pendingScan = null
                result.error("scan_unavailable", "Document scanner is unavailable.", null)
            }
    }

    private fun recognize(path: String, result: MethodChannel.Result) {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            val file = File(path).canonicalFile
            if (!file.path.startsWith(File(applicationInfo.dataDir).canonicalPath + "/")) error("Outside app sandbox")
            val image = InputImage.fromFilePath(this, Uri.fromFile(file))
            recognizer.process(image)
                .addOnSuccessListener { text ->
                    val lines = text.textBlocks.flatMap { block -> block.lines }.mapNotNull { line ->
                        val box = line.boundingBox ?: return@mapNotNull null
                        mapOf("text" to line.text, "confidence" to null,
                            "region" to mapOf("left" to box.left.toDouble(), "top" to box.top.toDouble(),
                                "right" to box.right.toDouble(), "bottom" to box.bottom.toDouble()))
                    }
                    result.success(mapOf("text" to text.text, "lines" to lines,
                        "provider" to "google_mlkit_android", "version" to "16.0.1"))
                }
                .addOnFailureListener { result.error("ocr_failed", "Text recognition failed.", null) }
                .addOnCompleteListener { recognizer.close() }
        } catch (_: Exception) {
            recognizer.close()
            result.error("invalid_image", "Could not read this image.", null)
        }
    }
}
