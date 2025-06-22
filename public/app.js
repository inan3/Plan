import { initializeApp } from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  sendEmailVerification,
  reload
} from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-auth.js';
import {
  getFirestore,
  doc,
  getDoc,
  setDoc,
  setLogLevel
} from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-firestore.js';
import {
  getStorage,
  ref as storageRef,
  uploadBytes,
  getDownloadURL
} from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-storage.js';
import {
  getFunctions,
  httpsCallable
} from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-functions.js';

const firebaseConfig = {
  apiKey: "AIzaSyA-BHmsMAtT4Zs2wK2BTpyu1UWKNZqoG14",
  authDomain: "plansocialapp.es",
  databaseURL: "https://plan-social-app-default-rtdb.europe-west1.firebasedatabase.app",
  projectId: "plan-social-app",
  storageBucket: "plan-social-app.firebasestorage.app",
  messagingSenderId: "861608593316",
  appId: "1:861608593316:web:fa8964d140025bb0e96331",
  measurementId: "G-Y9Q5WB4REW"
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);
const functions = getFunctions(app, 'europe-west1');

setLogLevel('debug');

const emailRegisterBtn = document.getElementById('emailRegisterBtn');
const googleRegisterBtn = document.getElementById('googleRegister');
const checkVerificationBtn = document.getElementById('checkVerificationBtn');
const completeProfileBtn = document.getElementById('completeProfileBtn');
const regEmail = document.getElementById('regEmail');
const regPwd = document.getElementById('regPwd');
const regMsg = document.getElementById('regMsg');
const nameInput = document.getElementById('nameInput');
const ageInput = document.getElementById('ageInput');
const profilePhoto = document.getElementById('profilePhoto');
const coverPhotos = document.getElementById('coverPhotos');
const completeMsg = document.getElementById('completeMsg');
const step1 = document.getElementById('registerStep1');
const step2 = document.getElementById('registerStep2');

async function isExplicit(file) {
  const reader = new FileReader();
  return new Promise((resolve, reject) => {
    reader.onloadend = async () => {
      try {
        const base64 = reader.result.split(',')[1];
        const callable = httpsCallable(functions, 'detectExplicitContent');
        const result = await callable({ image: base64 });
        resolve(result.data.explicit);
      } catch (e) {
        resolve(false);
      }
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

function showExplicitPopup() {
  const overlay = document.createElement('div');
  overlay.style.position = 'fixed';
  overlay.style.top = '0';
  overlay.style.left = '0';
  overlay.style.right = '0';
  overlay.style.bottom = '0';
  overlay.style.background = 'rgba(0,0,0,0.5)';
  overlay.style.display = 'flex';
  overlay.style.alignItems = 'center';
  overlay.style.justifyContent = 'center';
  overlay.innerHTML = `
    <div style="background:#fff;padding:20px;border-radius:8px;text-align:center;max-width:300px;">
      <p>Esta imagen de contenido explícito incumple la Norma sobre Contenido Sexual. Visita:</p>
      <button id="termsBtn" style="margin-top:8px;border:none;background:none;color:#007bff;text-decoration:underline">Condiciones de uso</button>
    </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
  document.getElementById('termsBtn').onclick = () => {
    window.open('https://plansocialapp.es/terms_and_conditions.html', '_blank');
  };
}

emailRegisterBtn?.addEventListener('click', async () => {
  regMsg.textContent = '';
  try {
    const cred = await createUserWithEmailAndPassword(auth, regEmail.value.trim(), regPwd.value.trim());
    await sendEmailVerification(cred.user);
    regMsg.textContent = `Se envió un correo a ${cred.user.email}`;
  } catch (e) {
    regMsg.textContent = e.message;
  }
});

googleRegisterBtn?.addEventListener('click', async () => {
  regMsg.textContent = '';
  try {
    const provider = new GoogleAuthProvider();
    const cred = await signInWithPopup(auth, provider);
    if (cred.user && !cred.user.emailVerified) {
      await sendEmailVerification(cred.user);
    }
    regMsg.textContent = `Se envió un correo a ${cred.user.email}`;
  } catch (e) {
    regMsg.textContent = e.message;
  }
});

checkVerificationBtn?.addEventListener('click', async () => {
  if (!auth.currentUser) return;
  await reload(auth.currentUser);
  if (!auth.currentUser.emailVerified) {
    await new Promise(r => setTimeout(r, 2000));
    await reload(auth.currentUser);
  }
  if (auth.currentUser.emailVerified) {
    step1.style.display = 'none';
    step2.style.display = 'block';
  } else {
    regMsg.textContent = 'Tu correo aún no está verificado.';
  }
});

completeProfileBtn?.addEventListener('click', async () => {
  if (!auth.currentUser) return;
  completeMsg.textContent = '';
  const name = nameInput.value.trim();
  const age = parseInt(ageInput.value, 10) || 18;
  if (!name) {
    completeMsg.textContent = 'Introduce un nombre';
    return;
  }
  try {
    let photoUrl = '';
    if (profilePhoto.files[0]) {
      if (await isExplicit(profilePhoto.files[0])) {
        showExplicitPopup();
        return;
      }
      const refP = storageRef(storage, `users/${auth.currentUser.uid}/profilePhoto/${profilePhoto.files[0].name}`);
      await uploadBytes(refP, profilePhoto.files[0]);
      photoUrl = await getDownloadURL(refP);
    }
    const coverUrls = [];
    for (const file of coverPhotos.files) {
      if (await isExplicit(file)) {
        showExplicitPopup();
        return;
      }
      const refC = storageRef(storage, `users/${auth.currentUser.uid}/coverPhotos/${file.name}`);
      await uploadBytes(refC, file);
      coverUrls.push(await getDownloadURL(refC));
    }
    await setDoc(doc(db, 'users', auth.currentUser.uid), {
      uid: auth.currentUser.uid,
      name,
      nameLowercase: name.toLowerCase(),
      age,
      photoUrl,
      coverPhotoUrl: coverUrls[0] || '',
      coverPhotos: coverUrls,
      privilegeLevel: 'Básico',
      dateCreatedData: new Date()
    });
    completeMsg.textContent = 'Registro completado';
    document.getElementById('registerModal').style.display = 'none';
  } catch (e) {
    completeMsg.textContent = e.message;
  }
});

onAuthStateChanged(auth, async (user) => {
  if (!user) return;
  if (user.emailVerified) {
    const snap = await getDoc(doc(db, 'users', user.uid));
    if (!snap.exists()) {
      step1.style.display = 'none';
      step2.style.display = 'block';
      document.getElementById('registerModal').style.display = 'block';
    }
  }
});
