# Guide de Dépannage - Page Blanche Après Connexion

## Problème Identifié
Page blanche après connexion réussie, impossible de voir les modules.

## Cause Racine
**Imports manquants dans App.tsx** :
- `AdminInterface` - Composant d'administration
- `OTCInterface` - Module OTC (Order Tracking & Control)

## Solution Appliquée

### 1. Imports Ajoutés
```typescript
// Dans src/App.tsx
import { OTCInterface } from './components/OTCInterface';
import AdminInterface from './components/AdminInterface';
```

### 2. Vérification des Routes
Toutes les routes sont maintenant correctement définies :
- `/` → Dashboard
- `/admin` → AdminInterface
- `/otc` → OTCInterface
- `/project-calculation-settings` → ProjectCalculationSettings
- Et toutes les autres routes...

## Étapes de Diagnostic

### 1. Vérifier la Console du Navigateur
1. Ouvrir les outils de développement (F12)
2. Aller dans l'onglet "Console"
3. Chercher les erreurs JavaScript (en rouge)
4. Les erreurs communes :
   - `Module not found`
   - `Cannot read property of undefined`
   - `Component is not defined`

### 2. Vérifier l'Onglet Network
1. Aller dans l'onglet "Network"
2. Rafraîchir la page
3. Chercher les requêtes échouées (en rouge)
4. Vérifier que les fichiers JS/CSS se chargent

### 3. Vérifier l'État d'Authentification
1. Dans la console, taper :
   ```javascript
   // Vérifier l'état de l'utilisateur
   console.log('User:', window.localStorage.getItem('sb-nvuohqfsgeulivaihxeh-auth-token'));
   
   // Vérifier la session Supabase
   import { supabase } from './lib/supabase';
   supabase.auth.getSession().then(({data}) => console.log('Session:', data));
   ```

### 4. Vérifier les Composants
1. S'assurer que tous les composants existent :
   - `src/components/Dashboard.tsx`
   - `src/components/AdminInterface.tsx`
   - `src/components/OTCInterface.tsx`
   - `src/components/ProjectCalculationSettings.tsx`

## Solutions Alternatives

### Si le problème persiste :

#### 1. Vider le Cache du Navigateur
- Ctrl+Shift+R (Windows/Linux)
- Cmd+Shift+R (Mac)
- Ou vider le cache dans les paramètres du navigateur

#### 2. Vérifier les Variables d'Environnement
```bash
# Vérifier que le fichier .env existe
cat .env

# Doit contenir :
VITE_SUPABASE_URL=https://nvuohqfsgeulivaihxeh.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### 3. Redémarrer le Serveur de Développement
```bash
# Arrêter le serveur (Ctrl+C)
# Puis redémarrer
npm run dev
# ou
yarn dev
```

#### 4. Vérifier les Dépendances
```bash
# Réinstaller les dépendances
npm install
# ou
yarn install
```

## Tests de Validation

### 1. Test de Connexion
1. Se connecter avec des identifiants valides
2. Vérifier que la page Dashboard s'affiche
3. Vérifier que tous les modules sont visibles

### 2. Test de Navigation
1. Cliquer sur chaque module
2. Vérifier que la navigation fonctionne
3. Vérifier que les composants se chargent

### 3. Test des Permissions
1. Tester avec un utilisateur admin
2. Tester avec un utilisateur normal
3. Vérifier que les accès sont corrects

## Messages d'Erreur Courants

### "Module not found"
- **Cause** : Import manquant ou chemin incorrect
- **Solution** : Vérifier les imports dans App.tsx

### "Cannot read property of undefined"
- **Cause** : Objet non initialisé
- **Solution** : Vérifier l'état d'authentification

### "Component is not defined"
- **Cause** : Composant non exporté correctement
- **Solution** : Vérifier l'export du composant

## Prévention Future

### 1. Vérifications Automatiques
- Ajouter des tests unitaires pour les imports
- Utiliser TypeScript strict mode
- Vérifier les imports lors des commits

### 2. Documentation
- Maintenir une liste des composants requis
- Documenter les dépendances entre composants
- Créer des guides de dépannage

### 3. Monitoring
- Surveiller les erreurs JavaScript en production
- Utiliser des outils de monitoring (Sentry, etc.)
- Logs détaillés pour le debugging

## Contact Support

Si le problème persiste après ces étapes :
1. Collecter les logs de la console
2. Prendre des captures d'écran
3. Noter les étapes de reproduction
4. Contacter l'équipe de développement

---

**Note** : Ce guide est spécifique au problème de page blanche causé par des imports manquants. D'autres causes peuvent nécessiter des solutions différentes.
