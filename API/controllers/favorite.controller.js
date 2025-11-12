const db = require("../models");
const Favorite = db.favorite;
const Event = db.event;
const User = db.user;

// Récupérer tous les favoris de l'utilisateur connecté
exports.getFavorites = async function(req, res) {
  try {
    const userId = req.userId; // Récupéré depuis le middleware authJwt
    if (!userId) {
      return res.status(401).json({ message: "User ID not found" });
    }
    
    const favorites = await Favorite.findAll({
      where: { user_id: userId }
    });
    
    // Convertir en format simple pour la réponse
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

// Ajouter un événement aux favoris
exports.addFavorite = async function(req, res) {
  try {
    const userId = req.userId;
    const { event_id } = req.body;

    if (!event_id) {
      return res.status(400).json({ message: "event_id is required" });
    }

    // Vérifier si l'événement existe
    const event = await Event.findByPk(event_id);
    if (!event) {
      return res.status(404).json({ message: "Event not found" });
    }

    // Vérifier si le favori existe déjà
    const existingFavorite = await Favorite.findOne({
      where: {
        user_id: userId,
        event_id: event_id
      }
    });

    if (existingFavorite) {
      return res.status(200).json({ message: "Already in favorites", favorite: existingFavorite });
    }

    // Créer le favori
    const favorite = await Favorite.create({
      user_id: userId,
      event_id: event_id
    });

    res.status(201).json({ message: "Favorite added", favorite });
  } catch (e) {
    console.error('Erreur addFavorite:', e);
    // Si c'est une erreur de contrainte unique, c'est que le favori existe déjà
    if (e.name === 'SequelizeUniqueConstraintError' || e.message.includes('UNIQUE constraint')) {
      return res.status(200).json({ message: "Already in favorites" });
    }
    res.status(500).json({ message: e.message, error: e.toString() });
  }
};

// Retirer un événement des favoris
exports.removeFavorite = async function(req, res) {
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

    await favorite.destroy();
    res.status(200).json({ message: "Favorite removed" });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

