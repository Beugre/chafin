import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import axios from "axios";
import { randomUUID } from "crypto";
import { buildDebtPDF } from "./debtAcknowledgment";

// Initialiser Firebase Admin
initializeApp();
const db = getFirestore();

// Exporter les fonctions utilitaires
export { cleanupMalformedSchedules, regenerateSchedules, recalculateAllSchedules } from "./cleanupSchedules";
export { testListLoans } from "./testLoans";
export { cleanupDuplicateSchedules } from "./cleanupDuplicates";
export { validateLoansIntegrity } from "./validateLoansIntegrity";
export { checkLoanStatus } from "./checkLoanStatus";
export { generateDebtAcknowledgment } from "./debtAcknowledgment";
export { backfillDebtDocuments } from "./backfillDebtDocs";

// ============================================================
// CONFIGURATION
// ============================================================

const EMAILJS_CONFIG = {
    serviceId: "service_s6kh76e",
    templateId: "template_byf1fdm",
    publicKey: "sUFWr-XkJM8NcZQ86",
    privateKey: "iihl6951E8XgF-0y3Dumm",
    apiUrl: "https://api.emailjs.com/api/v1.0/email/send",
};

// Constantes métier
const PENALTY_RATE = 0.05; // 5% de pénalité (une seule fois par échéance)
const PENALTY_GRACE_PERIOD_DAYS = 31; // Délai de grâce avant pénalité
const RISK_DOWNGRADE_THRESHOLD_DAYS = 60; // 2 mois => badge à risque

// Jours PRÉCIS où envoyer un rappel de RETARD (J+7 et J+21 UNIQUEMENT)
const OVERDUE_REMINDER_DAYS = [7, 21];
// Jours AVANT échéance pour les rappels préventifs (J-3 et J-1 UNIQUEMENT)
const UPCOMING_REMINDER_DAYS = [3, 1];

// ============================================================
// FONCTION PRINCIPALE : Vérification quotidienne à 9h
// ============================================================

/**
 * Cloud Function déclenchée automatiquement tous les jours à 9h (Europe/Paris).
 *
 * EMAILS ENVOYÉS (et UNIQUEMENT ceux-là) :
 *   J-3  → Rappel préventif "Votre échéance est dans 3 jours"
 *   J-1  → Rappel préventif "Votre échéance est demain"
 *   J+7  → Rappel retard consolidé (toutes les échéances en retard du prêt)
 *   J+21 → Rappel retard consolidé (toutes les échéances en retard du prêt)
 *   J+31 → Email pénalité consolidé (5% appliqué + lien reconnaissance de dette)
 *
 * SÉCURITÉS :
 * ✅ UN SEUL email par prêt par jour (pas un par échéance)
 * ✅ UN SEUL email de pénalité même si plusieurs échéances pénalisées
 * ✅ Clé anti-doublon par prêt+date
 * ✅ Respect des flags emailsDisabled / penaltiesDisabled
 * ✅ Garde-fou anti-fuite : en simulation, SEUL testEmail peut recevoir
 * ✅ Pénalité 5% = une seule fois par échéance (flag hasPenalty)
 * ✅ Aucun email de dégradation risque / reconnaissance de dette séparé
 */
export const dailyPaymentReminders = onSchedule({
    schedule: "0 9 * * *",
    timeZone: "Europe/Paris",
}, async () => {
    logger.info("🔔 Début vérification quotidienne (rappels + pénalités + risque)");
    await runDailyChecks(new Date(), false);
});

/**
 * Fonction HTTP pour TESTER/SIMULER la logique pour une date donnée.
 *
 * SÉCURITÉ ANTI-FUITE :
 * En mode simulation, AUCUN email ne peut partir vers un vrai utilisateur.
 * Le garde-fou est dans sendEmailViaEmailJS() qui BLOQUE tout email dont
 * le destinataire ne correspond pas EXACTEMENT au testEmail.
 *
 * Usage:
 *   DRY-RUN (voir ce qui se passerait, ZÉRO email envoyé) :
 *     GET /simulateDailyCheck?date=2026-02-26
 *
 *   ENVOI à email test UNIQUEMENT :
 *     GET /simulateDailyCheck?date=2026-02-26&sendEmails=true&email=yoann.beugre1@gmail.com
 */
