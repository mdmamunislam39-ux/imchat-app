// const express = require("express");
// const bodyParser = require("body-parser");
// const { genTestUserSig } = require("./tls-sig-api-v2"); // Tencent SDK

// const app = express();
// app.use(bodyParser.json());

// const SDKAppID = 20026600;  // আপনার Tencent SDKAppID
// const SECRETKEY = "xxxxxxxxxxxxxxxxxxxxxxxxxxxx"; // আপনার SecretKey
// const EXPIRETIME = 604800; // 7 days (second)

// app.post("/getUserSig", (req, res) => {
//   const userId = req.body.userId;
//   if (!userId) {
//     return res.status(400).json({ error: "Missing userId" });
//   }

//   const userSig = genTestUserSig(SDKAppID, SECRETKEY, userId, EXPIRETIME);
//   res.json({ userId, userSig });
// });

// app.listen(3000, () => {
//   console.log("Server running on http://localhost:3000");
// });

const express = require("express");
const cors = require("cors");
const { genSig } = require("./tls-sig-api-v2");

const app = express();
app.use(cors());
app.use(express.json());

const SDKAPPID = 20026600; // তোমার আসল SDKAppID বসাও
const SECRETKEY = "4ccefc94b5df6c9bb0541d773bec024b59199f07b733a37a5332773dd2881935"; 

app.post("/generateUserSig", (req, res) => {
  const { userId } = req.body;
  if (!userId) return res.status(400).send({ error: "userId required" });

  const userSig = genSig(SDKAPPID, SECRETKEY, userId);
  res.send({ userSig });
});

app.listen(3000, () => {
  console.log("🚀 Server running at http://localhost:3000");
});
