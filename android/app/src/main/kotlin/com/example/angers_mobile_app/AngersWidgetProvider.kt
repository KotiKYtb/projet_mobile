package com.example.angers_mobile_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class AngersWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Entrée lorsque le premier widget est créé
    }

    override fun onDisabled(context: Context) {
        // Entrée lorsque le dernier widget est supprimé
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Fonction helper pour décoder les valeurs JSON (home_widget stocke en JSON)
            fun decodeString(value: String?): String {
                if (value == null || value.isEmpty()) return ""
                // Si la valeur commence et finit par des guillemets, c'est du JSON
                return if (value.startsWith("\"") && value.endsWith("\"")) {
                    try {
                        // Décoder le JSON
                        val jsonValue = org.json.JSONObject("{\"v\":$value}").getString("v")
                        jsonValue
                    } catch (e: Exception) {
                        // Si ça échoue, essayer de retirer les guillemets manuellement
                        value.removeSurrounding("\"")
                    }
                } else {
                    value
                }
            }
            
            // Récupérer les données depuis SharedPreferences (gérées par home_widget)
            // home_widget utilise TOUJOURS FlutterSharedPreferences sur Android
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // Lister toutes les clés pour debug
            android.util.Log.e("AngersWidget", "═══════════════════════════════════════")
            android.util.Log.e("AngersWidget", "MISE À JOUR DU WIDGET (KOTLIN)")
            android.util.Log.e("AngersWidget", "═══════════════════════════════════════")
            android.util.Log.e("AngersWidget", "SharedPreferences: FlutterSharedPreferences")
            
            // Lister TOUTES les clés et leurs valeurs pour debug
            val allPrefs = prefs.all
            android.util.Log.e("AngersWidget", "Nombre total de clés: ${allPrefs.size}")
            if (allPrefs.isEmpty()) {
                android.util.Log.e("AngersWidget", "AUCUNE CLÉ TROUVÉE dans FlutterSharedPreferences!")
                android.util.Log.e("AngersWidget", "Vérifiez que home_widget sauvegarde bien les données")
            } else {
                android.util.Log.e("AngersWidget", "Toutes les clés: ${allPrefs.keys}")
                // Afficher les premières clés qui contiennent "event" ou "flutter"
                allPrefs.forEach { (key, value) ->
                    if (key.contains("event") || key.contains("flutter")) {
                        android.util.Log.e("AngersWidget", "   $key = $value")
                    }
                }
            }
            
            // home_widget stocke avec le préfixe "flutter."
            var eventsCountStr = prefs.getString("flutter.events_count", null)
            
            // Si pas trouvé, essayer sans préfixe (au cas où)
            if (eventsCountStr == null) {
                eventsCountStr = prefs.getString("events_count", null)
            }
            
            android.util.Log.e("AngersWidget", "Recherche: flutter.events_count=${eventsCountStr != null}, events_count=${prefs.getString("events_count", null) != null}")
            
            val eventsCountStrFinal = decodeString(eventsCountStr)
            val eventsCount = try {
                eventsCountStrFinal.toInt()
            } catch (e: NumberFormatException) {
                0
            }

            android.util.Log.e("AngersWidget", "Events count:")
            android.util.Log.e("AngersWidget", "   Raw: $eventsCountStr")
            android.util.Log.e("AngersWidget", "   Decoded: $eventsCountStrFinal")
            android.util.Log.e("AngersWidget", "   Final: $eventsCount")

            // Construire le layout du widget
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            android.util.Log.e("AngersWidget", "Layout chargé: ${R.layout.widget_layout}")

            if (eventsCount > 0) {
                android.util.Log.e("AngersWidget", "Affichage de $eventsCount événements")
                // Afficher les événements
                views.setViewVisibility(R.id.widget_empty_message, android.view.View.GONE)

                // Afficher jusqu'à 3 événements
                for (i in 0 until minOf(eventsCount, 3)) {
                    // home_widget utilise TOUJOURS le préfixe "flutter."
                    var titleRaw = prefs.getString("flutter.event_${i}_title", null)
                    var dateRaw = prefs.getString("flutter.event_${i}_date", null)
                    var locationRaw = prefs.getString("flutter.event_${i}_location", null)
                    var idRaw = prefs.getString("flutter.event_${i}_id", null)
                    
                    // Si pas trouvé, essayer sans préfixe (au cas où)
                    if (titleRaw == null) {
                        titleRaw = prefs.getString("event_${i}_title", null)
                        dateRaw = prefs.getString("event_${i}_date", null)
                        locationRaw = prefs.getString("event_${i}_location", null)
                        idRaw = prefs.getString("event_${i}_id", null)
                    }
                    
                    // Décoder les valeurs JSON
                    val title = decodeString(titleRaw)
                    val date = decodeString(dateRaw)
                    val location = decodeString(locationRaw)
                    val eventId = decodeString(idRaw)
                    
                    android.util.Log.e("AngersWidget", "Événement $i:")
                    android.util.Log.e("AngersWidget", "   Raw - title: $titleRaw, date: $dateRaw, location: $locationRaw, id: $idRaw")
                    android.util.Log.e("AngersWidget", "   Decoded - title: $title, date: $date, location: $location, id: $eventId")

                    // Créer un Intent pour ouvrir l'app avec l'ID de l'événement
                    val intent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("event_id", eventId)
                        putExtra("open_event_details", true)
                    }
                    val pendingIntent = android.app.PendingIntent.getActivity(
                        context,
                        i, // Request code unique pour chaque événement
                        intent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )

                    when (i) {
                        0 -> {
                            android.util.Log.e("AngersWidget", "   Mise à jour event_0_container")
                            views.setViewVisibility(R.id.event_0_container, android.view.View.VISIBLE)
                            views.setTextViewText(R.id.event_0_title, if (title.isNotEmpty()) title else "Titre vide")
                            views.setTextViewText(R.id.event_0_date, if (date.isNotEmpty()) date else "Date vide")
                            views.setTextViewText(R.id.event_0_location, if (location.isNotEmpty()) location else "Lieu vide")
                            views.setOnClickPendingIntent(R.id.event_0_container, pendingIntent)
                            android.util.Log.e("AngersWidget", "   TextViews mis à jour pour event_0 avec clic")
                        }
                        1 -> {
                            android.util.Log.e("AngersWidget", "   Mise à jour event_1_container")
                            views.setViewVisibility(R.id.event_1_container, android.view.View.VISIBLE)
                            views.setTextViewText(R.id.event_1_title, if (title.isNotEmpty()) title else "Titre vide")
                            views.setTextViewText(R.id.event_1_date, if (date.isNotEmpty()) date else "Date vide")
                            views.setTextViewText(R.id.event_1_location, if (location.isNotEmpty()) location else "Lieu vide")
                            views.setOnClickPendingIntent(R.id.event_1_container, pendingIntent)
                            android.util.Log.e("AngersWidget", "   TextViews mis à jour pour event_1 avec clic")
                        }
                        2 -> {
                            android.util.Log.e("AngersWidget", "   Mise à jour event_2_container")
                            views.setViewVisibility(R.id.event_2_container, android.view.View.VISIBLE)
                            views.setTextViewText(R.id.event_2_title, if (title.isNotEmpty()) title else "Titre vide")
                            views.setTextViewText(R.id.event_2_date, if (date.isNotEmpty()) date else "Date vide")
                            views.setTextViewText(R.id.event_2_location, if (location.isNotEmpty()) location else "Lieu vide")
                            views.setOnClickPendingIntent(R.id.event_2_container, pendingIntent)
                            android.util.Log.e("AngersWidget", "   TextViews mis à jour pour event_2 avec clic")
                        }
                    }
                }

                // Masquer les événements non utilisés
                for (i in eventsCount until 3) {
                    when (i) {
                        0 -> views.setViewVisibility(R.id.event_0_container, android.view.View.GONE)
                        1 -> views.setViewVisibility(R.id.event_1_container, android.view.View.GONE)
                        2 -> views.setViewVisibility(R.id.event_2_container, android.view.View.GONE)
                    }
                }
            } else {
                // Aucun événement, afficher le message vide
                android.util.Log.e("AngersWidget", "Aucun événement, affichage du message vide")
                views.setViewVisibility(R.id.widget_empty_message, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.event_0_container, android.view.View.GONE)
                views.setViewVisibility(R.id.event_1_container, android.view.View.GONE)
                views.setViewVisibility(R.id.event_2_container, android.view.View.GONE)
            }

            // Mettre à jour le widget
            android.util.Log.e("AngersWidget", "Mise à jour du widget avec appWidgetId: $appWidgetId")
            appWidgetManager.updateAppWidget(appWidgetId, views)
            android.util.Log.e("AngersWidget", "Widget mis à jour avec succès")
        }
    }
}

