// Script pour supprimer les échéanciers des prêts annulés, refusés et fermés
// Ces prêts ne devraient pas avoir d'échéancier actif
const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function cleanupCancelledLoanSchedules() {
  console.log('=== NETTOYAGE DES ÉCHÉANCIERS DE PRÊTS ANNULÉS/REFUSÉS ===\n');

  // Statuts qui ne devraient pas avoir d'échéancier
  const inactiveStatuses = ['annule', 'refuse'];

  const loansSnap = await db.collection('loans').get();
  let totalDeleted = 0;

  for (const loanDoc of loansSnap.docs) {
    const loan = loanDoc.data();
    const loanId = loanDoc.id;
    const statut = loan.statut;

    if (!inactiveStatuses.includes(statut)) continue;

    // Chercher les échéances de ce prêt
    const schedulesSnap = await db.collection('schedules')
      .where('loanId', '==', loanId)
      .get();

    if (schedulesSnap.empty) continue;

    // Récupérer le nom de l'emprunteur
    let borrowerName = 'Inconnu';
    try {
      const userDoc = await db.collection('users').doc(loan.emprunteurId || loan.userId).get();
      if (userDoc.exists) borrowerName = userDoc.data().nom || 'Inconnu';
    } catch (e) {}

    console.log(`🗑️  ${borrowerName} - ${loan.montant}€ (${statut}) : ${schedulesSnap.size} échéances à supprimer`);

    // Supprimer par batch
    const batch = db.batch();
    for (const schedDoc of schedulesSnap.docs) {
      batch.delete(schedDoc.ref);
    }
    await batch.commit();

    totalDeleted += schedulesSnap.size;
    console.log(`   ✅ ${schedulesSnap.size} échéances supprimées`);
  }

  console.log(`\n=== RÉSULTAT : ${totalDeleted} échéances orphelines supprimées ===`);
  process.exit(0);
}

cleanupCancelledLoanSchedules().catch(e => { console.error(e); process.exit(1); });
