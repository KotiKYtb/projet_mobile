const db = require("../models");
const ROLES = db.ROLES;
const User = db.user;

// Vérifie que l'email n'est pas déjà utilisé lors de l'inscription
checkDuplicateUsernameOrEmail = (req, res, next) => {
  User.findOne({
    where: {
      email: req.body.email
    }
  }).then(user => {
    if (user) {
      res.status(400).send({
        message: "Erreur! l'email utilisateur est déja existante!"
      });
      return;
    }
    next();
  });
};

// Valide que les rôles demandés lors de l'inscription existent dans la liste autorisée
checkRolesExisted = (req, res, next) => {
  if (req.body.roles) {
    for (let i = 0; i < req.body.roles.length; i++) {
      if (!ROLES.includes(req.body.roles[i])) {
        res.status(400).send({
          message: "Erreur! le role n'existe pas = " + req.body.roles[i]
        });
        return;
      }
    }
  }
  next();
};

const verifySignUp = {
  checkDuplicateUsernameOrEmail: checkDuplicateUsernameOrEmail,
  checkRolesExisted: checkRolesExisted
};

module.exports = verifySignUp;


