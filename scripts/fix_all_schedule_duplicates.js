/**
 * Script pour corriger les doublons de schedules sur TOUS les prêts.
 * 
 * Problème : le markPaymentReceived crée des docs avec ID structuré (loanId_numero)
 * qui n'ont pas de loanId, tandis que les vrais schedules (avec loanId) gardent isPaid=false.
 * 
 * Solution : Pour chaque prêt, vérifier si des docs structurés (loanId_X) existent avec isPaid=true,
 * et reporter l'info sur le vrai document (celui avec loanId dans les données).
 * Puis supprimer les doublons.
 * 
 * Usage:
 *   node scripts/fix_all_schedule_duplicates.js          # Diagnostic
 *   node scripts/fix_all_schedule_duplicates.js fix       # Correction
 */

const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const MODE = process.argv[2] || 'check';

async function main() {
  console.log(`=== Correction doublons schedules (mode: ${MODE}) ===\n`);

  // Récupérer tous les prêts actifs
  const loansSnapshot = await db.collection('loans')
    .where('statut', 'in', ['enCours', 'enRetard', 'solde'])
    .get();

  console.log(`📊 ${loansSnapshot.size} prêts à vérifier\n`);

  let totalFixes = 0;
  let totalDuplicatesRemoved = 0;
  const batch = db.batch();

  for (const loanDoc of loansSnapshot.docs) {
    const loan = loanDoc.data();
    const loanId = loanDoc.id;

    // Récupérer les schedules avec loanId (vrais documents)
    const realSchedules = await db.collection('schedules')
      .where('loanId', '==', loanId)
      .orderBy('numero')
      .get();

    if (realSchedules.empty) continue;

    let hasIssues = false;

    for (const realDoc of realSchedules.docs) {
      const realData = realDoc.data();
      const numero = realData.numero;

      // Vérifier si un document structuré existe
      const structuredId = `${loanId}_${numero}`;
      const structuredDoc = await db.collection('schedules').doc(structuredId).get();

      if (structuredDoc.exists) {
        const structuredData = structuredDoc.data();
        
        // Si le doc structuré est marqué payé mais pas le vrai
        if (structuredData.isPaid && !realData.isPaid) {
          if (!hasIssues) {
            console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
            console.log(`📋 ${loan.nomEmprunteur} - ${loan.montant}€`);
            hasIssues = true;
          }
          
          const paidAt = structuredData.paidAt;
          console.log(`  ❌ #${numero}: vrai doc (${realDoc.id}) = isPaid:false | doublon (${structuredId}) = isPaid:true`);
          console.log(`     → paidAt: ${paidAt?.toDate?.()?.toLocaleDateString('fr-FR') || 'N/A'}, paidAmount: ${structuredData.paidAmount}`);

          if (MODE === 'fix') {
            // Reporter isPaid sur le vrai document
            batch.update(realDoc.ref, {
              isPaid: true,
              paidAt: structuredData.paidAt || admin.firestore.FieldValue.serverTimestamp(),
              paidAmount: structuredData.paidAmount || realData.total,
              noteAdmin: structuredData.noteAdmin || null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            totalFixes++;
          }
        }

        // Supprimer le doublon (qu'il soit payé ou non, c'est un doublon sans loanId)
        if (!structuredData.loanId) {
          if (MODE === 'fix') {
            batch.delete(structuredDoc.ref);
            totalDuplicatesRemoved++;
          }
        }
      }
    }
  }

  if (MODE === 'fix' && (totalFixes > 0 || totalDuplicatesRemoved > 0)) {
    await batch.commit();
    console.log(`\n✅ ${totalFixes} échéances corrigées (isPaid → true)`);
    console.log(`🗑️  ${totalDuplicatesRemoved} doublons supprimés`);

    // Maintenant recalculer les statuts des prêts
    console.log(`\n🔄 Recalcul des statuts des prêts...`);
    
    const now = new Date();
    const activeLoans = await db.collection('loans')
      .where('statut', 'in', ['enCours', 'enRetard'])
      .get();

    for (const loanDoc of activeLoans.docs) {
      const loanId = loanDoc.id;
      const loan = loanDoc.data();

      const unpaidOverdue = await db.collection('schedules')
        .where('loanId', '==', loanId)
        .where('isPaid', '==', false)
        .get();

      let hasOverdue = false;
      for (const d of unpaidOverdue.docs) {
        const dueDate = d.data().dueDate?.toDate?.();
        if (dueDate && dueDate < now) {
          hasOverdue = true;
          break;
        }
      }

      // Vérifier si toutes les échéances sont payées
      const allSchedules = await db.collection('schedules')
        .where('loanId', '==', loanId)
        .get();
      const allPaid = allSchedules.docs.every(d => d.data().isPaid === true);

      let correctStatus;
      if (allPaid) {
        correctStatus = 'solde';
      } else if (hasOverdue) {
        correctStatus = 'enRetard';
      } else {
        correctStatus = 'enCours';
      }

      if (loan.statut !== correctStatus) {
        await db.collection('loans').doc(loanId).update({
          statut: correctStatus,
          updatedAt: new Date().toISOString(),
        });
        console.log(`  📋 ${loan.nomEmprunteur}: ${loan.statut} → ${correctStatus}`);
      }
    }

    console.log(`\n🎉 Tout est corrigé !`);
  } else if (MODE !== 'fix') {
    console.log(`\n📊 Résumé: ${totalFixes} corrections à faire, ${totalDuplicatesRemoved || '?'} doublons à supprimer`);
    console.log(`💡 Pour corriger: node scripts/fix_all_schedule_duplicates.js fix`);
  } else {
    console.log(`\n✅ Aucune correction nécessaire`);
  }

  process.exit(0);
}

main().catch(console.error);
