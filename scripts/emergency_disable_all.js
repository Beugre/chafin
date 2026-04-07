/**
 * SCRIPT URGENCE : Désactiver emails et pénalités pour TOUS les prêts
 * 
 * 1. emailsDisabled = true pour TOUS les prêts actifs
 * 2. penaltiesDisabled = true pour tous les prêts en retard
 */

const admin = require("firebase-admin");
const serviceAccount = require("../firebase-service-account.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function main() {
    console.log("🚨 URGENCE : Désactivation emails et pénalités...\n");

    // 1. Désactiver les emails pour TOUS les prêts actifs
    const allLoans = await db.collection("loans")
        .where("statut", "in", ["enCours", "enRetard", "approuve", "decaissementEffectue"])
        .get();

    console.log(`📊 ${allLoans.size} prêts actifs trouvés\n`);

    let emailsDisabled = 0;
    let penaltiesDisabled = 0;

    for (const doc of allLoans.docs) {
        const data = doc.data();
        const updates = {};

        // Désactiver les emails pour TOUS
        if (data.emailsDisabled !== true) {
            updates.emailsDisabled = true;
            emailsDisabled++;
        }

        // Désactiver les pénalités pour les prêts en retard
        if (data.statut === "enRetard" && data.penaltiesDisabled !== true) {
            updates.penaltiesDisabled = true;
            penaltiesDisabled++;
        }

        if (Object.keys(updates).length > 0) {
            updates.updatedAt = new Date().toISOString();
            await doc.ref.update(updates);
            console.log(`  ✅ ${data.nomEmprunteur} (${data.montant}€, ${data.statut}) → emails=${updates.emailsDisabled ? "OFF" : "-"} pénalités=${updates.penaltiesDisabled ? "OFF" : "-"}`);
        } else {
            console.log(`  ⏭️  ${data.nomEmprunteur} (${data.montant}€, ${data.statut}) → déjà désactivé`);
        }
    }

    console.log(`\n${"=".repeat(50)}`);
    console.log(`✅ ${emailsDisabled} prêts → emails désactivés`);
    console.log(`✅ ${penaltiesDisabled} prêts en retard → pénalités désactivées`);
    console.log(`${"=".repeat(50)}`);

    process.exit(0);
}

main().catch(e => { console.error("❌", e); process.exit(1); });
