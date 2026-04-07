"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupDuplicateSchedules = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const db = (0, firestore_1.getFirestore)();
/**
 * Nettoie les échéances en double pour un prêt
 * Garde uniquement la version avec dueDate au format Timestamp
 */
exports.cleanupDuplicateSchedules = (0, https_1.onRequest)(async (req, res) => {
    try {
        console.log("🧹 Début du nettoyage des échéances dupliquées");
        const schedulesSnapshot = await db.collection("schedules").get();
        // Grouper par loanId + numero
        const schedulesByLoanAndNumero = new Map();
        for (const doc of schedulesSnapshot.docs) {
            const data = doc.data();
            const key = `${data.loanId}_${data.numero}`;
            if (!schedulesByLoanAndNumero.has(key)) {
                schedulesByLoanAndNumero.set(key, []);
            }
            schedulesByLoanAndNumero.get(key).push(Object.assign({ id: doc.id, ref: doc.ref }, data));
        }
        let duplicatesRemoved = 0;
        // Pour chaque groupe, garder uniquement celle avec Timestamp
        for (const [key, schedules] of schedulesByLoanAndNumero.entries()) {
            if (schedules.length > 1) {
                console.log(`🔍 Trouvé ${schedules.length} doublons pour ${key}`);
                // Trier : Timestamp en premier, String après
                schedules.sort((a, b) => {
                    const aIsTimestamp = a.dueDate && typeof a.dueDate.toDate === 'function';
                    const bIsTimestamp = b.dueDate && typeof b.dueDate.toDate === 'function';
                    if (aIsTimestamp && !bIsTimestamp)
                        return -1;
                    if (!aIsTimestamp && bIsTimestamp)
                        return 1;
                    return 0;
                });
                // Garder le premier (avec Timestamp), supprimer les autres
                for (let i = 1; i < schedules.length; i++) {
                    await schedules[i].ref.delete();
                    duplicatesRemoved++;
                    console.log(`  ❌ Supprimé doublon: ${schedules[i].id}`);
                }
                console.log(`  ✅ Conservé: ${schedules[0].id}`);
            }
        }
        console.log(`✅ Nettoyage terminé: ${duplicatesRemoved} doublons supprimés`);
        res.json({
            success: true,
            duplicatesRemoved,
            message: `${duplicatesRemoved} échéances dupliquées supprimées`
        });
    }
    catch (error) {
        console.error("❌ Erreur lors du nettoyage:", error);
        res.status(500).json({
            success: false,
            error: String(error)
        });
    }
});
//# sourceMappingURL=cleanupDuplicates.js.map