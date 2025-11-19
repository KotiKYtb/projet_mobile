const { authJwt } = require("../middleware");
const controller = require("../controllers/event.controller");

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
   * /api/events:
   *   get:
   *     summary: Liste paginée des événements
   *     tags: [Events]
   *     parameters:
   *       - in: query
   *         name: page
   *         schema:
   *           type: integer
   *           default: 1
   *         description: Numéro de page
   *       - in: query
   *         name: pageSize
   *         schema:
   *           type: integer
   *           default: 50
   *           maximum: 200
   *         description: "Nombre d'éléments par page (max 200)"
   *       - in: query
   *         name: updatedSince
   *         schema:
   *           type: string
   *           format: date-time
   *         description: Filtrer les événements modifiés après cette date
   *     responses:
   *       200:
   *         description: Liste des événements
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/EventListResponse'
   *       500:
   *         description: Erreur serveur
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.get("/api/events", controller.list);

  /**
   * @swagger
   * /api/events/{id}:
   *   get:
   *     summary: Récupérer un événement par son ID
   *     tags: [Events]
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: integer
   *         description: "ID de l'événement"
   *     responses:
   *       200:
   *         description: "Détails de l'événement"
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Event'
   *       404:
   *         description: Événement non trouvé
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
  app.get("/api/events/:id", controller.getById);

  /**
   * @swagger
   * /api/events:
   *   post:
   *     summary: Créer un nouvel événement (Admin ou Organisation)
   *     tags: [Events]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             type: object
   *             required:
   *               - title
   *               - startAt
   *             properties:
   *               title:
   *                 type: string
   *                 example: Concert de jazz
   *               description:
   *                 type: string
   *                 example: Un magnifique concert de jazz en plein air
   *               startAt:
   *                 type: string
   *                 format: date-time
   *               endAt:
   *                 type: string
   *                 format: date-time
   *               location:
   *                 type: string
   *                 example: Place du Ralliement, Angers
   *               category:
   *                 type: string
   *                 example: Musique
   *               image_url:
   *                 type: string
   *     responses:
   *       201:
   *         description: Événement créé avec succès
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Event'
   *       400:
   *         description: Erreur de validation
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
   */
  app.post("/api/events", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.create);

  /**
   * @swagger
   * /api/events/{id}:
   *   put:
   *     summary: Mettre à jour un événement (Admin ou Organisation)
   *     tags: [Events]
   *     security:
   *       - bearerAuth: []
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: integer
   *         description: "ID de l'événement"
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             type: object
   *             properties:
   *               title:
   *                 type: string
   *               description:
   *                 type: string
   *               startAt:
   *                 type: string
   *                 format: date-time
   *               endAt:
   *                 type: string
   *                 format: date-time
   *               location:
   *                 type: string
   *               category:
   *                 type: string
   *               image_url:
   *                 type: string
   *     responses:
   *       200:
   *         description: Événement mis à jour
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Event'
   *       400:
   *         description: Erreur de validation
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
   *       404:
   *         description: Événement non trouvé
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   */
  app.put("/api/events/:id", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.update);

  /**
   * @swagger
   * /api/events/{id}:
   *   delete:
   *     summary: Supprimer un événement (Admin ou Organisation)
   *     tags: [Events]
   *     security:
   *       - bearerAuth: []
   *     parameters:
   *       - in: path
   *         name: id
   *         required: true
   *         schema:
   *           type: integer
   *         description: "ID de l'événement"
   *     responses:
   *       204:
   *         description: Événement supprimé avec succès
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
   *       404:
   *         description: Événement non trouvé
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
  app.delete("/api/events/:id", [authJwt.verifyToken, authJwt.isAdminOrOrganisation], controller.remove);
};