export const simulateDailyCheck = onRequest({
    cors: true,
}, async (req, res) => {
    try {
        const dateParam = req.query.date as string;
        const sendEmails = req.query.sendEmails === "true";
        const testEmail = (req.query.email as string) || "yoann.beugre1@gmail.com";

        if (!dateParam) {
            res.status(400).json({ error: "Paramètre 'date' requis (format: YYYY-MM-DD)" });
            return;
        }

        const simulatedDate = new Date(dateParam + "T09:00:00+01:00");
        if (isNaN(simulatedDate.getTime())) {
            res.status(400).json({ error: "Date invalide" });
            return;
        }

        logger.info(`🧪 SIMULATION pour ${dateParam}, sendEmails=${sendEmails}, testEmail=${testEmail}`);

        const results = await runDailyChecks(simulatedDate, true, sendEmails ? testEmail : undefined);

        res.json({
            date: dateParam,
            simulatedDate: simulatedDate.toISOString(),
            sendEmails,
            testEmail: sendEmails ? testEmail : "NON (dry-run)",
            results,
        });
    } catch (error: any) {
        logger.error("❌ Erreur simulation:", error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// LOGIQUE PRINCIPALE
// ============================================================

interface DailyCheckResults {
    loansProcessed: number;
    remindersWouldSend: number;
    remindersSent: number;
    penaltiesApplied: number;
    penaltiesSkipped: number;
    penaltyEmailsSent: number;
    riskDowngrades: number;
    emailsSkippedByFlag: number;
    penaltiesSkippedByFlag: number;
    details: any[];
}

async function runDailyChecks(
    now: Date,
    isSimulation: boolean,
    testEmail?: string
): Promise<DailyCheckResults> {
    const results: DailyCheckResults = {
        loansProcessed: 0,
        remindersWouldSend: 0,
        remindersSent: 0,
        penaltiesApplied: 0,
        penaltiesSkipped: 0,
        penaltyEmailsSent: 0,
        riskDowngrades: 0,
        emailsSkippedByFlag: 0,
        penaltiesSkippedByFlag: 0,
        details: [],
    };

    const userMaxOverdueDays: Map<string, number> = new Map();

    const activeLoansSnapshot = await db
        .collection("loans")
        .where("statut", "in", ["enCours", "enRetard"])
        .get();

    logger.info(`📊 ${activeLoansSnapshot.size} prêts actifs trouvés`);
    results.loansProcessed = activeLoansSnapshot.size;

    for (const loanDoc of activeLoansSnapshot.docs) {
        const loan = loanDoc.data();
        const loanId = loanDoc.id;

        // ── Lire les flags de désactivation ──
        const emailsDisabled = loan.emailsDisabled === true;
        const penaltiesDisabled = loan.penaltiesDisabled === true;

        const scheduleSnapshot = await db
            .collection("schedules")
            .where("loanId", "==", loanId)
            .where("isPaid", "==", false)
            .get();

        let hasOverduePayments = false;
        let loanMaxOverdueDays = 0;

        // ── PHASE 1 : Analyse de TOUTES les échéances impayées du prêt ──
        const overdueSchedules: Array<{ doc: any; data: any; days: number; dueDate: Date }> = [];
        const upcomingSchedules: Array<{ doc: any; data: any; days: number; dueDate: Date }> = [];

        for (const scheduleDoc of scheduleSnapshot.docs) {
            const schedule = scheduleDoc.data();

            let dueDate: Date;
            if (schedule.dueDate && typeof schedule.dueDate.toDate === "function") {
                dueDate = schedule.dueDate.toDate();
            } else if (typeof schedule.dueDate === "string") {
                dueDate = new Date(schedule.dueDate);
            } else {
                logger.warn(`⚠️ Format de date invalide pour schedule ${scheduleDoc.id}`);
                continue;
            }

            const daysDifference = Math.ceil(
                (dueDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
            );

            if (daysDifference < 0) {
                hasOverduePayments = true;
                const overdueDays = Math.abs(daysDifference);
                if (overdueDays > loanMaxOverdueDays) {
                    loanMaxOverdueDays = overdueDays;
                }
                overdueSchedules.push({ doc: scheduleDoc, data: schedule, days: overdueDays, dueDate });
            } else if (UPCOMING_REMINDER_DAYS.includes(daysDifference)) {
                upcomingSchedules.push({ doc: scheduleDoc, data: schedule, days: daysDifference, dueDate });
            }
        }

        // ── PHASE 2 : Pénalités (une seule fois par échéance après 31j) ──
        // On collecte TOUTES les pénalités à appliquer pour ce prêt,
        // puis on envoie UN SEUL email consolidé.
        const penaltiesAppliedThisLoan: Array<{
            scheduleNumero: number;
            originalTotal: number;
            penaltyAmount: number;
            newTotal: number;
            overdueDays: number;
        }> = [];

        for (const item of overdueSchedules) {
            // Déjà pénalisé → ignorer
            if (item.data.hasPenalty) {
                results.penaltiesSkipped++;
                continue;
            }
            // Pas encore 31 jours → ignorer
            if (item.days < PENALTY_GRACE_PERIOD_DAYS) {
                continue;
            }
            // Pénalités désactivées pour ce prêt → ignorer
            if (penaltiesDisabled) {
                results.penaltiesSkippedByFlag++;
                logger.info(`⏸️ Pénalité DÉSACTIVÉE pour prêt ${loanId} - échéance n°${item.data.numero}`);
                continue;
            }

            // Calcul de la pénalité
            const originalTotal = item.data.total as number;
            const penaltyAmount = Math.round(originalTotal * PENALTY_RATE * 100) / 100;
            const newTotal = Math.round((originalTotal + penaltyAmount) * 100) / 100;

            if (!isSimulation) {
                // Appliquer en Firestore (SANS email individuel, SANS régénération dette individuelle)
                await item.doc.ref.update({
                    hasPenalty: true,
                    penaltyAmount: penaltyAmount,
                    originalTotal: originalTotal,
                    total: newTotal,
                    penaltyAppliedAt: new Date(),
                });
                logger.info(`💰 Pénalité +${penaltyAmount}€ sur ${item.doc.id} (${originalTotal}€ → ${newTotal}€)`);
            }

            penaltiesAppliedThisLoan.push({
                scheduleNumero: item.data.numero,
                originalTotal,
                penaltyAmount,
                newTotal,
                overdueDays: item.days,
            });
            results.penaltiesApplied++;

            if (isSimulation) {
                results.details.push({
                    type: "PENALTY",
                    loanId,
                    scheduleNumero: item.data.numero,
                    overdueDays: item.days,
                    amount: `+${penaltyAmount.toFixed(2)}€`,
                });
            }
        }

        // Après toutes les pénalités de ce prêt :
        // → Régénérer la reconnaissance de dette UNE SEULE FOIS
        // → Envoyer UN SEUL email consolidé avec toutes les pénalités + lien dette
        if (penaltiesAppliedThisLoan.length > 0) {
            let debtUrl: string | undefined;

            if (!isSimulation) {
                debtUrl = await regenerateDebtAcknowledgment(loan, loanId);
            }

            if (!emailsDisabled) {
                const sent = await sendConsolidatedPenaltyEmail(
                    loan, loanId, penaltiesAppliedThisLoan, debtUrl,
                    isSimulation, testEmail
                );
                if (sent) results.penaltyEmailsSent++;
            } else {
                results.emailsSkippedByFlag++;
                logger.info(`⏸️ Email pénalité BLOQUÉ (emails désactivés) pour prêt ${loanId}`);
            }
        }

        // ── PHASE 3 : UN SEUL email de rappel par prêt par jour ──
        const loanDetail: any = {
            loanId,
            borrower: loan.nomEmprunteur || "Inconnu",
            montant: loan.montant,
            emailsDisabled,
            penaltiesDisabled,
            action: "NONE",
        };

        if (overdueSchedules.length > 0) {
            // ── RETARD : vérifier si aujourd'hui est un jour de rappel [7, 21] ──
            const shouldSend = OVERDUE_REMINDER_DAYS.includes(loanMaxOverdueDays);

            if (shouldSend) {
                results.remindersWouldSend++;
                loanDetail.action = `OVERDUE_REMINDER (${loanMaxOverdueDays}j retard, ${overdueSchedules.length} échéance(s))`;

                if (emailsDisabled) {
                    results.emailsSkippedByFlag++;
                    loanDetail.action += " → BLOQUÉ (emails désactivés)";
                } else {
                    const sent = await sendConsolidatedOverdueReminder(
                        loan, loanId, overdueSchedules, loanMaxOverdueDays, now,
                        isSimulation, testEmail
                    );
                    if (sent) results.remindersSent++;
                }
            } else {
                loanDetail.action = `OVERDUE_SILENT (${loanMaxOverdueDays}j retard - pas dans la liste [${OVERDUE_REMINDER_DAYS.join(",")}])`;
            }
        } else if (upcomingSchedules.length > 0) {
            // ── PRÉVENTIF : échéance à venir, prendre la plus proche ──
            const closest = upcomingSchedules.reduce((a, b) => a.days < b.days ? a : b);

            results.remindersWouldSend++;
            loanDetail.action = `UPCOMING_REMINDER (J-${closest.days}, ${formatDate(closest.dueDate)})`;

            if (emailsDisabled) {
                results.emailsSkippedByFlag++;
                loanDetail.action += " → BLOQUÉ (emails désactivés)";
            } else {
                const sent = await sendUpcomingReminder(
                    loan, loanId, closest, now,
                    isSimulation, testEmail
                );
                if (sent) results.remindersSent++;
            }
        }

        results.details.push(loanDetail);

        // Suivre le retard max pour cet utilisateur
        if (loan.userId && loanMaxOverdueDays > 0) {
            const currentMax = userMaxOverdueDays.get(loan.userId) || 0;
            if (loanMaxOverdueDays > currentMax) {
                userMaxOverdueDays.set(loan.userId, loanMaxOverdueDays);
            }
        }

        // Mise à jour du statut du prêt (enCours ↔ enRetard)
        if (!isSimulation) {
            if (hasOverduePayments && loan.statut !== "enRetard") {
                await db.collection("loans").doc(loanId).update({
                    statut: "enRetard",
                    updatedAt: new Date().toISOString(),
                });
                logger.info(`⚠️ Prêt ${loanId} marqué en retard`);
            } else if (!hasOverduePayments && loan.statut === "enRetard") {
                await db.collection("loans").doc(loanId).update({
                    statut: "enCours",
                    updatedAt: new Date().toISOString(),
                });
                logger.info(`✅ Prêt ${loanId} repassé en cours`);
            }
        }
    }

    // Vérifier les utilisateurs à dégrader (60+ jours de retard)
    // NOTE : Pas d'email de dégradation — uniquement Firestore + notification in-app
    if (!isSimulation) {
        for (const [userId, maxDays] of userMaxOverdueDays) {
            if (maxDays >= RISK_DOWNGRADE_THRESHOLD_DAYS) {
                const downgraded = await checkAndDowngradeUserRisk(userId, maxDays);
                if (downgraded) results.riskDowngrades++;
            }
        }
    }

    logger.info(`✅ Terminé: ${results.remindersSent} rappels, ${results.penaltiesApplied} pénalités, ${results.penaltyEmailsSent} emails pénalité, ${results.emailsSkippedByFlag} emails bloqués`);
    return results;
}

// ============================================================
// ENVOI D'EMAILS — UN SEUL PAR PRÊT PAR JOUR
// ============================================================

/**
 * Email consolidé de RETARD : liste TOUTES les échéances en retard d'un prêt
 * dans UN SEUL email. Anti-doublon par loanId + date du jour.
 * Envoyé UNIQUEMENT à J+7 et J+21.
 */
async function sendConsolidatedOverdueReminder(
    loan: any,
    loanId: string,
    overdueSchedules: Array<{ data: any; days: number; dueDate: Date }>,
    maxOverdueDays: number,
    now: Date,
    isSimulation: boolean,
    testEmail?: string
): Promise<boolean> {
    try {
        // Anti-doublon : UNE clé par prêt par jour
        const todayKey = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}`;
        const reminderKey = `overdue_${loanId}_${todayKey}`;

        if (!isSimulation) {
            const existing = await db.collection("reminder_logs").doc(reminderKey).get();
            if (existing.exists) {
                logger.info(`🔕 Rappel retard déjà envoyé aujourd'hui pour ${loanId}`);
                return false;
            }
        }

        const userDoc = await db.collection("users").doc(loan.userId).get();
        if (!userDoc.exists) return false;
        const userData = userDoc.data()!;
        const userEmail = testEmail || userData.email;
        const userName = `${userData.prenom} ${userData.nom}`;
        if (!userEmail) return false;

        // Récapitulatif consolidé
        const totalDue = overdueSchedules.reduce((sum, s) => sum + (s.data.total as number), 0);
        const scheduleList = overdueSchedules
            .sort((a, b) => a.data.numero - b.data.numero)
            .map(s => `  • Échéance n°${s.data.numero} du ${formatDate(s.dueDate)} : ${(s.data.total as number).toFixed(2)}€ (${s.days}j de retard)`)
            .join("\n");

        const subject = isSimulation
            ? `[TEST MAIL] ⚠️ Retard de paiement - ${overdueSchedules.length} échéance(s)`
            : `⚠️ Retard de paiement - ${overdueSchedules.length} échéance(s) en retard`;

        const message = `Bonjour ${userName},\n\n` +
            `Nous vous informons que ${overdueSchedules.length} échéance(s) de votre prêt de ${loan.montant}€ sont en retard.\n\n` +
            `📋 Récapitulatif :\n${scheduleList}\n\n` +
            `💰 Total à régulariser : ${totalDue.toFixed(2)}€\n` +
            `⏱️ Retard maximum : ${maxOverdueDays} jour(s)\n\n` +
            `ℹ️ Au-delà de ${PENALTY_GRACE_PERIOD_DAYS} jours de retard, une pénalité unique de 5% sera appliquée par échéance.\n\n` +
            `Merci de régulariser votre situation au plus vite.\n\n` +
            `Cordialement,\nL'équipe Chafin Loans`;

        const emailSent = await sendEmailViaEmailJS(
            { email: userEmail, name: userName, subject, message, from_name: "Chafin Loans" },
            isSimulation, testEmail
        );

        if (emailSent && !isSimulation) {
            await db.collection("reminder_logs").doc(reminderKey).set({
                loanId,
                userId: loan.userId,
                type: "overdue_consolidated",
                overdueCount: overdueSchedules.length,
                maxOverdueDays,
                totalDue,
                sentAt: new Date(),
            });
        }

        return emailSent;
    } catch (error) {
        logger.error(`❌ Erreur envoi rappel retard ${loanId}:`, error);
        return false;
    }
}

/**
 * Email de rappel préventif pour une échéance à venir.
 * UN SEUL par prêt par jour, anti-doublon par loanId + date.
 * Envoyé UNIQUEMENT à J-3 et J-1.
 */
async function sendUpcomingReminder(
    loan: any,
    loanId: string,
    scheduleInfo: { data: any; days: number; dueDate: Date },
    now: Date,
    isSimulation: boolean,
    testEmail?: string
): Promise<boolean> {
    try {
        const todayKey = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}`;
        const reminderKey = `upcoming_${loanId}_${todayKey}`;

        if (!isSimulation) {
            const existing = await db.collection("reminder_logs").doc(reminderKey).get();
            if (existing.exists) {
                logger.info(`🔕 Rappel préventif déjà envoyé aujourd'hui pour ${loanId}`);
                return false;
            }
        }

        const userDoc = await db.collection("users").doc(loan.userId).get();
        if (!userDoc.exists) return false;
        const userData = userDoc.data()!;
        const userEmail = testEmail || userData.email;
        const userName = `${userData.prenom} ${userData.nom}`;
        if (!userEmail) return false;

        const amount = (scheduleInfo.data.total as number).toFixed(2);
        const formattedDate = formatDate(scheduleInfo.dueDate);
        const days = scheduleInfo.days;

        const subject = isSimulation
            ? `[TEST MAIL] 📅 Rappel : Échéance ${days === 1 ? "demain" : "dans " + days + " jours"}`
            : `📅 Rappel : Échéance ${days === 1 ? "demain" : "dans " + days + " jours"}`;

        const message = `Bonjour ${userName},\n\n` +
            (days === 1
                ? `Rappel amical : Votre échéance de ${amount}€ est due demain (${formattedDate}).\nPensez à effectuer votre paiement.\n\n`
                : `Rappel amical : Votre prochaine échéance de ${amount}€ est prévue le ${formattedDate} (dans ${days} jours).\n\n`) +
            `📋 Détails :\n` +
            `• Montant : ${amount}€\n` +
            `• Date d'échéance : ${formattedDate}\n` +
            `• Échéance n°${scheduleInfo.data.numero}\n\n` +
            `Cordialement,\nL'équipe Chafin Loans`;

        const emailSent = await sendEmailViaEmailJS(
            { email: userEmail, name: userName, subject, message, from_name: "Chafin Loans" },
            isSimulation, testEmail
        );

        if (emailSent && !isSimulation) {
            await db.collection("reminder_logs").doc(reminderKey).set({
                loanId,
                userId: loan.userId,
                type: "upcoming",
                daysUntilDue: days,
                scheduleNumero: scheduleInfo.data.numero,
                sentAt: new Date(),
            });
        }

        return emailSent;
    } catch (error) {
        logger.error(`❌ Erreur envoi rappel préventif ${loanId}:`, error);
        return false;
    }
}

