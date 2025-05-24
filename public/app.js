import { initializeApp } from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-app.js';
import { getAuth, onAuthStateChanged } from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-auth.js';
import { getFirestore, doc, getDoc, setLogLevel } from 'https://www.gstatic.com/firebasejs/9.22.0/firebase-firestore.js';

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

setLogLevel('debug');

onAuthStateChanged(auth, async (user) => {
  if (!user) return; // aun sin sesión
  const snap = await getDoc(doc(db, 'users', user.uid));
  console.log(snap.data());
});
