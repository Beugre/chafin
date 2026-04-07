/**
 * Vérifier l'état réel des schedules pour les 3 personnes impactées
 */
const admin = require("../functions/node_modules/firebase-admin");
const serviceAccount = require("../firebase-service-account.json");
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function checkSchedules() {
  const now = new Date();

  // Prêts des 3 personnes concernées
  const loanIds = [
    "1b434d9e-f9c9-447b-8df0-d85fa7c76ee7", // Yvann 970€
    "f8c84aed-aa1a-4f76-a4de-ce674505e46c", // Yvann 925€
    "b0090eb5-076a-448e-bf20-6390a0050eda", // Cephora 100€
    "c992d109-3b18-42e4-b9da-75313629a41c", // Cephora 80€
    "c05726f9-613b-4174-8544-68d71787d47f", // Darlène 300€
  ];

  for (const loanId of loanIds) {
    // Infos du prêt
    const loanDoc = await db.collection("loans").doc(loanId).get();
    const loan = loanDoc.data();
    console.log(`\n${"=".repeat(70)}`);
    console.log(`PRÊT: ${loan.nomEmprunteur} - ${loan.montant}€ (${loanId.substring(0, 8)})`);
    console.log(`Statut: ${loan.statut}`);
    console.log(`${"=".repeat(70)}`);

    // Toutes les échéances de ce prêt
    const schedules = await db.collection("schedules")
      .where("loanId", "==", loanId)
      .orderBy("numero")
      .get();

    for (const doc of schedules.docs) {
      const s = doc.data();
      const dueDate = s.dueDate && s.dueDate.toDate ? s.dueDate.toDate() : new Date(s.dueDate);
      const daysDiff = Math.ceil((dueDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      const overdueDays = daysDiff < 0 ? Math.abs(daysDiff) : 0;

      const paidAt = s.paidAt && s.paidAt.toDate ? s.paidAt.toDate().toISOString().split("T")[0] : (s.paidAt || "N/A");

      console.log(`  #${s.numero} | Due: ${dueDate.toISOString().split("T")[0]} | isPaid: ${s.isPaid} | paidAt: ${paidAt} | total: ${s.total}€ | hasPenalty: ${s.hasPenalty || false} | retard: ${overdueDays > 0 ? overdueDays + "j" : "OK"} | penalty eligible (>=31j unpaid): ${!s.isPaid && overdueDays >= 31 ? "OUI" : "NON"}`);
    }
  }

  process.exit(0);
}

checkSchedules().catch(e => { console.error(e); process.exit(1); });
