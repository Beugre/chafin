/**
 * Script pour regénérer l'échéancier d'Yvann (prêt 970€)
 * - Supprime les anciennes échéances
 * - Crée 5 nouvelles échéances avec dates fin de mois
 * - Marque la 1ère échéance (31 déc 2025) comme payée
 */

const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const LOAN_ID = '1b434d9e-f9c9-447b-8df0-d85fa7c76ee7';

// Données du prêt
const MONTANT = 970;
const DUREE_MOIS = 5;
const TAUX = 15; // 15%
const INTERETS_TOTAL = MONTANT * (TAUX / 100); // 145.50€
const MONTANT_TOTAL = MONTANT + INTERETS_TOTAL; // 1115.50€
const MENSUALITE = MONTANT_TOTAL / DUREE_MOIS; // 223.10€
const PRINCIPAL_PAR_MOIS = MONTANT / DUREE_MOIS; // 194.00€
const INTERET_PAR_MOIS = INTERETS_TOTAL / DUREE_MOIS; // 29.10€

// Dates fin de mois (à partir du 31 décembre 2025)
const DATES_FIN_MOIS = [
  new Date(2025, 11, 31), // 31 décembre 2025
  new Date(2026, 0, 31),  // 31 janvier 2026
  new Date(2026, 1, 28),  // 28 février 2026
  new Date(2026, 2, 31),  // 31 mars 2026
  new Date(2026, 3, 30),  // 30 avril 2026
];

async function main() {
  console.log('=== Régénération échéancier Yvann - Prêt 970€ ===\n');

  // 1. Vérifier le prêt
  const loanDoc = await db.collection('loans').doc(LOAN_ID).get();
  if (!loanDoc.exists) {
    console.error('❌ Prêt non trouvé !');
    process.exit(1);
  }
  const loan = loanDoc.data();
  console.log(`✅ Prêt trouvé: ${loan.nomEmprunteur} - ${loan.montant}€ - ${loan.dureeMois} mois`);
  console.log(`   Taux: ${loan.tauxAnnuel}% | Mensualité: ${loan.mensualite}€\n`);

  // 2. Supprimer les anciennes échéances
  console.log('🗑️  Suppression des anciennes échéances...');
  const oldSchedules = await db.collection('schedules')
    .where('loanId', '==', LOAN_ID)
    .get();

  const batch = db.batch();
  let deleteCount = 0;
  
  for (const doc of oldSchedules.docs) {
    const data = doc.data();
    console.log(`   Suppression: Échéance #${data.numero} - ${data.dueDate?.toDate?.()?.toLocaleDateString('fr-FR') || 'N/A'}`);
    batch.delete(doc.ref);
    deleteCount++;
  }
  
  console.log(`   → ${deleteCount} échéances supprimées\n`);

  // 3. Créer les nouvelles échéances
  console.log('📝 Création des nouvelles échéances (fin de mois)...');
  
  for (let i = 0; i < DUREE_MOIS; i++) {
    const isPremiere = (i === 0);
    const date = DATES_FIN_MOIS[i];
    
    const scheduleData = {
      loanId: LOAN_ID,
      numero: i + 1,
      dueDate: admin.firestore.Timestamp.fromDate(date),
      principal: Math.round(PRINCIPAL_PAR_MOIS * 100) / 100,
      interet: Math.round(INTERET_PAR_MOIS * 100) / 100,
      total: Math.round(MENSUALITE * 100) / 100,
      isPaid: isPremiere, // 1ère échéance marquée comme payée
      paidAt: isPremiere ? admin.firestore.Timestamp.fromDate(new Date(2025, 11, 31)) : null,
      paidAmount: isPremiere ? Math.round(MENSUALITE * 100) / 100 : null,
      hasPenalty: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Utiliser un ID structuré pour compatibilité avec le code Flutter
    const docId = `${LOAN_ID}_${i + 1}`;
    batch.set(db.collection('schedules').doc(docId), scheduleData);

    const statusEmoji = isPremiere ? '✅ PAYÉE' : '⏳ À venir';
    console.log(`   Échéance #${i + 1}: ${date.toLocaleDateString('fr-FR')} - ${scheduleData.total}€ [${statusEmoji}]`);
  }

  // 4. Exécuter le batch
  await batch.commit();

  console.log('\n🎉 Échéancier regénéré avec succès !');
  console.log('\n📊 Résumé:');
  console.log(`   Capital: ${MONTANT}€`);
  console.log(`   Intérêts: ${INTERETS_TOTAL}€`);
  console.log(`   Total à rembourser: ${MONTANT_TOTAL}€`);
  console.log(`   Mensualité: ${Math.round(MENSUALITE * 100) / 100}€`);
  console.log(`   1ère échéance (31/12/2025): PAYÉE ✅`);
  console.log(`   Échéances restantes: ${DUREE_MOIS - 1}`);

  // 5. Vérification
  console.log('\n🔍 Vérification...');
  const newSchedules = await db.collection('schedules')
    .where('loanId', '==', LOAN_ID)
    .orderBy('numero')
    .get();

  for (const doc of newSchedules.docs) {
    const data = doc.data();
    const date = data.dueDate?.toDate?.()?.toLocaleDateString('fr-FR') || 'N/A';
    const paid = data.isPaid ? '✅' : '⏳';
    console.log(`   [${paid}] #${data.numero} - ${date} - ${data.total}€ (ID: ${doc.id})`);
  }

  process.exit(0);
}

main().catch(console.error);
