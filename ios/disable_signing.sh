#!/bin/bash

# Script pour désactiver la signature de code sur simulateur

# Aller dans le répertoire du projet
cd "$(dirname "$0")"

# Remplacer les paramètres de signature dans le projet
sed -i '' 's/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g' Runner.xcodeproj/project.pbxproj
sed -i '' 's/DEVELOPMENT_TEAM = L2Z4J59UCL;//g' Runner.xcodeproj/project.pbxproj

# Ajouter l'identité vide pour simulateur
sed -i '' '/CODE_SIGN_IDENTITY = "Apple Development";/a\
				"CODE_SIGN_IDENTITY[sdk=iphonesimulator*]" = "";
' Runner.xcodeproj/project.pbxproj

echo "Configuration de signature modifiée pour le simulateur"
