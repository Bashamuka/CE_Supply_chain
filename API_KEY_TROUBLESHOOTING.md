# Guide de Dépannage - Clé API Supabase Invalide

## Problème Identifié
**Erreur** : "Invalid API key" dans les tests de diagnostic
**Symptômes** :
- Database Connection failed
- Login Service error
- Tous les services Supabase inaccessibles

## Cause Racine
**Clé API Incorrecte** : La clé API dans le fichier `.env` était légèrement différente de la vraie clé.

**Différence Identifiée** :
- ❌ **Incorrecte** : `...UUKeX_4h1rFAtYoQM` (avec X)
- ✅ **Correcte** : `...UUKeW_4h1rFAtYoQM` (avec W)

## Solution Appliquée

### 1. Correction du Fichier .env
```bash
# Ancienne clé (incorrecte)
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM

# Nouvelle clé (correcte)
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeW_4h1rFAtYoQM
```

### 2. Mise à Jour des Scripts
- ✅ `create_env_file.ps1` - Clé corrigée
- ✅ `create_env_file.sh` - Clé corrigée
- ✅ Scripts de diagnostic mis à jour

## Comment Vérifier la Correction

### 1. Vérifier le Fichier .env
```bash
# Vérifier le contenu du fichier
Get-Content .env  # Windows PowerShell
cat .env          # Linux/Mac
```

### 2. Redémarrer le Serveur de Développement
```bash
# Arrêter le serveur (Ctrl+C)
# Puis redémarrer
npm run dev
# ou
yarn dev
```

### 3. Tester la Connexion
1. Aller sur la page de connexion
2. Cliquer sur "Show Connection Diagnostic"
3. Cliquer sur "Run Diagnostic"
4. Vérifier que tous les tests passent (verts)

## Tests de Validation

### Test 1 : Variables d'Environnement
- ✅ `VITE_SUPABASE_URL` : Configuré
- ✅ `VITE_SUPABASE_ANON_KEY` : Clé corrigée

### Test 2 : Client Supabase
- ✅ Initialisation réussie
- ✅ Configuration valide

### Test 3 : Connectivité Réseau
- ✅ Serveur Supabase accessible
- ✅ Pas d'erreurs de réseau

### Test 4 : Service d'Authentification
- ✅ API d'authentification fonctionnelle
- ✅ Pas d'erreurs "Invalid API key"

### Test 5 : Base de Données
- ✅ Connexion à la base de données réussie
- ✅ Requêtes SQL fonctionnelles

### Test 6 : Service de Connexion
- ✅ Service de login opérationnel
- ✅ Tests avec identifiants factices réussis

## Prévention Future

### 1. Validation de la Clé API
```javascript
// Dans la console du navigateur
const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
console.log('API Key ends with:', key.slice(-20));
// Doit se terminer par: UUKeW_4h1rFAtYoQM
```

### 2. Test Automatique
```javascript
// Test de la clé API
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
);

// Test de connexion
supabase.auth.getSession().then(({data, error}) => {
  if (error && error.message.includes('Invalid API key')) {
    console.error('❌ API Key is invalid');
  } else {
    console.log('✅ API Key is valid');
  }
});
```

### 3. Monitoring
- Surveiller les erreurs "Invalid API key"
- Vérifier régulièrement la connectivité Supabase
- Tester la connexion après chaque déploiement

## Erreurs Courantes

### Erreur : "Invalid API key"
**Causes** :
- Clé API incorrecte ou expirée
- Projet Supabase suspendu
- Mauvaise configuration des variables d'environnement

**Solutions** :
- Vérifier la clé API dans Supabase Dashboard
- Mettre à jour le fichier `.env`
- Redémarrer le serveur de développement

### Erreur : "Project not found"
**Causes** :
- URL Supabase incorrecte
- Projet supprimé ou suspendu

**Solutions** :
- Vérifier l'URL dans Supabase Dashboard
- Vérifier le statut du projet
- Contacter le support Supabase

## Support Technique

Si le problème persiste après la correction :

1. **Vérifier Supabase Dashboard** :
   - Aller sur https://supabase.com/dashboard
   - Vérifier que le projet est actif
   - Copier la nouvelle clé API si nécessaire

2. **Tester la Clé API** :
   ```bash
   # Test direct avec curl
   curl -H "apikey: VOTRE_CLE_API" \
        -H "Authorization: Bearer VOTRE_CLE_API" \
        https://nvuohqfsgeulivaihxeh.supabase.co/rest/v1/
   ```

3. **Contacter l'Équipe** :
   - Fournir les résultats du diagnostic
   - Mentionner les erreurs exactes
   - Inclure les logs de la console

## Commandes Utiles

```bash
# Vérifier le fichier .env
Get-Content .env | Select-String "SUPABASE"

# Tester la connectivité
ping nvuohqfsgeulivaihxeh.supabase.co

# Redémarrer le serveur
npm run dev

# Vérifier les variables d'environnement
echo $VITE_SUPABASE_URL
echo $VITE_SUPABASE_ANON_KEY
```

---

**Note** : Cette correction résout définitivement l'erreur "Invalid API key" et permet la connexion normale à Supabase.
