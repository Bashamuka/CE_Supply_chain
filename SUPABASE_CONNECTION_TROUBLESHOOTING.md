# Guide de Dépannage - Erreur de Connexion Supabase

## Problème Identifié
**Erreur** : `"Error: Failed to fetch (api.supabase.com)"`

## Causes Possibles

### 1. Fichier .env Manquant
**Symptôme** : L'application ne peut pas se connecter à Supabase
**Cause** : Le fichier `.env` n'existe pas ou est mal configuré

### 2. Variables d'Environnement Incorrectes
**Symptôme** : Connexion échoue avec des erreurs d'authentification
**Cause** : URL ou clé API incorrectes

### 3. Problème de Réseau
**Symptôme** : Erreur de fetch générique
**Cause** : Connexion internet ou firewall bloquant

### 4. Service Supabase Indisponible
**Symptôme** : Erreur temporaire
**Cause** : Maintenance ou problème côté Supabase

## Solutions

### Solution 1 : Créer le Fichier .env

**Étape 1** : Créer le fichier `.env` dans la racine du projet
```bash
# Dans le dossier CE_Supply_chain/
touch .env
```

**Étape 2** : Ajouter le contenu suivant
```env
VITE_SUPABASE_URL=https://nvuohqfsgeulivaihxeh.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM
```

**Étape 3** : Redémarrer le serveur de développement
```bash
npm run dev
# ou
yarn dev
```

### Solution 2 : Vérifier les Variables d'Environnement

**Vérification dans le navigateur** :
1. Ouvrir les outils de développement (F12)
2. Aller dans l'onglet "Console"
3. Taper : `console.log(import.meta.env.VITE_SUPABASE_URL)`
4. Vérifier que l'URL s'affiche correctement

**Vérification dans le code** :
```typescript
// Dans src/lib/supabase.ts
console.log('Supabase URL:', import.meta.env.VITE_SUPABASE_URL);
console.log('Supabase Key:', import.meta.env.VITE_SUPABASE_ANON_KEY);
```

### Solution 3 : Tester la Connexion Réseau

**Test de connectivité** :
```bash
# Tester la connexion à Supabase
ping nvuohqfsgeulivaihxeh.supabase.co

# Tester l'API Supabase
curl -I https://api.supabase.com
```

**Test dans le navigateur** :
1. Ouvrir https://nvuohqfsgeulivaihxeh.supabase.co
2. Vérifier que la page se charge
3. Vérifier qu'il n'y a pas d'erreurs CORS

### Solution 4 : Vérifier le Statut Supabase

**Vérifier le statut du service** :
1. Aller sur https://status.supabase.com
2. Vérifier qu'il n'y a pas de problèmes signalés
3. Attendre si c'est une maintenance

## Diagnostic Avancé

### 1. Vérifier les Logs de la Console
```javascript
// Dans la console du navigateur
console.log('Environment check:', {
  url: import.meta.env.VITE_SUPABASE_URL,
  key: import.meta.env.VITE_SUPABASE_ANON_KEY ? 'Present' : 'Missing'
});
```

### 2. Tester la Connexion Supabase
```javascript
// Dans la console du navigateur
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://nvuohqfsgeulivaihxeh.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM';

const supabase = createClient(supabaseUrl, supabaseKey);

// Tester la connexion
supabase.auth.getSession().then(({data, error}) => {
  if (error) {
    console.error('Supabase connection error:', error);
  } else {
    console.log('Supabase connected successfully');
  }
});
```

### 3. Vérifier les Erreurs CORS
Si vous voyez des erreurs CORS :
1. Vérifier que l'URL Supabase est correcte
2. Vérifier que la clé API est valide
3. Vérifier les paramètres CORS dans Supabase Dashboard

## Prévention

### 1. Fichier .env.example
Créer un fichier `.env.example` avec les variables requises :
```env
VITE_SUPABASE_URL=your_supabase_url_here
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

### 2. Validation des Variables
Ajouter une validation dans `src/lib/supabase.ts` :
```typescript
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Missing Supabase environment variables');
  throw new Error('Supabase credentials are missing. Please check your .env file.');
}

// Validation de l'URL
if (!supabaseUrl.startsWith('https://')) {
  throw new Error('Supabase URL must start with https://');
}
```

### 3. Monitoring
Ajouter des logs pour surveiller les connexions :
```typescript
console.log('Supabase client initialized:', {
  url: supabaseUrl,
  hasKey: !!supabaseAnonKey
});
```

## Support Technique

Si le problème persiste :

1. **Vérifier les logs** de la console du navigateur
2. **Tester la connectivité** réseau
3. **Vérifier le statut** de Supabase
4. **Redémarrer** le serveur de développement
5. **Vider le cache** du navigateur
6. **Contacter l'équipe** de développement

## Commandes Utiles

```bash
# Redémarrer le serveur
npm run dev

# Vérifier les variables d'environnement
echo $VITE_SUPABASE_URL

# Tester la connectivité
ping nvuohqfsgeulivaihxeh.supabase.co

# Vérifier les fichiers
ls -la | grep .env
```

---

**Note** : Cette erreur est généralement causée par un fichier `.env` manquant ou mal configuré. La solution la plus courante est de créer le fichier `.env` avec les bonnes variables d'environnement.
