package com.mumu.miniinstaller

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import java.io.File

class InstallActivity : AppCompatActivity() {

    private val TAG = "MiniInstaller"
    private val REQUEST_INSTALL_PERMISSION = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_install)

        val intent = intent
        val uri = intent.data

        if (uri == null) {
            finish()
            return
        }

        Log.d(TAG, "Received intent: action=${intent.action}, data=$uri, type=${intent.type}")

        // Verificar permiso de instalación
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!packageManager.canRequestPackageInstalls()) {
                val settingsIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                    .setData(Uri.parse("package:$packageName"))
                startActivityForResult(settingsIntent, REQUEST_INSTALL_PERMISSION)
                return
            }
        }

        installApk(uri)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_INSTALL_PERMISSION) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (packageManager.canRequestPackageInstalls()) {
                    installApk(intent.data!!)
                } else {
                    Toast.makeText(this, "Permiso requerido para instalar APKs", Toast.LENGTH_LONG).show()
                    finish()
                }
            }
        }
    }

    private fun installApk(uri: Uri) {
        val file = when (uri.scheme) {
            "file" -> File(uri.path!!)
            "content" -> {
                // Para content:// URIs, usar FileProvider o copiar
                val tempFile = File(cacheDir, "install_${System.currentTimeMillis()}.apk")
                try {
                    contentResolver.openInputStream(uri)?.use { input ->
                        tempFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                    tempFile
                } catch (e: Exception) {
                    Log.e(TAG, "Error copiando APK", e)
                    Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_LONG).show()
                    finish()
                    return
                }
            }
            else -> {
                Toast.makeText(this, "Scheme no soportado: ${uri.scheme}", Toast.LENGTH_LONG).show()
                finish()
                return
            }
        }

        if (!file.exists()) {
            Toast.makeText(this, "Archivo no encontrado: ${file.path}", Toast.LENGTH_LONG).show()
            finish()
            return
        }

        Log.d(TAG, "Instalando: ${file.path} (${file.length()} bytes)")

        val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            val fileUri = FileProvider.getUriForFile(
                this@InstallActivity,
                "${packageName}.fileprovider",
                file
            )
            setDataAndType(fileUri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            putExtra(Intent.EXTRA_RETURN_RESULT, true)
        }

        try {
            startActivityForResult(installIntent, 2001)
        } catch (e: Exception) {
            Log.e(TAG, "Error iniciando instalador", e)
            Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 2001) {
            when (resultCode) {
                Activity.RESULT_OK -> Toast.makeText(this, "Instalado correctamente", Toast.LENGTH_SHORT).show()
                Activity.RESULT_CANCELED -> Toast.makeText(this, "Instalación cancelada", Toast.LENGTH_SHORT).show()
                else -> Toast.makeText(this, "Error: $resultCode", Toast.LENGTH_SHORT).show()
            }
            finish()
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}