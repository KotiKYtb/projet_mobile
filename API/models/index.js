const config = require("../config/db.config.js");
const Sequelize = require("sequelize");

// configuration database
// Default to SQLite (no setup). Use MySQL only if USE_MYSQL=1
let sequelize;
if (process.env.USE_MYSQL === '1') {
  sequelize = new Sequelize(
    config.DB,
    config.USER,
    config.PASSWORD,
    {
      host: config.HOST,
      dialect: config.dialect,
      operatorsAliases: false,
      pool: {
        max: config.pool.max,
        min: config.pool.min,
        acquire: config.pool.acquire,
        idle: config.pool.idle
      }
    }
  );
} else {
  sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: 'data.sqlite',
    logging: false
  });
}

// constante BDD
const db = {};
db.Sequelize = Sequelize;
db.sequelize = sequelize;

// model and table
db.user = require("./users.model.js")(sequelize, Sequelize);
db.role = require("../models/role.model.js")(sequelize, Sequelize);
db.event = require("./events.model.js")(sequelize, Sequelize);
db.favorite = require("./favorites.model.js")(sequelize, Sequelize);
db.alert = require("./alerts.model.js")(sequelize, Sequelize);

// relation Many to Many between Role and Users
db.role.belongsToMany(db.user, {
  through: "user_roles",
  foreignKey: "roleId",
  otherKey: "userId"
});
db.user.belongsToMany(db.role, {
  through: "user_roles",
  foreignKey: "userId",
  otherKey: "roleId"
});

db.ROLES = ["user", "admin"];

module.exports = db;