/**
 * Script pour corriger les statuts des prêts incorrectement marqués "enRetard"
 * 
 * Logique : Un prêt est en retard UNIQUEMENT si une échéance NON PAYÉE
 * a une date d'échéance PASSÉE (avant aujourd'hui).
 * 
 * Usage:
 *   node scripts/fix_loan_statuses.js          # Mode diagnostic (dry-run)
 *   node scripts/fix_loan_statuses.js fix       # Mode correction
 */

const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const MODE = process.argv[2] || 'check'; // 'check' ou 'fix'

async function main() {
  console.log(`=== Diagnostic et correction des statuts de prêts ===`);
  console.log(`Mode: ${MODE === 'fix' ? '🔧 CORRECTION' : '🔍 DIAGNOSTIC'}\n`);

  const now = new Date();
  console.log(`Date actuelle: ${now.toLocaleDateString('fr-FR')} ${now.toLocaleTimeString('fr-FR')}\n`);

  // 1. Récupérer tous les prêts actifs
  const loansSnapshot = await db.collection('loans')
    .where('statut', 'in', ['enCours', 'enRetard'])
    .get();

  console.log(`📊 ${loansSnapshot.size} prêts actifs trouvés\n`);

  const fixes = [];

  for (const loanDoc of loansSnapshot.docs) {
    const loan = loanDoc.data();
    const loanId = loanDoc.id;

    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`📋 ${loan.nomEmprunteur} - ${loan.montant}€ (${loan.dureeMois} mois)`);
    console.log(`   Statut actuel: ${loan.statut}`);
    console.log(`   ID: ${loanId}`);

    // Récupérer les échéances
    const schedulesSnapshot = await db.collection('schedules')
      .where('loanId', '==', loanId)
      .orderBy('numero')
      .get();

    if (schedulesSnapshot.empty) {
      console.log(`   ⚠️  Aucune échéance trouvée !`);
      continue;
    }

    let hasOverduePayments = false;
    let nextUnpaidDate = null;
    let maxOverdueDays = 0;

    for (const schedDoc of schedulesSnapshot.docs) {
      const sched = schedDoc.data();
      const dueDate = sched.dueDate?.toDate?.();
      if (!dueDate) continue;

      const isPaid = sched.isPaid || false;
      const daysDiff = Math.ceil((dueDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

      const statusIcon = isPaid ? '✅' : (daysDiff < 0 ? '🔴' : '⏳');
      console.log(`   ${statusIcon} #${sched.numero} - ${dueDate.toLocaleDateString('fr-FR')} - ${sched.total}€ ${isPaid ? '(payée)' : daysDiff < 0 ? `(${Math.abs(daysDiff)}j retard)` : `(dans ${daysDiff}j)`}`);

      if (!isPaid && daysDiff < 0) {
        hasOverduePayments = true;
        const overdueDays = Math.abs(daysDiff);
        if (overdueDays > maxOverdueDays) maxOverdueDays = overdueDays;
      }

      if (!isPaid && !nextUnpaidDate) {
        nextUnpaidDate = dueDate;
      }
    }

    // Déterminer le bon statut
    const correctStatus = hasOverduePayments ? 'enRetard' : 'enCours';
    const currentStatus = loan.statut;

    if (currentStatus !== correctStatus) {
      console.log(`   ❌ STATUT INCORRECT: ${currentStatus} → devrait être: ${correctStatus}`);
      if (nextUnpaidDate) {
        console.log(`   📅 Prochaine échéance non payée: ${nextUnpaidDate.toLocaleDateString('fr-FR')}`);
      }
      fixes.push({
        loanId,
        name: loan.nomEmprunteur,
        currentStatus,
        correctStatus,
      });
    } else {
      console.log(`   ✅ Statut correct: ${currentStatus}`);
      if (hasOverduePayments) {
        console.log(`   ⚠️  Max retard: ${maxOverdueDays} jours`);
      }
    }
  }

  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`\n📊 RÉSUMÉ:`);
  console.log(`   Prêts analysés: ${loansSnapshot.size}`);
  console.log(`   Corrections nécessaires: ${fixes.length}`);

  if (fixes.length > 0) {
    console.log(`\n🔧 Corrections à apporter:`);
    for (const fix of fixes) {
      console.log(`   • ${fix.name}: ${fix.currentStatus} → ${fix.correctStatus}`);
    }

    if (MODE === 'fix') {
      console.log(`\n🔧 Application des corrections...`);
      for (const fix of fixes) {
        await db.collection('loans').doc(fix.loanId).update({
          statut: fix.correctStatus,
          updatedAt: new Date().toISOString(),
        });
        console.log(`   ✅ ${fix.name}: ${fix.currentStatus} → ${fix.correctStatus}`);
      }
      console.log(`\n🎉 ${fixes.length} prêts corrigés !`);
    } else {
      console.log(`\n💡 Pour appliquer les corrections, exécutez:`);
      console.log(`   node scripts/fix_loan_statuses.js fix`);
    }
  } else {
    console.log(`\n✅ Tous les statuts sont corrects !`);
  }

  process.exit(0);
}

main().catch(console.error);
