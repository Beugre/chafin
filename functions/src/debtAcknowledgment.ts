import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as logger from "firebase-functions/logger";
import axios from "axios";
import PDFDocument from "pdfkit";
import { randomUUID } from "crypto";

// Configuration EmailJS (identique à index.ts)
const EMAILJS_CONFIG = {
    serviceId: "service_s6kh76e",
    templateId: "template_byf1fdm",
    publicKey: "sUFWr-XkJM8NcZQ86",
    privateKey: "iihl6951E8XgF-0y3Dumm",
    apiUrl: "https://api.emailjs.com/api/v1.0/email/send",
};

/**
 * Cloud Function Firestore trigger : génère une reconnaissance de dette PDF
 * quand un prêt passe au statut "enCours" (après décaissement)
 * - Génère un PDF professionnel
 * - Le stocke dans Firebase Storage
 * - Envoie un email avec le lien de téléchargement
 */
export const generateDebtAcknowledgment = onDocumentUpdated("loans/{loanId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    // Trigger uniquement quand le statut passe à enCours (décaissement confirmé)
    if (before.statut === after.statut || after.statut !== "enCours") return;
    // Seulement depuis decaissementEffectue ou approuve
    if (before.statut !== "decaissementEffectue" && before.statut !== "approuve") return;

    // Guard d'idempotence : ne pas regénérer si déjà générée
    // (sauf si le flag forceRegenerateDebt est présent)
    if (after.reconnaissanceDetteGeneratedAt && !after.forceRegenerateDebt) {
        logger.info(`📄 Reconnaissance de dette déjà générée pour ${event.params.loanId} - skip`);
        return;
    }

    const loanId = event.params.loanId;
    logger.info(`📄 Génération reconnaissance de dette pour prêt ${loanId}`);

    const db = getFirestore();

    try {
        // Récupérer les données de l'emprunteur
        const userDoc = await db.collection("users").doc(after.userId).get();
        if (!userDoc.exists) {
            logger.error(`❌ Utilisateur ${after.userId} non trouvé`);
            return;
        }
        const userData = userDoc.data()!;

        // Récupérer l'échéancier
        const schedulesSnapshot = await db
            .collection("schedules")
            .where("loanId", "==", loanId)
            .orderBy("numero")
            .get();

        const schedules = schedulesSnapshot.docs.map(doc => doc.data());

        // Générer le PDF
        const pdfBuffer = await buildDebtPDF(after, userData, schedules, loanId);

        // Nom du fichier
        const sanitizedName = (userData.nom || "emprunteur").replace(/[^a-zA-Z0-9]/g, "_");
        const fileName = `${sanitizedName}_reconnaissance_dette_${loanId}.pdf`;
        const storagePath = `loans/${loanId}/contracts/${fileName}`;

        // Upload sur Firebase Storage avec download token
        const bucket = getStorage().bucket("chafin-23cad.firebasestorage.app");
        const file = bucket.file(storagePath);
        const downloadToken = randomUUID();

        await file.save(pdfBuffer, {
            metadata: {
                contentType: "application/pdf",
                metadata: {
                    firebaseStorageDownloadTokens: downloadToken,
                    loanId: loanId,
                    userId: after.userId,
                    type: "reconnaissance_dette",
                    generatedAt: new Date().toISOString(),
                },
            },
        });

        // Construire l'URL de téléchargement permanente
        const bucketName = bucket.name;
        const encodedPath = encodeURIComponent(storagePath);
        const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${downloadToken}`;

        // Sauvegarder l'URL dans le document du prêt
        await db.collection("loans").doc(loanId).update({
            reconnaissanceDetteUrl: downloadUrl,
            reconnaissanceDetteFileName: fileName,
            reconnaissanceDetteGeneratedAt: new Date().toISOString(),
        });

        // Envoyer par email
        if (userData.email) {
            await sendDebtAcknowledgmentEmail(
                userData.email,
                `${userData.prenom || ""} ${userData.nom || ""}`,
                after,
                loanId,
                downloadUrl
            );
        }

        logger.info(`✅ Reconnaissance de dette générée et envoyée pour ${loanId}`);
    } catch (error) {
        logger.error(`❌ Erreur génération reconnaissance de dette ${loanId}:`, error);
    }
});

// ============================================================
// GÉNÉRATION DU PDF
// ============================================================

export function buildDebtPDF(
    loan: FirebaseFirestore.DocumentData,
    user: FirebaseFirestore.DocumentData,
    schedules: FirebaseFirestore.DocumentData[],
    loanId: string
): Promise<Buffer> {
    return new Promise((resolve, reject) => {
        const doc = new PDFDocument({ margin: 50, size: "A4" });
        const chunks: Buffer[] = [];

        doc.on("data", (chunk: Buffer) => chunks.push(chunk));
        doc.on("end", () => resolve(Buffer.concat(chunks)));
        doc.on("error", reject);

        const now = new Date();
        const formattedDate = formatDateFR(now);

        const montant = (loan.montant as number) || 0;
        const taux = (loan.tauxAnnuel as number) || 0;
        const duree = (loan.dureeMois as number) || 0;
        const interets = montant * (taux / 100);
        const totalARembourser = montant + interets;
        const mensualite = duree > 0 ? totalARembourser / duree : 0;

        // ========== EN-TÊTE ==========
        doc.fontSize(24).font("Helvetica-Bold")
            .text("RECONNAISSANCE DE DETTE", { align: "center" });
        doc.moveDown(0.3);
        doc.fontSize(10).font("Helvetica")
            .text(`Référence : ${loanId}`, { align: "center" });
        doc.text(`Date d'établissement : ${formattedDate}`, { align: "center" });
        doc.moveDown(1.5);

        // ========== PARTIES ==========
        doc.fontSize(14).font("Helvetica-Bold")
            .text("ENTRE LES PARTIES");
        doc.moveDown(0.5);

        doc.fontSize(11).font("Helvetica");
        doc.font("Helvetica-Bold").text("Le Prêteur : ", { continued: true });
        doc.font("Helvetica").text("Chafin Loans - Plateforme de prêts entre particuliers");
        doc.moveDown(0.5);

        doc.font("Helvetica-Bold").text("L'Emprunteur : ", { continued: true });
        doc.font("Helvetica").text(`${user.prenom || ""} ${user.nom || ""}`);
        doc.text(`Email : ${user.email || "Non renseigné"}`);
        doc.text(`Téléphone : ${user.telephone || "Non renseigné"}`);
        doc.text(`Adresse : ${user.adresse || "Non renseignée"}`);
        doc.moveDown(1);

        // ========== OBJET ==========
        doc.fontSize(14).font("Helvetica-Bold")
            .text("OBJET DE LA RECONNAISSANCE");
        doc.moveDown(0.5);

        doc.fontSize(11).font("Helvetica");
        doc.text(
            `Je soussigné(e) ${user.prenom || ""} ${user.nom || ""}, ` +
            `reconnais devoir à Chafin Loans la somme de ${montant.toFixed(2)} euros, ` +
            `au titre d'un prêt personnel consenti ce jour.`
        );
        doc.moveDown(1);

        // ========== CONDITIONS DU PRÊT ==========
        doc.fontSize(14).font("Helvetica-Bold")
            .text("CONDITIONS DU PRÊT");
        doc.moveDown(0.5);

        doc.fontSize(11).font("Helvetica");
        const conditions: [string, string][] = [
            ["Capital emprunté", `${montant.toFixed(2)} €`],
            ["Taux d'intérêt", `${taux.toFixed(2)} %`],
            ["Durée de remboursement", `${duree} mois`],
            ["Intérêts totaux", `${interets.toFixed(2)} €`],
            ["Montant total à rembourser", `${totalARembourser.toFixed(2)} €`],
            ["Mensualité", `${mensualite.toFixed(2)} €`],
        ];

        for (const [label, value] of conditions) {
            doc.font("Helvetica-Bold").text(`${label} : `, { continued: true });
            doc.font("Helvetica").text(value);
        }
        doc.moveDown(1);

        // ========== ENGAGEMENT ==========
        doc.fontSize(14).font("Helvetica-Bold")
            .text("ENGAGEMENT DE REMBOURSEMENT");
        doc.moveDown(0.5);

        doc.fontSize(11).font("Helvetica");
        doc.text(
            `L'emprunteur s'engage à rembourser la somme totale de ${totalARembourser.toFixed(2)} € ` +
            `en ${duree} mensualités de ${mensualite.toFixed(2)} €, selon l'échéancier ci-dessous.`
        );
        doc.moveDown(0.5);
        doc.text(
            "En cas de retard de paiement, une pénalité de 5% du montant de l'échéance " +
            "sera automatiquement appliquée. Au-delà de 60 jours de retard, le niveau de " +
            "confiance de l'emprunteur sera dégradé, entraînant une majoration des taux " +
            "pour les futures demandes de prêt."
        );
        doc.moveDown(1);

        // ========== ÉCHÉANCIER ==========
        if (schedules.length > 0) {
            // Si on est trop bas sur la page, commencer une nouvelle page
            if (doc.y > 550) {
                doc.addPage();
            }

            doc.fontSize(14).font("Helvetica-Bold")
                .text("ÉCHÉANCIER DE REMBOURSEMENT");
            doc.moveDown(0.5);

            // Fonction pour dessiner l'en-tête du tableau
            const drawTableHeader = () => {
                doc.fontSize(9).font("Helvetica-Bold");
                const tableTop = doc.y;
                doc.text("N°", 50, tableTop, { width: 30 });
                doc.text("Date", 85, tableTop, { width: 90 });
                doc.text("Capital", 180, tableTop, { width: 80 });
                doc.text("Intérêts", 265, tableTop, { width: 80 });
                doc.text("Total", 350, tableTop, { width: 80 });
                doc.text("Statut", 435, tableTop, { width: 80 });
                doc.moveDown(0.5);
                // Ligne de séparation
                doc.moveTo(50, doc.y).lineTo(515, doc.y).stroke();
                doc.moveDown(0.3);
            };

            drawTableHeader();

            // Lignes du tableau
            doc.fontSize(9).font("Helvetica");
            for (const schedule of schedules) {
                // Si on approche de la fin de page, ajouter une nouvelle page
                if (doc.y > 720) {
                    doc.addPage();
                    drawTableHeader();
                    doc.fontSize(9).font("Helvetica");
                }

                const y = doc.y;

                let schedDate = "";
                if (schedule.dueDate && typeof schedule.dueDate.toDate === "function") {
                    schedDate = formatDateFR(schedule.dueDate.toDate());
                } else if (typeof schedule.dueDate === "string") {
                    schedDate = formatDateFR(new Date(schedule.dueDate));
                }

                // Déterminer le statut
                let statut = "À payer";
                if (schedule.isPaid) {
                    statut = "✓ Payé";
                } else if (schedule.hasPenalty) {
                    statut = "⚠ Pénalité";
                }

                doc.text(String(schedule.numero || ""), 50, y, { width: 30 });
                doc.text(schedDate, 85, y, { width: 90 });
                doc.text(`${((schedule.principal as number) || 0).toFixed(2)} €`, 180, y, { width: 80 });
                doc.text(`${((schedule.interet as number) || 0).toFixed(2)} €`, 265, y, { width: 80 });
                doc.text(`${((schedule.total as number) || 0).toFixed(2)} €`, 350, y, { width: 80 });
                doc.text(statut, 435, y, { width: 80 });
                doc.moveDown(0.5);
            }

            // Ligne de total en bas du tableau
            doc.moveDown(0.3);
            doc.moveTo(50, doc.y).lineTo(515, doc.y).stroke();
            doc.moveDown(0.3);
            const totalPrincipal = schedules.reduce((sum, s) => sum + ((s.principal as number) || 0), 0);
            const totalInterets = schedules.reduce((sum, s) => sum + ((s.interet as number) || 0), 0);
            const totalGeneral = schedules.reduce((sum, s) => sum + ((s.total as number) || 0), 0);
            const yTotal = doc.y;
            doc.fontSize(9).font("Helvetica-Bold");
            doc.text("TOTAL", 50, yTotal, { width: 120 });
            doc.text(`${totalPrincipal.toFixed(2)} €`, 180, yTotal, { width: 80 });
            doc.text(`${totalInterets.toFixed(2)} €`, 265, yTotal, { width: 80 });
            doc.text(`${totalGeneral.toFixed(2)} €`, 350, yTotal, { width: 80 });

            doc.moveDown(1);
        }

        // ========== SIGNATURES ==========
        // S'assurer qu'il y a assez de place pour les signatures
        if (doc.y > 650) {
            doc.addPage();
        }

        doc.fontSize(14).font("Helvetica-Bold")
            .text("SIGNATURES");
        doc.moveDown(1);

        doc.fontSize(11).font("Helvetica");
        const sigY = doc.y;

        // Colonne gauche - Prêteur
        doc.text("Le Prêteur", 50, sigY, { width: 200, align: "center" });
        doc.text("Chafin Loans", 50, sigY + 20, { width: 200, align: "center" });
        doc.text(`Fait le ${formattedDate}`, 50, sigY + 40, { width: 200, align: "center" });

        // Colonne droite - Emprunteur
        doc.text("L'Emprunteur", 300, sigY, { width: 200, align: "center" });
        doc.text(`${user.prenom || ""} ${user.nom || ""}`, 300, sigY + 20, { width: 200, align: "center" });
        doc.text(`Fait le ${formattedDate}`, 300, sigY + 40, { width: 200, align: "center" });

        // ========== PIED DE PAGE ==========
        doc.moveDown(4);
        doc.fontSize(8)
            .text(
                "Ce document constitue une reconnaissance de dette au sens des articles 1326 et suivants du Code civil. " +
                "Généré automatiquement par la plateforme Chafin Loans.",
                50, doc.y, { align: "center", width: 495 }
            );

        doc.end();
    });
}

