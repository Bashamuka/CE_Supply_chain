import { createClient } from '@supabase/supabase-js';

const sourceUrl = 'https://nvuohqfsgeulivaihxeh.supabase.co';
const sourceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeW_4h1rFAtYoQM';

const targetUrl = 'https://cvdxwhubdcdopgboamoh.supabase.co';
const targetKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2ZHh3aHViZGNkb3BnYm9hbW9oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5NjcwNDcsImV4cCI6MjA3NTU0MzA0N30.OerPQb22qBfatmZh5ly97p5WK7mkLJaWr4V-AIxwZn8';

const sourceClient = createClient(sourceUrl, sourceKey);
const targetClient = createClient(targetUrl, targetKey);

async function migrateTable(tableName, batchSize = 1000) {
  console.log(`\n📦 Migration de la table: ${tableName}`);

  try {
    const { data: sourceData, error: fetchError, count } = await sourceClient
      .from(tableName)
      .select('*', { count: 'exact' });

    if (fetchError) {
      console.error(`❌ Erreur lors de la lecture de ${tableName}:`, fetchError.message);
      return { success: false, count: 0 };
    }

    if (!sourceData || sourceData.length === 0) {
      console.log(`⚠️  Table ${tableName} est vide dans la source`);
      return { success: true, count: 0 };
    }

    console.log(`📊 Trouvé ${sourceData.length} enregistrements dans ${tableName}`);

    for (let i = 0; i < sourceData.length; i += batchSize) {
      const batch = sourceData.slice(i, i + batchSize);
      const { error: insertError } = await targetClient
        .from(tableName)
        .insert(batch);

      if (insertError) {
        console.error(`❌ Erreur lors de l'insertion dans ${tableName}:`, insertError.message);
        return { success: false, count: i };
      }

      console.log(`✅ Inséré ${Math.min(i + batchSize, sourceData.length)}/${sourceData.length} enregistrements`);
    }

    console.log(`✅ Migration de ${tableName} terminée: ${sourceData.length} enregistrements`);
    return { success: true, count: sourceData.length };

  } catch (error) {
    console.error(`❌ Erreur inattendue pour ${tableName}:`, error.message);
    return { success: false, count: 0 };
  }
}

async function migrateAllData() {
  console.log('🚀 Début de la migration des données...\n');
  console.log(`Source: ${sourceUrl}`);
  console.log(`Target: ${targetUrl}\n`);

  const results = {};

  const tables = [
    'parts',
    'stock_dispo',
    'orders',
    'parts_equivalence',
    'dealer_forward_planning',
    'projects',
    'project_machines',
    'project_machine_parts',
    'project_machine_order_numbers',
    'project_supplier_orders',
    'project_branches'
  ];

  for (const table of tables) {
    const result = await migrateTable(table);
    results[table] = result;
  }

  console.log('\n📊 RÉSUMÉ DE LA MIGRATION:');
  console.log('='.repeat(50));

  let totalRecords = 0;
  let successCount = 0;
  let failureCount = 0;

  for (const [table, result] of Object.entries(results)) {
    const status = result.success ? '✅' : '❌';
    console.log(`${status} ${table}: ${result.count} enregistrements`);
    totalRecords += result.count;
    if (result.success) successCount++;
    else failureCount++;
  }

  console.log('='.repeat(50));
  console.log(`Total: ${totalRecords} enregistrements migrés`);
  console.log(`Succès: ${successCount}/${tables.length} tables`);
  if (failureCount > 0) {
    console.log(`❌ Échecs: ${failureCount} tables`);
  }
  console.log('\n✨ Migration terminée!');
}

migrateAllData().catch(console.error);
