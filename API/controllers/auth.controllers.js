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
  // Hashage du mot de passe avec bcrypt (8 rounds de salage)
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
      // Vérification du mot de passe avec bcrypt
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
      // Génération d'un token d'accès valide 24h (86400 secondes)
      var accessToken = jwt.sign({ id: user.user_id, email: user.email }, config.secret, {
        expiresIn: 86400
      });
      console.log("=== ACCESS TOKEN ===");
      console.log(accessToken);
      // Décoder le token pour afficher son contenu
      const decodedToken = jwt.decode(accessToken);
      console.log("=== CONTENU DU TOKEN (DECODE) ===");
      console.log(JSON.stringify(decodedToken, null, 2));

      // Génération d'un refresh token valide 7 jours (604800 secondes)
      var refreshToken = jwt.sign({ id: user.user_id, type: 'refresh' }, config.secret, {
        expiresIn: 604800
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

// Permet de renouveler un access token expiré en utilisant un refresh token valide
exports.refreshToken = (req, res) => {
  const { refreshToken } = req.body;
  
  if (!refreshToken) {
    return res.status(401).send({ message: "Refresh token requis" });
  }

  try {
    const decoded = jwt.verify(refreshToken, config.secret);
    
    // Vérifie que le token est bien un refresh token et non un access token
    if (decoded.type !== 'refresh') {
      return res.status(401).send({ message: "Token invalide" });
    }

    // Génère un nouvel access token avec les informations de l'utilisateur
    const newAccessToken = jwt.sign(
      { id: decoded.id, email: decoded.email }, 
      config.secret, 
      { expiresIn: 86400 }
    );

    res.status(200).send({
      accessToken: newAccessToken
    });
  } catch (err) {
    res.status(401).send({ message: "Refresh token invalide ou expiré" });
  }
};


