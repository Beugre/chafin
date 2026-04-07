import * as functions from "firebase-functions";
import { getFirestore } from "firebase-admin/firestore";

/**
 * Fonction de test pour lister tous les prêts
 */
export const testListLoans = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
        try {
            console.log("🔍 Test: Listage de tous les prêts...");

            const db = getFirestore();
            const loansRef = db.collection("loans");

            console.log("📊 Collection: loans");

            const snapshot = await loansRef.get(); console.log(`✅ Nombre de prêts trouvés: ${snapshot.size}`);

            const loans: any[] = [];
            snapshot.forEach(doc => {
                const data = doc.data();
                console.log(`  - ${doc.id}: ${data.montant}€, ${data.dureeMois} mois, ${data.tauxAnnuel}%, statut: ${data.statut}`);
                loans.push({
                    id: doc.id,
                    montant: data.montant,
                    dureeMois: data.dureeMois,
                    tauxAnnuel: data.tauxAnnuel,
                    statut: data.statut,
                });
            });

            res.status(200).json({
                success: true,
                totalLoans: snapshot.size,
                loans: loans,
            });
        } catch (error) {
            console.error("❌ Erreur:", error);
            res.status(500).json({
                success: false,
                error: String(error),
            });
        }
    });
