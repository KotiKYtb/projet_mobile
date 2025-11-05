const jwt = require("jsonwebtoken");
const config = require("../config/auth.config.js");
const db = require("../models");
const User = db.user;

verifyToken = (req, res, next) => {
  let token = req.headers["x-access-token"];
  if (!token) {
    return res.status(403).send({ message: "No token provided!" });
  }
  jwt.verify(token, config.secret, (err, decoded) => {
    if (err) {
      return res.status(401).send({ message: "Unauthorized!" });
    }
    req.userId = decoded.id;
    next();
  });
};

isAdmin = (req, res, next) => {
  User.findByPk(req.userId).then(user => {
    if (!user) return res.status(401).send({ message: "Unauthorized!" });
    if (user.role === "admin") return next();
    res.status(403).send({ message: "Le role Admin est necessaire!" });
  });
};

isModerator = (req, res, next) => {
  User.findByPk(req.userId).then(user => {
    if (!user) return res.status(401).send({ message: "Unauthorized!" });
    if (user.role === "moderator") return next();
    res.status(403).send({ message: "Le role Moderateur est necessaire!" });
  });
};

isModeratorOrAdmin = (req, res, next) => {
  User.findByPk(req.userId).then(user => {
    if (!user) return res.status(401).send({ message: "Unauthorized!" });
    if (user.role === "moderator" || user.role === "admin") return next();
    res.status(403).send({ message: "Le role Admin ou Moderateur est necessaire!" });
  });
};

const authJwt = {
  verifyToken: verifyToken,
  isAdmin: isAdmin,
  isModerator: isModerator,
  isModeratorOrAdmin: isModeratorOrAdmin
};

module.exports = authJwt;


