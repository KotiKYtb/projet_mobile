#!/usr/bin/env node

/**
 * Script pour créer un utilisateur admin via la ligne de commande
 * 
 * Champs requis:
 *   - email
 *   - password
 *   - name
 *   - surname
 * 
 * Usage:
 *   node create-admin.js
 */

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

// Fonction pour créer un utilisateur admin
async function createAdmin(userData) {
  console.log('\n👤 Création de l\'utilisateur admin...');
  
  try {
    const response = await makeRequest(
      `${API_URL}/api/auth/signup`,
      'POST',
      userData
    );

    if (response.statusCode === 200) {
      console.log('✅ Utilisateur admin créé avec succès!');
      console.log('\n📋 Détails de l\'utilisateur créé:');
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
  console.log('   Création d\'un utilisateur admin');
  console.log('═══════════════════════════════════════════════════════\n');

  try {
    // Demander les informations de l'utilisateur
    console.log('📝 Informations de l\'utilisateur admin:');
    console.log('─────────────────────────────────────────────────────');
    
    const email = await askQuestion('Email (requis): ');
    if (!email) {
      console.error('❌ Erreur: L\'email est requis');
      process.exit(1);
    }

    const password = await askQuestion('Mot de passe (requis): ');
    if (!password) {
      console.error('❌ Erreur: Le mot de passe est requis');
      process.exit(1);
    }

    const name = await askQuestion('Prénom (requis): ');
    if (!name) {
      console.error('❌ Erreur: Le prénom est requis');
      process.exit(1);
    }

    const surname = await askQuestion('Nom (requis): ');
    if (!surname) {
      console.error('❌ Erreur: Le nom est requis');
      process.exit(1);
    }

    // Préparer les données de l'utilisateur
    const userData = {
      email,
      password,
      name,
      surname,
      role: 'admin' // Définir le rôle comme admin
    };

    // Afficher un résumé
    console.log('\n📋 Résumé de l\'utilisateur:');
    console.log('─────────────────────────────────────────────────────');
    console.log(`Email: ${email}`);
    console.log(`Prénom: ${name}`);
    console.log(`Nom: ${surname}`);
    console.log(`Rôle: admin`);

    // Confirmer
    const confirm = await askQuestion('\nCréer cet utilisateur admin? (o/n): ');
    if (confirm.toLowerCase() !== 'o' && confirm.toLowerCase() !== 'oui' && confirm.toLowerCase() !== 'y' && confirm.toLowerCase() !== 'yes') {
      console.log('❌ Création annulée');
      process.exit(0);
    }

    // Créer l'utilisateur
    await createAdmin(userData);

  } catch (error) {
    console.error('\n❌ Erreur:', error.message);
    process.exit(1);
  } finally {
    rl.close();
  }
}

// Exécuter le script
main();

