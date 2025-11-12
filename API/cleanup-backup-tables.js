#!/usr/bin/env node

/**
 * Script pour nettoyer les tables backup SQLite
 * 
 * Usage:
 *   node cleanup-backup-tables.js
 */

const db = require("./models");

async function cleanupBackupTables() {
  console.log('🧹 Nettoyage des tables backup...\n');
  
  const backupTables = [
    'users_backup',
    'events_backup',
    'favorites_backup',
    'alerts_backup'
  ];
  
  let cleanedCount = 0;
  
  for (const table of backupTables) {
    try {
      await db.sequelize.query(`DROP TABLE IF EXISTS ${table};`);
      console.log(`✅ Table ${table} nettoyée`);
      cleanedCount++;
    } catch (error) {
      console.log(`ℹ️  Table ${table} n'existe pas ou erreur: ${error.message}`);
    }
  }
  
  console.log(`\n✅ ${cleanedCount} table(s) backup nettoyée(s)`);
  await db.sequelize.close();
  process.exit(0);
}

cleanupBackupTables().catch((error) => {
  console.error('❌ Erreur lors du nettoyage:', error.message);
  process.exit(1);
});

