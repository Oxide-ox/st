package com.singo.tune

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MusicNotifReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val cmd = intent.getStringExtra("cmd") ?: return
        Handler(Looper.getMainLooper()).post {
            CustomMusicNotif.channel?.invokeMethod("onCommand", cmd)
        }
    }
}

object CustomMusicNotif {
    private const val CHANNEL_ID = "singo_custom_bg_player"
    private const val NOTIF_ID = 7742
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    var channel: MethodChannel? = null

    @Volatile
    private var updateSeq = 0
    private var lastArtUri: String? = null
    private var lastBitmap: Bitmap? = null

    fun show(context: Context, title: String, artist: String, artUri: String?, playing: Boolean) {
        val appCtx = context.applicationContext
        ensureChannel(appCtx)

        val seq = ++updateSeq
        if (artUri.isNullOrEmpty()) {
            lastArtUri = null
            lastBitmap = null
            postNotification(appCtx, title, artist, null, playing)
            return
        }

        if (artUri == lastArtUri && lastBitmap != null) {
            postNotification(appCtx, title, artist, lastBitmap, playing)
            return
        }

        executor.execute {
            val bmp = loadScaledBitmap(appCtx, artUri)
            if (seq != updateSeq) return@execute
            lastArtUri = artUri
            lastBitmap = bmp
            mainHandler.post {
                if (seq == updateSeq) {
                    postNotification(appCtx, title, artist, bmp, playing)
                }
            }
        }
    }

    fun hide(context: Context) {
        NotificationManagerCompat.from(context.applicationContext).cancel(NOTIF_ID)
    }

    private fun postNotification(
        context: Context,
        title: String,
        artist: String,
        bitmap: Bitmap?,
        playing: Boolean
    ) {
        val collapsed = buildRemoteViews(
            context,
            R.layout.notif_music_collapsed,
            title,
            artist,
            bitmap,
            playing
        )
        val expanded = buildRemoteViews(
            context,
            R.layout.notif_music_expanded,
            title,
            artist,
            bitmap,
            playing
        )

        val openIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val openPi = openIntent?.let {
            PendingIntent.getActivity(
                context,
                99,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_music)
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setOnlyAlertOnce(true)
            .setOngoing(playing)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (openPi != null) {
            builder.setContentIntent(openPi)
        }

        try {
            NotificationManagerCompat.from(context).notify(NOTIF_ID, builder.build())
        } catch (_: SecurityException) {
        }
    }

    private fun buildRemoteViews(
        context: Context,
        layoutId: Int,
        title: String,
        artist: String,
        bitmap: Bitmap?,
        playing: Boolean
    ): RemoteViews {
        val rv = RemoteViews(context.packageName, layoutId)
        rv.setTextViewText(R.id.txt_title, title)
        if (layoutId == R.layout.notif_music_expanded) {
            rv.setTextViewText(R.id.txt_artist, artist.ifEmpty { "Singo Tune" })
        }

        if (bitmap != null) {
            rv.setImageViewBitmap(R.id.img_bg, bitmap)
        } else {
            rv.setInt(R.id.img_bg, "setBackgroundColor", 0xFF1F1038.toInt())
        }

        rv.setImageViewResource(
            R.id.btn_play_pause,
            if (playing) R.drawable.ic_pause else R.drawable.ic_play
        )

        rv.setOnClickPendingIntent(R.id.btn_prev, cmdPendingIntent(context, 1, "prev"))
        rv.setOnClickPendingIntent(R.id.btn_play_pause, cmdPendingIntent(context, 2, "toggle"))
        rv.setOnClickPendingIntent(R.id.btn_next, cmdPendingIntent(context, 3, "next"))
        return rv
    }

    private fun cmdPendingIntent(context: Context, reqCode: Int, cmd: String): PendingIntent {
        val intent = Intent(context, MusicNotifReceiver::class.java).apply {
            putExtra("cmd", cmd)
        }
        return PendingIntent.getBroadcast(
            context,
            reqCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun loadScaledBitmap(context: Context, rawUri: String): Bitmap? {
        return try {
            val uri = Uri.parse(rawUri)
            val decoded = when (uri.scheme) {
                "http", "https" -> {
                    val conn = (URL(rawUri).openConnection() as HttpURLConnection).apply {
                        connectTimeout = 5000
                        readTimeout = 5000
                    }
                    conn.inputStream.use { BitmapFactory.decodeStream(it) }
                }
                "file" -> BitmapFactory.decodeFile(File(uri.path ?: return null).absolutePath)
                "content" -> context.contentResolver.openInputStream(uri)?.use {
                    BitmapFactory.decodeStream(it)
                }
                else -> BitmapFactory.decodeFile(rawUri)
            } ?: return null

            if (decoded.width <= 480) {
                decoded
            } else {
                val h = (decoded.height * (480f / decoded.width)).toInt().coerceAtLeast(1)
                Bitmap.createScaledBitmap(decoded, 480, h, true)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "Music Player",
                    NotificationManager.IMPORTANCE_LOW
                )
                mgr.createNotificationChannel(ch)
            }
        }
    }
}
