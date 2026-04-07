/**
 * Diagnostic complet du prêt Yvann 970€
 */
const admin = require("../functions/node_modules/firebase-admin");
const serviceAccount = require("../firebase-service-account.json");
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const LOAN_ID = "1b434d9e-f9c9-447b-8df0-d85fa7c76ee7";

async function diagnose() {
  // 1. Infos du prêt
  console.log("=== PRÊT ===");
  const loanDoc = await db.collection("loans").doc(LOAN_ID).get();
  const loan = loanDoc.data();
  console.log(JSON.stringify({
    id: LOAN_ID,
    userId: loan.userId,
    nomEmprunteur: loan.nomEmprunteur,
    montant: loan.montant,
    dureeMois: loan.dureeMois,
    tauxAnnuel: loan.tauxAnnuel,
    mensualite: loan.mensualite,
    coutTotalEstime: loan.coutTotalEstime,
    statut: loan.statut,
    createdAt: loan.createdAt,
    approvedAt: loan.approvedAt,
    disbursedAt: loan.disbursedAt,
    dateSouhaitee: loan.dateSouhaitee,
    datePremierRemboursement: loan.datePremierRemboursement,
    dateVirement: loan.dateVirement,
  }, null, 2));

  // 2. Schedules pour ce prêt
  console.log("\n=== SCHEDULES (loanId match) ===");
  const schedules = await db.collection("schedules")
    .where("loanId", "==", LOAN_ID)
    .orderBy("numero")
    .get();
  console.log(`Nombre de schedules trouvés: ${schedules.size}`);
  for (const doc of schedules.docs) {
    const s = doc.data();
    const dueDate = s.dueDate && s.dueDate.toDate ? s.dueDate.toDate().toISOString() : s.dueDate;
    const paidAt = s.paidAt && s.paidAt.toDate ? s.paidAt.toDate().toISOString() : s.paidAt;
    console.log(JSON.stringify({
      docId: doc.id,
      loanId: s.loanId,
      numero: s.numero,
      principal: s.principal,
      interet: s.interet,
      total: s.total,
      dueDate: dueDate,
      isPaid: s.isPaid,
      paidAt: paidAt,
      hasPenalty: s.hasPenalty || false,
    }));
  }

  // 3. Vérifier aussi dans payment_schedules (ancien nom possible)
  console.log("\n=== PAYMENT_SCHEDULES (si existe) ===");
  try {
    const ps = await db.collection("payment_schedules")
      .where("loanId", "==", LOAN_ID)
      .get();
    console.log(`Nombre dans payment_schedules: ${ps.size}`);
    for (const doc of ps.docs) {
      console.log(`  ${doc.id}: ${JSON.stringify(doc.data()).substring(0, 200)}`);
    }
  } catch (e) {
    console.log("Collection payment_schedules n'existe pas ou pas d'index");
  }

  // 4. Vérifier le format loanId stocké dans les schedules vs le prêt
  console.log("\n=== VÉRIFICATION FORMAT ===");
  console.log(`Loan ID: "${LOAN_ID}" (length: ${LOAN_ID.length})`);
  if (schedules.size > 0) {
    const firstSchedule = schedules.docs[0].data();
    console.log(`Schedule loanId: "${firstSchedule.loanId}" (length: ${firstSchedule.loanId.length})`);
    console.log(`Match exact: ${firstSchedule.loanId === LOAN_ID}`);
  }

  // 5. Chercher comment l'app Flutter lit les schedules
  console.log("\n=== STRUCTURE D'UN SCHEDULE ===");
  if (schedules.size > 0) {
    console.log(JSON.stringify(schedules.docs[0].data(), null, 2));
  }

  process.exit(0);
}

diagnose().catch(e => { console.error(e); process.exit(1); });
