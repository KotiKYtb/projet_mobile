const db = require("../models");
const FCMToken = db.fcmToken;
const User = db.user;
const Notification = db.notification;
const { 
  sendNotificationToToken, 
  sendNotificationToUser,
  sendNotificationToEventFavorites,
  sendNotificationToMultipleEventFavorites 
} = require("../services/firebase.service");

/**
 * Enregistre ou met à jour un token FCM pour un utilisateur
 */
exports.registerToken = async function(req, res) {
  try {
    const userId = req.userId;
    const { token, device_type } = req.body;

    if (!token) {
      return res.status(400).json({ message: "Token FCM requis" });
    }

    // Essayer de créer le token, ou le mettre à jour s'il existe déjà
    // Utiliser upsert pour gérer automatiquement le cas où le token existe déjà
    try {
      // Essayer de créer le token
      const fcmToken = await FCMToken.create({
        user_id: userId,
        token: token,
        device_type: device_type || 'android',
        active: true
      });
      
      return res.status(201).json({ 
        message: "Token enregistré avec succès", 
        token_id: fcmToken.token_id 
      });
    } catch (createError) {
      // Si l'erreur est une contrainte unique (token existe déjà)
      if (createError.name === 'SequelizeUniqueConstraintError' || 
          createError.original?.code === 'SQLITE_CONSTRAINT') {
        
        // Récupérer le token existant
        const existingToken = await FCMToken.findOne({ where: { token } });
        
        if (!existingToken) {
          // Cas improbable : erreur de contrainte mais token non trouvé
          throw createError;
        }

        // Mettre à jour le token existant
        await existingToken.update({
          user_id: userId,
          device_type: device_type || existingToken.device_type || 'android',
          active: true,
          updated_at: new Date()
        });

        return res.json({ 
          message: "Token mis à jour avec succès", 
          token_id: existingToken.token_id 
        });
      }
      
      // Si ce n'est pas une erreur de contrainte unique, relancer l'erreur
      throw createError;
    }
  } catch (e) {
    console.error("Erreur lors de l'enregistrement du token:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Supprime un token FCM (désactive)
 */
exports.removeToken = async function(req, res) {
  try {
    const userId = req.userId;
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({ message: "Token FCM requis" });
    }

    const fcmToken = await FCMToken.findOne({ 
      where: { token, user_id: userId } 
    });

    if (!fcmToken) {
      return res.status(404).json({ message: "Token non trouvé" });
    }

    await fcmToken.update({ active: false });
    res.json({ message: "Token supprimé avec succès" });
  } catch (e) {
    console.error("Erreur lors de la suppression du token:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Envoie une notification de test à l'utilisateur connecté
 */
exports.sendTestNotification = async function(req, res) {
  try {
    const userId = req.userId;
    const { title, body } = req.body;

    const result = await sendNotificationToUser(
      userId,
      title || "Notification de test",
      body || "Ceci est une notification de test depuis l'API !"
    );

    if (result.success) {
      res.json({ 
        message: "Notification envoyée avec succès",
        result 
      });
    } else {
      res.status(400).json({ 
        message: "Erreur lors de l'envoi de la notification",
        error: result.error,
        details: result.message 
      });
    }
  } catch (e) {
    console.error("Erreur lors de l'envoi de la notification:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Envoie une notification à un utilisateur spécifique (Admin uniquement)
 */
exports.sendNotificationToUser = async function(req, res) {
  try {
    const { userId, title, body, data } = req.body;

    if (!userId || !title || !body) {
      return res.status(400).json({ 
        message: "userId, title et body sont requis" 
      });
    }

    const result = await sendNotificationToUser(userId, title, body, data || {});

    if (result.success) {
      res.json({ 
        message: "Notification envoyée avec succès",
        result 
      });
    } else {
      res.status(400).json({ 
        message: "Erreur lors de l'envoi de la notification",
        error: result.error,
        details: result.message 
      });
    }
  } catch (e) {
    console.error("Erreur lors de l'envoi de la notification:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Envoie une notification à tous les utilisateurs qui ont un événement en favori
 */
exports.sendNotificationToEventFavorites = async function(req, res) {
  try {
    const { eventId, title, body, data } = req.body;

    if (!eventId || !title || !body) {
      return res.status(400).json({ 
        message: "eventId, title et body sont requis" 
      });
    }

    const result = await sendNotificationToEventFavorites(
      eventId, 
      title, 
      body, 
      data || {}
    );

    if (result.success) {
      res.json({ 
        message: "Notifications envoyées avec succès",
        result 
      });
    } else {
      res.status(400).json({ 
        message: "Erreur lors de l'envoi des notifications",
        error: result.error,
        details: result.message 
      });
    }
  } catch (e) {
    console.error("Erreur lors de l'envoi des notifications:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Crée une notification sans l'envoyer
 */
exports.createNotification = async function(req, res) {
  try {
    const userId = req.userId;
    const { eventIds, title, body } = req.body;

    if (!eventIds || !Array.isArray(eventIds) || eventIds.length === 0) {
      return res.status(400).json({ 
        message: "eventIds (tableau) est requis et ne doit pas être vide" 
      });
    }

    if (!title || !body) {
      return res.status(400).json({ 
        message: "title et body sont requis" 
      });
    }

    // Créer la notification sans l'envoyer
    const notification = await Notification.create({
      title,
      body,
      event_ids: JSON.stringify(eventIds),
      created_by: userId,
      sent_count: 0,
      failed_count: 0
    });

    res.status(201).json({ 
      message: "Notification créée avec succès",
      notification: {
        notification_id: notification.notification_id,
        title: notification.title,
        body: notification.body,
        event_ids: JSON.parse(notification.event_ids),
        sent_count: notification.sent_count,
        failed_count: notification.failed_count,
        created_at: notification.created_at
      }
    });
  } catch (e) {
    console.error("Erreur lors de la création de la notification:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Envoie une notification à tous les utilisateurs qui ont au moins un des événements en favori
 */
exports.sendNotificationToMultipleEventFavorites = async function(req, res) {
  try {
    const userId = req.userId;
    const { eventIds, title, body, data } = req.body;

    if (!eventIds || !Array.isArray(eventIds) || eventIds.length === 0) {
      return res.status(400).json({ 
        message: "eventIds (tableau) est requis et ne doit pas être vide" 
      });
    }

    if (!title || !body) {
      return res.status(400).json({ 
        message: "title et body sont requis" 
      });
    }

    // Envoyer les notifications
    const result = await sendNotificationToMultipleEventFavorites(
      eventIds, 
      title, 
      body, 
      data || {}
    );

    // Sauvegarder la notification en base de données
    const notification = await Notification.create({
      title,
      body,
      event_ids: JSON.stringify(eventIds),
      created_by: userId,
      sent_count: result.success ? (result.successCount || 0) : 0,
      failed_count: result.success ? (result.failureCount || 0) : 0
    });

    if (result.success) {
      res.json({ 
        message: "Notifications envoyées avec succès",
        result,
        notification: {
          notification_id: notification.notification_id,
          title: notification.title,
          body: notification.body,
          event_ids: JSON.parse(notification.event_ids),
          sent_count: notification.sent_count,
          failed_count: notification.failed_count,
          created_at: notification.created_at
        }
      });
    } else {
      res.status(400).json({ 
        message: "Erreur lors de l'envoi des notifications",
        error: result.error,
        details: result.message,
        notification: {
          notification_id: notification.notification_id,
          title: notification.title,
          body: notification.body,
          event_ids: JSON.parse(notification.event_ids),
          sent_count: notification.sent_count,
          failed_count: notification.failed_count,
          created_at: notification.created_at
        }
      });
    }
  } catch (e) {
    console.error("Erreur lors de l'envoi des notifications:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Récupère toutes les notifications créées par l'utilisateur connecté (ou toutes si admin)
 */
exports.getNotifications = async function(req, res) {
  try {
    const userId = req.userId;
    
    // Récupérer l'utilisateur pour vérifier son rôle
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(401).json({ message: "Utilisateur non trouvé" });
    }

    let whereClause = {};
    // Si l'utilisateur n'est pas admin, ne récupérer que ses propres notifications
    if (user.role !== 'admin') {
      whereClause.created_by = userId;
    }

    const notifications = await Notification.findAll({
      where: whereClause,
      include: [{
        model: User,
        as: 'creator',
        attributes: ['user_id', 'name', 'surname', 'email']
      }],
      order: [['created_at', 'DESC']]
    });

    const formattedNotifications = notifications.map(notif => ({
      notification_id: notif.notification_id,
      title: notif.title,
      body: notif.body,
      event_ids: JSON.parse(notif.event_ids),
      sent_count: notif.sent_count,
      failed_count: notif.failed_count,
      created_at: notif.created_at,
      created_by: notif.created_by,
      creator: notif.creator ? {
        user_id: notif.creator.user_id,
        name: notif.creator.name,
        surname: notif.creator.surname,
        email: notif.creator.email
      } : null
    }));

    res.json({ notifications: formattedNotifications });
  } catch (e) {
    console.error("Erreur lors de la récupération des notifications:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Met à jour une notification existante
 */
exports.updateNotification = async function(req, res) {
  try {
    const userId = req.userId;
    const notificationId = req.params.id;
    const { title, body, eventIds } = req.body;

    if (!title || !body) {
      return res.status(400).json({ 
        message: "title et body sont requis" 
      });
    }

    if (!eventIds || !Array.isArray(eventIds) || eventIds.length === 0) {
      return res.status(400).json({ 
        message: "eventIds (tableau) est requis et ne doit pas être vide" 
      });
    }

    // Récupérer la notification
    const notification = await Notification.findByPk(notificationId);
    if (!notification) {
      return res.status(404).json({ message: "Notification non trouvée" });
    }

    // Vérifier que l'utilisateur est le créateur ou un admin
    const user = await User.findByPk(userId);
    if (notification.created_by !== userId && user.role !== 'admin') {
      return res.status(403).json({ message: "Vous n'avez pas le droit de modifier cette notification" });
    }

    // Mettre à jour la notification
    await notification.update({
      title,
      body,
      event_ids: JSON.stringify(eventIds),
      // Réinitialiser les compteurs car la notification n'a pas encore été envoyée avec ces nouvelles données
      sent_count: 0,
      failed_count: 0
    });

    res.json({ 
      message: "Notification mise à jour avec succès",
      notification: {
        notification_id: notification.notification_id,
        title: notification.title,
        body: notification.body,
        event_ids: JSON.parse(notification.event_ids),
        sent_count: notification.sent_count,
        failed_count: notification.failed_count,
        created_at: notification.created_at
      }
    });
  } catch (e) {
    console.error("Erreur lors de la mise à jour de la notification:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Envoie une notification existante (par son ID)
 */
exports.sendNotificationById = async function(req, res) {
  try {
    const userId = req.userId;
    const notificationId = req.params.id;

    // Récupérer la notification
    const notification = await Notification.findByPk(notificationId);
    if (!notification) {
      return res.status(404).json({ message: "Notification non trouvée" });
    }

    // Vérifier que l'utilisateur est le créateur ou un admin
    const user = await User.findByPk(userId);
    if (notification.created_by !== userId && user.role !== 'admin') {
      return res.status(403).json({ message: "Vous n'avez pas le droit d'envoyer cette notification" });
    }

    const eventIds = JSON.parse(notification.event_ids);

    // Envoyer les notifications (passer le notificationId pour l'enregistrement)
    const result = await sendNotificationToMultipleEventFavorites(
      eventIds, 
      notification.title, 
      notification.body, 
      {},
      notification.notification_id
    );

    // Mettre à jour les statistiques (même si certaines ont échoué)
    await notification.update({
      sent_count: result.successCount || 0,
      failed_count: result.failureCount || 0
    });

    // Si au moins une notification a réussi, considérer comme un succès partiel
    // Si toutes ont échoué, retourner une erreur
    if (result.successCount > 0) {
      res.json({ 
        message: `Notifications envoyées: ${result.successCount} réussies, ${result.failureCount} échouées`,
        result 
      });
    } else {
      // Toutes les notifications ont échoué
      res.status(400).json({ 
        message: "Erreur lors de l'envoi des notifications",
        error: result.error || 'ALL_FAILED',
        details: result.message || 'Toutes les notifications ont échoué',
        result: result
      });
    }
  } catch (e) {
    console.error("Erreur lors de l'envoi de la notification:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Supprime une notification
 */
exports.deleteNotification = async function(req, res) {
  try {
    const userId = req.userId;
    const notificationId = req.params.id;

    // Récupérer la notification
    const notification = await Notification.findByPk(notificationId);
    if (!notification) {
      return res.status(404).json({ message: "Notification non trouvée" });
    }

    // Vérifier que l'utilisateur est le créateur ou un admin
    const user = await User.findByPk(userId);
    if (notification.created_by !== userId && user.role !== 'admin') {
      return res.status(403).json({ message: "Vous n'avez pas le droit de supprimer cette notification" });
    }

    // Supprimer la notification
    await notification.destroy();

    res.json({ message: "Notification supprimée avec succès" });
  } catch (e) {
    console.error("Erreur lors de la suppression de la notification:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Récupère les notifications reçues par l'utilisateur connecté
 */
exports.getMyReceivedNotifications = async function(req, res) {
  try {
    const userId = req.userId;
    const UserNotification = db.userNotification;
    const Notification = db.notification;
    const Event = db.event;

    const userNotifications = await UserNotification.findAll({
      where: { 
        user_id: userId,
        hidden: false // Ne récupérer que les notifications non masquées
      },
      include: [
        {
          model: Notification,
          as: 'notification',
          attributes: ['notification_id', 'title', 'body', 'created_at']
        },
        {
          model: Event,
          as: 'event',
          attributes: ['event_id', 'title', 'location']
        }
      ],
      order: [['created_at', 'DESC']]
    });

    const formattedNotifications = userNotifications.map(un => ({
      user_notification_id: un.user_notification_id,
      notification_id: un.notification_id,
      event_id: un.event_id,
      read: un.read,
      read_at: un.read_at,
      created_at: un.created_at,
      title: un.notification ? un.notification.title : 'Notification',
      body: un.notification ? un.notification.body : '',
      event_title: un.event ? un.event.title : null,
      event_location: un.event ? un.event.location : null
    }));

    res.json({ notifications: formattedNotifications });
  } catch (e) {
    console.error("Erreur lors de la récupération des notifications reçues:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Marque une notification comme lue
 */
exports.markNotificationAsRead = async function(req, res) {
  try {
    const userId = req.userId;
    const userNotificationId = req.params.id;
    const UserNotification = db.userNotification;

    const userNotification = await UserNotification.findByPk(userNotificationId);
    if (!userNotification) {
      return res.status(404).json({ message: "Notification non trouvée" });
    }

    // Vérifier que la notification appartient à l'utilisateur
    if (userNotification.user_id !== userId) {
      return res.status(403).json({ message: "Vous n'avez pas le droit de modifier cette notification" });
    }

    await userNotification.update({
      read: true,
      read_at: new Date()
    });

    res.json({ message: "Notification marquée comme lue", notification: userNotification });
  } catch (e) {
    console.error("Erreur lors du marquage de la notification:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Marque toutes les notifications comme lues
 */
exports.markAllNotificationsAsRead = async function(req, res) {
  try {
    const userId = req.userId;
    const UserNotification = db.userNotification;

    await UserNotification.update(
      {
        read: true,
        read_at: new Date()
      },
      {
        where: {
          user_id: userId,
          read: false,
          hidden: false
        }
      }
    );

    res.json({ message: "Toutes les notifications ont été marquées comme lues" });
  } catch (e) {
    console.error("Erreur lors du marquage de toutes les notifications:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Masque une notification de l'affichage
 */
exports.hideNotification = async function(req, res) {
  try {
    const userId = req.userId;
    const userNotificationId = req.params.id;
    const UserNotification = db.userNotification;

    const userNotification = await UserNotification.findByPk(userNotificationId);
    if (!userNotification) {
      return res.status(404).json({ message: "Notification non trouvée" });
    }

    // Vérifier que la notification appartient à l'utilisateur
    if (userNotification.user_id !== userId) {
      return res.status(403).json({ message: "Vous n'avez pas le droit de modifier cette notification" });
    }

    await userNotification.update({
      hidden: true
    });

    res.json({ message: "Notification masquée avec succès" });
  } catch (e) {
    console.error("Erreur lors du masquage de la notification:", e);
    res.status(500).json({ message: e.message });
  }
};

/**
 * Liste les tokens FCM de l'utilisateur connecté
 */
exports.getMyTokens = async function(req, res) {
  try {
    const userId = req.userId;

    const tokens = await FCMToken.findAll({
      where: { user_id: userId },
      order: [['created_at', 'DESC']]
    });

    res.json({ tokens });
  } catch (e) {
    console.error("Erreur lors de la récupération des tokens:", e);
    res.status(500).json({ message: e.message });
  }
};

