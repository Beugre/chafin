<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Chafin Loans - Instructions pour GitHub Copilot

## Contexte du projet
Application Flutter de prêts entre particuliers avec Firebase, incluant :
- Gestion d'authentification (emprunteurs, admin, super-admin)
- Calculs de taux d'intérêt selon des règles métier spécifiques
- Génération d'échéanciers et de contrats PDF
- Interface admin pour validation et suivi des prêts

## Règles de calcul importantes
### Taux de base par montant :
- 10% pour 10€ ≤ montant ≤ 2 000€
- 5% pour 2 001€ ≤ montant ≤ 10 000€
- 2,5% pour montant > 10 000€

### Coefficient de durée :
- ≤ 12 mois → coefficient 1,0
- 12 < durée < 24 mois → coefficient 1,5
- ≥ 24 mois → coefficient 2,0

### Formule finale :
`taux_effectif_annuel = taux_base(montant) × coefficient_durée(durée)`

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
