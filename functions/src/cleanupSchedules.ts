import * as functions from "firebase-functions";
import { getFirestore } from "firebase-admin/firestore";
import { FieldValue, Timestamp } from "firebase-admin/firestore";

/**
 * Fonction de nettoyage des schedules mal formés dans Firebase
 * 
 * Problème : Des schedules ont été créés avec seulement isPaid/paidAt/paidAmount
 * mais sans les champs obligatoires (loanId, dueDate, numero, principal, interet, total)
 * 
 * Cette fonction les supprime pour nettoyer la base de données.
 * 
 * Utilisation : Appeler manuellement via Firebase Console ou CLI
 */
export const cleanupMalformedSchedules = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
        try {
            console.log("🧹 Début du nettoyage des schedules mal formés...");

            const db = getFirestore();
            const schedulesRef = db.collection("schedules");
            const snapshot = await schedulesRef.get();

            let malformedCount = 0;
            let validCount = 0;
            const malformedIds: string[] = [];
            const batch = db.batch();
            let batchCount = 0;

            for (const doc of snapshot.docs) {
                const data = doc.data();

                // Vérifier si les champs obligatoires sont présents
                const isMalformed =
                    !data.loanId ||
                    !data.dueDate ||
                    data.numero === undefined ||
                    data.principal === undefined ||
                    data.interet === undefined ||
                    data.total === undefined;

                if (isMalformed) {
                    console.log(`❌ Schedule mal formé trouvé: ${doc.id}`);
                    console.log(`   Données: ${JSON.stringify(data)}`);
                    malformedIds.push(doc.id);
                    batch.delete(doc.ref);
                    batchCount++;
                    malformedCount++;

                    // Firebase batch limit = 500 operations
                    if (batchCount >= 450) {
                        await batch.commit();
                        console.log(`💾 Batch de ${batchCount} suppressions effectué`);
                        batchCount = 0;
                    }
                } else {
                    validCount++;
                }
            }

            // Commit remaining deletes
            if (batchCount > 0) {
                await batch.commit();
                console.log(`💾 Dernier batch de ${batchCount} suppressions effectué`);
            }

            const result = {
                success: true,
                message: "Nettoyage terminé avec succès",
                totalScanned: snapshot.size,
                malformedDeleted: malformedCount,
                validRemaining: validCount,
                deletedIds: malformedIds,
            };

            console.log("✅ Nettoyage terminé:");
            console.log(`   - Documents scannés: ${snapshot.size}`);
            console.log(`   - Mal formés supprimés: ${malformedCount}`);
            console.log(`   - Valides conservés: ${validCount}`);

            res.status(200).json(result);
        } catch (error) {
            console.error("❌ Erreur lors du nettoyage:", error);
            res.status(500).json({
                success: false,
                error: String(error),
            });
        }
    });

/**
 * Fonction pour recréer les schedules manquants pour tous les prêts en cours
 * 
 * Cette fonction regénère les échéanciers pour les prêts qui n'en ont pas
 * ou dont l'échéancier est incomplet.
 */
