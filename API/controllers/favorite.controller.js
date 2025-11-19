const db = require("../models");
const Sequelize = db.Sequelize;
const Favorite = db.favorite;
const Event = db.event;
const User = db.user;

exports.getFavorites = async function(req, res) {
  try {
    const userId = req.userId;
    if (!userId) {
      return res.status(401).json({ message: "User ID not found" });
    }
    
    const favorites = await Favorite.findAll({
      where: { user_id: userId }
    });
    
    const favoritesList = favorites.map(fav => ({
      user_id: fav.user_id || fav.dataValues.user_id,
      event_id: fav.event_id || fav.dataValues.event_id,
      created_at: fav.created_at || fav.dataValues.created_at,
      updated_at: fav.updated_at || fav.dataValues.updated_at
    }));
    
    res.json({ favorites: favoritesList });
  } catch (e) {
    console.error('Erreur getFavorites:', e);
    res.status(500).json({ message: e.message, error: e.toString() });
  }
};

exports.addFavorite = async function(req, res) {
  const maxRetries = 5;
  let retryCount = 0;
  
  while (retryCount < maxRetries) {
    try {
      const userId = req.userId;
      const { event_id } = req.body;

      if (!event_id) {
        return res.status(400).json({ message: "event_id is required" });
      }

      // Vérifier l'événement sans transaction pour éviter les verrous
      const event = await Event.findByPk(event_id);
      if (!event) {
        return res.status(404).json({ message: "Event not found" });
      }

      // Vérifie si le favori existe déjà pour éviter les doublons (sans transaction)
      const existingFavorite = await Favorite.findOne({
        where: {
          user_id: userId,
          event_id: event_id
        }
      });

      if (existingFavorite) {
        return res.status(200).json({ message: "Already in favorites", favorite: existingFavorite });
      }

      // Créer le favori sans transaction pour éviter les verrous
      // SQLite avec WAL mode gère mieux les INSERT sans transaction
      const favorite = await Favorite.create({
        user_id: userId,
        event_id: event_id
      });

      return res.status(201).json({ message: "Favorite added", favorite });
    } catch (e) {
      // Gère les erreurs de verrouillage SQLite avec retry
      if (e.message && (e.message.includes('SQLITE_BUSY') || e.message.includes('database is locked') || e.name === 'SequelizeTimeoutError')) {
        retryCount++;
        if (retryCount < maxRetries) {
          const delay = Math.min(200 * retryCount, 1000); // Délai progressif max 1s
          console.log(`Database locked, retry ${retryCount}/${maxRetries} (attente ${delay}ms)...`);
          await new Promise(resolve => setTimeout(resolve, delay));
          continue; // Réessayer
        } else {
          console.error('Erreur addFavorite après retries:', e);
          return res.status(500).json({ 
            message: "Database busy, please try again later", 
            error: "SQLITE_BUSY: database is locked" 
          });
        }
      }
      
      console.error('Erreur addFavorite:', e);
      
      // Gère les erreurs de contrainte unique (doublon) de manière gracieuse
      if (e.name === 'SequelizeUniqueConstraintError' || e.message.includes('UNIQUE constraint')) {
        return res.status(200).json({ message: "Already in favorites" });
      }
      
      return res.status(500).json({ message: e.message, error: e.toString() });
    }
  }
};

exports.removeFavorite = async function(req, res) {
  const maxRetries = 5;
  let retryCount = 0;
  
  while (retryCount < maxRetries) {
    try {
      const userId = req.userId;
      const eventId = req.params.eventId;

      const favorite = await Favorite.findOne({
        where: {
          user_id: userId,
          event_id: eventId
        }
      });

      if (!favorite) {
        return res.status(404).json({ message: "Favorite not found" });
      }

      // Supprimer sans transaction pour éviter les verrous
      await favorite.destroy();
      return res.status(200).json({ message: "Favorite removed" });
    } catch (e) {
      // Gère les erreurs de verrouillage SQLite avec retry
      if (e.message && (e.message.includes('SQLITE_BUSY') || e.message.includes('database is locked') || e.name === 'SequelizeTimeoutError')) {
        retryCount++;
        if (retryCount < maxRetries) {
          const delay = Math.min(200 * retryCount, 1000); // Délai progressif max 1s
          console.log(`Database locked, retry ${retryCount}/${maxRetries} (attente ${delay}ms)...`);
          await new Promise(resolve => setTimeout(resolve, delay));
          continue; // Réessayer
        } else {
          console.error('Erreur removeFavorite après retries:', e);
          return res.status(500).json({ 
            message: "Database busy, please try again later", 
            error: "SQLITE_BUSY: database is locked" 
          });
        }
      }
      
      console.error('Erreur removeFavorite:', e);
      return res.status(500).json({ message: e.message, error: e.toString() });
    }
  }
};