// ============================================================
// HELPERS
// ============================================================

export function formatDateFR(date: Date): string {
    return `${String(date.getDate()).padStart(2, "0")}/${String(date.getMonth() + 1).padStart(2, "0")}/${date.getFullYear()}`;
}

export async function sendDebtAcknowledgmentEmail(
    email: string,
    userName: string,
    loan: FirebaseFirestore.DocumentData,
    loanId: string,
    downloadUrl: string
): Promise<void> {
    try {
        const montant = (loan.montant as number) || 0;
        const taux = (loan.tauxAnnuel as number) || 0;
        const duree = (loan.dureeMois as number) || 0;
        const interets = montant * (taux / 100);
        const totalARembourser = montant + interets;

        const message = `Bonjour ${userName},\n\n` +
            `Suite au décaissement de votre prêt, nous vous transmettons votre reconnaissance de dette.\n\n` +
            `📋 Récapitulatif du prêt :\n` +
            `• Capital emprunté : ${montant.toFixed(2)}€\n` +
            `• Taux d'intérêt : ${taux.toFixed(2)}%\n` +
            `• Durée : ${duree} mois\n` +
            `• Montant total à rembourser : ${totalARembourser.toFixed(2)}€\n\n` +
            `📄 Votre reconnaissance de dette est disponible ici :\n${downloadUrl}\n\n` +
            `Ce document fait office de contrat entre vous et Chafin Loans. ` +
            `Veuillez le conserver précieusement.\n\n` +
            `Cordialement,\nL'équipe Chafin Loans`;

        await axios.post(EMAILJS_CONFIG.apiUrl, {
            service_id: EMAILJS_CONFIG.serviceId,
            template_id: EMAILJS_CONFIG.templateId,
            user_id: EMAILJS_CONFIG.publicKey,
            accessToken: EMAILJS_CONFIG.privateKey,
            template_params: {
                email: email,
                name: userName,
                subject: `📄 Reconnaissance de dette - Prêt ${loanId.substring(0, 8)}`,
                message: message,
                from_name: "Chafin Loans",
            },
        }, {
            headers: { "Origin": "https://chafin.web.app" },
        });

        logger.info(`📧 Email reconnaissance de dette envoyé à ${email}`);
    } catch (error) {
        logger.error("❌ Erreur envoi email reconnaissance:", error);
    }
}
