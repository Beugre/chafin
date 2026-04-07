/**
 * Diagnostic détaillé du prêt de Darlène
 */
const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const LOAN_ID = 'c05726f9-613b-4174-8544-68d71787d47f';

async function main() {
  console.log('=== Diagnostic prêt Darlène ===\n');

  // 1. Le prêt
  const loanDoc = await db.collection('loans').doc(LOAN_ID).get();
  const loan = loanDoc.data();
  console.log(`Prêt: ${loan.nomEmprunteur} - ${loan.montant}€ - ${loan.dureeMois} mois`);
  console.log(`Statut: ${loan.statut}`);
  console.log(`Taux: ${loan.tauxAnnuel}%`);
  console.log();

  // 2. Toutes les échéances (schedules)
  const schedules = await db.collection('schedules')
    .where('loanId', '==', LOAN_ID)
    .orderBy('numero')
    .get();

  console.log(`📊 ${schedules.size} échéances dans "schedules":\n`);
  for (const doc of schedules.docs) {
    const s = doc.data();
    const dueDate = s.dueDate?.toDate?.();
    const paidAt = s.paidAt?.toDate?.();
    console.log(`  #${s.numero} | ID: ${doc.id}`);
    console.log(`    dueDate: ${dueDate?.toLocaleDateString('fr-FR') || 'N/A'}`);
    console.log(`    total: ${s.total}€`);
    console.log(`    isPaid: ${s.isPaid}`);
    console.log(`    paidAt: ${paidAt?.toLocaleDateString('fr-FR') || 'null'}`);
    console.log(`    paidAmount: ${s.paidAmount || 'null'}`);
    console.log(`    hasPenalty: ${s.hasPenalty || false}`);
    console.log();
  }

  // 3. Vérifier aussi dans payment_schedules (ancien système)
  const paymentSchedules = await db.collection('payment_schedules').doc(LOAN_ID).get();
  if (paymentSchedules.exists) {
    console.log(`📋 Données dans "payment_schedules":`);
    console.log(JSON.stringify(paymentSchedules.data(), null, 2));
  } else {
    console.log(`📋 Aucune donnée dans "payment_schedules"`);
  }

  // 4. Vérifier les repayments
  const repayments = await db.collection('repayments')
    .where('loanId', '==', LOAN_ID)
    .get();

  console.log(`\n💰 ${repayments.size} remboursements (repayments):`);
  for (const doc of repayments.docs) {
    const r = doc.data();
    const date = r.paidAt?.toDate?.() || r.date?.toDate?.();
    console.log(`  - ${date?.toLocaleDateString('fr-FR') || 'N/A'} : ${r.amount || r.montant}€ (ID: ${doc.id})`);
  }

  process.exit(0);
}

main().catch(console.error);
