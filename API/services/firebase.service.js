// Service Firebase Admin pour envoyer des notifications push
// Nécessite le package firebase-admin et un fichier de clé de service account

let admin = null;
let initialized = false;

/**
 * Initialise Firebase Admin SDK
 * Nécessite un fichier de clé de service account Firebase
 * Téléchargez-le depuis: Firebase Console > Project Settings > Service Accounts
 */
function initializeFirebase() {
  if (initialized) {
    return admin;
  }

  try {
    // Essayer de charger firebase-admin
    admin = require('firebase-admin');
    
    // Vérifier si une clé de service account est configurée
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    const serviceAccountKey = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
    
    console.log('Firebase config - FIREBASE_SERVICE_ACCOUNT_PATH:', serviceAccountPath);
    console.log('Firebase config - FIREBASE_SERVICE_ACCOUNT_KEY:', serviceAccountKey ? 'Défini' : 'Non défini');
    
    if (!admin.apps.length) {
      if (serviceAccountPath) {
        // Charger depuis un fichier JSON
        // Résoudre le chemin relatif depuis le dossier API
        const path = require('path');
        const fs = require('fs');
        const resolvedPath = path.isAbsolute(serviceAccountPath) 
          ? serviceAccountPath 
          : path.resolve(__dirname, '..', serviceAccountPath);
        
        console.log('Tentative de chargement depuis:', resolvedPath);
        
        if (!fs.existsSync(resolvedPath)) {
          console.error('Fichier Firebase non trouvé:', resolvedPath);
          console.error('   Vérifiez que le chemin dans .env est correct');
          return null;
        }
        
        const serviceAccount = require(resolvedPath);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount)
        });
        console.log('Firebase Admin initialisé depuis fichier:', resolvedPath);
      } else if (serviceAccountKey) {
        // Charger depuis une variable d'environnement (JSON string)
        const serviceAccount = JSON.parse(serviceAccountKey);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount)
        });
        console.log('Firebase Admin initialisé depuis variable d\'environnement');
      } else {
        console.warn('Firebase Admin non configuré. Les notifications push ne fonctionneront pas.');
        console.warn('   Configurez FIREBASE_SERVICE_ACCOUNT_PATH ou FIREBASE_SERVICE_ACCOUNT_KEY');
        return null;
      }
    }
    
    initialized = true;
    return admin;
  } catch (error) {
    console.error('Erreur lors de l\'initialisation de Firebase Admin:', error.message);
    console.error('   Assurez-vous d\'avoir installé: npm install firebase-admin');
    return null;
  }
}

/**
 * Envoie une notification push à un token FCM spécifique
 * @param {string} fcmToken - Le token FCM du dispositif
 * @param {string} title - Titre de la notification
 * @param {string} body - Corps de la notification
 * @param {object} data - Données supplémentaires (optionnel)
 * @returns {Promise<object>} Résultat de l'envoi
 */
async function sendNotificationToToken(fcmToken, title, body, data = {}) {
  const firebaseAdmin = initializeFirebase();
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin non initialisé');
  }

  const message = {
    notification: {
      title: title,
      body: body
    },
    data: {
      ...data,
      // Convertir toutes les valeurs en string (requis par FCM)
      ...Object.keys(data).reduce((acc, key) => {
        acc[key] = String(data[key]);
        return acc;
      }, {})
    },
    token: fcmToken,
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'default'
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'default'
        }
      }
    }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Notification envoyée avec succès:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('Erreur lors de l\'envoi de la notification:', error);
    
    // Gérer les erreurs spécifiques
    if (error.code === 'messaging/invalid-registration-token' || 
        error.code === 'messaging/registration-token-not-registered') {
      // Token invalide ou expiré
      return { success: false, error: 'INVALID_TOKEN', message: error.message };
    }
    
    return { success: false, error: error.code || 'UNKNOWN', message: error.message };
  }
}

/**
 * Envoie une notification à plusieurs tokens FCM
 * @param {string[]} fcmTokens - Liste des tokens FCM
 * @param {string} title - Titre de la notification
 * @param {string} body - Corps de la notification
 * @param {object} data - Données supplémentaires (optionnel)
 * @returns {Promise<object>} Résultat de l'envoi
 */
