/**
 * Vérifie s'il existe des documents schedules avec ID structuré (loanId_numero)
 * en plus des documents avec ID auto-générés
 */
const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const LOAN_ID = 'c05726f9-613b-4174-8544-68d71787d47f';

async function main() {
  console.log('=== Recherche de doublons schedules Darlène ===\n');

  // Chercher avec ID structuré
  for (let i = 1; i <= 4; i++) {
    const docId = `${LOAN_ID}_${i}`;
    const doc = await db.collection('schedules').doc(docId).get();
    if (doc.exists) {
      const d = doc.data();
      console.log(`✅ TROUVÉ: ${docId}`);
      console.log(`   isPaid: ${d.isPaid}, paidAt: ${d.paidAt?.toDate?.()?.toLocaleDateString('fr-FR') || 'null'}`);
      console.log(`   total: ${d.total || 'N/A'}, loanId: ${d.loanId || 'N/A'}`);
      console.log(`   Toutes les données: ${JSON.stringify(d, null, 4)}\n`);
    } else {
      console.log(`❌ NON TROUVÉ: ${docId}`);
    }
  }

  // Aussi lister TOUS les schedules liés à ce prêt
  console.log('\n--- Tous les schedules avec loanId ---');
  const allSchedules = await db.collection('schedules')
    .where('loanId', '==', LOAN_ID)
    .get();
  
  console.log(`Total: ${allSchedules.size} documents`);
  for (const doc of allSchedules.docs) {
    const d = doc.data();
    console.log(`  ID: ${doc.id} | #${d.numero} | isPaid: ${d.isPaid} | total: ${d.total}`);
  }

  process.exit(0);
}

main().catch(console.error);
