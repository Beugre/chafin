// Firebase Configuration for Web
const firebaseConfig = {
  apiKey: 'AIzaSyD-IJ979UMdA4BJeH2zsPQOe9yNW18PxYg',
  appId: '1:314923488171:web:a1d494c389c229d8caf8ee',
  messagingSenderId: '314923488171',
  projectId: 'chafin-23cad',
  authDomain: 'chafin-23cad.firebaseapp.com',
  databaseURL: 'https://chafin-23cad-default-rtdb.europe-west1.firebasedatabase.app',
  storageBucket: 'chafin-23cad.firebasestorage.app',
  measurementId: 'G-SMVWN2SEQT',
};

// Initialize Firebase
try {
  firebase.initializeApp(firebaseConfig);
  console.log('✅ Firebase initialisé avec succès côté web');
} catch (error) {
  console.error('❌ Erreur initialisation Firebase:', error);
}
