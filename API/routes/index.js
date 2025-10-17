var express = require('express');
var router = express.Router();

/* GET home route returns JSON instead of rendering a view */
router.get('/', function(req, res, next) {
  res.json({ message: "Bienvenu à l'application JWT AUTH EXPRESS MYSQL." });
});

module.exports = router;
