const db = require("../models");
const Event = db.event;
const { geocodeAddress } = require("../services/geocoding.service");

exports.list = async function(req, res) {
  try {
    const { page = 1, pageSize = 50, updatedSince } = req.query;
    const where = {};
    // Filtre optionnel pour récupérer uniquement les événements modifiés après une date
    if (updatedSince) {
      where.updated_at = { [db.Sequelize.Op.gte]: new Date(updatedSince) };
    }
    // Limite la taille de page à 200 maximum pour éviter les surcharges
    const limit = Math.min(parseInt(pageSize), 200) || 50;
    const offset = (Math.max(parseInt(page), 1) - 1) * limit;
    const { rows, count } = await Event.findAndCountAll({
      where,
      order: [["updated_at", "DESC"]],
      limit,
      offset
    });
    res.json({ data: rows, total: count, page: parseInt(page), pageSize: limit });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.getById = async function(req, res) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) return res.status(404).json({ message: "Not found" });
    res.json(event);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.create = async function(req, res) {
  try {
    const now = new Date();
    const eventData = {
      ...req.body,
      created_by: req.userId || req.body.created_by,
      created_at: now,
      updated_at: now
    };

    // Log pour vérifier si l'image est bien reçue
    if (eventData.image_url) {
      const isDataUrl = eventData.image_url.startsWith('data:image');
      console.log(`Image reçue: ${isDataUrl ? 'Data URL (base64)' : 'URL réseau'}, longueur: ${eventData.image_url.length}`);
      if (isDataUrl) {
        console.log(`Format: ${eventData.image_url.substring(0, 50)}...`);
      }
    }

    // Géocodage automatique de l'adresse pour obtenir les coordonnées GPS
    // IMPORTANT: On ne fait confiance qu'aux coordonnées issues du géocodage
    // On ignore toute latitude/longitude envoyée par le client
    delete eventData.latitude;
    delete eventData.longitude;
    
    if (eventData.location) {
      console.log(`Géocodage de l'adresse: "${eventData.location}"`);
      const geocodeResult = await geocodeAddress(eventData.location, true);
      if (geocodeResult.success && geocodeResult.coordinates) {
        eventData.latitude = geocodeResult.coordinates.latitude;
        eventData.longitude = geocodeResult.coordinates.longitude;
        console.log(`Coordonnées obtenues: ${geocodeResult.coordinates.latitude}, ${geocodeResult.coordinates.longitude}`);
      } else {
        console.log(`Géocodage échoué pour: "${eventData.location}"`);
        console.log(`   Erreur: ${geocodeResult.error || 'Inconnue'}`);
        // Si le géocodage échoue, retourner une erreur pour forcer l'utilisateur à corriger
        return res.status(400).json({ 
          message: geocodeResult.error || 'Impossible de trouver cette adresse. Veuillez vérifier le format.',
          geocodeError: true,
          addressFormat: 'Format requis: "Numéro Rue, Code Postal Ville" (France sera ajouté automatiquement)'
        });
      }
    } else {
      // Pas d'adresse fournie, pas de coordonnées
      eventData.latitude = null;
      eventData.longitude = null;
    }

    const event = await Event.create(eventData);
    res.status(201).json(event);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
};

exports.update = async function(req, res) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) return res.status(404).json({ message: "Not found" });
    
    const updateData = { ...req.body };
    
    // IMPORTANT: On ne fait confiance qu'aux coordonnées issues du géocodage
    // On ignore toute latitude/longitude envoyée par le client
    delete updateData.latitude;
    delete updateData.longitude;
    
    // Re-géocode l'adresse uniquement si elle a changé
    if (updateData.location && updateData.location !== event.location) {
      console.log(`Re-géocodage de l'adresse: "${updateData.location}"`);
      const geocodeResult = await geocodeAddress(updateData.location, true);
      
      if (geocodeResult.success && geocodeResult.coordinates) {
        updateData.latitude = geocodeResult.coordinates.latitude;
        updateData.longitude = geocodeResult.coordinates.longitude;
        console.log(`Coordonnées obtenues: ${geocodeResult.coordinates.latitude}, ${geocodeResult.coordinates.longitude}`);
      } else {
        // Si le géocodage échoue, retourner une erreur pour forcer l'utilisateur à corriger
        console.log(`Géocodage échoué pour: "${updateData.location}"`);
        console.log(`   Erreur: ${geocodeResult.error || 'Inconnue'}`);
        return res.status(400).json({ 
          message: geocodeResult.error || 'Impossible de trouver cette adresse. Veuillez vérifier le format.',
          geocodeError: true,
          addressFormat: 'Format requis: "Numéro Rue, Code Postal Ville" (France sera ajouté automatiquement)'
        });
      }
    } else if (updateData.location && updateData.location === event.location) {
      // L'adresse n'a pas changé, garder les coordonnées existantes
      // Ne rien faire, les coordonnées existantes seront conservées
    } else if (!updateData.location) {
      // Pas d'adresse fournie, supprimer les coordonnées
      updateData.latitude = null;
      updateData.longitude = null;
    }
    
    await event.update(updateData);
    res.json(event);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
};

exports.remove = async function(req, res) {
  try {
    const event = await Event.findByPk(req.params.id);
    if (!event) return res.status(404).json({ message: "Not found" });
    await event.destroy();
    res.status(204).send();
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};


