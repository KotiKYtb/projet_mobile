const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configuration du stockage des fichiers
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    try {
      const uploadDir = path.join(__dirname, '../public/images/events');
      // Créer le dossier s'il n'existe pas
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
        console.log('Dossier créé:', uploadDir);
      }
      cb(null, uploadDir);
    } catch (error) {
      console.error('Erreur création dossier upload:', error);
      cb(error);
    }
  },
  filename: function (req, file, cb) {
    // Générer un nom de fichier unique avec timestamp
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'event-' + uniqueSuffix + ext);
  }
});

// Filtre pour accepter uniquement les images
const fileFilter = (req, file, cb) => {
  console.log('File filter - originalname:', file.originalname);
  console.log('File filter - mimetype:', file.mimetype);
  console.log('File filter - fieldname:', file.fieldname);
  
  const allowedTypes = /jpeg|jpg|png|gif|webp|heic|heif/;
  const ext = path.extname(file.originalname).toLowerCase().replace('.', '');
  const extname = allowedTypes.test(ext);
  
  // Vérifier le mimetype ou l'extension
  // Accepter si le mimetype commence par 'image/' OU si l'extension est valide
  // (certains appareils envoient application/octet-stream pour les images)
  const mimetype = file.mimetype && (
    file.mimetype.startsWith('image/') || 
    allowedTypes.test(file.mimetype)
  );

  console.log('File filter - extension:', ext);
  console.log('File filter - extname match:', extname);
  console.log('File filter - mimetype match:', mimetype);

  // Accepter si soit l'extension soit le mimetype est valide
  // OU si c'est application/octet-stream avec une extension d'image valide
  if (mimetype || extname || (file.mimetype === 'application/octet-stream' && extname)) {
    console.log('File filter - ACCEPTÉ');
    return cb(null, true);
  } else {
    const errorMsg = `Seules les images sont autorisées (jpeg, jpg, png, gif, webp, heic). Reçu: mimetype=${file.mimetype}, extension=${ext}`;
    console.log('File filter - REJET:', errorMsg);
    cb(new Error(errorMsg));
  }
};

// Configuration du stockage pour les photos de profil
const profileStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    try {
      const uploadDir = path.join(__dirname, '../public/images/profiles');
      // Créer le dossier s'il n'existe pas
      if (!fs.existsSync(uploadDir)) {
        fs.mkdirSync(uploadDir, { recursive: true });
        console.log('Dossier créé:', uploadDir);
      }
      cb(null, uploadDir);
    } catch (error) {
      console.error('Erreur création dossier upload profil:', error);
      cb(error);
    }
  },
  filename: function (req, file, cb) {
    // Générer un nom de fichier unique avec timestamp et userId
    const userId = req.userId || 'unknown';
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, 'profile-' + userId + '-' + uniqueSuffix + ext);
  }
});

// Configuration de multer pour les événements
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB max
  },
  fileFilter: fileFilter
});

// Configuration de multer pour les photos de profil
const uploadProfile = multer({
  storage: profileStorage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB max
  },
  fileFilter: fileFilter
});

// Middleware d'upload
exports.uploadImage = upload.single('image');
exports.uploadProfileImage = uploadProfile.single('image');

// Middleware pour gérer les erreurs de multer
exports.handleMulterError = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ message: 'Le fichier est trop volumineux (max 10MB)' });
    }
    return res.status(400).json({ message: 'Erreur multer: ' + err.message });
  }
  if (err) {
    return res.status(400).json({ message: err.message });
  }
  next();
};

// Contrôleur pour gérer l'upload d'images d'événements
exports.upload = (req, res) => {
  try {
    console.log('Upload image - req.file:', req.file ? 'présent' : 'absent');
    console.log('Upload image - req.body:', req.body);
    
    if (!req.file) {
      return res.status(400).json({ message: 'Aucun fichier uploadé. Assurez-vous que le champ est nommé "image"' });
    }

    // Construire l'URL de l'image
    // L'URL sera accessible via /images/events/filename
    const imageUrl = `/images/events/${req.file.filename}`;
    
    // Pour une URL complète, on peut utiliser req.protocol + '://' + req.get('host')
    const fullUrl = `${req.protocol}://${req.get('host')}${imageUrl}`;

    console.log('Image uploadée avec succès:', fullUrl);

    res.status(200).json({
      message: 'Image uploadée avec succès',
      imageUrl: fullUrl,
      filename: req.file.filename
    });
  } catch (error) {
    console.error('Erreur upload image:', error);
    res.status(500).json({ message: 'Erreur lors de l\'upload de l\'image: ' + error.message });
  }
};

// Contrôleur pour gérer l'upload de photos de profil
exports.uploadProfile = (req, res) => {
  try {
    console.log('========== UPLOAD PROFILE CONTROLLER ==========');
    console.log('Upload photo de profil - req.file:', req.file ? 'présent' : 'absent');
    if (req.file) {
      console.log('Upload photo de profil - filename:', req.file.filename);
      console.log('Upload photo de profil - size:', req.file.size);
      console.log('Upload photo de profil - mimetype:', req.file.mimetype);
      console.log('Upload photo de profil - originalname:', req.file.originalname);
    }
    console.log('Upload photo de profil - req.body:', req.body);
    
    if (!req.file) {
      console.error('ERREUR: Aucun fichier reçu');
      return res.status(400).json({ message: 'Aucun fichier uploadé. Assurez-vous que le champ est nommé "image"' });
    }

    // Construire seulement le chemin relatif (sans l'URL/IP)
    // Le chemin sera stocké dans la BDD : /images/profiles/filename
    const imagePath = `/images/profiles/${req.file.filename}`;

    console.log('Photo de profil uploadée avec succès, chemin:', imagePath);

    res.status(200).json({
      message: 'Photo de profil uploadée avec succès',
      imageUrl: imagePath, // Retourner seulement le chemin relatif
      filename: req.file.filename
    });
  } catch (error) {
    console.error('========== ERREUR UPLOAD PROFILE ==========');
    console.error('Erreur upload photo de profil:', error);
    console.error('Stack trace:', error.stack);
    res.status(500).json({ message: 'Erreur lors de l\'upload de la photo de profil: ' + error.message });
  }
};

