/**
 * Réinitialise les URLs des reconnaissances de dette pour forcer la régénération
 */
const admin = require("../functions/node_modules/firebase-admin");
const serviceAccount = require("../firebase-service-account.json");
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function resetDebtUrls() {
  const loans = await db.collection("loans")
    .where("statut", "in", ["enCours", "enRetard"])
    .get();

  console.log(`Réinitialisation de ${loans.size} prêts...`);
  let count = 0;
  for (const doc of loans.docs) {
    await doc.ref.update({
      reconnaissanceDetteUrl: admin.firestore.FieldValue.delete(),
      reconnaissanceDetteFileName: admin.firestore.FieldValue.delete(),
      reconnaissanceDetteGeneratedAt: admin.firestore.FieldValue.delete(),
    });
    count++;
    console.log(`  ✅ ${doc.id} - ${doc.data().nomEmprunteur}`);
  }
  console.log(`\n✅ ${count} URLs réinitialisées. Lancer le backfill maintenant.`);
  process.exit(0);
}

resetDebtUrls().catch(e => { console.error(e); process.exit(1); });
