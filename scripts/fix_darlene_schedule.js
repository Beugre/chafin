/**
 * Diagnostic des repayments de Darlène + correction des échéances
 */
const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const LOAN_ID = 'c05726f9-613b-4174-8544-68d71787d47f';

async function main() {
  const MODE = process.argv[2] || 'check';
  console.log(`=== Diagnostic + correction Darlène (mode: ${MODE}) ===\n`);

  // 1. Détails des repayments
  const repayments = await db.collection('repayments')
    .where('loanId', '==', LOAN_ID)
    .get();

  console.log(`💰 ${repayments.size} remboursements trouvés:\n`);
  const paidSchedules = new Map(); // numero -> repayment data

  for (const doc of repayments.docs) {
    const r = doc.data();
    console.log(`  ID: ${doc.id}`);
    console.log(`    Données complètes: ${JSON.stringify(r, null, 6)}`);
    console.log();
    
    // Trouver le numéro de mensualité
    const numero = r.numeroMensualite || r.numero || r.scheduleNumber;
    if (numero) {
      paidSchedules.set(numero, r);
    }
  }

  // 2. Les échéances
  const schedules = await db.collection('schedules')
    .where('loanId', '==', LOAN_ID)
    .orderBy('numero')
    .get();

  console.log(`\n📊 Échéances à corriger:`);
  const batch = db.batch();
  let fixCount = 0;

  for (const doc of schedules.docs) {
    const s = doc.data();
    const dueDate = s.dueDate?.toDate?.();
    
    // Vérifier si un repayment correspond à cette échéance
    const repayment = paidSchedules.get(s.numero);
    
    console.log(`  #${s.numero} (${dueDate?.toLocaleDateString('fr-FR')}) - isPaid: ${s.isPaid} - repayment trouvé: ${!!repayment}`);
    
    if (!s.isPaid && repayment) {
      console.log(`    → À CORRIGER: marquer comme payée`);
      if (MODE === 'fix') {
        batch.update(doc.ref, {
          isPaid: true,
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          paidAmount: s.total,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        fixCount++;
      }
    }
  }

  // Si aucun repayment n'a de numéro, essayons de matcher par nombre
  if (paidSchedules.size === 0 && repayments.size > 0) {
    console.log(`\n⚠️ Aucun numéro de mensualité dans les repayments.`);
    console.log(`   ${repayments.size} paiements enregistrés pour ${schedules.size} échéances.`);
    console.log(`\n   Les ${repayments.size} premières échéances devraient être marquées payées.`);
    
    if (MODE === 'fix') {
      let i = 0;
      for (const doc of schedules.docs) {
        if (i >= repayments.size) break;
        const s = doc.data();
        if (!s.isPaid) {
          console.log(`   → Marquage #${s.numero} comme payée`);
          batch.update(doc.ref, {
            isPaid: true,
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
            paidAmount: s.total,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          fixCount++;
        }
        i++;
      }
    }
  }

  if (MODE === 'fix' && fixCount > 0) {
    await batch.commit();
    console.log(`\n✅ ${fixCount} échéances marquées comme payées`);
    
    // Vérifier si toutes les échéances sont payées pour mettre à jour le statut
    const updatedSchedules = await db.collection('schedules')
      .where('loanId', '==', LOAN_ID)
      .where('isPaid', '==', false)
      .get();
    
    if (updatedSchedules.empty) {
      console.log(`🎉 Toutes les échéances payées ! Passage du prêt en "enCours" (ou "solde")`);
      await db.collection('loans').doc(LOAN_ID).update({
        statut: 'solde',
        updatedAt: new Date().toISOString(),
      });
      console.log(`✅ Prêt marqué comme soldé`);
    } else {
      const hasOverdue = [];
      const now = new Date();
      for (const d of updatedSchedules.docs) {
        const dd = d.data().dueDate?.toDate?.();
        if (dd && dd < now) hasOverdue.push(dd);
      }
      
      if (hasOverdue.length === 0) {
        console.log(`✅ Plus d'échéance en retard → passage en "enCours"`);
        await db.collection('loans').doc(LOAN_ID).update({
          statut: 'enCours',
          updatedAt: new Date().toISOString(),
        });
      } else {
        console.log(`⚠️ Il reste ${hasOverdue.length} échéance(s) en retard`);
      }
    }
  } else if (MODE !== 'fix') {
    console.log(`\n💡 Pour corriger: node scripts/diagnose_darlene.js fix`);
  }

  process.exit(0);
}

main().catch(console.error);
