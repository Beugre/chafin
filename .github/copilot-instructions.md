<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Chafin Loans - Instructions pour GitHub Copilot

## Contexte du projet
Application Flutter de prêts entre particuliers avec Firebase, incluant :
- Gestion d'authentification (emprunteurs, admin, super-admin)
- Calculs de taux d'intérêt selon des règles métier spécifiques
- Génération d'échéanciers et de contrats PDF
- Interface admin pour validation et suivi des prêts

## Règles de calcul importantes
### Taux d'intérêt selon la durée (règle en vigueur) :
- 1 mois (remboursement en une fois) → 5%
- 2 à 4 mensualités → 10%
- 5 à 6 mensualités → 15%

### Durée autorisée :
- Minimum : 1 mois
- Maximum : 6 mois

### Niveau de confiance (multiplicateur de risque) :
- 4-5/5 (faible risque) → taux ÷ 2
- 2-3/5 (normal) → taux inchangé
- 1/5 (gros risque) → taux × 2

### Formule :
`taux_effectif = taux_duree(dureeMois) × multiplicateur_risque(niveauConfiance)`
`mensualité = (capital + capital × taux_effectif / 100) / dureeMois`

## Architecture
- Utilise Provider pour la gestion d'état
- Firebase Auth pour l'authentification
- Firestore pour les données
- Go Router pour la navigation
- Structure MVVM avec des services séparés

## Bonnes pratiques
- Utiliser des constantes pour les seuils et taux
- Implémenter des tests unitaires pour les calculs
- Respecter les principes de clean architecture
- Documenter les formules mathématiques complexes
