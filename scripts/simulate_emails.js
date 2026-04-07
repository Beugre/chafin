/**
 * Script de simulation des emails pour les prochains jours.
 * 
 * Utilise la Cloud Function simulateDailyCheck pour simuler la logique
 * du dailyPaymentReminders à des dates futures, et envoyer les emails
 * uniquement à l'adresse de test avec [TEST MAIL] en objet.
 * 
 * Usage:
 *   node scripts/simulate_emails.js              → Dry-run (pas d'envoi)
 *   node scripts/simulate_emails.js --send       → Envoi réel à email test
 *   node scripts/simulate_emails.js --send --days 14   → Sur 14 jours
 */

const TEST_EMAIL = "yoann.beugre1@gmail.com";

// URL de la Cloud Function simulateDailyCheck 
// Après déploiement, remplacer par l'URL réelle
const BASE_URL = "https://us-central1-chafin-23cad.cloudfunctions.net/simulateDailyCheck";

async function main() {
    const args = process.argv.slice(2);
    const sendEmails = args.includes("--send");
    const daysIndex = args.indexOf("--days");
    const numDays = daysIndex !== -1 ? parseInt(args[daysIndex + 1]) : 7;

    console.log("=".repeat(70));
    console.log("🧪 SIMULATION EMAILS CHAFIN LOANS");
    console.log("=".repeat(70));
    console.log(`📧 Email de test   : ${TEST_EMAIL}`);
    console.log(`📅 Période         : ${numDays} jours à partir de demain`);
    console.log(`✉️  Envoi réel      : ${sendEmails ? "OUI" : "NON (dry-run)"}`);
    console.log(`🔗 Cloud Function  : ${BASE_URL}`);
    console.log("=".repeat(70));
    console.log("");

    const today = new Date();

    for (let i = 1; i <= numDays; i++) {
        const targetDate = new Date(today);
        targetDate.setDate(today.getDate() + i);
        const dateStr = targetDate.toISOString().split("T")[0]; // YYYY-MM-DD

        const dayName = targetDate.toLocaleDateString("fr-FR", { weekday: "long" });
        const fullDate = targetDate.toLocaleDateString("fr-FR", { 
            weekday: "long", year: "numeric", month: "long", day: "numeric" 
        });

        console.log(`\n${"─".repeat(60)}`);
        console.log(`📅 J+${i} — ${fullDate}`);
        console.log(`${"─".repeat(60)}`);

        try {
            const url = `${BASE_URL}?date=${dateStr}&sendEmails=${sendEmails}&email=${TEST_EMAIL}`;
            const response = await fetch(url);

            if (!response.ok) {
                console.log(`❌ Erreur HTTP ${response.status}: ${await response.text()}`);
                continue;
            }

            const result = await response.json();
            const r = result.results;

            console.log(`   📊 Prêts analysés     : ${r.loansProcessed}`);
            console.log(`   📩 Rappels à envoyer  : ${r.remindersWouldSend}`);
            console.log(`   ✅ Rappels envoyés    : ${r.remindersSent}`);
            console.log(`   💰 Pénalités          : ${r.penaltiesApplied}`);
            console.log(`   ⏸️  Emails bloqués     : ${r.emailsSkippedByFlag}`);
            console.log(`   🚫 Pénalités bloquées : ${r.penaltiesSkippedByFlag}`);

            if (r.details && r.details.length > 0) {
                console.log(`   ┌──────────────────────────────────────────────`);
                for (const d of r.details) {
                    if (d.type === "PENALTY") {
                        console.log(`   │ 💰 PÉNALITÉ: échéance n°${d.scheduleNumero} — ${d.amount} (${d.overdueDays}j retard)${d.blocked ? " ⛔ BLOQUÉ" : ""}`);
                    } else {
                        const flags = [];
                        if (d.emailsDisabled) flags.push("📧⛔");
                        if (d.penaltiesDisabled) flags.push("💰⛔");
                        const flagStr = flags.length > 0 ? ` [${flags.join(" ")}]` : "";
                        console.log(`   │ ${d.borrower} (${d.montant}€)${flagStr}`);
                        console.log(`   │   → ${d.action}`);
                    }
                }
                console.log(`   └──────────────────────────────────────────────`);
            }

        } catch (error) {
            console.log(`❌ Erreur: ${error.message}`);
            if (error.message.includes("fetch")) {
                console.log(`   💡 La Cloud Function n'est peut-être pas encore déployée.`);
                console.log(`   💡 Déployez d'abord avec: firebase deploy --only functions`);
                break;
            }
        }

        // Petit délai entre les requêtes pour ne pas surcharger
        if (sendEmails) {
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }

    console.log(`\n${"=".repeat(70)}`);
    console.log("✅ Simulation terminée");
    if (!sendEmails) {
        console.log("💡 Pour envoyer les emails de test: node scripts/simulate_emails.js --send");
    }
    console.log("=".repeat(70));
}

main().catch(console.error);
