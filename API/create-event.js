#!/usr/bin/env node

/**
 * Script pour créer un événement via la ligne de commande
 * 
 * Champs requis:
 *   - title (titre)
 *   - startAt (date de début au format ISO: "2024-12-25T10:00:00")
 *   - created_by (email de l'utilisateur créateur)
 * 
 * Champs optionnels:
 *   - description
 *   - endAt (date de fin au format ISO)
 *   - location (lieu)
 *   - category (catégorie)
 *   - image_url (URL de l'image)
 * 
 * Usage:
 *   node create-event.js
 */

const http = require('http');
const https = require('https');
const readline = require('readline');
const { URL } = require('url');

// Configuration
const API_URL = process.env.API_URL || 'http://172.16.80.151:8080';

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
  console.log('\n📅 Création de l\'événement...');
  
  try {
    const response = await makeRequest(
      `${API_URL}/api/events`,
      'POST',
      eventData,
      { 'x-access-token': token }
    );

    if (response.statusCode === 201) {
      console.log('✅ Événement créé avec succès!');
      console.log('\n📋 Détails de l\'événement créé:');
      console.log(JSON.stringify(response.body, null, 2));
      return response.body;
    } else {
      throw new Error(`Échec de la création: ${response.body.message || 'Erreur inconnue'}`);
    }
  } catch (error) {
    throw new Error(`Erreur lors de la création: ${error.message}`);
  }
}

// Fonction principale
async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('   Création d\'un événement');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Demander les informations de connexion
    console.log('📝 Informations de connexion (admin requis):');
    const email = await askQuestion('Email admin: ');
    const password = await askQuestion('Mot de passe: ');

    // Se connecter pour obtenir un token
    const token = await login(email, password);

    // Demander les informations de l'événement
    console.log('\n📝 Informations de l\'événement:');
    console.log('─────────────────────────────────────────────────────');
    
    // Champs requis
    const title = await askQuestion('Titre (requis): ');
    if (!title) {
      console.error('❌ Erreur: Le titre est requis');
      process.exit(1);
    }

    const startAt = await askQuestion('Date de début au format ISO (requis, ex: 2024-12-25T10:00:00): ');
    if (!startAt) {
      console.error('❌ Erreur: La date de début est requise');
      process.exit(1);
    }

    const createdBy = await askQuestion('Email du créateur (requis): ');
    if (!createdBy) {
      console.error('❌ Erreur: L\'email du créateur est requis');
      process.exit(1);
    }

    // Champs optionnels
    console.log('\n📝 Champs optionnels (appuyez sur Entrée pour ignorer):');
    const description = await askQuestion('Description: ');
    const endAt = await askQuestion('Date de fin au format ISO (ex: 2024-12-25T18:00:00): ');
    const location = await askQuestion('Lieu: ');
    const category = await askQuestion('Catégorie: ');
    const imageUrl = await askQuestion('URL de l\'image: ');

    // Préparer les données de l'événement
    const now = new Date().toISOString();
    const eventData = {
      title,
      startAt,
      created_by: createdBy,
      created_at: now,
      updated_at: now,
    };

    // Ajouter les champs optionnels s'ils sont fournis
    if (description) eventData.description = description;
    if (endAt) eventData.endAt = endAt;
    if (location) eventData.location = location;
    if (category) eventData.category = category;
    if (imageUrl) eventData.image_url = imageUrl;

    // Afficher un résumé
    console.log('\n📋 Résumé de l\'événement:');
    console.log('─────────────────────────────────────────────────────');
    console.log(`Titre: ${title}`);
    console.log(`Date de début: ${startAt}`);
    if (endAt) console.log(`Date de fin: ${endAt}`);
    if (location) console.log(`Lieu: ${location}`);
    if (category) console.log(`Catégorie: ${category}`);
    if (description) console.log(`Description: ${description.substring(0, 50)}${description.length > 50 ? '...' : ''}`);
    console.log(`Créé par: ${createdBy}`);

    // Confirmer
    const confirm = await askQuestion('\nCréer cet événement? (o/n): ');
    if (confirm.toLowerCase() !== 'o' && confirm.toLowerCase() !== 'oui' && confirm.toLowerCase() !== 'y' && confirm.toLowerCase() !== 'yes') {
      console.log('❌ Création annulée');
      process.exit(0);
    }

    // Créer l'événement
    await createEvent(eventData, token);

  } catch (error) {
    console.error('\n❌ Erreur:', error.message);
    process.exit(1);
  } finally {
    rl.close();
  }
}

// Exécuter le script
main();