export const regenerateSchedules = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
        try {
            console.log("🔄 Début de la régénération des schedules...");

            const db = getFirestore();
            const loansRef = db.collection("loans");
            const schedulesRef = db.collection("schedules");

            // Récupérer tous les prêts en cours, approuvés ou soldés
            const loansSnapshot = await loansRef
                .where("statut", "in", ["enCours", "approuve", "solde", "decaissementEffectue"])
                .get();

            let regeneratedCount = 0;
            const errors: string[] = [];

            for (const loanDoc of loansSnapshot.docs) {
                try {
                    const loan = loanDoc.data();
                    const loanId = loanDoc.id;

                    console.log(`📊 Vérification prêt ${loanId}...`);

                    // Vérifier si les schedules existent déjà
                    const existingSchedules = await schedulesRef
                        .where("loanId", "==", loanId)
                        .get();

                    const expectedScheduleCount = loan.dureeMois || 0;

                    if (existingSchedules.size >= expectedScheduleCount) {
                        console.log(
                            `✅ Prêt ${loanId}: ${existingSchedules.size}/${expectedScheduleCount} schedules OK`
                        );
                        continue;
                    }

                    console.log(
                        `⚠️ Prêt ${loanId}: seulement ${existingSchedules.size}/${expectedScheduleCount} schedules, régénération...`
                    );

                    // Supprimer les anciens schedules incomplets
                    const batch = db.batch();
                    for (const scheduleDoc of existingSchedules.docs) {
                        batch.delete(scheduleDoc.ref);
                    }
                    await batch.commit();

                    // Régénérer l'échéancier complet
                    const schedule = generateScheduleForLoan(loan, loanId);

                    const newBatch = db.batch();
                    for (const item of schedule) {
                        const scheduleRef = schedulesRef.doc(item.id);
                        newBatch.set(scheduleRef, item);
                    }
                    await newBatch.commit();

                    console.log(`✅ ${schedule.length} nouveaux schedules créés pour ${loanId}`);
                    regeneratedCount++;
                } catch (error) {
                    console.error(`❌ Erreur prêt ${loanDoc.id}:`, error);
                    errors.push(`${loanDoc.id}: ${error}`);
                }
            }

            const result = {
                success: true,
                message: "Régénération terminée",
                loansProcessed: loansSnapshot.size,
                schedulesRegenerated: regeneratedCount,
                errors: errors,
            };

            console.log("✅ Régénération terminée:");
            console.log(`   - Prêts traités: ${loansSnapshot.size}`);
            console.log(`   - Schedules régénérés: ${regeneratedCount}`);
            console.log(`   - Erreurs: ${errors.length}`);

            res.status(200).json(result);
        } catch (error) {
            console.error("❌ Erreur lors de la régénération:", error);
            res.status(500).json({
                success: false,
                error: String(error),
            });
        }
    });

/**
 * Génère un échéancier complet pour un prêt
 */
/**
 * Génère l'échéancier pour un prêt avec TAUX SIMPLE
 * RÈGLE : Mensualité constante = (Capital + Intérêts totaux) / Durée
 * Exemple : 1000€ sur 12 mois à 20% → 1200€ total → 100€/mois
 */
function generateScheduleForLoan(loan: any, loanId: string): any[] {
    const schedule: any[] = [];
    const capital = loan.montant;
    const tauxAnnuel = loan.tauxAnnuel;
    const dureeMois = loan.dureeMois;

    // TAUX SIMPLE : Intérêts totaux calculés sur le capital initial
    const interetsTotaux = capital * (tauxAnnuel / 100);
    const montantTotal = capital + interetsTotaux;

    // Mensualité constante
    const mensualiteConstante = montantTotal / dureeMois;

    // Répartition proportionnelle des intérêts et du principal
    const interetMensuel = interetsTotaux / dureeMois;
    const principalMensuel = capital / dureeMois;

    // Gérer les arrondis : accumuler pour ajuster la dernière mensualité
    let totalPrincipalAccumule = 0;
    let totalInteretAccumule = 0;

    const datePremierPaiement = loan.datePremierRemboursement
        ? new Date(loan.datePremierRemboursement)
        : new Date(loan.dateSouhaitee);

    for (let i = 1; i <= dureeMois; i++) {
        // Calculer la date d'échéance
        const dueDate = new Date(datePremierPaiement);
        dueDate.setMonth(dueDate.getMonth() + i - 1);

        let principal: number;
        let interet: number;
        let total: number;

        if (i < dureeMois) {
            // Pour les mensualités 1 à n-1 : utiliser la répartition proportionnelle
            principal = Math.round(principalMensuel * 100) / 100;
            interet = Math.round(interetMensuel * 100) / 100;
            total = Math.round(mensualiteConstante * 100) / 100;

            totalPrincipalAccumule += principal;
            totalInteretAccumule += interet;
        } else {
            // Pour la dernière mensualité : ajuster pour que le total soit exact
            principal = Math.round((capital - totalPrincipalAccumule) * 100) / 100;
            interet = Math.round((interetsTotaux - totalInteretAccumule) * 100) / 100;
            total = principal + interet;
        }

        // Créer l'item de schedule
        const scheduleItem = {
            id: `${loanId}_${i}`,
            loanId: loanId,
            numero: i,
            dueDate: Timestamp.fromDate(dueDate),
            principal: principal,
            interet: interet,
            total: total,
            isPaid: false,
            paidAt: null,
            paidAmount: null,
            noteAdmin: null,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: null,
        };

        schedule.push(scheduleItem);
    }

    return schedule;
}

