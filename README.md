# Chafin - Application de Prêts entre Particuliers

Application Flutter complète pour la gestion de prêts entre particuliers avec Firebase comme backend.

## 🚀 Fonctionnalités

### Pour les Emprunteurs
- ✅ Inscription et connexion sécurisées
- ✅ Demande de prêt avec calcul automatique des taux
- ✅ Suivi des remboursements
- ✅ Génération d'échéanciers de paiement
- 🔄 Téléchargement de documents justificatifs
- 🔄 Génération de contrats PDF

### Pour les Administrateurs
- ✅ Dashboard de gestion des prêts
- ✅ Validation/refus des demandes
- ✅ Suivi des performances
- 🔄 Génération de rapports
- 🔄 Gestion des utilisateurs

## 📊 Règles de Calcul des Taux

### Taux de Base par Montant
- **10%** pour 10€ ≤ montant ≤ 2 000€
- **5%** pour 2 001€ ≤ montant ≤ 10 000€
- **2,5%** pour montant > 10 000€

### Coefficient de Durée
- **≤ 12 mois** → coefficient 1,0
- **12 < durée < 24 mois** → coefficient 1,5
- **≥ 24 mois** → coefficient 2,0

### Formule Finale
```
Taux Effectif Annuel = Taux Base(montant) × Coefficient Durée(durée)
```

## 🏗️ Architecture

```
lib/
├── models/           # Modèles de données (User, Loan, Schedule)
├── services/         # Logique métier (Auth, Loan, Calculations)
├── providers/        # Gestion d'état avec Provider
├── screens/          # Interfaces utilisateur
│   ├── auth/         # Écrans d'authentification
│   ├── borrower/     # Écrans emprunteur
│   └── admin/        # Écrans administrateur
├── utils/            # Utilitaires (Router, Constants)
└── main.dart         # Point d'entrée
```

## � Installation

### Prérequis
- Flutter 3.32.8+
- Dart 3.5.8+
- Firebase CLI
- Compte Firebase

### Configuration

1. **Cloner le projet**
```bash
git clone <repository-url>
cd Chafin
```

2. **Installer les dépendances**
```bash
flutter pub get
```

3. **Configuration Firebase**
   - Créer un projet Firebase
   - Activer Authentication, Firestore, Storage
   - Télécharger le fichier de configuration
   - Remplacer `firebase-service-account.json`

4. **Générer les fichiers**
```bash
dart run build_runner build
```

5. **Lancer l'application**
```bash
flutter run
```

## 🧪 Tests

### Tests Unitaires
```bash
flutter test
```

### Tests de Calculs
Le projet inclut 16 tests unitaires couvrant tous les scénarios de calcul de taux :
- Tests par tranche de montant
- Tests par coefficient de durée
- Tests des 5 exemples de spécification

### Tests d'Intégration Firebase
Utilisez l'écran `/debug` pour :
- Tester la connexion Firebase
- Initialiser des données de test
- Lister les utilisateurs
- Nettoyer les données

## 🔐 Sécurité

### Règles Firestore
```javascript
// Utilisateurs : lecture/écriture de ses propres données
// Admins : lecture de tous les utilisateurs
// Super-admins : écriture complète

// Prêts : emprunteurs voient leurs prêts
// Admins : accès complet pour validation
```

### Règles Storage
```javascript
// Documents : téléchargement par propriétaire seulement
// Admins : accès lecture pour validation
// Contrôle de taille et type de fichier
```

## 🚀 Déploiement

### Développement
```bash
flutter run -d web
```

### Production
```bash
./deploy.sh prod
```

Le script de déploiement :
1. Vérifie les prérequis
2. Build l'application web
3. Déploie les règles et index Firestore
4. Déploie l'application sur Firebase Hosting

## 📱 Comptes de Test

### Administrateur
- **Email:** admin@chafin.com
- **Mot de passe:** admin123

### Emprunteur
- **Email:** emprunteur@test.com
- **Mot de passe:** test123

*Ces comptes sont créés automatiquement via l'écran de debug*

## 🔍 Debug et Développement

### Écran de Debug (`/debug`)
Accessible depuis l'écran de connexion, permet de :
- Tester la connexion Firebase
- Initialiser des données de test
- Lister les utilisateurs en base
- Supprimer toutes les données

### Logs Firebase
```bash
firebase functions:log
```

### Monitoring
- Console Firebase pour les métriques
- Crashlytics pour les erreurs (à configurer)

## 📦 Dépendances Principales

```yaml
dependencies:
  flutter: sdk
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  firebase_storage: ^12.3.4
  provider: ^6.1.2
  go_router: ^14.6.2
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test: sdk
  build_runner: ^2.4.13
  json_serializable: ^6.8.0
```

## 🤝 Contribution

### Structure des Commits
```
type(scope): description

Types: feat, fix, docs, style, refactor, test, chore
Scopes: auth, loan, calc, ui, firebase
```

### Standards de Code
- Utiliser `dart format`
- Respecter les règles de linting
- Tests obligatoires pour la logique métier
- Documentation des fonctions complexes

## � Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 📞 Support

Pour toute question ou problème :
1. Vérifier la documentation
2. Consulter les logs Firebase
3. Utiliser l'écran de debug
4. Contacter l'équipe de développement

---

**Version actuelle:** 1.0.0  
**Dernière mise à jour:** Janvier 2025  
**Statut:** ✅ Production Ready