// ============================================================
// EMAIL CONSOLIDÉ DE PÉNALITÉ (UN SEUL par prêt, même si N échéances)
// ============================================================

/**
 * UN SEUL email pour TOUTES les pénalités appliquées sur un prêt.
 * Inclut le lien vers la reconnaissance de dette actualisée.
 * Anti-doublon par loanId + date.
 */
async function sendConsolidatedPenaltyEmail(
    loan: any,
    loanId: string,
    penalties: Array<{
        scheduleNumero: number;
        originalTotal: number;
        penaltyAmount: number;
        newTotal: number;
        overdueDays: number;
    }>,
    debtUrl: string | undefined,
    isSimulation: boolean,
    testEmail?: string
): Promise<boolean> {
    try {
        const now = new Date();
        const todayKey = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}`;
        const penaltyKey = `penalty_${loanId}_${todayKey}`;

        if (!isSimulation) {
            const existing = await db.collection("reminder_logs").doc(penaltyKey).get();
            if (existing.exists) {
                logger.info(`🔕 Email pénalité déjà envoyé aujourd'hui pour ${loanId}`);
                return false;
            }
        }

        const userDoc = await db.collection("users").doc(loan.userId).get();
        if (!userDoc.exists) return false;
        const userData = userDoc.data()!;
        const userEmail = testEmail || userData.email;
        const userName = `${userData.prenom} ${userData.nom}`;
        if (!userEmail) return false;

        const totalPenalty = penalties.reduce((sum, p) => sum + p.penaltyAmount, 0);
        const totalNewAmount = penalties.reduce((sum, p) => sum + p.newTotal, 0);

        const penaltyList = penalties
            .sort((a, b) => a.scheduleNumero - b.scheduleNumero)
            .map(p =>
                `  • Échéance n°${p.scheduleNumero} : ${p.originalTotal.toFixed(2)}€ → ${p.newTotal.toFixed(2)}€ (+${p.penaltyAmount.toFixed(2)}€ de pénalité, ${p.overdueDays}j de retard)`
            )
            .join("\n");

        const subject = isSimulation
            ? `[TEST MAIL] ⚠️ Pénalité de retard appliquée - ${penalties.length} échéance(s)`
            : `⚠️ Pénalité de retard appliquée - ${penalties.length} échéance(s)`;

        let message = `Bonjour ${userName},\n\n` +
            `Suite au retard de paiement sur votre prêt de ${loan.montant}€, ` +
            `une pénalité de retard de 5% a été appliquée sur ${penalties.length} échéance(s) ` +
            `en retard de plus de ${PENALTY_GRACE_PERIOD_DAYS} jours.\n\n` +
            `📋 Détail des pénalités :\n${penaltyList}\n\n` +
            `💰 Total des pénalités : +${totalPenalty.toFixed(2)}€\n` +
            `💰 Nouveau total à régler : ${totalNewAmount.toFixed(2)}€\n\n` +
            `⚠️ Cette pénalité est appliquée une seule fois par échéance.\n` +
            `Aucun frais supplémentaire quotidien ne s'applique.\n\n`;

        if (debtUrl) {
            message += `📄 Votre reconnaissance de dette actualisée est disponible ici :\n${debtUrl}\n\n` +
                `Ce document remplace la version précédente et reflète les montants mis à jour.\n\n`;
        }

        message += `Merci de régulariser votre situation au plus vite.\n\n` +
            `Cordialement,\nL'équipe Chafin Loans`;

        const emailSent = await sendEmailViaEmailJS(
            { email: userEmail, name: userName, subject, message, from_name: "Chafin Loans" },
            isSimulation, testEmail
        );

        if (emailSent && !isSimulation) {
            await db.collection("reminder_logs").doc(penaltyKey).set({
                loanId,
                userId: loan.userId,
                type: "penalty_consolidated",
                penaltyCount: penalties.length,
                totalPenalty,
                penalties: penalties.map(p => ({
                    scheduleNumero: p.scheduleNumero,
                    originalTotal: p.originalTotal,
                    penaltyAmount: p.penaltyAmount,
                    newTotal: p.newTotal,
                })),
                sentAt: new Date(),
            });

            // Logger aussi dans penalty_logs pour historique détaillé
            for (const p of penalties) {
                await db.collection("penalty_logs").add({
                    loanId,
                    userId: loan.userId,
                    scheduleNumero: p.scheduleNumero,
                    originalTotal: p.originalTotal,
                    penaltyAmount: p.penaltyAmount,
                    newTotal: p.newTotal,
                    overdueDays: p.overdueDays,
                    consolidatedEmail: true,
                    sentAt: new Date(),
                });
            }
        }

        return emailSent;
    } catch (error) {
        logger.error(`❌ Erreur envoi email pénalité consolidé ${loanId}:`, error);
        return false;
    }
}

