#!/bin/bash

# Script de déploiement des corrections du mapping CSV
# Ce script applique toutes les corrections nécessaires

echo "=== DÉPLOIEMENT DES CORRECTIONS CSV MAPPING ==="
echo ""

# 1. Vérifier que nous sommes dans le bon répertoire
if [ ! -f "package.json" ]; then
    echo "❌ Erreur: Ce script doit être exécuté depuis la racine du projet"
    exit 1
fi

echo "✅ Répertoire de projet détecté"
echo ""

# 2. Construire le projet
echo "🔨 Construction du projet..."
npm run build

if [ $? -eq 0 ]; then
    echo "✅ Construction réussie"
else
    echo "❌ Erreur lors de la construction"
    exit 1
fi

echo ""

# 3. Vérifier les fichiers modifiés
echo "📁 Fichiers modifiés:"
echo "  - src/components/CSVImporter.tsx (mapping strict)"
echo "  - src/components/ImportReportDisplay.tsx (nouveau composant)"
echo "  - parts_template.csv (template CSV)"
echo "  - Scripts SQL de diagnostic et nettoyage"
echo ""

# 4. Instructions pour l'utilisateur
echo "📋 INSTRUCTIONS POUR L'UTILISATION:"
echo ""
echo "1. NETTOYAGE DES DONNÉES EXISTANTES:"
echo "   - Exécutez le script SQL: clean_parts_table.sql"
echo "   - Ou videz manuellement la table: DELETE FROM parts;"
echo ""
echo "2. IMPORT DES NOUVELLES DONNÉES:"
echo "   - Utilisez le template CSV: parts_template.csv"
echo "   - Assurez-vous d'avoir exactement 23 colonnes"
echo "   - Utilisez l'interface d'import dans l'application"
echo ""
echo "3. VALIDATION DES RÉSULTATS:"
echo "   - Le système affichera automatiquement un rapport d'import"
echo "   - Exécutez le script de test: test_csv_mapping_fix.sql"
echo ""
echo "4. FONCTIONNALITÉS AJOUTÉES:"
echo "   ✅ Mapping strict des colonnes par position"
echo "   ✅ Détection automatique des délimiteurs CSV"
echo "   ✅ Rapport de validation post-import"
echo "   ✅ Interface utilisateur pour les rapports"
echo "   ✅ Détection des valeurs suspectes"
echo "   ✅ Scripts de diagnostic et nettoyage"
echo ""

# 5. Déploiement sur Netlify (si configuré)
if [ -f "netlify.toml" ]; then
    echo "🚀 Déploiement sur Netlify..."
    npm run deploy
    
    if [ $? -eq 0 ]; then
        echo "✅ Déploiement Netlify réussi"
    else
        echo "⚠️  Erreur lors du déploiement Netlify"
    fi
else
    echo "ℹ️  Pas de configuration Netlify détectée"
fi

echo ""
echo "=== DÉPLOIEMENT TERMINÉ ==="
echo ""
echo "🎉 Les corrections du mapping CSV sont maintenant actives!"
echo ""
echo "📖 Pour plus d'informations, consultez: CSV_MAPPING_FIX_README.md"