async function sendNotificationToMultipleTokens(fcmTokens, title, body, data = {}) {
  const firebaseAdmin = initializeFirebase();
  if (!firebaseAdmin) {
    throw new Error('Firebase Admin non initialisé');
  }

  if (!fcmTokens || fcmTokens.length === 0) {
    return { success: false, error: 'NO_TOKENS', message: 'Aucun token fourni' };
  }

  // Valider et nettoyer les tokens
  const validTokens = fcmTokens.filter(token => {
    if (!token || typeof token !== 'string' || token.trim().length === 0) {
      console.warn('Token invalide ignoré:', token);
      return false;
    }
    return true;
  });

  if (validTokens.length === 0) {
    console.error('Aucun token valide après nettoyage');
    return { success: false, error: 'NO_VALID_TOKENS', message: 'Aucun token valide fourni' };
  }

  if (validTokens.length < fcmTokens.length) {
    console.warn(`${fcmTokens.length - validTokens.length} tokens invalides ignorés`);
  }

  const message = {
    notification: {
      title: title,
      body: body
    },
    data: {
      ...data,
      ...Object.keys(data).reduce((acc, key) => {
        acc[key] = String(data[key]);
        return acc;
      }, {})
    },
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'default'
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'default'
        }
      }
    },
    tokens: validTokens
  };

  try {
    console.log(`Envoi de ${validTokens.length} notification(s) via Firebase sendEachForMulticast...`);
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`${response.successCount} notifications envoyées avec succès`);
    console.log(`${response.failureCount} échecs`);
    
    // Log détaillé des résultats
    if (response.responses && response.responses.length > 0) {
      console.log(`Détail des envois:`);
      response.responses.forEach((resp, index) => {
        if (resp.success) {
          console.log(`  Token ${index + 1}: SUCCÈS (messageId: ${resp.messageId})`);
        } else {
          console.log(`  Token ${index + 1}: ÉCHEC (${resp.error?.code}: ${resp.error?.message})`);
        }
      });
    }
    
    // Analyser les erreurs pour identifier les tokens invalides
    const invalidTokens = [];
    if (response.responses && response.responses.length > 0) {
      response.responses.forEach((resp, index) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          const errorMessage = resp.error?.message || 'Erreur inconnue';
          console.error(`Échec pour le token ${index + 1}: ${errorCode} - ${errorMessage}`);
          
          // Identifier les tokens invalides ou expirés
          if (errorCode === 'messaging/invalid-registration-token' || 
              errorCode === 'messaging/registration-token-not-registered' ||
              errorCode === 'messaging/invalid-argument') {
            invalidTokens.push(validTokens[index]);
          }
        }
      });
    }
    
    // Supprimer les tokens invalides de la base de données
    if (invalidTokens.length > 0) {
      try {
        const db = require("../models");
        const FCMToken = db.fcmToken;
        await FCMToken.destroy({
          where: { token: invalidTokens }
        });
        console.log(`${invalidTokens.length} tokens invalides supprimés de la base de données`);
      } catch (err) {
        console.error('Erreur lors de la suppression des tokens invalides:', err.message);
      }
    }
    
    // Retourner success: true seulement si au moins une notification a réussi
    // Sinon, considérer comme un échec partiel mais pas une erreur totale
    return {
      success: response.successCount > 0,
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses,
      invalidTokensCount: invalidTokens.length
    };
  } catch (error) {
    console.error('Erreur lors de l\'envoi des notifications:', error);
    console.error('Détails de l\'erreur:', error.code, error.message);
    return { success: false, error: error.code || 'UNKNOWN', message: error.message };
  }
}

/**
 * Envoie une notification à un utilisateur spécifique
 * @param {number} userId - ID de l'utilisateur
 * @param {string} title - Titre de la notification
 * @param {string} body - Corps de la notification
 * @param {object} data - Données supplémentaires (optionnel)
 * @returns {Promise<object>} Résultat de l'envoi
 */
