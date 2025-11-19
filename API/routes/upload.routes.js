const { authJwt } = require("../middleware");
const controller = require("../controllers/upload.controller");
const multer = require('multer');

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
   * /api/upload/image:
   *   post:
   *     summary: Uploader une image d'événement
   *     tags: [Upload]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         multipart/form-data:
   *           schema:
   *             type: object
   *             required:
   *               - image
   *             properties:
   *               image:
   *                 type: string
   *                 format: binary
   *                 description: Fichier image (jpeg, jpg, png, gif, webp, heic) - max 10MB
   *     responses:
   *       200:
   *         description: Image uploadée avec succès
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/UploadResponse'
   *       400:
   *         description: Aucun fichier uploadé ou fichier invalide
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
  app.post(
    "/api/upload/image",
    [authJwt.verifyToken, authJwt.isAdminOrOrganisation],
    (req, res, next) => {
      console.log('Upload route - Headers:', req.headers);
      console.log('Upload route - Content-Type:', req.headers['content-type']);
      controller.uploadImage(req, res, (err) => {
        if (err) {
          console.error('Erreur multer:', err);
          // Gérer les erreurs de multer
          if (err instanceof multer.MulterError) {
            console.error('MulterError code:', err.code);
            if (err.code === 'LIMIT_FILE_SIZE') {
              return res.status(400).json({ message: 'Le fichier est trop volumineux (max 10MB)' });
            }
            if (err.code === 'LIMIT_UNEXPECTED_FILE') {
              return res.status(400).json({ message: 'Champ de fichier inattendu. Le champ doit être nommé "image"' });
            }
            return res.status(400).json({ message: 'Erreur multer: ' + err.message, code: err.code });
          }
          return res.status(400).json({ message: err.message });
        }
        next();
      });
    },
    controller.upload
  );

  /**
   * @swagger
   * /api/upload/profile:
   *   post:
   *     summary: Uploader une photo de profil (organisateurs uniquement)
   *     tags: [Upload]
   *     security:
   *       - bearerAuth: []
   *     requestBody:
   *       required: true
   *       content:
   *         multipart/form-data:
   *           schema:
   *             type: object
   *             required:
   *               - image
   *             properties:
   *               image:
   *                 type: string
   *                 format: binary
   *                 description: Fichier image (jpeg, jpg, png, gif, webp, heic) - max 10MB
   *     responses:
   *       200:
   *         description: Photo de profil uploadée avec succès
   *         content:
   *           application/json:
   *             schema:
   *               $ref: '#/components/schemas/UploadResponse'
   *       400:
   *         description: Aucun fichier uploadé ou fichier invalide
   *       401:
   *         description: Non authentifié
   *       403:
   *         description: Accès refusé (organisateur requis)
   *       500:
   *         description: Erreur serveur
   */
  app.post(
    "/api/upload/profile",
    [authJwt.verifyToken, authJwt.isOrganisation],
    (req, res, next) => {
      console.log('========== UPLOAD PROFILE ROUTE HIT ==========');
      console.log('Upload profil route - Headers:', req.headers);
      console.log('Upload profil route - Content-Type:', req.headers['content-type']);
      console.log('Upload profil route - UserId:', req.userId);
      controller.uploadProfileImage(req, res, (err) => {
        if (err) {
          console.error('========== ERREUR MULTER PROFILE ==========');
          console.error('Erreur multer:', err);
          console.error('Erreur type:', err.constructor.name);
          // Gérer les erreurs de multer
          if (err instanceof multer.MulterError) {
            console.error('MulterError code:', err.code);
            if (err.code === 'LIMIT_FILE_SIZE') {
              return res.status(400).json({ message: 'Le fichier est trop volumineux (max 10MB)' });
            }
            if (err.code === 'LIMIT_UNEXPECTED_FILE') {
              return res.status(400).json({ message: 'Champ de fichier inattendu. Le champ doit être nommé "image"' });
            }
            return res.status(400).json({ message: 'Erreur multer: ' + err.message, code: err.code });
          }
          return res.status(400).json({ message: err.message });
        }
        console.log('Multer a traité le fichier avec succès, passage au contrôleur...');
        next();
      });
    },
    controller.uploadProfile
  );
};

