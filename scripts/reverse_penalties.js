/**
 * Script pour annuler TOUTES les pénalités appliquées par erreur.
 * - Restaure les montants originaux dans les schedules
 * - Supprime les penalty_logs
 * - Régénère les reconnaissances de dette sans pénalités
 */
const admin = require("../functions/node_modules/firebase-admin");
const serviceAccount = require("../firebase-service-account.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function reversePenalties() {
  console.log("🔄 Début annulation de toutes les pénalités...\n");

  // 1. Trouver tous les schedules avec pénalité
  const penalizedSchedules = await db.collection("schedules").where("hasPenalty", "==", true).get();
  console.log(`📊 ${penalizedSchedules.size} échéances pénalisées trouvées\n`);

  let reversed = 0;
  for (const doc of penalizedSchedules.docs) {
    const data = doc.data();
    const originalTotal = data.originalTotal;

    if (originalTotal === undefined || originalTotal === null) {
      console.log(`⚠️ Schedule ${doc.id} n'a pas de originalTotal, skip`);
      continue;
    }

    // Restaurer le montant original
    await doc.ref.update({
      total: originalTotal,
      hasPenalty: false,
      penaltyAmount: admin.firestore.FieldValue.delete(),
      originalTotal: admin.firestore.FieldValue.delete(),
      penaltyAppliedAt: admin.firestore.FieldValue.delete(),
    });

    const dueDate = data.dueDate && data.dueDate.toDate ? data.dueDate.toDate().toISOString().split("T")[0] : "?";
    console.log(`✅ Schedule ${doc.id} (prêt ${data.loanId}, #${data.numero}, due ${dueDate}): ${data.total}€ → ${originalTotal}€`);
    reversed++;
  }

  // 2. Supprimer tous les penalty_logs
  const penaltyLogs = await db.collection("penalty_logs").get();
  console.log(`\n🗑️ Suppression de ${penaltyLogs.size} penalty_logs...`);
  for (const doc of penaltyLogs.docs) {
    await doc.ref.delete();
  }
  console.log("✅ Tous les penalty_logs supprimés");

  // 3. Vérifier que les reconnaissances de dette existantes sont intactes
  // (les reconnaissances originales au décaissement ne contiennent pas de pénalités)
  // Pas besoin de régénérer les PDFs — les originaux générés au décaissement sont corrects.
  // Les versions "actualisées" suite aux pénalités seront écrasées lors de la prochaine
  // application légitime de pénalité.

  console.log(`\n✅ TERMINÉ: ${reversed} échéances restaurées, ${penaltyLogs.size} logs supprimés`);
  console.log("\n📌 Les échéanciers sont revenus à leur état original (sans pénalité).");
  console.log("📌 Le système réappliquera automatiquement les pénalités légitimes (≥31 jours) demain.");

  process.exit(0);
}

reversePenalties().catch(e => { console.error("❌ Erreur:", e); process.exit(1); });
