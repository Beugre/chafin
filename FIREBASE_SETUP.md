# 🔥 Configuration Firebase Authentication

## Problème identifié
L'erreur `FirebaseAuthException: configuration-not-found` indique que l'authentification Firebase n'est pas correctement configurée pour le web.

## ✅ Solutions à appliquer

### 1. Activer l'Authentification Email/Mot de passe

Dans la Console Firebase :
1. Allez sur **Authentication** > **Sign-in method**
2. Cliquez sur **Email/Password**
3. **Activez** la première option (Email/password)
4. **Sauvegardez**

### 2. Configurer les Domaines Autorisés

Dans **Authentication** > **Settings** > **Authorized domains** :
1. Ajoutez `localhost` si pas déjà présent
2. Ajoutez `127.0.0.1` si pas déjà présent  
3. Ajoutez `chafin-23cad.web.app`
4. Ajoutez `chafin-23cad.firebaseapp.com`

### 3. Vérifier la Configuration Web

Dans **Project Settings** > **General** > **Your apps** :
1. Vérifiez que l'app Web est bien enregistrée
2. Notez l'App ID : `1:314923488171:web:a1d494c389c229d8caf8ee`
3. Si nécessaire, re-téléchargez la config

### 4. Tester depuis localhost

L'application doit fonctionner depuis :
- `http://localhost:PORT` (Flutter development)
- `http://127.0.0.1:PORT` (alternative)

## 🚀 Commandes pour tester

```bash
# 1. Tester l'application normale
flutter run -d chrome

# 2. Tester avec le fichier de debug Firebase
flutter run -t lib/firebase_test.dart -d chrome

# 3. Vérifier la console Firebase
open "https://console.firebase.google.com/project/chafin-23cad/authentication"
```

## 🐞 Debug supplémentaire

Si le problème persiste :

1. **Vérifier les règles Firestore** (déjà fait ✅)
2. **Regénérer firebase_options.dart** :
   ```bash
   flutterfire configure
   ```
3. **Nettoyer et rebuilder** :
   ```bash
   flutter clean
   flutter pub get
   flutter run -d chrome
   ```

## 📞 Support

- Console Firebase: https://console.firebase.google.com/project/chafin-23cad
- Documentation: https://firebase.google.com/docs/auth/web/start