async function sendNotificationToUser(userId, title, body, data = {}) {
  const db = require("../models");
  const FCMToken = db.fcmToken;
  
  // Récupérer tous les tokens actifs de l'utilisateur
  const tokens = await FCMToken.findAll({
    where: {
      user_id: userId,
      active: true
    }
  });

  if (tokens.length === 0) {
    return { success: false, error: 'NO_TOKENS', message: 'Aucun token FCM trouvé pour cet utilisateur' };
  }

  const fcmTokens = tokens.map(t => t.token);
  return await sendNotificationToMultipleTokens(fcmTokens, title, body, data);
}

/**
 * Envoie une notification à tous les utilisateurs qui ont un événement en favori
 * @param {number} eventId - ID de l'événement
 * @param {string} title - Titre de la notification
 * @param {string} body - Corps de la notification
 * @param {object} data - Données supplémentaires (optionnel)
 * @returns {Promise<object>} Résultat de l'envoi
 */
async function sendNotificationToEventFavorites(eventId, title, body, data = {}) {
  const db = require("../models");
  const Favorite = db.favorite;
  const FCMToken = db.fcmToken;
  
  // Récupérer tous les utilisateurs qui ont cet événement en favori
  const favorites = await Favorite.findAll({
    where: { event_id: eventId }
  });

  if (favorites.length === 0) {
    return { success: false, error: 'NO_FAVORITES', message: 'Aucun utilisateur n\'a cet événement en favori' };
  }

  const userIds = favorites.map(f => f.user_id);
  
  // Récupérer tous les tokens actifs de ces utilisateurs
  const tokens = await FCMToken.findAll({
    where: {
      user_id: userIds,
      active: true
    }
  });

  if (tokens.length === 0) {
    return { success: false, error: 'NO_TOKENS', message: 'Aucun token FCM trouvé pour ces utilisateurs' };
  }

  const fcmTokens = tokens.map(t => t.token);
  
  // Ajouter l'event_id dans les données
  const notificationData = {
    ...data,
    event_id: String(eventId)
  };
  
  return await sendNotificationToMultipleTokens(fcmTokens, title, body, notificationData);
}

/**
 * Envoie une notification à tous les utilisateurs qui ont au moins un des événements en favori
 * Envoie une notification séparée pour chaque événement à chaque utilisateur qui l'a en favoris
 * @param {number[]} eventIds - Liste des IDs d'événements
 * @param {string} title - Titre de la notification
 * @param {string} body - Corps de la notification
 * @param {object} data - Données supplémentaires (optionnel)
 * @param {number} notificationId - ID de la notification dans la base de données (optionnel)
 * @returns {Promise<object>} Résultat de l'envoi
 */
