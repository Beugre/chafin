const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const now = new Date('2026-02-24T12:00:00Z');

async function generateReport() {
  console.log('='.repeat(80));
  console.log('📊 RAPPORT COMPLET DES PRÊTS - 24 Février 2026');
  console.log('='.repeat(80));

  // Récupérer tous les prêts
  const loansSnap = await db.collection('loans').get();
  
  const stats = { enRetard: 0, enCours: 0, solde: 0, autre: 0 };
  const details = [];

  for (const loanDoc of loansSnap.docs) {
    const loan = loanDoc.data();
    const loanId = loanDoc.id;

    // Récupérer l'emprunteur
    let borrowerName = 'Inconnu';
    try {
      const userDoc = await db.collection('users').doc(loan.emprunteurId || loan.userId).get();
      if (userDoc.exists) {
        borrowerName = userDoc.data().nom || userDoc.data().displayName || 'Inconnu';
      }
    } catch (e) {}

    // Récupérer les échéances
    const schedulesSnap = await db.collection('schedules')
      .where('loanId', '==', loanId)
      .orderBy('numero')
      .get();

    const echeances = schedulesSnap.docs.map(d => ({ id: d.id, ...d.data() }));
    
    const totalEcheances = echeances.length;
    const payees = echeances.filter(e => e.isPaid === true);
    const impayees = echeances.filter(e => e.isPaid !== true);
    
    // Trouver les échéances en retard (impayées avec date passée)
    const enRetard = impayees.filter(e => {
      const dueDate = e.dueDate?.toDate ? e.dueDate.toDate() : new Date(e.dueDate);
      return dueDate < now;
    });

    // Prochaine échéance
    const prochaineImpayee = impayees.sort((a, b) => {
      const da = a.dueDate?.toDate ? a.dueDate.toDate() : new Date(a.dueDate);
      const db2 = b.dueDate?.toDate ? b.dueDate.toDate() : new Date(b.dueDate);
      return da - db2;
    })[0];

    // Calculer les jours de retard max
    let maxJoursRetard = 0;
    for (const e of enRetard) {
      const dueDate = e.dueDate?.toDate ? e.dueDate.toDate() : new Date(e.dueDate);
      const jours = Math.floor((now - dueDate) / (1000 * 60 * 60 * 24));
      if (jours > maxJoursRetard) maxJoursRetard = jours;
    }

    // Déterminer le statut
    let statut = loan.statut || 'inconnu';
    let emoji = '⚪';
    if (statut === 'solde') { emoji = '🟣'; stats.solde++; }
    else if (enRetard.length > 0) { emoji = '🔴'; stats.enRetard++; }
    else if (statut === 'enCours' || statut === 'decaissementEffectue') { emoji = '🟢'; stats.enCours++; }
    else { emoji = '⚪'; stats.autre++; }

    details.push({
      emoji,
      borrowerName,
      montant: loan.montant,
      statut,
      totalEcheances,
      payees: payees.length,
      enRetard: enRetard.length,
      maxJoursRetard,
      echeances,
      prochaineImpayee,
      loanId,
      hasPenalty: echeances.some(e => e.hasPenalty === true)
    });
  }

  // Tri: en retard d'abord, puis en cours, puis soldés
  details.sort((a, b) => {
    if (a.enRetard > 0 && b.enRetard === 0) return -1;
    if (a.enRetard === 0 && b.enRetard > 0) return 1;
    return b.maxJoursRetard - a.maxJoursRetard;
  });

  // Affichage
  console.log('');
  console.log(`🔴 En retard: ${stats.enRetard} | 🟢 À jour: ${stats.enCours} | 🟣 Soldés: ${stats.solde} | ⚪ Autre: ${stats.autre}`);
  console.log('');

  for (const d of details) {
    console.log('─'.repeat(70));
    console.log(`${d.emoji} ${d.borrowerName} — ${d.montant}€ (${d.statut})`);
    console.log(`   📋 Échéances: ${d.payees}/${d.totalEcheances} payées`);
    
    if (d.enRetard > 0) {
      console.log(`   ⏰ ${d.enRetard} échéance(s) en retard (max ${d.maxJoursRetard} jours)`);
    }
    if (d.hasPenalty) {
      console.log(`   ⚠️  Pénalité appliquée`);
    }

    // Détail de chaque échéance
    for (const e of d.echeances) {
      const dueDate = e.dueDate?.toDate ? e.dueDate.toDate() : new Date(e.dueDate);
      const dateStr = dueDate.toLocaleDateString('fr-FR');
      const isPaid = e.isPaid === true;
      const isOverdue = !isPaid && dueDate < now;
      const jours = isOverdue ? Math.floor((now - dueDate) / (1000 * 60 * 60 * 24)) : 0;

      let icon = isPaid ? '✅' : (isOverdue ? '❌' : '⏳');
      let extra = '';
      if (isPaid) extra = ' — Payée';
      else if (isOverdue) extra = ` — EN RETARD (${jours}j)`;
      else extra = ' — À venir';

      if (e.hasPenalty) extra += ' [PÉNALITÉ]';
      if (e.penaltyAmount) extra += ` (+${e.penaltyAmount.toFixed(2)}€)`;

      console.log(`      ${icon} #${e.numero} | ${dateStr} | ${(e.total || 0).toFixed(2)}€${extra}`);
    }

    if (d.prochaineImpayee && !d.echeances.every(e => e.isPaid)) {
      const nextDate = d.prochaineImpayee.dueDate?.toDate ? d.prochaineImpayee.dueDate.toDate() : new Date(d.prochaineImpayee.dueDate);
      if (nextDate >= now) {
        console.log(`   ➡️  Prochaine échéance: #${d.prochaineImpayee.numero} le ${nextDate.toLocaleDateString('fr-FR')}`);
      }
    }
  }

  console.log('');
  console.log('='.repeat(80));
  console.log('FIN DU RAPPORT');
  console.log('='.repeat(80));

  process.exit(0);
}

generateReport().catch(e => { console.error(e); process.exit(1); });
