/**
 * État des lieux complet de TOUS les prêts et échéances
 * Vérifie : statuts, retards, pénalités, prochaines échéances
 */
const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function main() {
  const now = new Date();
  console.log(`╔══════════════════════════════════════════════════════════════╗`);
  console.log(`║        ÉTAT DES LIEUX - CHAFIN LOANS                       ║`);
  console.log(`║        ${now.toLocaleDateString('fr-FR')} ${now.toLocaleTimeString('fr-FR').substring(0,5)}                                      ║`);
  console.log(`╚══════════════════════════════════════════════════════════════╝\n`);

  // Tous les prêts actifs
  const loansSnapshot = await db.collection('loans')
    .where('statut', 'in', ['enCours', 'enRetard', 'solde', 'decaissementEffectue'])
    .get();

  const summary = { aJour: [], enRetard: [], presqueEnRetard: [], soldes: [] };

  for (const loanDoc of loansSnapshot.docs) {
    const loan = loanDoc.data();
    const loanId = loanDoc.id;

    // Échéances
    const schedulesSnap = await db.collection('schedules')
      .where('loanId', '==', loanId)
      .orderBy('numero')
      .get();

    if (schedulesSnap.empty) continue;

    const echeances = [];
    let paidCount = 0;
    let overdueCount = 0;
    let maxOverdueDays = 0;
    let nextDueDate = null;
    let nextDueAmount = null;
    let totalDu = 0;
    let totalPaye = 0;

    for (const doc of schedulesSnap.docs) {
      const s = doc.data();
      const dueDate = s.dueDate?.toDate?.();
      if (!dueDate) continue;

      const daysDiff = Math.ceil((dueDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      const isPaid = s.isPaid || false;

      totalDu += s.total || 0;
      if (isPaid) {
        paidCount++;
        totalPaye += s.paidAmount || s.total || 0;
      }

      if (!isPaid && daysDiff < 0) {
        overdueCount++;
        const od = Math.abs(daysDiff);
        if (od > maxOverdueDays) maxOverdueDays = od;
      }

      if (!isPaid && !nextDueDate) {
        nextDueDate = dueDate;
        nextDueAmount = s.total;
      }

      echeances.push({
        numero: s.numero,
        dueDate,
        total: s.total,
        isPaid,
        hasPenalty: s.hasPenalty || false,
        daysDiff,
      });
    }

    const totalEcheances = echeances.length;
    const daysUntilNext = nextDueDate ? Math.ceil((nextDueDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)) : null;

    // Classifier
    const entry = {
      nom: loan.nomEmprunteur,
      montant: loan.montant,
      duree: loan.dureeMois,
      statut: loan.statut,
      paidCount,
      totalEcheances,
      overdueCount,
      maxOverdueDays,
      nextDueDate,
      nextDueAmount,
      daysUntilNext,
      echeances,
      totalDu: Math.round(totalDu * 100) / 100,
      totalPaye: Math.round(totalPaye * 100) / 100,
    };

    if (overdueCount > 0) {
      summary.enRetard.push(entry);
    } else if (daysUntilNext !== null && daysUntilNext <= 7) {
      summary.presqueEnRetard.push(entry);
    } else if (paidCount === totalEcheances) {
      summary.soldes.push(entry);
    } else {
      summary.aJour.push(entry);
    }
  }

  // === AFFICHAGE ===

  // EN RETARD
  console.log(`\n🔴 EN RETARD (${summary.enRetard.length} prêts)`);
  console.log(`${'─'.repeat(60)}`);
  for (const e of summary.enRetard) {
    console.log(`  👤 ${e.nom} — ${e.montant}€ (${e.duree} mois) [${e.statut}]`);
    console.log(`     Payées: ${e.paidCount}/${e.totalEcheances} | En retard: ${e.overdueCount} | Max retard: ${e.maxOverdueDays}j`);
    if (e.maxOverdueDays >= 31) {
      console.log(`     ⚠️  PÉNALITÉ APPLICABLE (≥31j de retard)`);
    } else {
      console.log(`     ⏳ Pénalité dans ${31 - e.maxOverdueDays}j (grace period 31j)`);
    }
    // Détail échéances
    for (const ec of e.echeances) {
      const d = ec.dueDate.toLocaleDateString('fr-FR');
      const status = ec.isPaid ? '✅ Payée' : (ec.daysDiff < 0 ? `🔴 ${Math.abs(ec.daysDiff)}j retard` : `⏳ Dans ${ec.daysDiff}j`);
      const penalty = ec.hasPenalty ? ' +pénalité' : '';
      console.log(`     #${ec.numero} ${d} — ${ec.total}€ [${status}${penalty}]`);
    }
    console.log();
  }

  // PRESQUE EN RETARD (≤7j avant prochaine échéance)
  console.log(`\n🟡 ÉCHÉANCE PROCHE ≤7j (${summary.presqueEnRetard.length} prêts)`);
  console.log(`${'─'.repeat(60)}`);
  for (const e of summary.presqueEnRetard) {
    console.log(`  👤 ${e.nom} — ${e.montant}€ (${e.duree} mois) [${e.statut}]`);
    console.log(`     Payées: ${e.paidCount}/${e.totalEcheances} | Prochaine: ${e.nextDueDate.toLocaleDateString('fr-FR')} (${e.daysUntilNext}j) — ${e.nextDueAmount}€`);
    for (const ec of e.echeances) {
      const d = ec.dueDate.toLocaleDateString('fr-FR');
      const status = ec.isPaid ? '✅ Payée' : `⏳ Dans ${ec.daysDiff}j`;
      console.log(`     #${ec.numero} ${d} — ${ec.total}€ [${status}]`);
    }
    console.log();
  }

  // À JOUR
  console.log(`\n🟢 À JOUR (${summary.aJour.length} prêts)`);
  console.log(`${'─'.repeat(60)}`);
  for (const e of summary.aJour) {
    console.log(`  👤 ${e.nom} — ${e.montant}€ (${e.duree} mois) [${e.statut}]`);
    console.log(`     Payées: ${e.paidCount}/${e.totalEcheances} | Prochaine: ${e.nextDueDate?.toLocaleDateString('fr-FR') || 'N/A'} (${e.daysUntilNext}j) — ${e.nextDueAmount}€`);
    console.log();
  }

  // SOLDÉS
  if (summary.soldes.length > 0) {
    console.log(`\n✅ SOLDÉS (${summary.soldes.length} prêts)`);
    console.log(`${'─'.repeat(60)}`);
    for (const e of summary.soldes) {
      console.log(`  👤 ${e.nom} — ${e.montant}€ | Total payé: ${e.totalPaye}€`);
    }
  }

  // RÉSUMÉ GLOBAL
  const totalLoans = summary.aJour.length + summary.enRetard.length + summary.presqueEnRetard.length + summary.soldes.length;
  console.log(`\n╔══════════════════════════════════════════════════════════════╗`);
  console.log(`║  RÉSUMÉ                                                     ║`);
  console.log(`║  Total prêts actifs: ${String(totalLoans).padEnd(39)}║`);
  console.log(`║  🟢 À jour:          ${String(summary.aJour.length).padEnd(39)}║`);
  console.log(`║  🟡 Échéance proche:  ${String(summary.presqueEnRetard.length).padEnd(39)}║`);
  console.log(`║  🔴 En retard:        ${String(summary.enRetard.length).padEnd(39)}║`);
  console.log(`║  ✅ Soldés:           ${String(summary.soldes.length).padEnd(39)}║`);
  console.log(`╚══════════════════════════════════════════════════════════════╝`);

  process.exit(0);
}

main().catch(console.error);
