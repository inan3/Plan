const functions = require('firebase-functions/v1');
const admin     = require('firebase-admin');
const nodemailer= require('nodemailer');
const express   = require('express');
admin.initializeApp();

const { user, pass } = functions.config().smtp;   // firebase functions:config:set …

const transporter = nodemailer.createTransport({
  host: 'smtp.hostinger.com',
  port: 465,
  secure: true,
  auth: { user, pass }            // sin  tls.rejectUnauthorized
});

const app = express().use(express.json());

app.post('/', async (req, res) => {
  const { email = '' } = req.body;
  if (!email) return res.status(400).send('Falta email');
  try {
    const raw = await admin.auth().generatePasswordResetLink(email);

    const url = new URL(raw);            // conserva query completa
    url.pathname = '/reset_password.html';

    await transporter.sendMail({
      from: `"Plan" <${user}>`,
      to: email,
      subject: 'Restablece tu contraseña',
      html: `<p>Pulsa este enlace para restablecer tu contraseña:</p>
             <a href="${url}">${url}</a>`
    });
    res.send('Correo enviado');
  } catch (err) {
    console.error(err);
    res.status(500).send('Error interno');
  }
});

exports.sendResetEmail = functions.region('europe-west1').https.onRequest(app);
