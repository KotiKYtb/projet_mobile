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
      define: { underscored: true },
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
    logging: false,
    define: { underscored: true }
  });
}

// constante BDD
const db = {};
db.Sequelize = Sequelize;
db.sequelize = sequelize;

// model and table
db.user = require("./users.model.js")(sequelize, Sequelize);
db.event = require("./events.model.js")(sequelize, Sequelize);
db.favorite = require("./favorites.model.js")(sequelize, Sequelize);
db.alert = require("./alerts.model.js")(sequelize, Sequelize);


// relation Many to Many between Users and Events through Favorites
db.user.belongsToMany(db.event, {
  through: db.favorite,
  foreignKey: "user_id",
  otherKey: "event_id",
  as: "favoriteEvents"
});
db.event.belongsToMany(db.user, {
  through: db.favorite,
  foreignKey: "event_id",
  otherKey: "user_id",
  as: "usersWhoFavorited"
});
// helpful direct relations for joins
db.favorite.belongsTo(db.user, { foreignKey: "user_id" });
db.favorite.belongsTo(db.event, { foreignKey: "event_id" });
db.user.hasMany(db.favorite, { foreignKey: "user_id" });
db.event.hasMany(db.favorite, { foreignKey: "event_id" });

// Relation pour created_by dans events
db.event.belongsTo(db.user, { 
  foreignKey: "created_by",
  as: "creator"
});
db.user.hasMany(db.event, { 
  foreignKey: "created_by",
  as: "createdEvents"
});

db.ROLES = ["user", "admin", "organisation"];

module.exports = db;