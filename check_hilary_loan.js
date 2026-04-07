const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkHilaryLoan() {
  try {
    // Chercher le prêt de Hilary
    const loansSnapshot = await db.collection('loans')
      .where('borrowerName', '==', 'Hilary')
      .get();
    
    if (loansSnapshot.empty) {
      console.log('❌ Aucun prêt trouvé pour Hilary');
      return;
    }
    
    loansSnapshot.forEach(async (doc) => {
      const loan = doc.data();
      console.log('\n📋 Prêt de Hilary:');
      console.log('ID:', doc.id);
      console.log('Statut:', loan.statut);
      console.log('Montant:', loan.amount);
      console.log('Durée:', loan.duration);
      console.log('Taux:', loan.interestRate);
      console.log('Date création:', loan.createdAt?.toDate());
      
      // Chercher les échéances
      const schedulesSnapshot = await db.collection('schedules')
        .where('loanId', '==', doc.id)
        .get();
      
      console.log('\n📅 Échéances:');
      console.log('Nombre total:', schedulesSnapshot.size);
      
      if (schedulesSnapshot.empty) {
        console.log('❌ AUCUNE ÉCHÉANCE TROUVÉE !');
      } else {
        schedulesSnapshot.docs.forEach((scheduleDoc) => {
          const schedule = scheduleDoc.data();
          console.log('\nÉchéance:', schedule.numero);
          console.log('  - Date:', schedule.dueDate?.toDate());
          console.log('  - Montant:', schedule.total);
          console.log('  - Payée:', schedule.isPaid);
        });
      }
    });
    
    setTimeout(() => process.exit(0), 2000);
  } catch (error) {
    console.error('Erreur:', error);
    process.exit(1);
  }
}

checkHilaryLoan();
