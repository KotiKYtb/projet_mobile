const config = require("../config/db.config.js");
const Sequelize = require("sequelize");
const path = require("path");

// Configuration de la connexion à la base de données
// Utilise MySQL si USE_MYSQL=1, sinon utilise SQLite par défaut
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
  // SQLite par défaut pour le développement (fichier data.sqlite)
  // Mode DELETE au lieu de WAL pour éviter les fichiers .shm et .wal
  sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: 'data.sqlite',
    logging: false,
    define: { underscored: true },
    pool: {
      max: 5,
      min: 0,
      acquire: 30000, // Temps max pour acquérir une connexion (30s)
      idle: 10000     // Temps avant de libérer une connexion inutilisée (10s)
    },
    dialectOptions: {
      // Options pour gérer les verrous SQLite
      timeout: 60000, // 60 secondes de timeout pour les opérations
    }
  });
  
  // Configurer SQLite avec mode DELETE (pas de fichiers .shm et .wal)
  // Forcer le mode DELETE sur chaque nouvelle connexion
  sequelize.afterConnect(async (connection) => {
    try {
      // Forcer le mode DELETE immédiatement
      await connection.exec('PRAGMA journal_mode = DELETE;');
      await connection.exec('PRAGMA busy_timeout = 60000;');
      await connection.exec('PRAGMA synchronous = NORMAL;');
    } catch (error) {
      console.warn('Erreur lors de la configuration SQLite:', error.message);
    }
  });
  
  // Aussi forcer le mode DELETE lors de l'ouverture initiale
  sequelize.authenticate()
    .then(() => {
      return sequelize.query('PRAGMA journal_mode = DELETE;');
    })
    .then(() => {
      console.log('Mode DELETE forcé sur la connexion SQLite initiale');
    })
    .catch((err) => {
      // Ignorer les erreurs d'authentification si la base n'existe pas encore
      if (!err.message.includes('no such table')) {
        console.warn('Erreur lors de la configuration initiale SQLite:', err.message);
      }
    });
}

const db = {};
db.Sequelize = Sequelize;
db.sequelize = sequelize;

db.user = require("./users.model.js")(sequelize, Sequelize);
db.event = require("./events.model.js")(sequelize, Sequelize);
db.favorite = require("./favorites.model.js")(sequelize, Sequelize);
db.fcmToken = require("./fcm_tokens.model.js")(sequelize, Sequelize);
db.notification = require("./notifications.model.js")(sequelize, Sequelize);
db.userNotification = require("./user_notifications.model.js")(sequelize, Sequelize);


// Relations many-to-many entre User et Event via la table Favorite
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
// Relations belongsTo et hasMany pour les favoris
db.favorite.belongsTo(db.user, { foreignKey: "user_id" });
db.favorite.belongsTo(db.event, { foreignKey: "event_id" });
db.user.hasMany(db.favorite, { foreignKey: "user_id" });
db.event.hasMany(db.favorite, { foreignKey: "event_id" });

// Relation entre Event et User pour le créateur de l'événement
db.event.belongsTo(db.user, { 
  foreignKey: "created_by",
  as: "creator"
});
db.user.hasMany(db.event, { 
  foreignKey: "created_by",
  as: "createdEvents"
});

// Relation entre User et FCMToken
db.user.hasMany(db.fcmToken, { 
  foreignKey: "user_id",
  as: "fcmTokens"
});
db.fcmToken.belongsTo(db.user, { 
  foreignKey: "user_id",
  as: "user"
});

// Relation entre User et Notification
db.user.hasMany(db.notification, { 
  foreignKey: "created_by",
  as: "createdNotifications"
});
db.notification.belongsTo(db.user, { 
  foreignKey: "created_by",
  as: "creator"
});

// Relation entre User et UserNotification (notifications reçues)
db.user.hasMany(db.userNotification, { 
  foreignKey: "user_id",
  as: "receivedNotifications"
});
db.userNotification.belongsTo(db.user, { 
  foreignKey: "user_id",
  as: "user"
});

// Relation entre Notification et UserNotification
db.notification.hasMany(db.userNotification, { 
  foreignKey: "notification_id",
  as: "userNotifications"
});
db.userNotification.belongsTo(db.notification, { 
  foreignKey: "notification_id",
  as: "notification"
});

// Relation entre Event et UserNotification
db.event.hasMany(db.userNotification, { 
  foreignKey: "event_id",
  as: "userNotifications"
});
db.userNotification.belongsTo(db.event, { 
  foreignKey: "event_id",
  as: "event"
});

db.ROLES = ["user", "admin", "organisation"];

module.exports = db;