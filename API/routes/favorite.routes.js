const { authJwt } = require("../middleware");
const controller = require("../controllers/favorite.controller");

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
   * /api/favorites:
   *   get:
   *     summary: Récupérer la liste des favoris de l'utilisateur connecté
   *     tags: [Favorites]
   *     security:
   *       - bearerAuth: []
   *     responses:
   *       200:
   *         description: Liste des favoris
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/FavoriteListResponse'
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
  app.get("/api/favorites", [authJwt.verifyToken], controller.getFavorites);

  /**
   * @swagger
   * /api/favorites:
   *   post:
   *     summary: Ajouter un événement aux favoris
   *     tags: [Favorites]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         application/json:
   *           schema:
   *             $ref: '#/components/schemas/AddFavoriteRequest'
   *     responses:
   *       200:
   *         description: Événement déjà dans les favoris
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Already in favorites
   *                 favorite:
   *                   $ref: '#/components/schemas/Favorite'
   *       201:
   *         description: Favori ajouté avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Favorite added
   *                 favorite:
   *                   $ref: '#/components/schemas/Favorite'
   *       400:
   *         description: Paramètres manquants
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
  app.post("/api/favorites", [authJwt.verifyToken], controller.addFavorite);

  /**
   * @swagger
   * /api/favorites/{eventId}:
   *   delete:
   *     summary: Retirer un événement des favoris
   *     tags: [Favorites]
   *     security:
   *       - bearerAuth: []
   *     parameters:
   *       - in: path
   *         name: eventId
   *         required: true
   *         schema:
   *           type: integer
   *         description: "ID de l'événement à retirer des favoris"
   *     responses:
   *       200:
   *         description: Favori retiré avec succès
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 message:
   *                   type: string
   *                   example: Favorite removed
   *       401:
   *         description: Non authentifié
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/Error'
   *       404:
   *         description: Favori non trouvé
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
  app.delete("/api/favorites/:eventId", [authJwt.verifyToken], controller.removeFavorite);
};

