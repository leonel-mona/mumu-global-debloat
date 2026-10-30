package com.mumu.store;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import java.io.DataOutputStream;
import java.io.IOException;

/**
 * Activity mínima que intercepta intents de instalación APK y los pasa al servicio.
 * Actúa como fallback cuando el receiver no puede interceptar.
 */
public class MainActivity extends Activity {
    private static final String TAG = "MumuStore";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent intent = getIntent();
        if (intent != null && intent.getData() != null) {
            Log.i(TAG, "MainActivity recibio intent: " + intent.getData());

            Uri apkUri = intent.getData();
            String apkPath = "";

            // Obtener la ruta real del archivo
            if (apkUri.getScheme() != null && apkUri.getScheme().equals("file")) {
                apkPath = apkUri.getPath();
            } else if (apkUri.getScheme() != null && apkUri.getScheme().equals("content")) {
                // Para content://, usar el path como fallback
                apkPath = apkUri.getLastPathSegment();
            }

            if (apkPath.isEmpty()) {
                Log.e(TAG, "No se pudo obtener la ruta del APK");
                finish();
                return;
            }

            // Ejecutar instalación via root usando ProcessBuilder
            try {
                Log.i(TAG, "Instalando APK via root: " + apkPath);

                // Usar su 0 (root user) en lugar de su -c
                // Esto evita problemas de parsing de comandos
                ProcessBuilder pb = new ProcessBuilder("su", "0", "pm", "install", "-r", apkPath);
                Process p = pb.start();

                // Leer la salida
                java.io.BufferedReader reader = new java.io.BufferedReader(
                    new java.io.InputStreamReader(p.getInputStream()));
                String line;
                while ((line = reader.readLine()) != null) {
                    Log.i(TAG, "STDOUT: " + line);
                }

                java.io.BufferedReader errorReader = new java.io.BufferedReader(
                    new java.io.InputStreamReader(p.getErrorStream()));
                while ((line = errorReader.readLine()) != null) {
                    Log.e(TAG, "STDERR: " + line);
                }

                int exitCode = p.waitFor();
                Log.i(TAG, "Instalación completada. Exit code: " + exitCode);
            } catch (Exception e) {
                Log.e(TAG, "Error durante la instalación", e);
            }
        }
        finish();
    }
}