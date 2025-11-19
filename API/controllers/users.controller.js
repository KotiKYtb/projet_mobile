const db = require("../models");
const bcrypt = require("bcryptjs");

// Fonction helper pour extraire le chemin relatif d'une URL complète
function extractImagePath(imageUrl) {
  if (!imageUrl) return null;
  
  // Si c'est déjà un chemin relatif (commence par /), le retourner tel quel
  if (imageUrl.startsWith('/')) {
    return imageUrl;
  }
  
  // Si c'est une URL complète, extraire le chemin
  try {
    const url = new URL(imageUrl);
    // Retourner le pathname (ex: /images/profiles/profile-123.jpg)
    const pathname = url.pathname;
    console.log('Extraction chemin relatif depuis URL:', imageUrl, '->', pathname);
    return pathname;
  } catch (e) {
    // Si ce n'est pas une URL valide, essayer d'extraire manuellement
    // Chercher le pattern /images/ dans l'URL
    const imagesIndex = imageUrl.indexOf('/images/');
    if (imagesIndex !== -1) {
      const path = imageUrl.substring(imagesIndex);
      console.log('Extraction manuelle du chemin:', imageUrl, '->', path);
      return path;
    }
    // Si on ne trouve pas /images/, retourner null pour éviter de stocker une URL invalide
    console.warn('Impossible d\'extraire le chemin relatif de:', imageUrl);
    return null;
  }
}

// Fonction helper pour construire l'URL complète à partir d'un chemin relatif
function buildImageUrl(imagePath, req) {
  if (!imagePath) return null;
  
  // Si c'est déjà une URL complète, vérifier si c'est une ancienne URL à convertir
  if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
    // Extraire le chemin relatif de l'ancienne URL
    const extractedPath = extractImagePath(imagePath);
    if (extractedPath) {
      console.log('Ancienne URL détectée, conversion en chemin relatif:', imagePath, '->', extractedPath);
      // Reconstruire l'URL avec l'IP actuelle
      imagePath = extractedPath;
    } else {
      // Si on ne peut pas extraire, retourner null pour éviter les erreurs
      console.warn('Impossible de convertir l\'ancienne URL:', imagePath);
      return null;
    }
  }
  
  // Si c'est un chemin relatif, construire l'URL complète
  // PRIORITÉ : utiliser req pour construire l'URL dynamiquement (toujours à jour avec l'URL actuelle)
  if (req) {
    const protocol = req.protocol || 'http';
    const host = req.get('host') || `localhost:${process.env.PORT || 8080}`;
    return `${protocol}://${host}${imagePath.startsWith('/') ? '' : '/'}${imagePath}`;
  }
  
  // Fallback : utiliser API_IP depuis .env si disponible
  if (process.env.API_IP) {
    const apiIp = process.env.API_IP;
    const port = process.env.PORT || 8080;
    // Si API_IP contient déjà http:// ou https://, l'utiliser tel quel
    if (apiIp.startsWith('http://') || apiIp.startsWith('https://')) {
      return `${apiIp}${imagePath.startsWith('/') ? '' : '/'}${imagePath}`;
    }
    // Sinon, construire l'URL avec http://
    return `http://${apiIp}:${port}${imagePath.startsWith('/') ? '' : '/'}${imagePath}`;
  }
  
  // Dernier fallback
  return `http://localhost:${process.env.PORT || 8080}${imagePath.startsWith('/') ? '' : '/'}${imagePath}`;
}

// Fonction helper pour formater un utilisateur avec URL complète
function formatUserWithFullUrl(user, req) {
  if (!user) return user;
  
  const userData = user.toJSON ? user.toJSON() : user;
  if (userData.profile_picture) {
    // Construire l'URL complète avec l'IP actuelle (les anciennes URLs ont déjà été migrées au démarrage)
    userData.profile_picture = buildImageUrl(userData.profile_picture, req);
  }
  return userData;
}

