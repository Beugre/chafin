const admin = require("../functions/node_modules/firebase-admin");
const serviceAccount = require("../firebase-service-account.json");
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function checkDamage() {
  // 1. Vérifier les penalty_logs
  console.log("=== PENALTY LOGS ===");
  const penaltyLogs = await db.collection("penalty_logs").get();
  for (const doc of penaltyLogs.docs) {
    const d = doc.data();
    console.log(JSON.stringify({
      id: doc.id,
      loanId: d.loanId,
      userId: d.userId,
      scheduleNumero: d.scheduleNumero,
      originalTotal: d.originalTotal,
      penaltyAmount: d.penaltyAmount,
      newTotal: d.newTotal,
      overdueDays: d.overdueDays,
      sentAt: d.sentAt && d.sentAt.toDate ? d.sentAt.toDate().toISOString() : d.sentAt,
    }));
  }

  // 2. Vérifier les schedules avec pénalité
  console.log("\n=== SCHEDULES WITH PENALTY ===");
  const penalizedSchedules = await db.collection("schedules").where("hasPenalty", "==", true).get();
  for (const doc of penalizedSchedules.docs) {
    const d = doc.data();
    const dueDate = d.dueDate && d.dueDate.toDate ? d.dueDate.toDate().toISOString() : d.dueDate;
    console.log(JSON.stringify({
      id: doc.id,
      loanId: d.loanId,
      numero: d.numero,
      isPaid: d.isPaid,
      total: d.total,
      originalTotal: d.originalTotal,
      penaltyAmount: d.penaltyAmount,
      dueDate: dueDate,
      hasPenalty: d.hasPenalty,
    }));
  }

  // 3. Vérifier les prêts enRetard
  console.log("\n=== LOANS enRetard ===");
  const lateLoans = await db.collection("loans").where("statut", "==", "enRetard").get();
  for (const doc of lateLoans.docs) {
    const d = doc.data();
    console.log(JSON.stringify({
      id: doc.id, userId: d.userId, montant: d.montant,
      nomEmprunteur: d.nomEmprunteur, statut: d.statut,
    }));
  }

  // 4. Vérifier les prêts enCours
  console.log("\n=== LOANS enCours ===");
  const activeLoans = await db.collection("loans").where("statut", "==", "enCours").get();
  for (const doc of activeLoans.docs) {
    const d = doc.data();
    console.log(JSON.stringify({
      id: doc.id, userId: d.userId, montant: d.montant,
      nomEmprunteur: d.nomEmprunteur, statut: d.statut,
    }));
  }

  // 5. Vérifier les users touchés
  console.log("\n=== USERS IMPACTED ===");
  const userIds = new Set();
  for (const doc of penaltyLogs.docs) { userIds.add(doc.data().userId); }
  for (const uid of userIds) {
    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists) {
      const u = userDoc.data();
      console.log(JSON.stringify({
        uid, prenom: u.prenom, nom: u.nom, email: u.email,
        niveauConfiance: u.niveauConfiance,
      }));
    }
  }

  // 6. Vérifier les admins (pour savoir l'email admin)
  console.log("\n=== ADMINS ===");
  const admins = await db.collection("users").where("role", "in", ["admin", "superAdmin"]).get();
  for (const doc of admins.docs) {
    const u = doc.data();
    console.log(JSON.stringify({ uid: doc.id, prenom: u.prenom, nom: u.nom, email: u.email, role: u.role }));
  }

  // 7. Tous les emprunteurs actifs (pour email de communication)
  console.log("\n=== ALL BORROWERS ===");
  const borrowers = await db.collection("users").where("role", "==", "borrower").get();
  for (const doc of borrowers.docs) {
    const u = doc.data();
    console.log(JSON.stringify({ uid: doc.id, prenom: u.prenom, nom: u.nom, email: u.email }));
  }

  process.exit(0);
}

checkDamage().catch(e => { console.error(e); process.exit(1); });