async function sendNotificationToMultipleEventFavorites(eventIds, title, body, data = {}, notificationId = null) {
  const db = require("../models");
  const Favorite = db.favorite;
  const FCMToken = db.fcmToken;
  const Event = db.event;
  const UserNotification = db.userNotification;
  const { Op } = db.Sequelize;
  
  if (!eventIds || eventIds.length === 0) {
    return { success: false, error: 'NO_EVENTS', message: 'Aucun événement fourni' };
  }
  
  // Récupérer les informations des événements
  const events = await Event.findAll({
    where: {
      event_id: { [Op.in]: eventIds }
    }
  });

  if (events.length === 0) {
    return { success: false, error: 'EVENTS_NOT_FOUND', message: 'Aucun événement trouvé' };
  }

  // Créer un map pour accéder rapidement aux événements par ID
  const eventsMap = new Map();
  events.forEach(event => {
    eventsMap.set(event.event_id, event);
  });

  let totalSuccessCount = 0;
  let totalFailureCount = 0;
  const errors = [];

  // Pour chaque événement, envoyer une notification à tous les utilisateurs qui l'ont en favoris
  for (const eventId of eventIds) {
    const event = eventsMap.get(eventId);
    if (!event) {
      console.warn(`Événement ${eventId} non trouvé, ignoré`);
      continue;
    }

    // Récupérer tous les utilisateurs qui ont cet événement en favori
    const favorites = await Favorite.findAll({
      where: { event_id: eventId }
    });

    console.log(`Événement ${eventId}: ${favorites.length} utilisateur(s) ont cet événement en favori`);
    
    if (favorites.length === 0) {
      console.log(`Aucun utilisateur n'a l'événement ${eventId} en favori`);
      continue;
    }

    const userIds = favorites.map(f => f.user_id);
    console.log(`IDs des utilisateurs avec l'événement ${eventId} en favori:`, userIds);
    
    // Récupérer tous les tokens actifs de ces utilisateurs, triés par date de mise à jour (plus récent en premier)
    const tokens = await FCMToken.findAll({
      where: {
        user_id: { [Op.in]: userIds },
        active: true
      },
      order: [['updated_at', 'DESC']] // Plus récent en premier
    });

    console.log(`Tokens FCM actifs trouvés pour ces utilisateurs: ${tokens.length}`);
    
    // Si aucun token actif, vérifier s'il y a des tokens inactifs
    if (tokens.length === 0) {
      const allTokens = await FCMToken.findAll({
        where: {
          user_id: { [Op.in]: userIds }
        }
      });
      console.log(`Tokens FCM totaux (actifs + inactifs) pour ces utilisateurs: ${allTokens.length}`);
      
      if (allTokens.length > 0) {
        const activeCount = allTokens.filter(t => t.active).length;
        const inactiveCount = allTokens.filter(t => !t.active).length;
        console.log(`  - Actifs: ${activeCount}`);
        console.log(`  - Inactifs: ${inactiveCount}`);
      }
      
      console.log(`Aucun token FCM actif trouvé pour les utilisateurs ayant l'événement ${eventId} en favori`);
      errors.push(`Événement ${eventId}: ${favorites.length} utilisateur(s) en favori mais aucun token FCM actif`);
      continue;
    }

    // Dédupliquer les tokens : ne garder qu'un seul token par utilisateur (le plus récent)
    const tokensByUser = new Map();
    tokens.forEach(token => {
      if (!tokensByUser.has(token.user_id)) {
        tokensByUser.set(token.user_id, token);
      } else {
        // Si on a déjà un token pour cet utilisateur, garder le plus récent
        const existingToken = tokensByUser.get(token.user_id);
        if (token.updated_at > existingToken.updated_at) {
          tokensByUser.set(token.user_id, token);
        }
      }
    });

    const uniqueTokens = Array.from(tokensByUser.values());
    const fcmTokens = uniqueTokens.map(t => t.token);
    
    console.log(`Tokens FCM après déduplication (1 par utilisateur): ${fcmTokens.length} tokens pour ${uniqueTokens.length} utilisateurs`);
    console.log(`  Détail par utilisateur:`);
    uniqueTokens.forEach((token, index) => {
      console.log(`    ${index + 1}. User ${token.user_id}: token ${token.token.substring(0, 20)}... (mis à jour: ${token.updated_at})`);
    });
    
    if (tokens.length > uniqueTokens.length) {
      console.log(`  ${tokens.length - uniqueTokens.length} token(s) dupliqué(s) ignoré(s) pour ${tokens.length - uniqueTokens.length} utilisateur(s)`);
    }
    
    // Personnaliser le titre et le corps avec le nom de l'événement
    // Le titre contient le nom de l'événement pour qu'il soit visible directement
    const personalizedTitle = `${title} - ${event.title}`;
    // Le corps contient le message original + le nom de l'événement en début
    const personalizedBody = event.location 
      ? `${event.title}\n\n${body}\n\n ${event.location}`
      : `${event.title}\n\n${body}`;
    
    // Ajouter l'event_id dans les données
    const notificationData = {
      ...data,
      event_id: String(eventId),
      event_title: event.title
    };
    
    console.log(`Envoi notification pour événement "${event.title}" (ID: ${eventId})`);
    console.log(`   Titre: "${personalizedTitle}"`);
    console.log(`   Corps: "${personalizedBody}"`);
    console.log(`   Destinataires: ${fcmTokens.length} tokens (${uniqueTokens.length} utilisateurs uniques)`);
    console.log(`   Tokens: ${fcmTokens.map((t, i) => `${i + 1}. ${t.substring(0, 20)}...`).join(', ')}`);
    
    // Envoyer la notification pour cet événement
    const result = await sendNotificationToMultipleTokens(fcmTokens, personalizedTitle, personalizedBody, notificationData);
    
    console.log(`   Résultat: ${result.successCount} réussies, ${result.failureCount} échouées`);
    
    // Enregistrer les notifications dans user_notifications pour chaque utilisateur
    // Dédupliquer d'abord pour éviter les doublons
    if (notificationId && result.success) {
      try {
        // Dédupliquer les userIds pour éviter les doublons
        const uniqueUserIds = [...new Set(userIds)];
        
        // Vérifier quelles notifications existent déjà pour éviter les doublons
        const existingNotifications = await UserNotification.findAll({
          where: {
            notification_id: notificationId,
            event_id: eventId,
            user_id: { [Op.in]: uniqueUserIds }
          },
          attributes: ['user_id']
        });
        
        const existingUserIds = new Set(existingNotifications.map(n => n.user_id));
        const newUserIds = uniqueUserIds.filter(userId => !existingUserIds.has(userId));
        
        if (newUserIds.length > 0) {
          const userNotificationsToCreate = newUserIds.map(userId => ({
            user_id: userId,
            notification_id: notificationId,
            event_id: eventId,
            read: false
          }));
          
          await UserNotification.bulkCreate(userNotificationsToCreate, {
            ignoreDuplicates: true // Double protection
          });
          
          console.log(`${userNotificationsToCreate.length} nouvelles notifications enregistrées dans user_notifications pour l'événement ${eventId}`);
          if (existingUserIds.size > 0) {
            console.log(`${existingUserIds.size} notification(s) déjà existante(s) ignorée(s)`);
          }
        } else {
          console.log(`Toutes les notifications pour l'événement ${eventId} existent déjà, aucune nouvelle notification créée`);
        }
      } catch (err) {
        console.error(`Erreur lors de l'enregistrement des notifications: ${err.message}`);
      }
    }
    
    if (result.success) {
      totalSuccessCount += result.successCount || 0;
      totalFailureCount += result.failureCount || 0;
    } else {
      // Si toutes les notifications ont échoué, compter tous les tokens comme échecs
      totalFailureCount += fcmTokens.length;
      
      // Construire un message d'erreur détaillé
      let errorMessage = 'Erreur inconnue';
      if (result.error) {
        errorMessage = result.error;
      } else if (result.message) {
        errorMessage = result.message;
      } else if (result.failureCount > 0) {
        errorMessage = `${result.failureCount} notification(s) échouée(s)`;
      }
      
      errors.push(`Erreur pour l'événement ${eventId}: ${errorMessage}`);
      console.error(`Erreur lors de l'envoi pour l'événement ${eventId}:`, result);
    }
  }

  // Si aucune notification n'a été envoyée avec succès, retourner un message d'erreur plus clair
  if (totalSuccessCount === 0) {
    // Si aucune notification n'a été tentée (pas de tokens), c'est différent d'un échec d'envoi
    if (totalFailureCount === 0 && errors.length > 0) {
      return {
        success: false,
        successCount: 0,
        failureCount: 0,
        error: 'NO_TOKENS',
        message: errors.join('; '),
        errors: errors
      };
    }
    
    return {
      success: false,
      successCount: 0,
      failureCount: totalFailureCount,
      error: 'ALL_FAILED',
      message: errors.length > 0 ? errors.join('; ') : 'Toutes les notifications ont échoué',
      errors: errors.length > 0 ? errors : undefined
    };
  }
  
  return {
    success: totalSuccessCount > 0,
    successCount: totalSuccessCount,
    failureCount: totalFailureCount,
    errors: errors.length > 0 ? errors : undefined
  };
}

module.exports = {
  initializeFirebase,
  sendNotificationToToken,
  sendNotificationToMultipleTokens,
  sendNotificationToUser,
  sendNotificationToEventFavorites,
  sendNotificationToMultipleEventFavorites
};