// ============================================================
// EMAILJS — AVEC GARDE-FOU ANTI-FUITE
// ============================================================

/**
 * Envoie un email via EmailJS.
 *
 * GARDE-FOU ANTI-FUITE (3 niveaux de sécurité) :
 *
 *  1. isSimulation=true + pas de testEmail → BLOQUÉ (dry-run)
 *  2. isSimulation=true + email cible ≠ testEmail → BLOQUÉ
 *  3. isSimulation=true + email cible = testEmail → AUTORISÉ
 *  4. isSimulation=false → envoi normal (production)
 */
async function sendEmailViaEmailJS(
    emailData: any,
    isSimulation: boolean = false,
    testEmail?: string
): Promise<boolean> {
    // ── GARDE-FOU ANTI-FUITE ──
    if (isSimulation) {
        if (!testEmail) {
            // Dry-run : aucun email ne part, on simule un succès
            logger.info(`🧪 [DRY-RUN] Email simulé (non envoyé) → ${emailData.email} — Sujet: ${emailData.subject}`);
            return true;
        }
        if (emailData.email !== testEmail) {
            // SÉCURITÉ : email cible ne correspond PAS au testEmail → BLOQUER
            logger.warn(`🛑 [SÉCURITÉ] Email BLOQUÉ en simulation : cible="${emailData.email}", testEmail autorisé="${testEmail}" — Sujet: ${emailData.subject}`);
            return false;
        }
        // Email cible === testEmail → autoriser l'envoi avec [TEST MAIL]
        logger.info(`🧪 [TEST] Envoi autorisé vers ${testEmail} — Sujet: ${emailData.subject}`);
    }

    try {
        const response = await axios.post(EMAILJS_CONFIG.apiUrl, {
            service_id: EMAILJS_CONFIG.serviceId,
            template_id: EMAILJS_CONFIG.templateId,
            user_id: EMAILJS_CONFIG.publicKey,
            accessToken: EMAILJS_CONFIG.privateKey,
            template_params: emailData,
        }, {
            headers: { "Origin": "https://chafin.web.app" },
        });

        if (response.status === 200) {
            logger.info(`✅ Email envoyé à ${emailData.email} — Sujet: ${emailData.subject}`);
            return true;
        } else {
            logger.error(`❌ Échec envoi email: ${response.status} - ${response.data}`);
            return false;
        }
    } catch (error: any) {
        logger.error("❌ Erreur EmailJS:", error.message);
        if (error.response) {
            logger.error("❌ Response data:", error.response.data);
        }
        return false;
    }
}

