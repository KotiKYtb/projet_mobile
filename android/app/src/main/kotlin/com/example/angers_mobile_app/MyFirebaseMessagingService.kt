package com.example.angers_mobile_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        Log.d(TAG, "Refreshed token: $token")
        // Envoyer le token à votre serveur si nécessaire
        sendRegistrationToServer(token)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "From: ${remoteMessage.from}")

        // Si le message contient une notification, Android l'affiche automatiquement
        // On ne doit PAS afficher de notification manuellement ici pour éviter les doublons
        // On laisse Flutter gérer l'affichage via FirebaseMessagingService
        
        // Vérifier si le message contient des données
        if (remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "Message data payload: ${remoteMessage.data}")
            // Ne pas afficher de notification ici, laisser Flutter gérer
            // handleDataMessage(remoteMessage.data)
        }

        // NE PAS afficher de notification ici car Android le fait automatiquement
        // et Flutter gère aussi les notifications en foreground
        // Cela évite les doublons
        remoteMessage.notification?.let {
            Log.d(TAG, "Message Notification Body: ${it.body} - Android l'affichera automatiquement")
            // sendNotification(it.title ?: "Nocta", it.body ?: "") // DÉSACTIVÉ pour éviter les doublons
        }
    }

    private fun handleDataMessage(data: Map<String, String>) {
        // Traiter les données personnalisées du message
        // Par exemple, extraire un event_id pour naviguer vers les détails
        val eventId = data["event_id"]
        val title = data["title"] ?: "Nocta"
        val body = data["body"] ?: "Nouvelle notification"
        
        if (eventId != null) {
            sendNotificationWithIntent(title, body, eventId)
        } else {
            sendNotification(title, body)
        }
    }

    private fun sendNotification(title: String, messageBody: String) {
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val channelId = "nocta_channel"
        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        
        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(messageBody)
            .setAutoCancel(true)
            .setSound(defaultSoundUri)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Créer le canal de notification pour Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Nocta Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications de Nocta"
            }
            notificationManager.createNotificationChannel(channel)
        }

        notificationManager.notify(0, notificationBuilder.build())
    }

    private fun sendNotificationWithIntent(title: String, messageBody: String, eventId: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("event_id", eventId)
            putExtra("open_event_details", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val channelId = "nocta_channel"
        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        
        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(messageBody)
            .setAutoCancel(true)
            .setSound(defaultSoundUri)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Créer le canal de notification pour Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Nocta Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications de Nocta"
            }
            notificationManager.createNotificationChannel(channel)
        }

        notificationManager.notify(0, notificationBuilder.build())
    }

    private fun sendRegistrationToServer(token: String) {
        // TODO: Envoyer le token à votre serveur backend
        Log.d(TAG, "Token à envoyer au serveur: $token")
    }

    companion object {
        private const val TAG = "MyFirebaseMsgService"
    }
}

