/**
 * Script pour ajouter un parrainage rétroactif sur un prêt existant
 * 
 * Usage:
 *   node scripts/add_retroactive_referral.js check     # Mode diagnostic
 *   node scripts/add_retroactive_referral.js apply      # Mode application
 */

const admin = require('../functions/node_modules/firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const MODE = process.argv[2] || 'check';

// ─── Configuration du parrainage rétroactif ─────────────────────
const PARRAIN_EMAIL = 'Hilarymboumba@gmail.com';
const BORROWER_NAME = 'Sandra Ludwine TSONGA MAGANGA';
// ─────────────────────────────────────────────────────────────────

async function main() {
  console.log('=== Parrainage Rétroactif ===');
  console.log(`Mode: ${MODE === 'apply' ? '🔧 APPLICATION' : '🔍 DIAGNOSTIC'}`);
  console.log(`Parrain: ${PARRAIN_EMAIL}`);
  console.log(`Emprunteur: ${BORROWER_NAME}\n`);

  // 1. Trouver le prêt de TSONGA MAGANGA
  const loansSnapshot = await db.collection('loans')
    .where('nomEmprunteur', '==', BORROWER_NAME)
    .get();

  if (loansSnapshot.empty) {
    console.log('❌ Aucun prêt trouvé pour', BORROWER_NAME);
    // Essayer une recherche plus large
    console.log('\n🔍 Recherche de tous les prêts...');
    const allLoans = await db.collection('loans').get();
    allLoans.forEach(doc => {
      const d = doc.data();
      console.log(`  - ${d.nomEmprunteur} | Statut: ${d.statut} | Montant: ${d.montant}€`);
    });
    process.exit(1);
  }

  console.log(`✅ ${loansSnapshot.size} prêt(s) trouvé(s) pour ${BORROWER_NAME}\n`);

  for (const loanDoc of loansSnapshot.docs) {
    const loan = loanDoc.data();
    const loanId = loanDoc.id;

    console.log(`📋 Prêt: ${loanId}`);
    console.log(`   Montant: ${loan.montant}€`);
    console.log(`   Statut: ${loan.statut}`);
    console.log(`   Durée: ${loan.dureeMois} mois`);
    console.log(`   Coût total estimé: ${loan.coutTotalEstime}€`);
    console.log(`   ParrainEmail actuel: ${loan.parrainEmail || 'aucun'}`);

    // Calcul du bonus parrain (20% des intérêts)
    // Note: coutTotalEstime = total des intérêts (pas montant + intérêts)
    const interetsTotal = loan.coutTotalEstime;
    const bonusParrain = interetsTotal * 0.20;

    console.log(`\n💰 Calcul commission:`);
    console.log(`   Intérêts totaux: ${interetsTotal.toFixed(2)}€`);
    console.log(`   Commission parrain (20%): ${bonusParrain.toFixed(2)}€`);

    // Vérifier si un referral existe déjà
    const existingReferrals = await db.collection('referrals')
      .where('loanId', '==', loanId)
      .get();

    if (!existingReferrals.empty) {
      console.log(`\n⚠️  Un parrainage existe déjà pour ce prêt!`);
      existingReferrals.forEach(doc => {
        const r = doc.data();
        console.log(`   Parrain: ${r.parrainEmail} | Statut: ${r.statut}`);
      });
      continue;
    }

    // Déterminer le statut du referral selon le statut du prêt
    let referralStatut = 'en_attente';
    if (['decaisse', 'decaissementEffectue', 'actif', 'enCours', 'enRetard', 'rembourse', 'ferme'].includes(loan.statut)) {
      referralStatut = 'pret_decaisse';
    }

    console.log(`\n📝 Referral à créer:`);
    console.log(`   parrainEmail: ${PARRAIN_EMAIL}`);
    console.log(`   filleulName: ${BORROWER_NAME}`);
    console.log(`   filleulUserId: ${loan.userId}`);
    console.log(`   montantPret: ${loan.montant}`);
    console.log(`   interetsTotal: ${interetsTotal.toFixed(2)}`);
    console.log(`   bonusParrain: ${bonusParrain.toFixed(2)}`);
    console.log(`   statut: ${referralStatut}`);

    if (MODE === 'apply') {
      console.log('\n🔧 Application...');

      // 1. Créer le document referral
      const referralRef = db.collection('referrals').doc();
      await referralRef.set({
        id: referralRef.id,
        loanId: loanId,
        parrainEmail: PARRAIN_EMAIL,
        filleulUserId: loan.userId,
        filleulName: BORROWER_NAME,
        montantPret: loan.montant,
        interetsTotal: parseFloat(interetsTotal.toFixed(2)),
        bonusParrain: parseFloat(bonusParrain.toFixed(2)),
        statut: referralStatut,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`   ✅ Referral créé: ${referralRef.id}`);

      // 2. Mettre à jour le prêt avec parrainEmail
      await db.collection('loans').doc(loanId).update({
        parrainEmail: PARRAIN_EMAIL,
        updatedAt: new Date().toISOString(),
      });
      console.log(`   ✅ Prêt mis à jour avec parrainEmail`);

      console.log(`\n✅ Parrainage rétroactif appliqué avec succès!`);
      console.log(`\n📧 Les emails au parrain seront envoyés depuis l'interface Flutter.`);
      console.log(`   Vous pouvez aussi les déclencher depuis l'écran de test email admin.`);
    } else {
      console.log('\n💡 Exécutez avec "apply" pour appliquer: node scripts/add_retroactive_referral.js apply');
    }
  }

  process.exit(0);
}

main().catch(err => {
  console.error('❌ Erreur:', err);
  process.exit(1);
});
