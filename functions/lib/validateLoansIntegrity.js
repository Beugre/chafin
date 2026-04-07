"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateLoansIntegrity = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const db = (0, firestore_1.getFirestore)();
/**
 * Vérifie la cohérence entre les prêts et leurs échéanciers
 * Détecte les incohérences : échéances manquantes, doublons, montants incorrects, etc.
 */
exports.validateLoansIntegrity = (0, https_1.onRequest)(async (req, res) => {
    var _a, _b, _c;
    try {
        console.log("🔍 Début de la validation de l'intégrité des prêts");
        const loansSnapshot = await db.collection("loans").get();
        const schedulesSnapshot = await db.collection("schedules").get();
        // Grouper les échéances par loanId
        const schedulesByLoan = new Map();
        for (const doc of schedulesSnapshot.docs) {
            const data = doc.data();
            const loanId = data.loanId;
            if (!schedulesByLoan.has(loanId)) {
                schedulesByLoan.set(loanId, []);
            }
            schedulesByLoan.get(loanId).push(Object.assign({ id: doc.id }, data));
        }
        const issues = [];
        let totalLoans = 0;
        let loansWithIssues = 0;
        for (const loanDoc of loansSnapshot.docs) {
            totalLoans++;
            const loan = loanDoc.data();
            const loanId = loanDoc.id;
            const schedules = schedulesByLoan.get(loanId) || [];
            const loanIssues = [];
            // 1. Vérifier si le prêt devrait avoir un échéancier
            const shouldHaveSchedule = ["approuve", "enCours", "decaissementEffectue", "enRetard", "solde"].includes(loan.statut);
            if (shouldHaveSchedule && schedules.length === 0) {
                loanIssues.push(`❌ Aucun échéancier trouvé (statut: ${loan.statut})`);
            }
            if (schedules.length > 0) {
                // 2. Vérifier le nombre d'échéances
                const expectedCount = loan.dureeMois;
                const actualCount = schedules.length;
                if (actualCount !== expectedCount) {
                    loanIssues.push(`⚠️ Nombre d'échéances incorrect: ${actualCount} au lieu de ${expectedCount}`);
                }
                // 3. Vérifier les doublons de numéros
                const numeros = schedules.map(s => s.numero);
                const uniqueNumeros = new Set(numeros);
                if (numeros.length !== uniqueNumeros.size) {
                    const duplicates = numeros.filter((n, i) => numeros.indexOf(n) !== i);
                    loanIssues.push(`🔴 Numéros d'échéances dupliqués: ${[...new Set(duplicates)].join(", ")}`);
                }
                // 4. Vérifier la continuité des numéros (1, 2, 3, ...)
                const sortedNumeros = [...uniqueNumeros].sort((a, b) => a - b);
                for (let i = 0; i < sortedNumeros.length; i++) {
                    if (sortedNumeros[i] !== i + 1) {
                        loanIssues.push(`⚠️ Numérotation discontinue: manque ${i + 1}, trouvé ${sortedNumeros[i]}`);
                        break;
                    }
                }
                // 5. Calculer le total attendu avec TAUX SIMPLE
                const capital = loan.montant;
                const taux = loan.tauxAnnuel;
                const interetsTotal = capital * (taux / 100);
                const montantTotal = capital + interetsTotal;
                // 6. Vérifier la somme des échéances
                const totalSchedules = schedules.reduce((sum, s) => sum + (s.total || 0), 0);
                const difference = Math.abs(totalSchedules - montantTotal);
                if (difference > 0.1) {
                    loanIssues.push(`💰 Montant total incorrect: ${totalSchedules.toFixed(2)}€ au lieu de ${montantTotal.toFixed(2)}€ (écart: ${difference.toFixed(2)}€)`);
                }
                // 7. Vérifier que les mensualités sont constantes (sauf arrondis)
                const mensualites = schedules.map(s => s.total);
                const avgMensualite = mensualites.reduce((a, b) => a + b, 0) / mensualites.length;
                const hasInconsistentMensualites = mensualites.some(m => Math.abs(m - avgMensualite) > 0.5);
                if (hasInconsistentMensualites) {
                    loanIssues.push(`⚠️ Mensualités non constantes: min ${Math.min(...mensualites).toFixed(2)}€, max ${Math.max(...mensualites).toFixed(2)}€`);
                }
                // 8. Vérifier les champs obligatoires
                for (const schedule of schedules) {
                    const missingFields = [];
                    if (!schedule.loanId)
                        missingFields.push("loanId");
                    if (!schedule.numero)
                        missingFields.push("numero");
                    if (!schedule.dueDate)
                        missingFields.push("dueDate");
                    if (schedule.principal === undefined)
                        missingFields.push("principal");
                    if (schedule.interet === undefined)
                        missingFields.push("interet");
                    if (schedule.total === undefined)
                        missingFields.push("total");
                    if (schedule.isPaid === undefined)
                        missingFields.push("isPaid");
                    if (missingFields.length > 0) {
                        loanIssues.push(`❌ Échéance #${schedule.numero}: champs manquants [${missingFields.join(", ")}]`);
                    }
                }
                // 9. Vérifier la cohérence du calcul (principal + interet = total)
                for (const schedule of schedules) {
                    const calculatedTotal = (schedule.principal || 0) + (schedule.interet || 0);
                    const actualTotal = schedule.total || 0;
                    const diff = Math.abs(calculatedTotal - actualTotal);
                    if (diff > 0.01) {
                        loanIssues.push(`⚠️ Échéance #${schedule.numero}: total incohérent (${(_a = schedule.principal) === null || _a === void 0 ? void 0 : _a.toFixed(2)} + ${(_b = schedule.interet) === null || _b === void 0 ? void 0 : _b.toFixed(2)} ≠ ${(_c = schedule.total) === null || _c === void 0 ? void 0 : _c.toFixed(2)})`);
                    }
                }
                // 10. Vérifier les dates en séquence
                const dates = schedules
                    .sort((a, b) => a.numero - b.numero)
                    .map(s => {
                    var _a;
                    if ((_a = s.dueDate) === null || _a === void 0 ? void 0 : _a.toDate)
                        return s.dueDate.toDate();
                    if (typeof s.dueDate === 'string')
                        return new Date(s.dueDate);
                    return null;
                });
                for (let i = 1; i < dates.length; i++) {
                    if (dates[i] && dates[i - 1] && dates[i] <= dates[i - 1]) {
                        loanIssues.push(`📅 Échéance #${i + 1}: date non croissante`);
                    }
                }
            }
            if (loanIssues.length > 0) {
                loansWithIssues++;
                issues.push({
                    loanId: loanId,
                    emprunteur: loan.nomEmprunteur || loan.borrowerName || "Inconnu",
                    montant: loan.montant,
                    statut: loan.statut,
                    nbEcheances: schedules.length,
                    problemes: loanIssues
                });
            }
        }
        // Résumé
        const summary = {
            totalLoans,
            loansWithIssues,
            loansHealthy: totalLoans - loansWithIssues,
            healthPercentage: ((totalLoans - loansWithIssues) / totalLoans * 100).toFixed(1)
        };
        console.log(`✅ Validation terminée: ${loansWithIssues}/${totalLoans} prêts avec problèmes`);
        res.json({
            success: true,
            summary,
            issues,
            timestamp: new Date().toISOString()
        });
    }
    catch (error) {
        console.error("❌ Erreur lors de la validation:", error);
        res.status(500).json({
            success: false,
            error: String(error)
        });
    }
});
//# sourceMappingURL=validateLoansIntegrity.js.map