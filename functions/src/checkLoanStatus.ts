import { onRequest } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

const db = getFirestore();

/**
 * Vérifie et met à jour le statut d'un prêt spécifique
 */
export const checkLoanStatus = onRequest(async (req, res) => {
    try {
        const loanId = req.query.loanId as string;

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

        const loan = loanDoc.data()!;
        const now = new Date();

        // Récupérer les échéances non payées
        const schedulesSnapshot = await db
            .collection("schedules")
            .where("loanId", "==", loanId)
            .where("isPaid", "==", false)
            .get();

        logger.info(`📊 ${schedulesSnapshot.size} échéances non payées`);

        let hasOverduePayments = false;
        const overdueSchedules: any[] = [];

        for (const scheduleDoc of schedulesSnapshot.docs) {
            const schedule = scheduleDoc.data();
            const dueDate = schedule.dueDate.toDate();
            const daysDifference = Math.ceil(
                (dueDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
            );

            logger.info(
                `  Échéance #${schedule.numero}: ${dueDate.toISOString()} (${daysDifference} jours)`
            );

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
        } else if (!hasOverduePayments && loan.statut === "enRetard") {
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

    } catch (error) {
        logger.error("❌ Erreur:", error);
        res.status(500).json({
            success: false,
            error: String(error),
        });
    }
});
