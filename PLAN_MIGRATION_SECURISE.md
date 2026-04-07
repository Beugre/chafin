# Plan de migration sécurisé OVH → Firebase

## Phase 1: Coexistence (MAINTENANT - 1-2 semaines)
✅ OVH: ton-domaine.com (version actuelle)  
✅ Firebase: https://chafin.web.app (version avec rappels) ← NOUVELLE URL
- Les utilisateurs utilisent OVH
- Tu testes Firebase en interne sur la nouvelle URL propre
- Pas de conflit DNS

## Phase 2: Tests utilisateurs (Optionnel)
- Donner le lien Firebase à quelques utilisateurs test
- Valider que tout fonctionne parfaitement
- Tester les rappels automatiques

## Phase 3: Migration DNS (1 jour J)
MATIN:
1. Dans Firebase Console > Hosting > Add custom domain
2. Noter les DNS Firebase (ex: 151.101.1.195)

APRÈS-MIDI:
3. Chez OVH > DNS > Modifier les enregistrements A
   - Anciens: 198.51.100.x (OVH)  
   - Nouveaux: 151.101.1.195 (Firebase)
4. Attendre propagation DNS (2-48h)
5. Supprimer l'hébergement OVH une fois confirmé

## Phase 4: Nettoyage
- Garder juste le nom de domaine chez OVH (quelques €/an)
- Supprimer l'hébergement web OVH
- Firebase devient la solution unique

## ⚠️ Backup de sécurité
- Garder les fichiers OVH 48h après migration
- En cas de problème, retour rapide possible