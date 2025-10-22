# Script PowerShell pour appliquer l'algorithme d'allocation progressive affiné
# Ce script applique la migration et rafraîchit toutes les vues dans le bon ordre

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ALGORITHME D'ALLOCATION PROGRESSIVE AFFINÉ" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si le fichier de migration existe
$migrationFile = "supabase\migrations\20251022000000_refine_progressive_allocation_final.sql"
if (-not (Test-Path $migrationFile)) {
    Write-Host "ERREUR : Le fichier de migration n'existe pas : $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "OK Fichier de migration trouve : $migrationFile" -ForegroundColor Green
Write-Host ""

# Instructions pour l'utilisateur
Write-Host "INSTRUCTIONS D'APPLICATION :" -ForegroundColor Yellow
Write-Host "1. Ouvrez votre dashboard Supabase" -ForegroundColor White
Write-Host "2. Allez dans 'SQL Editor'" -ForegroundColor White
Write-Host "3. Copiez le contenu de : $migrationFile" -ForegroundColor White
Write-Host "4. Collez et exécutez le SQL" -ForegroundColor White
Write-Host ""

Write-Host "OU utilisez la commande suivante si vous avez Supabase CLI :" -ForegroundColor Yellow
Write-Host "   supabase db push" -ForegroundColor Cyan
Write-Host ""

# Afficher le contenu du fichier de rafraîchissement des vues
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SCRIPT SQL POUR RAFRAÎCHIR LES VUES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$refreshScript = @"
-- Rafraîchir toutes les vues matérialisées dans le bon ordre
-- Exécutez ce script APRÈS avoir appliqué la migration

-- Étape 1 : Rafraîchir les vues de base
REFRESH MATERIALIZED VIEW mv_project_machine_parts_aggregated;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_otc;
REFRESH MATERIALIZED VIEW mv_project_parts_used_quantities_enhanced;
REFRESH MATERIALIZED VIEW mv_project_parts_transit_invoiced;
REFRESH MATERIALIZED VIEW mv_project_parts_stock_availability;

-- Étape 2 : Rafraîchir la vue finale
REFRESH MATERIALIZED VIEW mv_project_analytics_complete;

-- Vérification : Compter les lignes dans chaque vue
SELECT 
  'mv_project_machine_parts_aggregated' as view_name,
  COUNT(*) as row_count
FROM mv_project_machine_parts_aggregated
UNION ALL
SELECT 
  'mv_project_parts_used_quantities',
  COUNT(*)
FROM mv_project_parts_used_quantities
UNION ALL
SELECT 
  'mv_project_parts_used_quantities_otc',
  COUNT(*)
FROM mv_project_parts_used_quantities_otc
UNION ALL
SELECT 
  'mv_project_parts_used_quantities_enhanced',
  COUNT(*)
FROM mv_project_parts_used_quantities_enhanced
UNION ALL
SELECT 
  'mv_project_parts_transit_invoiced',
  COUNT(*)
FROM mv_project_parts_transit_invoiced
UNION ALL
SELECT 
  'mv_project_parts_stock_availability',
  COUNT(*)
FROM mv_project_parts_stock_availability
UNION ALL
SELECT 
  'mv_project_analytics_complete',
  COUNT(*)
FROM mv_project_analytics_complete;
"@

# Sauvegarder le script de rafraîchissement
$refreshFile = "refresh_all_views.sql"
$refreshScript | Out-File -FilePath $refreshFile -Encoding UTF8
Write-Host "OK Script de rafraichissement sauvegarde dans : $refreshFile" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RÉSUMÉ DES CHANGEMENTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "OK Ordre d'allocation : Used -> Available -> Invoiced -> Backorders" -ForegroundColor Green
Write-Host "OK Priorite chronologique : created_at, puis id" -ForegroundColor Green
Write-Host "OK Ressources isolees par projet" -ForegroundColor Green
Write-Host "OK Dedoublonnage du stock automatique" -ForegroundColor Green
Write-Host "OK Gestion des cas limites (quantity_used >= quantity_required)" -ForegroundColor Green
Write-Host ""

Write-Host "PRÊT À APPLIQUER !" -ForegroundColor Cyan
Write-Host "Suivez les instructions ci-dessus pour appliquer la migration." -ForegroundColor White
Write-Host ""

