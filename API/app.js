// Charger les variables d'environnement depuis .env
// Chercher d'abord dans le dossier API, puis à la racine du projet
const path = require('path');
const fs = require('fs');

// Chemin du .env dans le dossier API
const envPathAPI = path.join(__dirname, '.env');
// Chemin du .env à la racine du projet (un niveau au-dessus)
const envPathRoot = path.join(__dirname, '..', '.env');

// Charger le .env qui existe
if (fs.existsSync(envPathAPI)) {
  require('dotenv').config({ path: envPathAPI });
  console.log('Fichier .env chargé depuis: API/.env');
} else if (fs.existsSync(envPathRoot)) {
  require('dotenv').config({ path: envPathRoot });
  console.log('Fichier .env chargé depuis: .env (racine)');
} else {
  require('dotenv').config();
  console.log('Aucun fichier .env trouvé, utilisation des variables d\'environnement système');
}

var express = require('express');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var createError = require('http-errors');
var cors = require('cors');
var swaggerUi = require('swagger-ui-express');
var swaggerSpec = require('./config/swagger.config');

var indexRouter = require('./routes/index');
var usersRouter = require('./routes/users');

var app = express();

// Configuration CORS pour autoriser les requêtes depuis n'importe quelle origine
// avec support des credentials (cookies, headers d'authentification)
var corsOptions = {
  origin: true,
  credentials: true
};

app.use(cors(corsOptions));
app.use(logger('dev'));
// Augmenter la limite de taille pour permettre l'envoi d'images en base64 (50MB)
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: false, limit: '50mb' }));
app.use(cookieParser());

// Fonction pour obtenir la spec Swagger dynamique
function getSwaggerSpecForUI(req) {
  try {
    const getSwaggerSpec = require('./config/swagger.config').getSwaggerSpec;
    const dynamicSpec = getSwaggerSpec ? getSwaggerSpec(req) : require('./config/swagger.config');
    
    // S'assurer que la spec a bien le champ openapi avec la bonne version
    if (!dynamicSpec.openapi && !dynamicSpec.swagger) {
      dynamicSpec.openapi = '3.0.0';
    }
    
    // S'assurer que la version est au format correct (3.0.0, pas juste 3.0)
    if (dynamicSpec.openapi && typeof dynamicSpec.openapi === 'string') {
      const version = dynamicSpec.openapi;
      if (!version.match(/^3\.\d+\.\d+$/)) {
        dynamicSpec.openapi = '3.0.0';
      }
    }
    
    return dynamicSpec;
  } catch (error) {
    console.error('Erreur lors de la génération de la spec Swagger:', error);
    return {
      openapi: '3.0.0',
      info: {
        title: 'Angers Mobile App API',
        version: '1.0.0',
        description: 'Documentation de l\'API'
      },
      paths: {}
    };
  }
}

// Endpoint pour servir la spec Swagger dynamique
app.get('/api-docs/swagger.json', (req, res) => {
  try {
    const dynamicSpec = getSwaggerSpecForUI(req);
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.json(dynamicSpec);
  } catch (error) {
    console.error('Erreur lors de la génération de la spec Swagger:', error);
    res.status(500).json({ 
      error: 'Erreur lors de la génération de la documentation',
      message: error.message 
    });
  }
});

// Configuration Swagger dynamique qui utilise l'URL de la requête
app.use('/api-docs', swaggerUi.serve, (req, res, next) => {
  const swaggerSpec = getSwaggerSpecForUI(req);
  swaggerUi.setup(swaggerSpec, {
    swaggerOptions: {
      persistAuthorization: true,
      validatorUrl: null, // Désactiver la validation pour éviter les erreurs
      supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
      displayRequestDuration: true
    },
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'Angers Mobile App API Documentation'
  })(req, res, next);
});

app.use('/', indexRouter);
app.use('/users', usersRouter);
app.use('/api/users', usersRouter);

app.get('/', function(req, res) {
  res.json({ message: "Bienvenu à l'application JWT AUTH EXPRESS MYSQL." });
});

app.use(express.static(path.join(__dirname, 'public')));

const db = require("./models");

// Force la recréation complète de la base de données si RESET_DB=1
const shouldForceSync = process.env.RESET_DB === '1';
const isSQLite = db.sequelize.getDialect() === 'sqlite';

// SQLite ne peut pas modifier des tables avec des contraintes de clés étrangères
const syncOptions = shouldForceSync 
  ? { force: true } 
  : (isSQLite ? {} : { alter: true });

