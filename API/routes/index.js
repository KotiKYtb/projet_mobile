var express = require('express');
var router = express.Router();

/* GET home route returns JSON instead of rendering a view */
router.get('/', function(req, res, next) {
  res.json({ message: "Bienvenu à l'application JWT AUTH EXPRESS MYSQL." });
});

/* GET server info - returns the server IP and port for automatic discovery */
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
