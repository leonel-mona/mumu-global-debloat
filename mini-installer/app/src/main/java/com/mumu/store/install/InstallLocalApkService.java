package com.mumu.store.install;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;
import java.io.*;

/**
 * Receiver que intercepta las descargas completadas del navegador
 * y las instala directamente (sin UI, sin anuncios).
 * Actúa como la "Tienda MuMu" limpia.
 */
public class InstallLocalApkService extends BroadcastReceiver {
    private static final String TAG = "MumuStore";

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        Log.i(TAG, "Broadcast recibido: " + action);

        if (!android.app.DownloadManager.ACTION_DOWNLOAD_COMPLETE.equals(action)) {
            return;
        }

        long downloadId = intent.getLongExtra(android.app.DownloadManager.EXTRA_DOWNLOAD_ID, -1);
        if (downloadId == -1) {
            Log.w(TAG, "Download ID invalido");
            return;
        }

        // Obtener la URI del archivo descargado
        android.app.DownloadManager dm = (android.app.DownloadManager) context.getSystemService(Context.DOWNLOAD_SERVICE);
        android.database.Cursor cursor = dm.query(new android.app.DownloadManager.Query().setFilterById(downloadId));

        if (cursor == null || !cursor.moveToFirst()) {
            Log.w(TAG, "No se encontro la descarga");
            return;
        }

        int columnIndex = cursor.getColumnIndex(android.app.DownloadManager.COLUMN_LOCAL_URI);
        int statusIndex = cursor.getColumnIndex(android.app.DownloadManager.COLUMN_STATUS);
        int titleIndex = cursor.getColumnIndex(android.app.DownloadManager.COLUMN_TITLE);

        String localUri = cursor.getString(columnIndex);
        int status = cursor.getInt(statusIndex);
        String title = cursor.getString(titleIndex);

        cursor.close();

        Log.i(TAG, "Descarga: " + title + ", status: " + status + ", URI: " + localUri);

        // Verificar que sea un APK
        boolean isApk = localUri != null && (localUri.endsWith(".apk") || (title != null && title.endsWith(".apk")));
        if (!isApk || status != android.app.DownloadManager.STATUS_SUCCESSFUL) {
            Log.i(TAG, "No es un APK o descarga fallida, ignorando");
            return;
        }

        // Instalar directamente via root
        installApk(context, Uri.parse(localUri));
    }

    private void installApk(Context context, Uri apkUri) {
        try {
            Log.i(TAG, "Instalando APK: " + apkUri.getLastPathSegment());

            // Copiar el archivo a /data/local/tmp para evitar problemas con content://
            File tempFile = new File("/data/local/tmp/mumu_install.apk");
            try (InputStream in = context.getContentResolver().openInputStream(apkUri);
                 OutputStream out = new FileOutputStream(tempFile)) {
                byte[] buffer = new byte[8192];
                int len;
                while ((len = in.read(buffer)) > 0) {
                    out.write(buffer, 0, len);
                }
            }

            // Ejecutar la instalación vía root
            Process p = Runtime.getRuntime().exec(
                new String[]{"su", "-c", "pm install -r /data/local/tmp/mumu_install.apk"});
            int exitCode = p.waitFor();
            Log.i(TAG, "Instalación completada. Exit code: " + exitCode);

            tempFile.delete();
        } catch (Exception e) {
            Log.e(TAG, "Error durante la instalación", e);
        }
    }
}