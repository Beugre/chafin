"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkLoanStatus = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const logger = __importStar(require("firebase-functions/logger"));
const db = (0, firestore_1.getFirestore)();
/**
 * Vérifie et met à jour le statut d'un prêt spécifique
 */
exports.checkLoanStatus = (0, https_1.onRequest)(async (req, res) => {
    try {
        const loanId = req.query.loanId;
        if (!loanId) {
            res.status(400).json({ error: "loanId requis" });
            return;
        }
        logger.info(`🔍 Vérification du prêt ${loanId}`);
        // Récupérer le prêt
        const loanDoc = await db.collection("loans").doc(loanId).get();
        if (!loanDoc.exists) {
            res.status(404).json({ error: "Prêt non trouvé" });
            return;
        }
        const loan = loanDoc.data();
        const now = new Date();
        // Récupérer les échéances non payées
        const schedulesSnapshot = await db
            .collection("schedules")
            .where("loanId", "==", loanId)
            .where("isPaid", "==", false)
            .get();
        logger.info(`📊 ${schedulesSnapshot.size} échéances non payées`);
        let hasOverduePayments = false;
        const overdueSchedules = [];
        for (const scheduleDoc of schedulesSnapshot.docs) {
            const schedule = scheduleDoc.data();
            const dueDate = schedule.dueDate.toDate();
            const daysDifference = Math.ceil((dueDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
            logger.info(`  Échéance #${schedule.numero}: ${dueDate.toISOString()} (${daysDifference} jours)`);
            if (daysDifference < 0) {
                hasOverduePayments = true;
                overdueSchedules.push({
                    numero: schedule.numero,
                    dueDate: dueDate.toISOString(),
                    daysOverdue: Math.abs(daysDifference),
                    amount: schedule.total,
                });
            }
        }
        // Déterminer le nouveau statut
        let newStatus = loan.statut;
        let statusChanged = false;
        if (hasOverduePayments && loan.statut !== "enRetard") {
            newStatus = "enRetard";
            statusChanged = true;
            await db.collection("loans").doc(loanId).update({
                statut: "enRetard",
                updatedAt: new Date(),
            });
            logger.info(`⚠️ Prêt ${loanId} marqué en retard`);
        }
        else if (!hasOverduePayments && loan.statut === "enRetard") {
            newStatus = "enCours";
            statusChanged = true;
            await db.collection("loans").doc(loanId).update({
                statut: "enCours",
                updatedAt: new Date(),
            });
            logger.info(`✅ Prêt ${loanId} repassé en cours`);
        }
        res.json({
            success: true,
            loanId,
            previousStatus: loan.statut,
            newStatus,
            statusChanged,
            hasOverduePayments,
            overdueSchedules,
            totalUnpaidSchedules: schedulesSnapshot.size,
        });
    }
    catch (error) {
        logger.error("❌ Erreur:", error);
        res.status(500).json({
            success: false,
            error: String(error),
        });
    }
});
//# sourceMappingURL=checkLoanStatus.js.map