// Pour SQLite, forcer le mode DELETE AVANT toute opération pour éviter la création de fichiers .shm et .wal
const initDatabase = async () => {
  if (isSQLite) {
    try {
      await db.sequelize.query(`PRAGMA journal_mode = DELETE;`);
      console.log('SQLite configuré en mode DELETE (pas de fichiers .shm/.wal)');
    } catch (error) {
      console.warn('Erreur lors de la configuration du mode DELETE:', error.message);
    }
  }
  
  return db.sequelize.sync(syncOptions);
};

// Fonction pour extraire le chemin relatif d'une URL complète
function extractImagePath(imageUrl) {
  if (!imageUrl) return null;
  
  // Si c'est déjà un chemin relatif (commence par /), le retourner tel quel
  if (imageUrl.startsWith('/')) {
    return imageUrl;
  }
  
  // Si c'est une URL complète, extraire le chemin
  try {
    const url = new URL(imageUrl);
    return url.pathname;
  } catch (e) {
    // Si ce n'est pas une URL valide, essayer d'extraire manuellement
    const imagesIndex = imageUrl.indexOf('/images/');
    if (imagesIndex !== -1) {
      return imageUrl.substring(imagesIndex);
    }
    return null;
  }
}

// Fonction de migration pour convertir les anciennes URLs en chemins relatifs
async function migrateProfilePictures() {
  try {
    console.log('Début de la migration des profile_picture...');
    const users = await db.user.findAll({
      attributes: ['user_id', 'profile_picture'],
      where: {
        profile_picture: { [db.Sequelize.Op.ne]: null }
      }
    });
    
    let migratedCount = 0;
    for (const user of users) {
      if (user.profile_picture && (user.profile_picture.startsWith('http://') || user.profile_picture.startsWith('https://'))) {
        const extractedPath = extractImagePath(user.profile_picture);
        if (extractedPath) {
          await user.update({ profile_picture: extractedPath });
          console.log(`  Utilisateur ${user.user_id}: ${user.profile_picture} -> ${extractedPath}`);
          migratedCount++;
        }
      }
    }
    
    if (migratedCount > 0) {
      console.log(`Migration terminée: ${migratedCount} profile_picture convertis en chemins relatifs`);
    } else {
      console.log('Aucune migration nécessaire: tous les profile_picture sont déjà en chemins relatifs');
    }
  } catch (error) {
    console.error('Erreur lors de la migration des profile_picture:', error.message);
  }
}

initDatabase()
  .then(async function() {
    if (shouldForceSync) {
      console.log('Database recreated with { force: true }');
    } else {
      console.log(`Database synced${isSQLite ? ' (SQLite - no alter)' : ' (with alter)'}`);
    }
    
    // Pour SQLite, vérifier et ajouter la colonne profile_picture si elle n'existe pas
    if (isSQLite) {
      try {
        const [columns] = await db.sequelize.query(`PRAGMA table_info(users)`);
        const hasProfilePicture = columns.some(col => col.name === 'profile_picture');
        
        if (!hasProfilePicture) {
          console.log('Ajout de la colonne profile_picture à la table users...');
          await db.sequelize.query(`ALTER TABLE users ADD COLUMN profile_picture TEXT`);
          console.log('Colonne profile_picture ajoutée avec succès !');
        }
      } catch (error) {
        // Ignorer l'erreur si la colonne existe déjà ou si la table n'existe pas encore
        if (!error.message.includes('duplicate column') && !error.message.includes('no such table')) {
          console.warn('Erreur lors de la vérification/ajout de profile_picture:', error.message);
        }
      }
    }
    
    // Migration des profile_picture : convertir les anciennes URLs en chemins relatifs
    await migrateProfilePictures();
  })
  .catch(function(e) {
    console.error('Database sync failed:', e.message);
    console.error('Full error:', e);
    
    // Gestion spécifique des erreurs de validation SQLite
    if (e.message && (e.message.includes('Validation error') || e.message.includes('FOREIGN KEY'))) {
      console.warn('SQLite constraint error detected.');
      console.warn('Solution: Supprimez data.sqlite et redémarrez, ou utilisez RESET_DB=1 npm start');
      console.warn('L\'API continue de démarrer, mais certaines fonctionnalités peuvent ne pas fonctionner.');
    }
  });


require('./routes/auth.routes')(app);
require('./routes/event.routes')(app);
require('./routes/favorite.routes')(app);
require('./routes/notification.routes')(app);
require('./routes/upload.routes')(app);



app.use(function(req, res, next) {
  next(createError(404));
});

app.use(function(err, req, res, next) {
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};
  res.status(err.status || 500);
  res.json({ error: res.locals.message });
});

module.exports = app;
