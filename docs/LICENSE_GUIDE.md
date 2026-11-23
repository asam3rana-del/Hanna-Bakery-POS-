# License — Hanna Bakery POS

Offline license: internet ki zaroorat nahi. Har install ka apna **Device ID** hota hai; us ID ki key sirf
usi device par chalti hai. Key Ed25519 se sign hoti hai — app ke andar sirf PUBLIC key hai, is liye koi
app khol kar bhi naya license nahi bana sakta.

## Customer ke liye flow
1. App install → **7 din free trial** (sab features).
2. Trial / license khatam → app sirf License screen dikhati hai. **Data mehfooz** rehta hai.
3. License screen par Device ID (jaise `HB7K-2M9Q-X4TZ`) → "WhatsApp par bhejein" (aap ke number par).
4. Aap key banakar WhatsApp karte hain → customer **Paste → ACTIVATE**. App foran khul jati hai.
5. Settings → License mein status, expiry aur Device ID hamesha nazar aata hai. 7 din reh jayen to dashboard
   par roz ek yaad dihani.

## Key banana (aap ke computer par)
Private key file: `hanna_bakery_license_private.key` (alag se di gayi hai — repo mein NAHI).
Isay `tools/license/` ke saath ek hi folder mein rakhein, ya `--key <path>` dein.

Node (koi package nahi chahiye):
```
node tools/license/hanna_license.js issue --device HB7K-2M9Q-X4TZ --shop "Ali Bakers" --days 365
node tools/license/hanna_license.js issue --device HB7K-2M9Q-X4TZ --shop "Ali Bakers" --until 2027-12-31
node tools/license/hanna_license.js issue --device HB7K-2M9Q-X4TZ --shop "Ali Bakers" --lifetime
```
Python (`pip install cryptography`): `python tools/license/hanna_license.py issue ...` (same options).

Har key `licenses_issued.csv` mein likhi jati hai (private key wale folder mein) — record ke liye.

## Zaroori baatein
- **Private key ka backup** (USB / Google Drive mein password ke saath). Gum ho gayi to naye license nahi ban sakte.
  Leak ho gayi to koi bhi license bana sakta hai → nayi key (`genkey`), `lib/license/license_keys.dart` mein nayi
  public key, nayi app build, aur sab customers ko nayi keys.
- Private key, `*.key`, `licenses_issued.csv` kabhi GitHub par na daalein (`.gitignore` mein hain).
- Renewal: wahi Device ID, nayi `--until` / `--days` key. Purani key ki jagah nayi paste karein.
- Device ID kab badalta hai: app uninstall / "Clear data" / naya phone / Windows reinstall. Tab naye ID ki key dein.
  (Data backup se restore hota hai, license nahi — license device ka hai.)
- Phone ki date peeche ki gayi ho to app ruk jati hai ("tareekh ghalat hai") jab tak sahi date na lagayein.
- Format: `HBK1.<payload>.<signature>` — payload mein device, shop, plan, issue date, expiry (khali = lifetime).
