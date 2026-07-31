const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Try to find the service account key
const functionsDir = path.join(__dirname, 'functions');
const files = fs.readdirSync(functionsDir);
const keyFile = files.find(f => f.endsWith('.json') && f.includes('firebase-adminsdk'));

if (!keyFile) {
  console.log("No service account key found");
  process.exit(1);
}

const serviceAccount = require(path.join(functionsDir, keyFile));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://imchat-84519-default-rtdb.asia-southeast1.firebasedatabase.app"
});

async function run() {
  const db = admin.database();
  const snap = await db.ref('pink_greedy_game/current_round').once('value');
  console.log("Pink current state:", snap.val());
  
  const snap2 = await db.ref('greedy_game/current_round').once('value');
  console.log("Greedy current state:", snap2.val());
  
  process.exit(0);
}
run();
