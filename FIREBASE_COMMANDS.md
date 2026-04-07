# Scripts de déploiement Firebase

## Déploiement complet
firebase deploy

## Déploiement de l'app web uniquement
firebase deploy --only hosting

## Déploiement des fonctions uniquement  
firebase deploy --only functions

## Rebuild + déploiement web
flutter build web && firebase deploy --only hosting

## Monitoring des Cloud Functions
firebase functions:log

## Test local des fonctions
cd functions && npm run serve

## Vérifier l'état du projet
firebase projects:list
firebase use --add