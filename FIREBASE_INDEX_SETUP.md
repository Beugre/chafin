# Configuration Firebase pour Chafin

## Index Composite Requis

Pour optimiser les performances des requêtes, Firebase nécessite un index composite pour la collection `loans`.

### Méthode 1: Via Console Firebase (Recommandée)

1. Allez sur [Firebase Console](https://console.firebase.google.com/project/chafin-23cad/firestore/indexes)
2. Cliquez sur "Créer un index"
3. Collection: `loans`
4. Ajoutez ces champs dans l'ordre :
   - `userId` (Croissant)
   - `createdAt` (Décroissant)
   - `__name__` (Croissant) - Ajouté automatiquement
5. Cliquez sur "Créer l'index"

### Méthode 2: Via firebase.json (Automatique)

Ajoutez ce fichier `firestore.indexes.json` à la racine du projet :

```json
{
  "indexes": [
    {
      "collectionGroup": "loans",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

Puis déployez avec : `firebase deploy --only firestore:indexes`

### Méthode 3: URL Directe

Cliquez sur ce lien généré par Firebase :
```
https://console.firebase.google.com/v1/r/project/chafin-23cad/firestore/indexes?create_composite=Ckpwcm9qZWN0cy9jaGFmaW4tMjNjYWQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2xvYW5zL2luZGV4ZXMvXxABGgoKBnVzZXJJZBABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI
```

## Statut Actuel

✅ **Solution temporaire appliquée** : Le tri par `createdAt` se fait maintenant côté client
🔄 **Solution optimale** : Créer l'index composite pour améliorer les performances

## Notes Importantes

- L'application fonctionne sans l'index (tri côté client)
- L'index améliore les performances pour de grandes collections
- La création d'index peut prendre quelques minutes à quelques heures selon la taille des données
