#!/bin/bash

# Script utilitaire pour le développement Chafin
# Usage: ./dev.sh [command]

set -e

PROJECT_DIR="/Users/yoannbeugre/Documents/Documents - MacBook Pro de Yoann/DEV/Chafin"
cd "$PROJECT_DIR"

# Fonction d'aide
show_help() {
    echo "📱 Script de développement Chafin"
    echo ""
    echo "Usage: ./dev.sh [COMMAND]"
    echo ""
    echo "Commandes disponibles:"
    echo "  setup     - Configuration initiale du projet"
    echo "  run       - Lancer l'app sur Chrome"
    echo "  run-ios   - Lancer l'app sur iOS"
    echo "  build     - Générer les fichiers et builder"
    echo "  test      - Lancer les tests"
    echo "  clean     - Nettoyer le projet"
    echo "  firebase  - Initialiser Firebase"
    echo "  deploy    - Déployer en production"
    echo "  help      - Afficher cette aide"
    echo ""
}

# Configuration initiale
setup_project() {
    echo "🔧 Configuration initiale du projet..."
    
    echo "📦 Installation des dépendances Flutter..."
    flutter pub get
    
    echo "🏗️  Génération des fichiers..."
    dart run build_runner build --delete-conflicting-outputs
    
    echo "🔥 Configuration Firebase..."
    if ! command -v firebase &> /dev/null; then
        echo "📥 Installation Firebase CLI..."
        npm install -g firebase-tools
    fi
    
    echo "✅ Configuration terminée !"
    echo "💡 Utilisez './dev.sh run' pour lancer l'application"
}

# Lancer sur Chrome
run_chrome() {
    echo "🚀 Lancement sur Chrome..."
    flutter run -d chrome
}

# Lancer sur iOS
run_ios() {
    echo "🚀 Lancement sur iOS..."
    flutter run -d ios
}

# Builder le projet
build_project() {
    echo "🏗️  Build du projet..."
    
    echo "📦 Nettoyage..."
    flutter clean
    flutter pub get
    
    echo "🔨 Génération des fichiers..."
    dart run build_runner build --delete-conflicting-outputs
    
    echo "📱 Build web..."
    flutter build web --release
    
    echo "✅ Build terminé !"
}

# Lancer les tests
run_tests() {
    echo "🧪 Lancement des tests..."
    flutter test --coverage
    echo "📊 Rapport de couverture généré dans coverage/"
}

# Nettoyer le projet
clean_project() {
    echo "🧹 Nettoyage du projet..."
    flutter clean
    rm -rf build/
    rm -rf .dart_tool/
    rm -rf coverage/
    echo "✅ Projet nettoyé !"
}

# Initialiser Firebase
setup_firebase() {
    echo "🔥 Configuration Firebase..."
    
    echo "🔐 Connexion Firebase..."
    firebase login --no-localhost
    
    echo "📋 Sélection du projet..."
    firebase use chafin-23cad
    
    echo "📊 Déploiement des règles..."
    firebase deploy --only firestore:rules,firestore:indexes,storage
    
    echo "✅ Firebase configuré !"
}

# Déployer
deploy_app() {
    echo "🚀 Déploiement en production..."
    ./deploy.sh prod
}

# Router selon la commande
case "${1:-help}" in
    "setup")
        setup_project
        ;;
    "run")
        run_chrome
        ;;
    "run-ios")
        run_ios
        ;;
    "build")
        build_project
        ;;
    "test")
        run_tests
        ;;
    "clean")
        clean_project
        ;;
    "firebase")
        setup_firebase
        ;;
    "deploy")
        deploy_app
        ;;
    "help"|*)
        show_help
        ;;
esac
