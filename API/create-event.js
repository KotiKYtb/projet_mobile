#!/usr/bin/env node

/**
 * Script pour créer automatiquement des événements prédéfinis
 * 
 * Les événements sont définis en dur dans le fichier et créés automatiquement
 * 
 * Usage:
 *   node create-event.js
 */

// Événements prédéfinis à créer
const PREDEFINED_EVENTS = [
  {
    title: "Conférence Tech",
    description: "Conférence sur les dernières innovations technologiques avec des experts du secteur.",
    startAt: "2025-08-10T14:00:00",
    endAt: "2025-08-10T18:00:00",
    location: "Université d'Angers",
    category: "Éducation",
    image_url: "https://imgs.search.brave.com/KENcVy6cvsfPkhq30lzwpsikGFS3z5YAws7y8TV0ztE/rs:fit:500:0:1:0/g:ce/aHR0cHM6Ly90aG90/aXNtZWRpYS5jb20v/d3AtY29udGVudC91/cGxvYWRzLzIwMjUv/MDEvTG9nb19Fc2Fp/cF9ibGFuYy5wbmc"
  },
  {
    title: "Marché Nocturne",
    description: "Marché de nuit avec produits locaux, artisanat et animations.",
    startAt: "2025-05-30T18:00:00",
    endAt: "2025-05-30T23:00:00",
    location: "Quai de la Loire",
    category: "Commerce",
    image_url: "https://imgs.search.brave.com/rV5rnw9INKbaQXwdnjvZCe4GE8HywJaCXMkyBxjEfJs/rs:fit:500:0:1:0/g:ce/aHR0cHM6Ly9pLnBp/bmltZy5jb20vb3Jp/Z2luYWxzLzM4L2M1/L2RjLzM4YzVkYzlh/YjJhZDAxMDY0YzUy/NzZjM2JmODdhNWYx/LmpwZw"
  },
  {
    title: "Exposition d'Art Contemporain",
    description: "Exposition d'œuvres d'artistes contemporains locaux et internationaux.",
    startAt: "2025-09-01T10:00:00",
    endAt: "2025-09-30T18:00:00",
    location: "Musée des Beaux-Arts",
    category: "Culture",
    image_url: "https://imgs.search.brave.com/f5DBWxhtkm-1zeNxR-I-zzaPXBVTPiW6Vtf7BpHRETQ/rs:fit:500:0:1:0/g:ce/aHR0cHM6Ly93d3cu/ZWxsZXNib3VnZW50/LmNvbS9kb2N1bWVu/dHMvcGFydGVuYWly/ZXMvMTc3L2xvZ29f/ZXNhaXBfaW5nZW5p/ZXVyX3J2Yl8yMDE2/LnRodW1iLmpwZw"
  }
];

const http = require('http');
const https = require('https');
const readline = require('readline');
const { URL } = require('url');

// Configuration
const API_URL = process.env.API_URL || 'http://172.16.81.38:8080';

// Interface readline pour lire les entrées utilisateur
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Fonction pour poser une question
function askQuestion(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer.trim());
    });
  });
}

// Fonction pour faire une requête HTTP
function makeRequest(url, method = 'GET', data = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const isHttps = urlObj.protocol === 'https:';
    const client = isHttps ? https : http;
    
    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port || (isHttps ? 443 : 80),
      path: urlObj.pathname + urlObj.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    };

    const req = client.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : {};
          resolve({ statusCode: res.statusCode, body: parsed });
        } catch (e) {
          resolve({ statusCode: res.statusCode, body: body });
        }
      });
    });

    req.on('error', (e) => {
      reject(e);
    });

    if (data) {
      req.write(JSON.stringify(data));
    }

    req.end();
  });
}

// Fonction pour se connecter et obtenir un token
async function login(email, password) {
  console.log(`\n🔐 Connexion en tant que ${email}...`);
  
  try {
    const response = await makeRequest(
      `${API_URL}/api/auth/signin`,
      'POST',
      { email, password }
    );

    if (response.statusCode === 200 && response.body.accessToken) {
      console.log('✅ Connexion réussie!');
      return response.body.accessToken;
    } else {
      throw new Error(`Échec de la connexion: ${response.body.message || 'Erreur inconnue'}`);
    }
  } catch (error) {
    throw new Error(`Erreur lors de la connexion: ${error.message}`);
  }
}

// Fonction pour créer un événement
async function createEvent(eventData, token) {
  try {
    const response = await makeRequest(
      `${API_URL}/api/events`,
      'POST',
      eventData,
      { 'x-access-token': token }
    );

    if (response.statusCode === 201) {
      return { success: true, event: response.body };
    } else {
      return { success: false, error: response.body.message || 'Erreur inconnue' };
    }
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Fonction principale
async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('   Création automatique d\'événements prédéfinis');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Demander les informations de connexion
    console.log('📝 Informations de connexion (admin requis):');
    const email = await askQuestion('Email admin: ');
    const password = await askQuestion('Mot de passe: ');

    // Se connecter pour obtenir un token
    const token = await login(email, password);

    // Afficher les événements à créer
    console.log(`\n📋 ${PREDEFINED_EVENTS.length} événements prédéfinis seront créés:`);
    console.log('─────────────────────────────────────────────────────');
    PREDEFINED_EVENTS.forEach((event, index) => {
      console.log(`${index + 1}. ${event.title} - ${event.location} (${event.startAt})`);
    });

    // Confirmer
    const confirm = await askQuestion('\nCréer tous ces événements? (o/n): ');
    if (confirm.toLowerCase() !== 'o' && confirm.toLowerCase() !== 'oui' && confirm.toLowerCase() !== 'y' && confirm.toLowerCase() !== 'yes') {
      console.log('❌ Création annulée');
      process.exit(0);
    }

    // Créer tous les événements
    console.log('\n📅 Création des événements...\n');
    let successCount = 0;
    let errorCount = 0;

    for (let i = 0; i < PREDEFINED_EVENTS.length; i++) {
      const eventData = PREDEFINED_EVENTS[i];
      console.log(`[${i + 1}/${PREDEFINED_EVENTS.length}] Création de "${eventData.title}"...`);
      
      const result = await createEvent(eventData, token);
      
      if (result.success) {
        console.log(`✅ "${eventData.title}" créé avec succès!`);
        successCount++;
      } else {
        console.log(`❌ Erreur pour "${eventData.title}": ${result.error}`);
        errorCount++;
      }
    }

    // Résumé
    console.log('\n═══════════════════════════════════════════════════════');
    console.log('📊 Résumé:');
    console.log(`   ✅ ${successCount} événement(s) créé(s) avec succès`);
    if (errorCount > 0) {
      console.log(`   ❌ ${errorCount} événement(s) en erreur`);
    }
    console.log('═══════════════════════════════════════════════════════\n');

  } catch (error) {
    console.error('\n❌ Erreur:', error.message);
    process.exit(1);
  } finally {
    rl.close();
  }
}

// Exécuter le script
main();

