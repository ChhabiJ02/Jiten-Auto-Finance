package com.example.showroom_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "whatsapp_pdf_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "shareToWhatsApp") {

                val filePath = call.argument<String>("filePath")
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")

                if (filePath == null || phone == null || message == null) {
                    result.error("INVALID_ARGUMENTS", "Missing arguments", null)
                    return@setMethodCallHandler
                }

                try {

                    val file = File(filePath)

                    val uri = FileProvider.getUriForFile(
                        this,
                        "${applicationContext.packageName}.provider",
                        file
                    )

                    val intent = Intent(Intent.ACTION_SEND)

                    intent.type = "application/pdf"

                    intent.putExtra(Intent.EXTRA_STREAM, uri)

                    intent.putExtra(
                        Intent.EXTRA_TEXT,
                        message
                    )

                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

                    val phoneDigits = phone.replace("[^0-9]".toRegex(), "")
                    val whatsappNumber = if (phoneDigits.length == 10) {
                        "91$phoneDigits"
                    } else {
                        phoneDigits
                    }

                    if (whatsappNumber.isNotEmpty()) {
                        intent.putExtra("jid", "$whatsappNumber@s.whatsapp.net")
                    }

                    if (isAppInstalled("com.whatsapp")) {
                        intent.setPackage("com.whatsapp")
                    } else if (isAppInstalled("com.whatsapp.w4b")) {
                        intent.setPackage("com.whatsapp.w4b")
                    }

                    startActivity(intent)

                    result.success(true)

                } catch (e: Exception) {
                    result.error(
                        "WHATSAPP_ERROR",
                        e.message,
                        null
                    )
                }

            } else {
                result.notImplemented()
            }
        }
    }

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}