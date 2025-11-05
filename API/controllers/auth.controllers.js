const db = require("../models");
const config = require("../config/auth.config");
const User = db.user;
const Op = db.Sequelize.Op;
var jwt = require("jsonwebtoken");
var bcrypt = require("bcryptjs");

exports.signup = (req, res) => {
  const { email, password, name, surname, role } = req.body || {};
  if (!email || !password) {
    return res.status(400).send({ message: "email et password requis" });
  }
  User.create({
    email: email,
    password: bcrypt.hashSync(password, 8),
    name: name || "",
    surname: surname || "",
    role: role || "user",
    created_at: new Date(),
    updated_at: new Date()
  })
    .then(function() { res.send({ message: "Utilisateur enregistré" }); })
    .catch(function(err) { res.status(500).send({ message: err.message }); });
};

exports.signin = (req, res) => {
  User.findOne({
    where: { email: req.body.email }
  })
    .then(user => {
      if (!user) {
        return res.status(404).send({ message: "Utilisateur non trouvé." });
      }
      var passwordIsValid = bcrypt.compareSync(
        req.body.password,
        user.password
      );
      if (!passwordIsValid) {
        return res.status(401).send({
          accessToken: null,
          message: "Mot de passe incorrect!"
        });
      }
      // Access token (24 heures)
      var accessToken = jwt.sign({ id: user.user_id, email: user.email }, config.secret, {
        expiresIn: 86400 // 24 heures
      });

      // Refresh token (long terme - 7 jours)
      var refreshToken = jwt.sign({ id: user.user_id, type: 'refresh' }, config.secret, {
        expiresIn: 604800 // 7 jours
      });

      res.status(200).send({
        id: user.user_id,
        email: user.email,
        name: user.name,
        surname: user.surname,
        role: user.role,
        accessToken: accessToken,
        refreshToken: refreshToken,
        roles: [user.role]
      });
    })
    .catch(err => {
      res.status(500).send({ message: err.message });
    });
};

exports.refreshToken = (req, res) => {
  const { refreshToken } = req.body;
  
  if (!refreshToken) {
    return res.status(401).send({ message: "Refresh token requis" });
  }

  try {
    // Vérifier le refresh token
    const decoded = jwt.verify(refreshToken, config.secret);
    
    if (decoded.type !== 'refresh') {
      return res.status(401).send({ message: "Token invalide" });
    }

    // Générer un nouveau access token
    const newAccessToken = jwt.sign(
      { id: decoded.id, email: decoded.email }, 
      config.secret, 
      { expiresIn: 86400 } // 24 heures
    );

    res.status(200).send({
      accessToken: newAccessToken
    });
  } catch (err) {
    res.status(401).send({ message: "Refresh token invalide ou expiré" });
  }
};


