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
exports.backfillDebtDocuments = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("firebase-admin/firestore");
const storage_1 = require("firebase-admin/storage");
const logger = __importStar(require("firebase-functions/logger"));
const crypto_1 = require("crypto");
const debtAcknowledgment_1 = require("./debtAcknowledgment");
/**
 * Cloud Function HTTP one-shot :
 * Génère et envoie les reconnaissances de dette pour TOUS les prêts
 * déjà en cours (enCours, enRetard) qui n'en ont pas encore.
 *
 * Usage : appeler une seule fois via l'URL de la fonction ou la console Firebase
 * GET https://us-central1-chafin-23cad.cloudfunctions.net/backfillDebtDocuments
 */
exports.backfillDebtDocuments = functions
    .region("us-central1")
    .runWith({ timeoutSeconds: 540, memory: "512MB" }) // 9 min timeout, plus de mémoire pour les PDFs
    .https.onRequest(async (req, res) => {
    logger.info("📄 [BACKFILL] Début de la génération des reconnaissances de dette manquantes...");
    const db = (0, firestore_1.getFirestore)();
    const bucket = (0, storage_1.getStorage)().bucket("chafin-23cad.firebasestorage.app");
    // Compteurs pour le rapport
    let totalFound = 0;
    let totalGenerated = 0;
    let totalEmailed = 0;
    let totalSkipped = 0;
    const errors = [];
    const generated = [];
    try {
        // Récupérer tous les prêts en cours ou en retard
        const activeStatuses = ["enCours", "enRetard"];
        const allLoans = [];
        for (const statut of activeStatuses) {
            const snapshot = await db
                .collection("loans")
                .where("statut", "==", statut)
                .get();
            snapshot.docs.forEach(doc => allLoans.push(doc));
        }
        totalFound = allLoans.length;
        logger.info(`📊 [BACKFILL] ${totalFound} prêts actifs trouvés (enCours + enRetard)`);
        // Filtrer ceux qui n'ont pas encore de reconnaissance de dette
        const loansWithoutDebt = allLoans.filter(doc => {
            const data = doc.data();
            return !data.reconnaissanceDetteUrl;
        });
        logger.info(`📋 [BACKFILL] ${loansWithoutDebt.length} prêts sans reconnaissance de dette`);
        totalSkipped = totalFound - loansWithoutDebt.length;
        // Traiter chaque prêt séquentiellement (pour éviter de surcharger EmailJS)
        for (const loanDoc of loansWithoutDebt) {
            const loanId = loanDoc.id;
            const loanData = loanDoc.data();
            try {
                logger.info(`🔄 [BACKFILL] Traitement du prêt ${loanId}...`);
                // Récupérer les données de l'emprunteur
                const userDoc = await db.collection("users").doc(loanData.userId).get();
                if (!userDoc.exists) {
                    logger.warn(`⚠️ [BACKFILL] Utilisateur ${loanData.userId} non trouvé pour prêt ${loanId}`);
                    errors.push({ loanId, error: `Utilisateur ${loanData.userId} non trouvé` });
                    continue;
                }
                const userData = userDoc.data();
                // Récupérer l'échéancier
                const schedulesSnapshot = await db
                    .collection("schedules")
                    .where("loanId", "==", loanId)
                    .orderBy("numero")
                    .get();
                const schedules = schedulesSnapshot.docs.map(doc => doc.data());
                // Générer le PDF
                const pdfBuffer = await (0, debtAcknowledgment_1.buildDebtPDF)(loanData, userData, schedules, loanId);
                // Nom du fichier
                const sanitizedName = (userData.nom || "emprunteur").replace(/[^a-zA-Z0-9]/g, "_");
                const fileName = `${sanitizedName}_reconnaissance_dette_${loanId}.pdf`;
                const storagePath = `loans/${loanId}/contracts/${fileName}`;
                // Upload sur Firebase Storage
                const file = bucket.file(storagePath);
                const downloadToken = (0, crypto_1.randomUUID)();
                await file.save(pdfBuffer, {
                    metadata: {
                        contentType: "application/pdf",
                        metadata: {
                            firebaseStorageDownloadTokens: downloadToken,
                            loanId: loanId,
                            userId: loanData.userId,
                            type: "reconnaissance_dette",
                            generatedAt: new Date().toISOString(),
                            source: "backfill", // Marquer comme généré par backfill
                        },
                    },
                });
                // URL de téléchargement
                const bucketName = bucket.name;
                const encodedPath = encodeURIComponent(storagePath);
                const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${downloadToken}`;
                // Sauvegarder dans Firestore
                await db.collection("loans").doc(loanId).update({
                    reconnaissanceDetteUrl: downloadUrl,
                    reconnaissanceDetteFileName: fileName,
                    reconnaissanceDetteGeneratedAt: new Date().toISOString(),
                });
                totalGenerated++;
                const userName = `${userData.prenom || ""} ${userData.nom || ""}`.trim();
                generated.push({ loanId, userName, montant: loanData.montant || 0 });
                logger.info(`✅ [BACKFILL] PDF généré pour ${loanId} (${userName})`);
                // Envoyer par email
                if (userData.email) {
                    try {
                        await (0, debtAcknowledgment_1.sendDebtAcknowledgmentEmail)(userData.email, userName, loanData, loanId, downloadUrl);
                        totalEmailed++;
                        logger.info(`📧 [BACKFILL] Email envoyé à ${userData.email}`);
                    }
                    catch (emailErr) {
                        logger.error(`⚠️ [BACKFILL] Erreur email pour ${loanId}:`, emailErr);
                        errors.push({ loanId, error: `PDF généré mais erreur email: ${emailErr}` });
                    }
                    // Petite pause entre chaque email pour ne pas surcharger EmailJS (200 req/mois)
                    await sleep(2000);
                }
            }
            catch (loanErr) {
                logger.error(`❌ [BACKFILL] Erreur pour prêt ${loanId}:`, loanErr);
                errors.push({ loanId, error: String(loanErr) });
            }
        }
        // Rapport final
        const report = {
            success: true,
            summary: {
                totalLoansActifs: totalFound,
                dejaAvecReconnaissance: totalSkipped,
                sansReconnaissance: loansWithoutDebt.length,
                pdfsGeneres: totalGenerated,
                emailsEnvoyes: totalEmailed,
                erreurs: errors.length,
            },
            generated,
            errors: errors.length > 0 ? errors : undefined,
            timestamp: new Date().toISOString(),
        };
        logger.info(`🏁 [BACKFILL] Terminé ! ${totalGenerated} PDFs générés, ${totalEmailed} emails envoyés`);
        res.status(200).json(report);
    }
    catch (error) {
        logger.error("❌ [BACKFILL] Erreur fatale:", error);
        res.status(500).json({
            success: false,
            error: String(error),
            partialResults: {
                pdfsGeneres: totalGenerated,
                emailsEnvoyes: totalEmailed,
                erreurs: errors,
            },
        });
    }
});
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}
//# sourceMappingURL=backfillDebtDocs.js.map