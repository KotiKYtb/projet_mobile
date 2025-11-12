#!/usr/bin/env node

/**
 * Script pour corriger la table favorites
 * Supprime la contrainte unique sur user_id et ajoute une contrainte unique sur (user_id, event_id)
 * 
 * Usage:
 *   node fix-favorites-table.js
 */

const db = require("./models");

async function fixFavoritesTable() {
  try {
    console.log('🔧 Correction de la table favorites...\n');
    
    // Supprimer la contrainte unique sur user_id si elle existe
    try {
      await db.sequelize.query(`
        CREATE TABLE IF NOT EXISTS favorites_new (
          user_id INTEGER NOT NULL,
          event_id INTEGER NOT NULL,
          created_at DATETIME NOT NULL,
          updated_at DATETIME NOT NULL,
          PRIMARY KEY (user_id, event_id)
        );
      `);
      
      // Copier les données
      await db.sequelize.query(`
        INSERT OR IGNORE INTO favorites_new (user_id, event_id, created_at, updated_at)
        SELECT DISTINCT user_id, event_id, created_at, updated_at
        FROM favorites;
      `);
      
      // Supprimer l'ancienne table
      await db.sequelize.query(`DROP TABLE favorites;`);
      
      // Renommer la nouvelle table
      await db.sequelize.query(`ALTER TABLE favorites_new RENAME TO favorites;`);
      
      console.log('✅ Table favorites corrigée avec succès!');
      console.log('   - Contrainte unique sur (user_id, event_id) ajoutée');
      console.log('   - Contrainte unique sur user_id seul supprimée\n');
    } catch (error) {
      console.error('❌ Erreur lors de la correction:', error.message);
      throw error;
    }
    
    await db.sequelize.close();
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    await db.sequelize.close();
    process.exit(1);
  }
}

fixFavoritesTable();

