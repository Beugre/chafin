#!/bin/bash

# Script de déploiement Firebase pour Chafin
# Usage: ./deploy.sh [env]
# Environnements disponibles: dev, prod

set -e

ENV=${1:-dev}
PROJECT_DIR="/Users/yoannbeugre/Documents/Documents - MacBook Pro de Yoann/DEV/Chafin"

echo "🚀 Déploiement Chafin - Environnement: $ENV"

# Vérification des prérequis
echo "📋 Vérification des prérequis..."

if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI non installé. Installation..."
    npm install -g firebase-tools
fi

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter non installé"
    exit 1
fi

# Changement vers le répertoire du projet
cd "$PROJECT_DIR"

echo "✅ Prérequis vérifiés"

# Configuration Firebase selon l'environnement
case $ENV in
    "dev")
        PROJECT_ID="chafin-23cad"
        ;;
    "prod")
        PROJECT_ID="chafin-23cad"  # Même projet pour l'instant
        ;;
    *)
        echo "❌ Environnement non supporté: $ENV"
        echo "Environnements disponibles: dev, prod"
        exit 1
        ;;
esac

echo "🔧 Configuration pour $ENV (projet: $PROJECT_ID)"

# Login Firebase
echo "🔐 Authentification Firebase..."
firebase login --no-localhost

# Sélection du projet
firebase use "$PROJECT_ID"

# Build Flutter Web
echo "🏗️  Build Flutter Web..."
flutter clean
flutter pub get
flutter build web --release

# Déploiement des règles Firestore
echo "📋 Déploiement des règles Firestore..."
firebase deploy --only firestore:rules

# Déploiement des index Firestore
echo "📊 Déploiement des index Firestore..."
firebase deploy --only firestore:indexes

# Déploiement des règles Storage
echo "📁 Déploiement des règles Storage..."
firebase deploy --only storage

# Déploiement du site web
echo "🌐 Déploiement de l'application web..."
firebase deploy --only hosting

echo ""
echo "✅ Déploiement terminé avec succès !"
echo ""
echo "🌍 Application disponible sur:"
echo "   https://$PROJECT_ID.web.app"
echo "   https://$PROJECT_ID.firebaseapp.com"
echo ""
echo "📊 Console Firebase:"
echo "   https://console.firebase.google.com/project/$PROJECT_ID"
echo ""

# Ouverture automatique dans le navigateur
read -p "Ouvrir l'application dans le navigateur ? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "https://$PROJECT_ID.web.app"
fi