/**
 * Recalcule TOUS les échéanciers avec le nouveau calcul de mensualité constante
 * PRÉSERVE les paiements déjà effectués (isPaid, paidAt, paidAmount)
 */
export const recalculateAllSchedules = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
        try {
            console.log("🔄 Début du recalcul de TOUS les échéanciers... [v2]");

            const db = getFirestore();
            const loansRef = db.collection("loans");
            const schedulesRef = db.collection("schedules");

            // Récupérer tous les prêts (tous statuts)
            const loansSnapshot = await loansRef.get();

            console.log(`📊 Nombre total de prêts trouvés: ${loansSnapshot.size}`);

            let recalculatedLoans = 0;
            let preservedPayments = 0;
            const errors: string[] = [];

            for (const loanDoc of loansSnapshot.docs) {
                try {
                    const loan = loanDoc.data();
                    const loanId = loanDoc.id;

                    console.log(`📊 Recalcul prêt ${loanId}...`);
                    console.log(`   Montant: ${loan.montant}, Durée: ${loan.dureeMois}, Taux: ${loan.tauxAnnuel}`);

                    // Vérifier que les champs nécessaires existent
                    if (!loan.montant || !loan.dureeMois || !loan.tauxAnnuel) {
                        console.log(`⚠️ Prêt ${loanId}: champs manquants, ignoré`);
                        continue;
                    }

                    // Récupérer les échéances existantes
                    const existingSchedules = await schedulesRef
                        .where("loanId", "==", loanId)
                        .get();

                    // Sauvegarder l'état des paiements
                    const paymentStatus = new Map<number, { isPaid: boolean, paidAt: any, paidAmount: number | null }>();
                    existingSchedules.forEach(doc => {
                        const data = doc.data();
                        if (data.isPaid) {
                            paymentStatus.set(data.numero, {
                                isPaid: data.isPaid,
                                paidAt: data.paidAt,
                                paidAmount: data.paidAmount
                            });
                            preservedPayments++;
                        }
                    });

                    console.log(`   💰 ${paymentStatus.size} paiements à préserver`);

                    // Supprimer les anciens schedules
                    const deleteBatch = db.batch();
                    existingSchedules.forEach(doc => {
                        deleteBatch.delete(doc.ref);
                    });
                    await deleteBatch.commit();

                    // Régénérer l'échéancier avec le nouveau calcul
                    const newSchedule = generateScheduleForLoan(loan, loanId);

                    // Restaurer les paiements
                    newSchedule.forEach(item => {
                        const payment = paymentStatus.get(item.numero);
                        if (payment) {
                            item.isPaid = payment.isPaid;
                            item.paidAt = payment.paidAt;
                            item.paidAmount = payment.paidAmount;
                        }
                    });

                    // Créer les nouveaux schedules
                    const createBatch = db.batch();
                    newSchedule.forEach(item => {
                        const scheduleRef = schedulesRef.doc(item.id);
                        createBatch.set(scheduleRef, item);
                    });
                    await createBatch.commit();

                    console.log(`   ✅ ${newSchedule.length} échéances recalculées, ${paymentStatus.size} paiements restaurés`);
                    recalculatedLoans++;
                } catch (error) {
                    console.error(`❌ Erreur prêt ${loanDoc.id}:`, error);
                    errors.push(`${loanDoc.id}: ${error}`);
                }
            }

            const result = {
                success: true,
                message: "Recalcul terminé avec préservation des paiements",
                totalLoans: loansSnapshot.size,
                loansRecalculated: recalculatedLoans,
                paymentsPreserved: preservedPayments,
                errors: errors,
            };

            console.log("✅ Recalcul terminé:");
            console.log(`   - Prêts traités: ${loansSnapshot.size}`);
            console.log(`   - Échéanciers recalculés: ${recalculatedLoans}`);
            console.log(`   - Paiements préservés: ${preservedPayments}`);
            console.log(`   - Erreurs: ${errors.length}`);

            res.status(200).json(result);
        } catch (error) {
            console.error("❌ Erreur lors du recalcul:", error);
            res.status(500).json({
                success: false,
                error: String(error),
            });
        }
    });
