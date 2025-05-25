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
      const refP = storageRef(storage, `users/${auth.currentUser.uid}/profilePhoto/${profilePhoto.files[0].name}`);
      await uploadBytes(refP, profilePhoto.files[0]);
      photoUrl = await getDownloadURL(refP);
    }
    const coverUrls = [];
    for (const file of coverPhotos.files) {
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
