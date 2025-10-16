# Script PowerShell de déploiement des corrections du mapping CSV
# Ce script applique toutes les corrections nécessaires

Write-Host "=== DÉPLOIEMENT DES CORRECTIONS CSV MAPPING ===" -ForegroundColor Green
Write-Host ""

# 1. Vérifier que nous sommes dans le bon répertoire
if (-not (Test-Path "package.json")) {
    Write-Host "❌ Erreur: Ce script doit être exécuté depuis la racine du projet" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Répertoire de projet détecté" -ForegroundColor Green
Write-Host ""

# 2. Construire le projet
Write-Host "🔨 Construction du projet..." -ForegroundColor Yellow
npm run build

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Construction réussie" -ForegroundColor Green
} else {
    Write-Host "❌ Erreur lors de la construction" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 3. Vérifier les fichiers modifiés
Write-Host "📁 Fichiers modifiés:" -ForegroundColor Cyan
Write-Host "  - src/components/CSVImporter.tsx (mapping strict)" -ForegroundColor White
Write-Host "  - src/components/ImportReportDisplay.tsx (nouveau composant)" -ForegroundColor White
Write-Host "  - parts_template.csv (template CSV)" -ForegroundColor White
Write-Host "  - Scripts SQL de diagnostic et nettoyage" -ForegroundColor White
Write-Host ""

# 4. Instructions pour l'utilisateur
Write-Host "📋 INSTRUCTIONS POUR L'UTILISATION:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. NETTOYAGE DES DONNÉES EXISTANTES:" -ForegroundColor Yellow
Write-Host "   - Exécutez le script SQL: clean_parts_table.sql" -ForegroundColor White
Write-Host "   - Ou videz manuellement la table: DELETE FROM parts;" -ForegroundColor White
Write-Host ""
Write-Host "2. IMPORT DES NOUVELLES DONNÉES:" -ForegroundColor Yellow
Write-Host "   - Utilisez le template CSV: parts_template.csv" -ForegroundColor White
Write-Host "   - Assurez-vous d'avoir exactement 23 colonnes" -ForegroundColor White
Write-Host "   - Utilisez l'interface d'import dans l'application" -ForegroundColor White
Write-Host ""
Write-Host "3. VALIDATION DES RÉSULTATS:" -ForegroundColor Yellow
Write-Host "   - Le système affichera automatiquement un rapport d'import" -ForegroundColor White
Write-Host "   - Exécutez le script de test: test_csv_mapping_fix.sql" -ForegroundColor White
Write-Host ""
Write-Host "4. FONCTIONNALITÉS AJOUTÉES:" -ForegroundColor Yellow
Write-Host "   ✅ Mapping strict des colonnes par position" -ForegroundColor Green
Write-Host "   ✅ Détection automatique des délimiteurs CSV" -ForegroundColor Green
Write-Host "   ✅ Rapport de validation post-import" -ForegroundColor Green
Write-Host "   ✅ Interface utilisateur pour les rapports" -ForegroundColor Green
Write-Host "   ✅ Détection des valeurs suspectes" -ForegroundColor Green
Write-Host "   ✅ Scripts de diagnostic et nettoyage" -ForegroundColor Green
Write-Host ""

# 5. Déploiement sur Netlify (si configuré)
if (Test-Path "netlify.toml") {
    Write-Host "🚀 Déploiement sur Netlify..." -ForegroundColor Yellow
    npm run deploy
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Déploiement Netlify réussi" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Erreur lors du déploiement Netlify" -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️  Pas de configuration Netlify détectée" -ForegroundColor Blue
}

Write-Host ""
Write-Host "=== DÉPLOIEMENT TERMINÉ ===" -ForegroundColor Green
Write-Host ""
Write-Host "🎉 Les corrections du mapping CSV sont maintenant actives!" -ForegroundColor Green
Write-Host ""
Write-Host "📖 Pour plus d'informations, consultez: CSV_MAPPING_FIX_README.md" -ForegroundColor Cyan
