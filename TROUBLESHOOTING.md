# 🔧 Guide de Dépannage - Erreur de Connexion Supabase

## 🚨 Problème Identifié
Vous recevez l'erreur : **"An error occurred during login. Please try again."**

## 🔍 Causes Possibles

### 1. **Variables d'Environnement Manquantes ou Incorrectes**
- Les variables `VITE_SUPABASE_URL` et `VITE_SUPABASE_ANON_KEY` ne sont pas correctement configurées dans Netlify
- Les variables sont présentes mais avec des valeurs incorrectes

### 2. **Problème de Base de Données**
- L'utilisateur `pacifiquebashamuka@gmail.com` n'existe pas dans la table `auth.users`
- Le mot de passe est incorrect
- Le profil utilisateur n'existe pas dans la table `profiles`

### 3. **Configuration Supabase**
- Les politiques RLS (Row Level Security) bloquent l'accès
- La configuration d'authentification est incorrecte

## 🛠️ Solutions

### **Étape 1 : Vérifier les Variables d'Environnement**

#### Option A : Via l'Interface Netlify
1. **Aller sur** [https://app.netlify.com/](https://app.netlify.com/)
2. **Sélectionner** votre site
3. **Aller dans** Site settings > Environment variables
4. **Vérifier** que ces variables existent :
   ```
   VITE_SUPABASE_URL = https://nvuohqfsgeulivaihxeh.supabase.co
   VITE_SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM
   ```

#### Option B : Via Script PowerShell
```powershell
# Exécuter dans le dossier du projet
.\check-netlify-env.ps1
```

### **Étape 2 : Utiliser le Diagnostic Intégré**

1. **Aller sur** votre site déployé
2. **Sur la page de login**, vous verrez maintenant un composant de diagnostic
3. **Cliquer sur** "Run Supabase Diagnostic"
4. **Analyser** les résultats pour identifier le problème

### **Étape 3 : Vérifier la Base de Données**

#### A. Vérifier l'Utilisateur
```sql
-- Dans Supabase SQL Editor
SELECT * FROM auth.users WHERE email = 'pacifiquebashamuka@gmail.com';
```

#### B. Vérifier le Profil
```sql
-- Dans Supabase SQL Editor
SELECT * FROM profiles WHERE email = 'pacifiquebashamuka@gmail.com';
```

#### C. Créer l'Utilisateur si Nécessaire
```sql
-- Dans Supabase SQL Editor
INSERT INTO auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  role
) VALUES (
  gen_random_uuid(),
  'pacifiquebashamuka@gmail.com',
  crypt('admin', gen_salt('bf')),
  now(),
  now(),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{}',
  false,
  'authenticated'
);

-- Créer le profil
INSERT INTO profiles (id, email, role, created_at, updated_at)
SELECT 
  id,
  email,
  'admin',
  now(),
  now()
FROM auth.users 
WHERE email = 'pacifiquebashamuka@gmail.com';
```

### **Étape 4 : Vérifier les Politiques RLS**

```sql
-- Vérifier les politiques sur la table profiles
SELECT * FROM pg_policies WHERE tablename = 'profiles';

-- Si nécessaire, créer une politique pour l'authentification
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);
```

## 🔄 Redéploiement

Après avoir corrigé les variables d'environnement :

1. **Aller dans** Netlify Dashboard
2. **Cliquer sur** "Trigger deploy" ou "Deploy site"
3. **Attendre** que le déploiement se termine
4. **Tester** la connexion

## 🧪 Test de Connexion

### Test 1 : Diagnostic Intégré
- Utiliser le composant de diagnostic sur la page de login
- Vérifier tous les tests (variables, connexion, authentification, login)

### Test 2 : Console du Navigateur
```javascript
// Ouvrir la console du navigateur (F12)
// Exécuter ce code pour tester la connexion
const { createClient } = await import('@supabase/supabase-js');

const supabase = createClient(
  'https://nvuohqfsgeulivaihxeh.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM'
);

// Test de connexion
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'pacifiquebashamuka@gmail.com',
  password: 'admin'
});

console.log('Login result:', { data, error });
```

## 📞 Support

Si le problème persiste :

1. **Vérifier** les logs Netlify (Site settings > Functions > Logs)
2. **Vérifier** les logs Supabase (Dashboard > Logs)
3. **Utiliser** le composant de diagnostic pour identifier le problème exact
4. **Partager** les résultats du diagnostic pour obtenir de l'aide

## ✅ Checklist de Vérification

- [ ] Variables d'environnement correctement configurées dans Netlify
- [ ] Site redéployé après modification des variables
- [ ] Utilisateur existe dans `auth.users`
- [ ] Profil existe dans `profiles`
- [ ] Politiques RLS correctement configurées
- [ ] Diagnostic intégré exécuté sans erreur
- [ ] Test de connexion réussi

---

**Note :** Le composant de diagnostic a été ajouté à votre page de login pour faciliter le dépannage. Il vous donnera des informations détaillées sur l'état de la connexion Supabase.
