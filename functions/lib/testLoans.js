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
exports.testListLoans = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("firebase-admin/firestore");
/**
 * Fonction de test pour lister tous les prêts
 */
exports.testListLoans = functions
    .region("us-central1")
    .https.onRequest(async (req, res) => {
    try {
        console.log("🔍 Test: Listage de tous les prêts...");
        const db = (0, firestore_1.getFirestore)();
        const loansRef = db.collection("loans");
        console.log("📊 Collection: loans");
        const snapshot = await loansRef.get();
        console.log(`✅ Nombre de prêts trouvés: ${snapshot.size}`);
        const loans = [];
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
    }
    catch (error) {
        console.error("❌ Erreur:", error);
        res.status(500).json({
            success: false,
            error: String(error),
        });
    }
});
//# sourceMappingURL=testLoans.js.map