/**
 * Envoie un email de communication générale à tous les emprunteurs
 * pour les informer des nouvelles conditions de pénalités de retard.
 * 
 * Usage :
 *   node scripts/send_policy_email.js test     → Envoie à l'admin seul (pour contrôle)
 *   node scripts/send_policy_email.js send     → Envoie à tous les emprunteurs
 */
const axiosModule = require("../functions/node_modules/axios");
const axios = axiosModule.default || axiosModule;
const admin = require("../functions/node_modules/firebase-admin");
const serviceAccount = require("../firebase-service-account.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const EMAILJS_CONFIG = {
  serviceId: "service_s6kh76e",
  templateId: "template_byf1fdm",
  publicKey: "sUFWr-XkJM8NcZQ86",
  privateKey: "iihl6951E8XgF-0y3Dumm",
  apiUrl: "https://api.emailjs.com/api/v1.0/email/send",
};

const ADMIN_EMAIL = "yoann.beugre1@gmail.com";

function buildPolicyMessage(prenom, nom) {
  return `Bonjour ${prenom} ${nom},

Nous vous informons de l'évolution des conditions générales de Chafin Loans concernant les retards de paiement.

📋 NOUVELLES CONDITIONS APPLICABLES :

1️⃣ DÉLAI DE GRÂCE DE 31 JOURS
   Si une mensualité n'est pas réglée dans les 31 jours suivant sa date d'échéance, une pénalité de retard sera automatiquement appliquée.

2️⃣ PÉNALITÉ DE 5% SUR LA MENSUALITÉ EN RETARD
   La pénalité correspond à 5% du montant de l'échéance concernée. Elle est appliquée une seule fois par échéance en retard.

   Exemple : Pour une mensualité de 200€ due le 31 décembre, si celle-ci n'est toujours pas réglée au 31 janvier (31 jours après), une pénalité de 10€ (5% × 200€) sera ajoutée. Le montant à régler deviendra alors 210€.

3️⃣ DÉGRADATION DU NIVEAU DE CONFIANCE
   Au-delà de 60 jours de retard, votre niveau de confiance sera automatiquement dégradé, ce qui pourra entraîner des conditions moins avantageuses pour vos futures demandes de prêt.

💡 RECOMMANDATIONS :
• Pensez à régler vos échéances avant la date prévue
• Des rappels automatiques vous seront envoyés avant chaque échéance (15 jours, 7 jours, 3 jours et la veille)

Ces mesures visent à assurer le bon fonctionnement de la plateforme et à protéger l'ensemble de nos utilisateurs.

Nous restons à votre disposition pour toute question.

Cordialement,
L'équipe Chafin Loans`;
}

async function sendEmail(email, name, subject, message) {
  try {
    const response = await axios.post(EMAILJS_CONFIG.apiUrl, {
      service_id: EMAILJS_CONFIG.serviceId,
      template_id: EMAILJS_CONFIG.templateId,
      user_id: EMAILJS_CONFIG.publicKey,
      accessToken: EMAILJS_CONFIG.privateKey,
      template_params: {
        email: email,
        name: name,
        subject: subject,
        message: message,
        from_name: "Chafin Loans",
      },
    }, {
      headers: { "Origin": "https://chafin.web.app" },
    });

    if (response.status === 200) {
      console.log(`  ✅ Email envoyé à ${name} (${email})`);
      return true;
    } else {
      console.log(`  ❌ Échec: ${response.status}`);
      return false;
    }
  } catch (error) {
    console.log(`  ❌ Erreur: ${error.message}`);
    if (error.response) console.log(`     Response: ${JSON.stringify(error.response.data)}`);
    return false;
  }
}

async function main() {
  const mode = process.argv[2] || "test";
  const subject = "📢 Évolution des conditions - Pénalités de retard Chafin Loans";

  if (mode === "test") {
    console.log("📧 MODE TEST - Envoi à l'admin seul pour contrôle\n");
    console.log("--- Aperçu du mail ---");
    console.log(buildPolicyMessage("Prénom", "Nom"));
    console.log("\n--- Envoi test ---");

    const msg = buildPolicyMessage("Admin", "Chafin");
    await sendEmail(ADMIN_EMAIL, "Admin Chafin", `[TEST] ${subject}`, msg);

    console.log("\n✅ Email test envoyé à " + ADMIN_EMAIL);
    console.log("📌 Pour envoyer à tous les emprunteurs : node scripts/send_policy_email.js send");

  } else if (mode === "send") {
    console.log("📧 MODE ENVOI RÉEL - Envoi à tous les emprunteurs\n");

    // Récupérer tous les emprunteurs depuis Firestore
    const borrowers = await db.collection("users").where("role", "==", "borrower").get();
    const validBorrowers = [];

    for (const doc of borrowers.docs) {
      const u = doc.data();
      // Exclure les comptes test et sans email
      if (u.email && u.email !== "test@example.com" && u.email !== "k@gmail.com") {
        validBorrowers.push({
          prenom: u.prenom || "",
          nom: u.nom || "",
          email: u.email,
        });
      }
    }

    console.log(`📊 ${validBorrowers.length} emprunteurs à contacter\n`);

    let sent = 0;
    for (const user of validBorrowers) {
      const name = `${user.prenom} ${user.nom}`.trim();
      const msg = buildPolicyMessage(user.prenom || "Cher emprunteur", user.nom || "");
      const ok = await sendEmail(user.email, name || "Emprunteur", subject, msg);
      if (ok) sent++;

      // Délai entre les envois pour ne pas surcharger EmailJS
      await new Promise(r => setTimeout(r, 1500));
    }

    console.log(`\n✅ ${sent}/${validBorrowers.length} emails de communication envoyés`);
  } else {
    console.log("Usage: node scripts/send_policy_email.js [test|send]");
  }

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
