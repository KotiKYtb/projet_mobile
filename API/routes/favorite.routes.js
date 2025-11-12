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

  // Toutes les routes nécessitent une authentification
  app.get("/api/favorites", [authJwt.verifyToken], controller.getFavorites);
  app.post("/api/favorites", [authJwt.verifyToken], controller.addFavorite);
  app.delete("/api/favorites/:eventId", [authJwt.verifyToken], controller.removeFavorite);
};

