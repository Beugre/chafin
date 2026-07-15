const admin = require('../functions/node_modules/firebase-admin');
const sa = require('../firebase-service-account.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function check() {
  // 1. Check kill switch
  const ks = await db.collection('config').doc('emailKillSwitch').get();
  console.log('Kill switch doc exists:', ks.exists);
  if (ks.exists) console.log('Kill switch data:', JSON.stringify(ks.data()));
  else console.log('=> Pas de kill switch => emails autorisés par défaut');

  // 2. Check recent email logs
  try {
    const logs = await db.collection('emailLogs').orderBy('timestamp', 'desc').limit(10).get();
    console.log('\nDerniers emails (' + logs.size + '):');
    logs.forEach(doc => {
      const d = doc.data();
      const ts = d.timestamp ? d.timestamp.toDate().toISOString() : 'no date';
      console.log('  -', d.to, '|', d.subject || d.type, '|', d.status || 'n/a', '|', ts);
    });
  } catch(e) {
    console.log('Pas de collection emailLogs ou erreur:', e.message);
  }

  // 3. Check admin emails
  const admins = await db.collection('users').where('role', 'in', ['admin', 'superAdmin']).get();
  console.log('\nAdmins (' + admins.size + '):');
  admins.forEach(doc => {
    console.log('  -', doc.data().email, '(' + doc.data().role + ')');
  });

  // 4. Check recent conversations
  const convs = await db.collection('conversations').get();
  console.log('\nConversations (' + convs.size + '):');
  convs.forEach(doc => {
    const d = doc.data();
    console.log('  -', d.userName, '|', d.userEmail, '| unreadAdmin:', d.unreadByAdmin, '| unreadUser:', d.unreadByUser);
  });

  process.exit(0);
}
check().catch(e => { console.error(e); process.exit(1); });
