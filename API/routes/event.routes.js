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

  // Public: list and get
  app.get("/api/events", controller.list);
  app.get("/api/events/:id", controller.getById);

  // Admin only: create/update/delete
  app.post("/api/events", [authJwt.verifyToken, authJwt.isAdmin], controller.create);
  app.put("/api/events/:id", [authJwt.verifyToken, authJwt.isAdmin], controller.update);
  app.delete("/api/events/:id", [authJwt.verifyToken, authJwt.isAdmin], controller.remove);
};


