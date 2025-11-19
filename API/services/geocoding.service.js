const NodeGeocoder = require('node-geocoder');

const options = {
  provider: 'openstreetmap',
  httpAdapter: 'https',
  formatter: null
};

const geocoder = NodeGeocoder(options);

// Liste des communes de la région d'Angers (pour détection automatique)
const ANJERS_REGION_CITIES = [
  'angers', 'saint-barthelemy-d\'anjou', 'saint barthelemy d\'anjou',
  'saint-barthelemy', 'saint barthelemy', 'trélazé', 'trelaze',
  'avrillé', 'avrille', 'beaucouzé', 'beaucouze', 'bouchemaine',
  'saint-sylvain-d\'anjou', 'saint sylvain d\'anjou', 'verrières-en-anjou',
  'verrieres en anjou', 'ecouflant', 'écouflant'
];

/**
 * Valide le format d'adresse requis
 * Format attendu: "Numéro Rue, Code Postal Ville" (France sera ajouté automatiquement)
 * Exemple: "18 rue du 8 mai 1945, 49124 Saint barthelemy d'Anjou"
 */
function validateAddressFormat(address) {
  if (!address || typeof address !== 'string' || address.trim() === '') {
    return {
      valid: false,
      error: 'L\'adresse ne peut pas être vide'
    };
  }

  const trimmed = address.trim();
  
  // Vérifier qu'il y a au moins une virgule (séparateur entre rue et ville)
  if (!trimmed.includes(',')) {
    return {
      valid: false,
      error: 'Format invalide. Utilisez: "Numéro Rue, Code Postal Ville"'
    };
  }

  // Vérifier qu'il y a un numéro de rue (commence par un chiffre ou contient un numéro)
  const hasNumber = /\d/.test(trimmed.split(',')[0].trim());
  if (!hasNumber) {
    return {
      valid: false,
      error: 'L\'adresse doit contenir un numéro de rue'
    };
  }

  return { valid: true };
}

/**
 * Améliore l'adresse pour le géocodage en ajoutant des informations manquantes
 */
function enhanceAddressForGeocoding(address) {
  let enhanced = address.trim();
  
  // Vérifier si l'adresse contient déjà une ville de la région
  const lowerAddress = enhanced.toLowerCase();
  const hasCity = ANJERS_REGION_CITIES.some(city => 
    lowerAddress.includes(city.toLowerCase())
  );
  
  // Si pas de ville détectée et pas "france", ajouter "Angers, France"
  if (!hasCity && !lowerAddress.includes('france')) {
    // Vérifier si c'est juste une rue sans ville
    const parts = enhanced.split(',');
    if (parts.length === 1 || (parts.length === 2 && !/\d{5}/.test(parts[1]))) {
      enhanced = `${enhanced}, Angers, France`;
    } else {
      enhanced = `${enhanced}, France`;
    }
  } else if (!lowerAddress.includes('france')) {
    enhanced = `${enhanced}, France`;
  }
  
  return enhanced;
}

/**
 * Convertit une adresse en coordonnées GPS (latitude, longitude)
 * Format requis: "Numéro Rue, Code Postal Ville, France"
 * Exemple: "18 rue du 8 mai 1945, 49124 Saint barthelemy d'Anjou, France"
 */
async function geocodeAddress(address, strictMode = true) {
  if (!address || typeof address !== 'string' || address.trim() === '') {
    console.log('Géocodage: Adresse vide ou invalide');
    return {
      success: false,
      error: 'L\'adresse ne peut pas être vide',
      coordinates: null
    };
  }

  // Validation du format en mode strict
  if (strictMode) {
    const validation = validateAddressFormat(address);
    if (!validation.valid) {
      console.log(`Géocodage: Format invalide - ${validation.error}`);
      return {
        success: false,
        error: validation.error,
        coordinates: null
      };
    }
  }

  try {
    let searchAddress = enhanceAddressForGeocoding(address);
    console.log(`Géocodage - Adresse originale: "${address}"`);
    console.log(`Géocodage - Adresse enrichie: "${searchAddress}"`);

    console.log(`Géocodage - Appel à OpenStreetMap pour: "${searchAddress}"`);
    const results = await geocoder.geocode(searchAddress);
    
    console.log(`Géocodage - Nombre de résultats: ${results ? results.length : 0}`);
    
    if (results && results.length > 0) {
      const firstResult = results[0];
      const lat = parseFloat(firstResult.latitude);
      const lng = parseFloat(firstResult.longitude);
      
      // Vérifier que les coordonnées sont valides
      if (isNaN(lat) || isNaN(lng)) {
        console.log(`Géocodage: Coordonnées invalides reçues`);
        return {
          success: false,
          error: 'Coordonnées GPS invalides. Veuillez vérifier votre adresse.',
          coordinates: null
        };
      }
      
      console.log(`Géocodage réussi pour "${address}"`);
      console.log(`   → Latitude: ${lat}`);
      console.log(`   → Longitude: ${lng}`);
      console.log(`   → Résultat: ${firstResult.formattedAddress || 'N/A'}`);
      
      return {
        success: true,
        error: null,
        coordinates: {
          latitude: lat,
          longitude: lng,
          formattedAddress: firstResult.formattedAddress
        }
      };
    }
    
    console.log(`Géocodage: Aucun résultat trouvé pour "${address}"`);
    return {
      success: false,
      error: 'Adresse introuvable. Veuillez vérifier le format: "Numéro Rue, Code Postal Ville, France"',
      coordinates: null
    };
  } catch (error) {
    console.error(`Erreur lors du géocodage de l'adresse "${address}":`, error.message);
    console.error(`   Stack:`, error.stack);
    return {
      success: false,
      error: `Erreur lors de la recherche de l'adresse: ${error.message}`,
      coordinates: null
    };
  }
}

module.exports = {
  geocodeAddress,
  validateAddressFormat
};

