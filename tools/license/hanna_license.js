#!/usr/bin/env node
// Hanna Bakery POS — license key generator (developer ke computer par chalayein, kabhi customer ko na dein).
// Koi npm package nahi chahiye (Node 16+ ka built-in crypto).
//
//   node hanna_license.js genkey [--out hanna_bakery_license_private.key]
//       Naya key pair. Private key file bana kar public key print karta hai — wo public key
//       lib/license/license_keys.dart mein `licensePublicKeyB64` par lagayein. (Sirf ek dafa; key badli to
//       purane saare license bekaar ho jate hain.)
//
//   node hanna_license.js issue --device HB7K-2M9Q-X4TZ --shop "Ali Bakers" [--days 365 | --until 2027-12-31 | --lifetime]
//                               [--plan pro] [--key hanna_bakery_license_private.key]
//       Customer ka Device ID (app ki License screen par) se license key banata hai. Key customer ko WhatsApp karein.
//       Har key licenses_issued.csv mein bhi likhi jati hai (record).
'use strict';
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PREFIX = 'HBK1';
const PKCS8_ED25519 = Buffer.from('302e020100300506032b657004220420', 'hex');

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  if (i < 0) return def;
  const v = process.argv[i + 1];
  return v === undefined || v.startsWith('--') ? true : v;
}
const b64url = (buf) => Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const ymd = (d) => d.toISOString().slice(0, 10);
const normDevice = (s) => String(s).toUpperCase().replace(/[^A-Z0-9]/g, '');

function die(msg) {
  console.error('ERROR: ' + msg);
  process.exit(1);
}

function genkey() {
  const out = arg('out', 'hanna_bakery_license_private.key');
  if (fs.existsSync(out)) die(out + ' pehle se maujood hai — purani key mat mitayein (warna purane license bekaar).');
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  const raw = privateKey.export({ format: 'der', type: 'pkcs8' }).subarray(16);
  const pub = publicKey.export({ format: 'der', type: 'spki' }).subarray(12);
  fs.writeFileSync(out, raw.toString('base64') + '\n', { mode: 0o600 });
  console.log('Private key: ' + out + '  (MEHFOOZ rakhein, backup lein, kisi ko na dein)');
  console.log('Public key (license_keys.dart mein lagayein):');
  console.log(pub.toString('base64'));
}

function issue() {
  const keyFile = arg('key', 'hanna_bakery_license_private.key');
  if (!fs.existsSync(keyFile)) die('Private key file nahi mili: ' + keyFile);
  const device = arg('device');
  const shop = arg('shop', '');
  if (!device || device === true) die('--device <Device ID> zaroori hai');
  const dev = normDevice(device);
  if (dev.length !== 12) die('Device ID 12 harf ka hota hai (jaise HB7K-2M9Q-X4TZ). Mila: ' + device);
  const plan = String(arg('plan', 'pro'));
  const today = new Date();
  let expiry = '';
  if (arg('lifetime', false) === true) {
    expiry = '';
  } else if (arg('until')) {
    const u = String(arg('until'));
    if (!/^\d{4}-\d{2}-\d{2}$/.test(u)) die('--until YYYY-MM-DD');
    expiry = u;
  } else {
    const days = parseInt(arg('days', '365'), 10);
    if (!(days > 0)) die('--days ghalat');
    expiry = ymd(new Date(today.getTime() + days * 86400000));
  }
  const payload = {
    v: 1,
    d: dev.slice(0, 4) + '-' + dev.slice(4, 8) + '-' + dev.slice(8, 12),
    s: String(shop === true ? '' : shop),
    p: plan,
    i: ymd(today),
    e: expiry,
  };
  const body = PREFIX + '.' + b64url(Buffer.from(JSON.stringify(payload), 'utf8'));
  const raw = Buffer.from(fs.readFileSync(keyFile, 'utf8').trim(), 'base64');
  if (raw.length !== 32) die('Private key file kharab hai');
  const key = crypto.createPrivateKey({ key: Buffer.concat([PKCS8_ED25519, raw]), format: 'der', type: 'pkcs8' });
  const sig = crypto.sign(null, Buffer.from(body, 'ascii'), key);
  const license = body + '.' + b64url(sig);
  const csv = path.join(path.dirname(path.resolve(keyFile)), 'licenses_issued.csv');
  if (!fs.existsSync(csv)) fs.writeFileSync(csv, 'issued,device,shop,plan,expiry,license\n');
  const q = (s) => '"' + String(s).replace(/"/g, '""') + '"';
  fs.appendFileSync(csv, [payload.i, payload.d, q(payload.s), payload.p, payload.e || 'lifetime', license].join(',') + '\n');
  console.log('Device : ' + payload.d);
  console.log('Shop   : ' + payload.s);
  console.log('Plan   : ' + payload.p);
  console.log('Expiry : ' + (payload.e || 'LIFETIME'));
  console.log('\nLICENSE KEY (customer ko bhejein):\n' + license);
}

const cmd = process.argv[2];
if (cmd === 'genkey') genkey();
else if (cmd === 'issue') issue();
else {
  console.log('Use:\n  node hanna_license.js genkey\n  node hanna_license.js issue --device XXXX-XXXX-XXXX --shop "Shop" [--days 365|--until YYYY-MM-DD|--lifetime]');
  process.exit(cmd ? 1 : 0);
}
