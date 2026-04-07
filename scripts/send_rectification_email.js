/**
 * Envoie un email de rectification aux personnes ayant reçu des pénalités par erreur.
 * 
 * Usage :
 *   node scripts/send_rectification_email.js test     → Envoie à l'admin seul (pour contrôle)
 *   node scripts/send_rectification_email.js send     → Envoie aux 3 personnes concernées
 */
const axiosModule = require("../functions/node_modules/axios");
const axios = axiosModule.default || axiosModule;

const EMAILJS_CONFIG = {
  serviceId: "service_s6kh76e",
  templateId: "template_byf1fdm",
  publicKey: "sUFWr-XkJM8NcZQ86",
  privateKey: "iihl6951E8XgF-0y3Dumm",
  apiUrl: "https://api.emailjs.com/api/v1.0/email/send",
};

const ADMIN_EMAIL = "yoann.beugre1@gmail.com";

// Les 3 personnes qui ont reçu les pénalités par erreur
const AFFECTED_USERS = [
  { prenom: "Yvann", nom: "Wayhi", email: "wayiyvann@yahoo.fr" },
  { prenom: "Cephora", nom: "Gnangangomo", email: "cephoralauryl@yahoo.fr" },
  { prenom: "Darlène", nom: "Ngodjou Mboumba", email: "ngodjou1@gmail.com" },
];

function buildRectificationMessage(prenom, nom) {
  return `Bonjour ${prenom} ${nom},

Nous vous contactons suite à un email de pénalité de retard que vous avez reçu aujourd'hui de la part de Chafin Loans.

⚠️ RECTIFICATION IMPORTANTE :

L'email de pénalité que vous avez reçu a été envoyé par erreur suite à un dysfonctionnement technique de notre système. Nous vous prions de ne pas en tenir compte.

✅ CE QUI A ÉTÉ FAIT :
• Toutes les pénalités appliquées ont été annulées
• Vos échéanciers ont été restaurés à leurs montants originaux
• Aucune modification n'a été apportée à vos prêts

📌 VOS ÉCHÉANCIERS NE SONT PAS IMPACTÉS :
Les montants de vos mensualités restent identiques à ce qui était prévu initialement. Vous n'avez aucune majoration à payer suite à cet incident.

Nous vous présentons nos sincères excuses pour ce désagrément et vous remercions de votre compréhension.

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
  const subject = "📢 Rectification - Email de pénalité envoyé par erreur";

  if (mode === "test") {
    console.log("📧 MODE TEST - Envoi à l'admin seul pour contrôle\n");
    console.log("--- Aperçu du mail pour Yvann Wayhi ---");
    console.log(buildRectificationMessage("Yvann", "Wayhi"));
    console.log("\n--- Envoi test ---");

    // Envoyer les 3 versions à l'admin pour qu'il voie le contenu pour chaque personne
    for (const user of AFFECTED_USERS) {
      const msg = buildRectificationMessage(user.prenom, user.nom);
      await sendEmail(
        ADMIN_EMAIL,
        `${user.prenom} ${user.nom}`,
        `[TEST pour ${user.prenom}] ${subject}`,
        msg
      );
    }
    console.log("\n✅ 3 emails test envoyés à " + ADMIN_EMAIL);
    console.log("📌 Pour envoyer aux vrais destinataires : node scripts/send_rectification_email.js send");

  } else if (mode === "send") {
    console.log("📧 MODE ENVOI RÉEL - Envoi aux 3 personnes concernées\n");

    let sent = 0;
    for (const user of AFFECTED_USERS) {
      const name = `${user.prenom} ${user.nom}`;
      const msg = buildRectificationMessage(user.prenom, user.nom);
      const ok = await sendEmail(user.email, name, subject, msg);
      if (ok) sent++;

      // Petit délai entre les envois
      await new Promise(r => setTimeout(r, 1000));
    }

    console.log(`\n✅ ${sent}/${AFFECTED_USERS.length} emails de rectification envoyés`);
  } else {
    console.log("Usage: node scripts/send_rectification_email.js [test|send]");
  }

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
