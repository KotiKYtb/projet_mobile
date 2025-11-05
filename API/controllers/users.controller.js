const db = require("../models");

exports.list = async function(req, res) {
  try {
    const users = await db.user.findAll({
      attributes: [
        'user_id', 'email', 'password', 
        'name', 'surname', 'role', 'created_at', 'updated_at'
      ]
    });
    res.json(users);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};

exports.updateRole = async function(req, res) {
  try {
    const { userId } = req.params;
    const { role } = req.body;
    
    // Vérifier que le rôle est valide
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
    const userId = req.userId; // Récupéré depuis le middleware authJwt
    const user = await db.user.findByPk(userId, {
      attributes: ['user_id', 'email', 'name', 'surname', 'role', 'created_at', 'updated_at']
    });
    
    if (!user) {
      return res.status(404).json({ message: 'Utilisateur non trouvé' });
    }
    
    res.json(user);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
};


