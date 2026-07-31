const admin = require("firebase-admin");
admin.initializeApp({
  projectId: "imchat-84519"
});
const db = admin.firestore();

async function run() {
  const snapshot = await db.collection("super_admins").get();
  console.log("=== SUPER ADMINS ===");
  snapshot.forEach(doc => {
    console.log(doc.id, "=>", doc.data());
  });
  
  const usersSnapshot = await db.collection("Users").where("userType", "==", "admin").get();
  console.log("\n=== USERS WITH userType == admin ===");
  usersSnapshot.forEach(doc => {
    console.log(doc.id, "=>", doc.data().fullname, doc.data().searchId, doc.data().roles);
  });
  
  process.exit(0);
}
run().catch(err => {
  console.error(err);
  process.exit(1);
});