function formatDate(date: Date): string {
    return `${String(date.getDate()).padStart(2, "0")}/${String(date.getMonth() + 1).padStart(2, "0")}/${date.getFullYear()}`;
}

// ============================================================
// RÉGÉNÉRATION RECONNAISSANCE DE DETTE (sans email séparé)
// ============================================================

/**
 * Régénère le PDF de reconnaissance de dette et met à jour Firestore.
 * NE ENVOIE PAS d'email — le lien est inclus dans l'email de pénalité consolidé.
 * Retourne l'URL de téléchargement du PDF.
 */
async function regenerateDebtAcknowledgment(
    loan: FirebaseFirestore.DocumentData,
    loanId: string
): Promise<string | undefined> {
    try {
        const userDoc = await db.collection("users").doc(loan.userId).get();
        if (!userDoc.exists) return undefined;
        const userData = userDoc.data()!;

        const schedulesSnapshot = await db
            .collection("schedules")
            .where("loanId", "==", loanId)
            .orderBy("numero")
            .get();
        const schedules = schedulesSnapshot.docs.map(doc => doc.data());

        const pdfBuffer = await buildDebtPDF(loan, userData, schedules, loanId);

        const sanitizedName = (userData.nom || "emprunteur").replace(/[^a-zA-Z0-9]/g, "_");
        const fileName = `${sanitizedName}_reconnaissance_dette_${loanId}.pdf`;
        const storagePath = `loans/${loanId}/contracts/${fileName}`;

        const bucket = getStorage().bucket("chafin-23cad.firebasestorage.app");
        const file = bucket.file(storagePath);
        const downloadToken = randomUUID();

        await file.save(pdfBuffer, {
            metadata: {
                contentType: "application/pdf",
                metadata: {
                    firebaseStorageDownloadTokens: downloadToken,
                    loanId,
                    userId: loan.userId,
                    type: "reconnaissance_dette_actualisee",
                    generatedAt: new Date().toISOString(),
                },
            },
        });

        const encodedPath = encodeURIComponent(storagePath);
        const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${downloadToken}`;

        await db.collection("loans").doc(loanId).update({
            reconnaissanceDetteUrl: downloadUrl,
            reconnaissanceDetteFileName: fileName,
            reconnaissanceDetteGeneratedAt: new Date().toISOString(),
        });

        logger.info(`📄 Reconnaissance de dette actualisée pour prêt ${loanId}`);
        return downloadUrl;
    } catch (error) {
        logger.error(`❌ Erreur régénération reconnaissance ${loanId}:`, error);
        return undefined;
    }
}

// ============================================================
// DÉGRADATION AUTOMATIQUE DU NIVEAU DE RISQUE (sans email)
// ============================================================

/**
 * Dégrade le niveau de risque d'un utilisateur après 60+ jours de retard.
 * Met à jour Firestore + ajoute une notification in-app.
 * PAS D'EMAIL — l'utilisateur voit la notification dans l'app.
 */
async function checkAndDowngradeUserRisk(userId: string, maxOverdueDays: number): Promise<boolean> {
    try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) return false;

        const userData = userDoc.data()!;
        const currentLevel = userData.niveauConfiance as number | null | undefined;

        if (currentLevel !== null && currentLevel !== undefined && currentLevel <= 1.0) {
            return false;
        }

        const previousLevel = currentLevel ?? 3.0;

        await db.collection("users").doc(userId).update({
            niveauConfiance: 1.0,
            commentaireRisque: `Dégradation automatique : ${maxOverdueDays} jours de retard (seuil: ${RISK_DOWNGRADE_THRESHOLD_DAYS}j). Ancien niveau: ${previousLevel}`,
            dernierEvaluationRisque: new Date().toISOString(),
            evaluePar: "SYSTEM_AUTO",
        });

        await db.collection("risk_assessments").add({
            userId, previousLevel, newLevel: 1.0,
            reason: `Retard de paiement automatique (${maxOverdueDays} jours)`,
            assessedBy: "SYSTEM_AUTO",
            assessedAt: new Date(),
            isAutomatic: true,
        });

        await db.collection("notifications").add({
            userId,
            title: "⚠️ Niveau de risque modifié",
            body: `Votre niveau de confiance est passé de "${getRiskLabel(previousLevel)}" à "Gros risque" suite à ${maxOverdueDays} jours de retard.`,
            type: "rateChange",
            isRead: false,
            data: { previousLevel, newLevel: 1.0, reason: "auto_downgrade", overdueDays: maxOverdueDays },
            createdAt: new Date(),
        });

        logger.info(`🔴 Utilisateur ${userId} dégradé: ${previousLevel} → 1.0 (${maxOverdueDays}j retard)`);
        return true;
    } catch (error) {
        logger.error(`❌ Erreur dégradation risque ${userId}:`, error);
        return false;
    }
}

function getRiskLabel(level: number): string {
    if (level >= 4.0) return "Faible risque";
    if (level >= 2.0) return "Risque normal";
    return "Gros risque";
}