exports.list = async function(req, res) {
  try {
    const users = await db.user.findAll({
      attributes: [
        'user_id', 'email', 'password', 
        'name', 'surname', 'role', 'profile_picture', 'created_at', 'updated_at'
      ]
    });
    // Formater les utilisateurs avec URL complète pour profile_picture
    const formattedUsers = users.map(user => formatUserWithFullUrl(user, req));
    res.json(formattedUsers);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.updateRole = async function(req, res) {
  try {
    const { userId } = req.params;
    const { role } = req.body;
    
    // Validation des rôles autorisés
    const validRoles = ['user', 'admin', 'organisation'];
    if (!validRoles.includes(role)) {
      return res.status(400).json({ message: 'Rôle invalide' });
    }
    
    const user = await db.user.findByPk(userId);
    if (!user) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    await user.update({ role: role });
    res.json({ message: 'Rôle mis à jour avec succès', user: user });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.getCurrentUser = async function(req, res) {
  try {
    const userId = req.userId;
    const user = await db.user.findByPk(userId, {
      attributes: ['user_id', 'email', 'name', 'surname', 'role', 'profile_picture', 'created_at', 'updated_at']
    });
    
    if (!user) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    // Formater l'utilisateur avec URL complète pour profile_picture
    const formattedUser = formatUserWithFullUrl(user, req);
    res.json(formattedUser);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.updateProfile = async function(req, res) {
  try {
    const userId = req.userId;
    const { profile_picture } = req.body;
    
    const user = await db.user.findByPk(userId);
    if (!user) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    // Mettre à jour uniquement le champ profile_picture si fourni
    const updateData = {};
    if (profile_picture !== undefined && profile_picture !== null && profile_picture !== '') {
      // Extraire seulement le chemin relatif (sans l'URL/IP)
      const extractedPath = extractImagePath(profile_picture);
      if (extractedPath) {
        updateData.profile_picture = extractedPath;
        console.log('Mise à jour profile_picture - URL reçue:', profile_picture);
        console.log('Mise à jour profile_picture - chemin relatif stocké:', updateData.profile_picture);
      } else {
        console.warn('Impossible d\'extraire le chemin relatif, profile_picture non mis à jour');
        return res.status(400).json({ message: 'Format d\'URL d\'image invalide' });
      }
    }
    
    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ message: 'Aucune donnée à mettre à jour' });
    }
    
    await user.update(updateData);
    
    // Récupérer l'utilisateur mis à jour
    const updatedUser = await db.user.findByPk(userId, {
      attributes: ['user_id', 'email', 'name', 'surname', 'role', 'profile_picture', 'created_at', 'updated_at']
    });
    
    // Formater l'utilisateur avec URL complète pour profile_picture
    const formattedUser = formatUserWithFullUrl(updatedUser, req);
    res.json({ message: 'Profil mis à jour avec succès', user: formattedUser });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.changePassword = async function(req, res) {
  try {
    const userId = req.userId;
    const { oldPassword, newPassword } = req.body;
    
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ message: 'Ancien mot de passe et nouveau mot de passe requis' });
    }
    
    // Validation de la longueur minimale du mot de passe
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Le nouveau mot de passe doit contenir au moins 6 caractères' });
    }
    
    const user = await db.user.findByPk(userId);
    if (!user) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    // Vérification que l'ancien mot de passe est correct
    const passwordIsValid = bcrypt.compareSync(oldPassword, user.password);
    if (!passwordIsValid) {
      return res.status(401).json({ message: 'Ancien mot de passe incorrect' });
    }
    
    // Empêche l'utilisateur de réutiliser le même mot de passe
    if (oldPassword === newPassword) {
      return res.status(400).json({ message: 'Le nouveau mot de passe doit être différent de l\'ancien' });
    }
    
    // Hashage du nouveau mot de passe avant stockage
    const hashedPassword = bcrypt.hashSync(newPassword, 8);
    
    await user.update({ 
      password: hashedPassword,
      updated_at: new Date()
    });
    
    res.json({ message: 'Mot de passe modifié avec succès' });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};


