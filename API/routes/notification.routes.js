const { authJwt } = require("../middleware");
const controller = require("../controllers/notification.controller");

module.exports = function(app) {
  app.use(function(req, res, next) {
    res.header(
      "Access-Control-Allow-Headers",
      "x-access-token, Origin, Content-Type, Accept"
    );
    next();
  });

  /**
   * @swagger
   * /api/notifications/token:
   *   post:
   *     summary: Enregistrer un token FCM pour l'utilisateur connecté
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/RegisterTokenRequest'
   *     responses:
   *       201:
   *         description: Token enregistré avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Token enregistré avec succès
   *                 token_id:
   *                   type: integer
   *                   example: 1
   *       200:
   *         description: Token mis à jour
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Token mis à jour
   *                 token_id:
   *                   type: integer
   *                   example: 1
   *       400:
   *         description: Token manquant
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.post("/api/notifications/token", [authJwt.verifyToken], controller.registerToken);

  /**
   * @swagger
   * /api/notifications/token:
   *   delete:
   *     summary: Supprimer un token FCM
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/RemoveTokenRequest'
   *     responses:
   *       200:
   *         description: Token supprimé avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Token supprimé avec succès
   *       400:
   *         description: Token manquant
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       404:
   *         description: Token non trouvé
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.delete("/api/notifications/token", [authJwt.verifyToken], controller.removeToken);

  /**
   * @swagger
   * /api/notifications/test:
   *   post:
   *     summary: Envoyer une notification de test à l'utilisateur connecté
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/SendNotificationRequest'
   *     responses:
   *       200:
   *         description: Notification envoyée avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notification envoyée avec succès
   *                 result:
   *                   type: object
   *       400:
   *         description: Erreur lors de l'envoi
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.post("/api/notifications/test", [authJwt.verifyToken], controller.sendTestNotification);

  /**
   * @swagger
   * /api/notifications/user:
   *   post:
   *     summary: Envoyer une notification à un utilisateur (Admin uniquement)
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/SendNotificationToUserRequest'
   *     responses:
   *       200:
   *         description: Notification envoyée avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notification envoyée avec succès
   *                 result:
   *                   type: object
   *       400:
   *         description: Paramètres manquants ou invalides
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé (admin requis)
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.post("/api/notifications/user", [authJwt.verifyToken, authJwt.isAdmin], controller.sendNotificationToUser);

  /**
   * @swagger
   * /api/notifications/event:
   *   post:
   *     summary: Envoyer une notification à tous les favoris d'un événement (Admin uniquement)
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/SendNotificationToEventRequest'
   *     responses:
   *       200:
   *         description: Notifications envoyées avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notifications envoyées avec succès
   *                 result:
   *                   type: object
   *       400:
   *         description: Paramètres manquants ou invalides
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé (admin requis)
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.post("/api/notifications/event", [authJwt.verifyToken, authJwt.isAdmin], controller.sendNotificationToEventFavorites);

  /**
   * @swagger
   * /api/notifications/events:
   *   post:
   *     summary: Envoyer une notification à tous les favoris de plusieurs événements (Admin ou Organisation)
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/SendNotificationToEventsRequest'
   *     responses:
   *       200:
   *         description: Notifications envoyées avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notifications envoyées avec succès
   *                 result:
   *                   type: object
   *                 notification:
   *                   $ref: '#/components/schemas/Notification'
   *       400:
   *         description: Paramètres manquants ou invalides
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé (admin ou organisation requis)
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.post("/api/notifications/events", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.sendNotificationToMultipleEventFavorites);

  /**
   * @swagger
   * /api/notifications:
   *   get:
   *     summary: Récupère toutes les notifications créées (par l'utilisateur connecté ou toutes si admin)
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     responses:
   *       200:
   *         description: Liste des notifications
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/NotificationListResponse'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.get("/api/notifications", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.getNotifications);

  /**
   * @swagger
   * /api/notifications:
   *   post:
   *     summary: Crée une notification sans l'envoyer
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/CreateNotificationRequest'
   *     responses:
   *       201:
   *         description: Notification créée avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notification créée avec succès
   *                 notification:
   *                   $ref: '#/components/schemas/Notification'
   *       400:
   *         description: Données invalides
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé (admin ou organisation requis)
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.post("/api/notifications", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.createNotification);

  /**
   * @swagger
   * /api/notifications/{id}:
   *   put:
   *     summary: Met à jour une notification existante
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: integer
   *         description: ID de la notification
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/UpdateNotificationRequest'
   *     responses:
   *       200:
   *         description: Notification mise à jour avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notification mise à jour avec succès
   *                 notification:
   *                   $ref: '#/components/schemas/Notification'
   *       400:
   *         description: Données invalides
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       404:
   *         description: Notification non trouvée
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.put("/api/notifications/:id", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.updateNotification);

  /**
   * @swagger
   * /api/notifications/{id}/send:
   *   post:
   *     summary: Envoie une notification existante par son ID
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: integer
   *         description: ID de la notification
   *     responses:
   *       200:
   *         description: Notifications envoyées avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notifications envoyées avec succès
   *                 result:
   *                   type: object
   *       400:
   *         description: Erreur lors de l'envoi
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       404:
   *         description: Notification non trouvée
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.post("/api/notifications/:id/send", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.sendNotificationById);

  /**
   * @swagger
   * /api/notifications/{id}:
   *   delete:
   *     summary: Supprime une notification
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: integer
   *         description: ID de la notification
   *     responses:
   *       200:
   *         description: Notification supprimée avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notification supprimée avec succès
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       404:
   *         description: Notification non trouvée
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.delete("/api/notifications/:id", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.deleteNotification);

  /**
   * @swagger
   * /api/notifications/tokens:
   *   get:
   *     summary: Liste les tokens FCM de l'utilisateur connecté
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     responses:
   *       200:
   *         description: Liste des tokens
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/FCMTokenListResponse'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.get("/api/notifications/tokens", [authJwt.verifyToken], controller.getMyTokens);

  /**
   * @swagger
   * /api/notifications/received:
   *   get:
   *     summary: Récupère les notifications reçues par l'utilisateur connecté
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     responses:
   *       200:
   *         description: Liste des notifications reçues
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/UserNotificationListResponse'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.get("/api/notifications/received", [authJwt.verifyToken], controller.getMyReceivedNotifications);

  /**
   * @swagger
   * /api/notifications/received/{id}/read:
   *   put:
   *     summary: Marque une notification comme lue
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: integer
   *         description: ID de la notification utilisateur
   *     responses:
   *       200:
   *         description: Notification marquée comme lue
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notification marquée comme lue
   *                 notification:
   *                   $ref: '#/components/schemas/UserNotification'
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       404:
   *         description: Notification non trouvée
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.put("/api/notifications/received/:id/read", [authJwt.verifyToken], controller.markNotificationAsRead);

  /**
   * @swagger
   * /api/notifications/received/read-all:
   *   put:
   *     summary: Marque toutes les notifications comme lues
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     responses:
   *       200:
   *         description: Toutes les notifications marquées comme lues
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Toutes les notifications ont été marquées comme lues
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.put("/api/notifications/received/read-all", [authJwt.verifyToken], controller.markAllNotificationsAsRead);

  /**
   * @swagger
   * /api/notifications/received/{id}/hide:
   *   put:
   *     summary: Masque une notification de l'affichage
   *     tags: [Notifications]
   *     security:
   *       - bearerAuth: []
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: integer
   *         description: ID de la notification utilisateur
   *     responses:
   *       200:
   *         description: Notification masquée avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Notification masquée avec succès
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       403:
   *         description: Accès refusé
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       404:
   *         description: Notification non trouvée
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.put("/api/notifications/received/:id/hide", [authJwt.verifyToken], controller.hideNotification);
};

