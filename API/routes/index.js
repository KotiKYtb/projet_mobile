var express = require('express');
var router = express.Router();

/**
 * @swagger
 * /:
 *   get:
 *     summary: Message de bienvenue de l'API
 *     tags: [General]
 *     responses:
 *       200:
 *         description: Message de bienvenue
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: "Bienvenu à l'application JWT AUTH EXPRESS MYSQL."
 */
router.get('/', function(req, res, next) {
  res.json({ message: "Bienvenu à l'application JWT AUTH EXPRESS MYSQL." });
});

/**
 * @swagger
 * /api/server-info:
 *   get:
 *     summary: Informations du serveur pour la découverte automatique
 *     tags: [General]
 *     responses:
 *       200:
 *         description: Informations du serveur
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 ip:
 *                   type: string
 *                   description: Adresse IP du serveur
 *                   example: 192.168.1.100
 *                 port:
 *                   type: integer
 *                   description: Port du serveur
 *                   example: 8080
 *                 baseUrl:
 *                   type: string
 *                   description: "URL de base de l'API"
 *                   example: http://192.168.1.100:8080
 *                 allIPs:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       name:
 *                         type: string
 *                       ip:
 *                         type: string
 *                   description: Liste de toutes les adresses IP disponibles
 *                 message:
 *                   type: string
 *                   example: Server information for automatic discovery
 */
router.get('/api/server-info', function(req, res, next) {
  var app = req.app;
  var serverIP = app.get('serverIP') || 'localhost';
  var serverPort = app.get('serverPort') || 8080;
  var allIPs = app.get('allIPs') || [];
  
  res.json({
    ip: serverIP,
    port: serverPort,
    baseUrl: `http://${serverIP}:${serverPort}`,
    allIPs: allIPs,
    message: 'Server information for automatic discovery'
  });
});

module.exports = router;
