# Script de déploiement pour Netlify avec corrections CSV mapping
# Ce script déploie la version stable avec les corrections du mapping CSV

Write-Host "=== DÉPLOIEMENT NETLIFY - CORRECTIONS CSV MAPPING ===" -ForegroundColor Green
Write-Host ""

# Vérifier que nous sommes dans le bon répertoire
if (-not (Test-Path "package.json")) {
    Write-Host "❌ Erreur: Ce script doit être exécuté depuis la racine du projet" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Répertoire de projet détecté" -ForegroundColor Green
Write-Host ""

# Vérifier les fichiers de correction CSV
Write-Host "📁 Vérification des fichiers de correction CSV..." -ForegroundColor Cyan
$csvFiles = @(
    "src/components/CSVImporter.tsx",
    "src/components/ImportReportDisplay.tsx", 
    "parts_template.csv",
    "CSV_MAPPING_FIX_README.md",
    "test_csv_mapping_only.sql"
)

foreach ($file in $csvFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $file - MANQUANT" -ForegroundColor Red
    }
}

Write-Host ""

# Essayer de trouver Node.js
Write-Host "🔍 Recherche de Node.js..." -ForegroundColor Yellow
$nodePaths = @(
    "C:\Program Files\nodejs\node.exe",
    "C:\Program Files (x86)\nodejs\node.exe",
    "C:\Users\$env:USERNAME\AppData\Local\Programs\nodejs\node.exe",
    "C:\Users\$env:USERNAME\AppData\Roaming\npm\node.exe"
)

$nodeFound = $false
foreach ($path in $nodePaths) {
    if (Test-Path $path) {
        Write-Host "✅ Node.js trouvé: $path" -ForegroundColor Green
        $env:PATH = "$(Split-Path $path);$env:PATH"
        $nodeFound = $true
        break
    }
}

if (-not $nodeFound) {
    Write-Host "⚠️  Node.js non trouvé dans les chemins standards" -ForegroundColor Yellow
    Write-Host "Tentative de construction avec les outils disponibles..." -ForegroundColor Yellow
}

# Essayer de construire le projet
Write-Host ""
Write-Host "🔨 Construction du projet..." -ForegroundColor Yellow

try {
    # Essayer npm d'abord
    $npmResult = & npm run build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Construction réussie avec npm" -ForegroundColor Green
    } else {
        throw "npm failed"
    }
} catch {
    Write-Host "⚠️  npm non disponible, tentative avec npx..." -ForegroundColor Yellow
    try {
        $npxResult = & npx vite build 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Construction réussie avec npx vite" -ForegroundColor Green
        } else {
            throw "npx failed"
        }
    } catch {
        Write-Host "❌ Impossible de construire le projet automatiquement" -ForegroundColor Red
        Write-Host "Veuillez construire manuellement avec: npm run build" -ForegroundColor Yellow
        Write-Host "Puis déployez avec: npm run deploy" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

# Vérifier que le build a été créé
if (Test-Path "dist") {
    Write-Host "✅ Dossier dist créé avec succès" -ForegroundColor Green
    $distSize = (Get-ChildItem "dist" -Recurse | Measure-Object -Property Length -Sum).Sum
    Write-Host "📊 Taille du build: $([math]::Round($distSize/1MB, 2)) MB" -ForegroundColor Cyan
} else {
    Write-Host "❌ Dossier dist non trouvé" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Déploiement sur Netlify
Write-Host "🚀 Déploiement sur Netlify..." -ForegroundColor Yellow

try {
    $deployResult = & npm run deploy 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Déploiement Netlify réussi!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎉 CORRECTIONS CSV MAPPING DÉPLOYÉES!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 Fonctionnalités déployées:" -ForegroundColor Cyan
        Write-Host "  ✅ Mapping strict des colonnes CSV" -ForegroundColor Green
        Write-Host "  ✅ Analyse complète de toutes les lignes" -ForegroundColor Green
        Write-Host "  ✅ Focus uniquement sur les problèmes de mapping" -ForegroundColor Green
        Write-Host "  ✅ Suppression des faux positifs" -ForegroundColor Green
        Write-Host "  ✅ Interface utilisateur améliorée" -ForegroundColor Green
        Write-Host "  ✅ Rapport de validation post-import" -ForegroundColor Green
        Write-Host "  ✅ Scripts de diagnostic et nettoyage" -ForegroundColor Green
        Write-Host "  ✅ Template CSV standardisé" -ForegroundColor Green
        Write-Host ""
        Write-Host "🌐 Votre application est maintenant disponible sur Netlify!" -ForegroundColor Green
    } else {
        Write-Host "❌ Erreur lors du déploiement Netlify" -ForegroundColor Red
        Write-Host "Résultat: $deployResult" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ Impossible de déployer automatiquement" -ForegroundColor Red
    Write-Host "Veuillez déployer manuellement avec: npm run deploy" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== DÉPLOIEMENT TERMINÉ ===" -ForegroundColor Green
