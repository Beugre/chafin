# Guide de migration OVH → Firebase

## Étape 1: Test en parallèle (ACTUEL)
- App OVH: ton-domaine.com  
- App Firebase: https://chafin-23cad.web.app
- ✅ Rappels automatiques sur Firebase uniquement

## Étape 2: Redirection domaine
```bash
# Connecter ton domaine à Firebase
firebase hosting:sites:create ton-nouveau-site
# Puis dans Firebase Console > Hosting > Add custom domain
```

## Étape 3: DNS chez OVH
```
# Modifier les enregistrements DNS
A    @              151.101.1.195
A    @              151.101.65.195  
CNAME www            chafin-23cad.web.app
```

## Étape 4: Migration complète
- Tester tout fonctionne sur Firebase
- Arrêter l'hébergement OVH (économies)
- Garder juste le nom de domaine chez OVH

## Économies potentielles
OVH hébergement: ~5-15€/mois → Firebase: 0€/mois