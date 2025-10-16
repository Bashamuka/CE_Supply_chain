# Guide de Dépannage - Problèmes de Connexion

## Problème Identifié
**Symptôme** : "An error occurred during login. Please try again." malgré un compte valide

## Causes Possibles

### 1. Problème de Configuration Supabase
**Symptôme** : Erreur générique lors de la connexion
**Causes** :
- Fichier `.env` manquant ou incorrect
- Variables d'environnement mal configurées
- Clé API Supabase invalide ou expirée

### 2. Problème de Compte Utilisateur
**Symptôme** : Connexion échoue avec des identifiants corrects
**Causes** :
- Email non confirmé
- Compte suspendu ou désactivé
- Profil utilisateur manquant dans la table `profiles`

### 3. Problème de Base de Données
**Symptôme** : Connexion réussit mais profil non trouvé
**Causes** :
- Table `profiles` manquante
- Politiques RLS bloquant l'accès
- Données corrompues

### 4. Problème de Réseau
**Symptôme** : Erreur de fetch ou timeout
**Causes** :
- Connexion internet instable
- Firewall bloquant Supabase
- Problème côté Supabase

## Solutions Détaillées

### Solution 1 : Vérifier la Configuration Supabase

**Étape 1** : Vérifier le fichier `.env`
```bash
# Vérifier que le fichier existe
ls -la .env

# Vérifier le contenu
cat .env
```

**Étape 2** : Vérifier les variables dans le navigateur
```javascript
// Dans la console du navigateur (F12)
console.log('Supabase URL:', import.meta.env.VITE_SUPABASE_URL);
console.log('Supabase Key:', import.meta.env.VITE_SUPABASE_ANON_KEY);
```

**Étape 3** : Tester la connexion Supabase
```javascript
// Dans la console du navigateur
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://nvuohqfsgeulivaihxeh.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

const supabase = createClient(supabaseUrl, supabaseKey);

// Tester la connexion
supabase.auth.getSession().then(({data, error}) => {
  if (error) {
    console.error('Supabase error:', error);
  } else {
    console.log('Supabase connected:', data);
  }
});
```

### Solution 2 : Vérifier le Compte Utilisateur

**Étape 1** : Vérifier l'email de confirmation
- Aller dans votre boîte email
- Chercher un email de confirmation de Supabase
- Cliquer sur le lien de confirmation si nécessaire

**Étape 2** : Vérifier le statut du compte
```sql
-- Dans Supabase SQL Editor
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  last_sign_in_at
FROM auth.users 
WHERE email = 'votre-email@example.com';
```

**Étape 3** : Vérifier le profil utilisateur
```sql
-- Vérifier si le profil existe
SELECT 
  id,
  email,
  role,
  created_at
FROM profiles 
WHERE email = 'votre-email@example.com';
```

### Solution 3 : Créer le Profil Utilisateur

**Si le profil n'existe pas** :
```sql
-- Créer le profil utilisateur
INSERT INTO profiles (id, email, role, created_at, updated_at)
SELECT 
  id,
  email,
  'employee', -- ou 'admin' selon vos besoins
  NOW(),
  NOW()
FROM auth.users 
WHERE email = 'votre-email@example.com'
AND id NOT IN (SELECT id FROM profiles);
```

### Solution 4 : Vérifier les Politiques RLS

**Vérifier les politiques sur la table profiles** :
```sql
-- Voir les politiques RLS
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'profiles';
```

**Créer une politique si nécessaire** :
```sql
-- Politique pour permettre la lecture des profils
CREATE POLICY "Users can view their own profile" ON profiles
FOR SELECT USING (auth.uid() = id);

-- Politique pour permettre la mise à jour des profils
CREATE POLICY "Users can update their own profile" ON profiles
FOR UPDATE USING (auth.uid() = id);
```

### Solution 5 : Diagnostic Automatique

**Utiliser le composant de diagnostic** :
1. Aller sur la page de connexion
2. Cliquer sur "Show Connection Diagnostic"
3. Cliquer sur "Run Diagnostic"
4. Analyser les résultats

**Tests effectués** :
- ✅ Variables d'environnement
- ✅ Client Supabase
- ✅ Connectivité réseau
- ✅ Service d'authentification
- ✅ Connexion base de données
- ✅ Service de connexion

## Actions Correctives

### Si le Diagnostic Échoue

**1. Problème de Variables d'Environnement** :
```bash
# Recréer le fichier .env
.\create_env_file.ps1  # Windows
./create_env_file.sh   # Linux/Mac
```

**2. Problème de Compte** :
- Vérifier l'email de confirmation
- Créer un nouveau compte si nécessaire
- Contacter l'administrateur

**3. Problème de Base de Données** :
- Vérifier les politiques RLS
- Créer le profil utilisateur manquant
- Vérifier la structure des tables

### Si le Diagnostic Réussit Mais la Connexion Échoue

**1. Vérifier les Identifiants** :
- S'assurer que l'email est correct
- Vérifier le mot de passe
- Essayer de réinitialiser le mot de passe

**2. Vérifier le Profil** :
- S'assurer que le profil existe dans la table `profiles`
- Vérifier que le rôle est correct

**3. Vérifier les Logs** :
- Ouvrir la console du navigateur (F12)
- Regarder les erreurs lors de la connexion
- Vérifier les requêtes réseau

## Prévention

### 1. Monitoring
- Surveiller les erreurs de connexion
- Vérifier régulièrement les politiques RLS
- Monitorer les performances Supabase

### 2. Tests Réguliers
- Tester la connexion périodiquement
- Vérifier les variables d'environnement
- Valider la structure de la base de données

### 3. Documentation
- Maintenir la liste des utilisateurs
- Documenter les politiques RLS
- Garder les guides de dépannage à jour

## Support Technique

Si le problème persiste :

1. **Collecter les informations** :
   - Résultats du diagnostic
   - Logs de la console
   - Messages d'erreur exacts

2. **Vérifier l'environnement** :
   - Version de Node.js
   - Version des dépendances
   - Configuration du navigateur

3. **Contacter l'équipe** :
   - Fournir les informations collectées
   - Décrire les étapes de reproduction
   - Mentionner les solutions déjà tentées

---

**Note** : Ce guide couvre les causes les plus courantes de problèmes de connexion. Le composant de diagnostic intégré peut aider à identifier rapidement le problème spécifique.
