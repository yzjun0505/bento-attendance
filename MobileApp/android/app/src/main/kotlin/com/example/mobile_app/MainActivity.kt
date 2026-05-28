package com.example.mobile_app

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannel = "jingmap_app/update_download"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enqueue" -> {
                        val url = call.argument<String>("url").orEmpty()
                        val fileName = call.argument<String>("fileName").orEmpty()
                        val title = call.argument<String>("title") ?: "正在下载更新"
                        if (url.isBlank() || fileName.isBlank()) {
                            result.error("INVALID_ARGUMENT", "url/fileName is required", null)
                            return@setMethodCallHandler
                        }
                        result.success(enqueueApkDownload(url, fileName, title))
                    }
                    "query" -> {
                        val downloadId = call.argument<Number>("downloadId")?.toLong()
                        if (downloadId == null) {
                            result.error("INVALID_ARGUMENT", "downloadId is required", null)
                            return@setMethodCallHandler
                        }
                        result.success(queryDownload(downloadId))
                    }
                    "cancel" -> {
                        val downloadId = call.argument<Number>("downloadId")?.toLong()
                        if (downloadId == null) {
                            result.error("INVALID_ARGUMENT", "downloadId is required", null)
                            return@setMethodCallHandler
                        }
                        getDownloadManager().remove(downloadId)
                        result.success(null)
                    }
                    "install" -> {
                        val downloadId = call.argument<Number>("downloadId")?.toLong()
                        if (downloadId == null) {
                            result.error("INVALID_ARGUMENT", "downloadId is required", null)
                            return@setMethodCallHandler
                        }
                        installDownloadedApk(downloadId, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun enqueueApkDownload(url: String, fileName: String, title: String): Long {
        val destination = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        File(destination, fileName).delete()

        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(title)
            .setDescription("境图新版安装包")
            .setMimeType("application/vnd.android.package-archive")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, fileName)

        return getDownloadManager().enqueue(request)
    }

    private fun queryDownload(downloadId: Long): Map<String, Any?> {
        val query = DownloadManager.Query().setFilterById(downloadId)
        getDownloadManager().query(query).use { cursor ->
            if (!cursor.moveToFirst()) {
                return mapOf(
                    "exists" to false,
                    "status" to "missing",
                    "downloadedBytes" to 0L,
                    "totalBytes" to -1L,
                    "reason" to 0,
                    "localUri" to null,
                )
            }

            val statusCode = cursor.getIntColumn(DownloadManager.COLUMN_STATUS)
            return mapOf(
                "exists" to true,
                "status" to statusName(statusCode),
                "downloadedBytes" to cursor.getLongColumn(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
                "totalBytes" to cursor.getLongColumn(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                "reason" to cursor.getIntColumn(DownloadManager.COLUMN_REASON),
                "localUri" to cursor.getStringColumn(DownloadManager.COLUMN_LOCAL_URI),
            )
        }
    }

    private fun installDownloadedApk(downloadId: Long, result: MethodChannel.Result) {
        val downloadManager = getDownloadManager()
        val uri = downloadManager.getUriForDownloadedFile(downloadId)
        if (uri == null) {
            result.error("APK_NOT_READY", "安装包尚未下载完成", null)
            return
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message ?: "无法打开安装器", null)
        }
    }

    private fun getDownloadManager(): DownloadManager {
        return getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    }

    private fun statusName(status: Int): String {
        return when (status) {
            DownloadManager.STATUS_PENDING -> "pending"
            DownloadManager.STATUS_RUNNING -> "running"
            DownloadManager.STATUS_PAUSED -> "paused"
            DownloadManager.STATUS_SUCCESSFUL -> "successful"
            DownloadManager.STATUS_FAILED -> "failed"
            else -> "unknown"
        }
    }

    private fun Cursor.getIntColumn(name: String): Int {
        val index = getColumnIndex(name)
        return if (index >= 0) getInt(index) else 0
    }

    private fun Cursor.getLongColumn(name: String): Long {
        val index = getColumnIndex(name)
        return if (index >= 0) getLong(index) else 0L
    }

    private fun Cursor.getStringColumn(name: String): String? {
        val index = getColumnIndex(name)
        return if (index >= 0) getString(index) else null
    }
}
