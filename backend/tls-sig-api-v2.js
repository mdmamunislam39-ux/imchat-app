// const crypto = require('crypto');

// function hmacsha256(sdkAppid, key, content) {
//   return crypto.createHmac('sha256', key).update(content).digest();
// }

// function base64Encode(str) {
//   return Buffer.from(str).toString('base64')
//     .replace(/\+/g, '*')
//     .replace(/\//g, '-')
//     .replace(/=/g, '_');
// }

// function base64Decode(str) {
//   str = str.replace(/\*/g, '+').replace(/-/g, '/').replace(/_/g, '=');
//   return Buffer.from(str, 'base64');
// }

// function genSig(sdkAppid, key, userId, expire = 180 * 24 * 3600) {
//   const currTime = Math.floor(Date.now() / 1000);
//   const sigDoc = {
//     'TLS.ver': '2.0',
//     'TLS.identifier': userId,
//     'TLS.sdkappid': sdkAppid,
//     'TLS.expire': expire,
//     'TLS.time': currTime
//   };

//   const sigDocJson = JSON.stringify(sigDoc);
//   const sig = hmacsha256(sdkAppid, key, Buffer.from(sigDocJson));
//   sigDoc['TLS.sig'] = sig.toString('base64');

//   return base64Encode(JSON.stringify(sigDoc));
// }

// module.exports = {
//   genSig
// };

const crypto = require('crypto');

function hmacsha256(key, content) {
  return crypto.createHmac('sha256', key).update(content).digest();
}

function base64Encode(str) {
  return Buffer.from(str).toString('base64')
    .replace(/\+/g, '*')
    .replace(/\//g, '-')
    .replace(/=/g, '_');
}

function genSig(sdkAppid, key, userId, expire = 180 * 24 * 3600) {
  const currTime = Math.floor(Date.now() / 1000);

  const sigDoc = {
    "TLS.ver": "2.0",
    "TLS.identifier": userId,
    "TLS.sdkappid": sdkAppid,
    "TLS.expire": expire,
    "TLS.time": currTime
  };

  const sigDocJson = JSON.stringify(sigDoc);

  const sig = hmacsha256(key, Buffer.from(sigDocJson));
  sigDoc["TLS.sig"] = sig.toString('base64');

  return base64Encode(JSON.stringify(sigDoc));
}

module.exports = { genSig };

