# Bakery modules — Hanna Bakery POS

## 1. Cake Orders (Dashboard → Cake Orders)
- **New Order:** customer, phone, item (quick chips: Birthday / Wedding / Custom cake, Cup cakes...), flavour,
  wazan (Pound / Kg), cake par message, design notes, delivery date + time, pickup ya home delivery (pata),
  total aur advance (cash / bank).
- **Open** tab: LATE / TODAY / TOMORROW / LATER groups. Har order par tap:
  Ready, Receive payment, **Deliver & collect balance**, Edit, Print slip (thermal), Share slip (WhatsApp), Call,
  Cancel (advance wapsi ke saath), Delete (sirf jab koi paisa na liya ho).
- Dashboard par card + badge: late + aaj ke orders, aur baqi wusooli.
- Notification (Android): subah aaj / late orders, shaam ko kal ke orders ki tayyari.
- Paisa: advance / payment = Cash IN row `Income: Cake Order #00012 ...` → Day Book, Cash & Bank, Reports (Other
  Income) mein khud. Cancel par wapsi = Expense (Miscellaneous) → profit se minus.
- Reports → Bakery reports → **Cake Orders Summary** (mahina-war orders, qeemat, wusooli, cancel).
- Note: orders ki table sirf isi device par hai (cloud sync mein nahi); unki cash rows sync hoti hain.

## 2. Production & Recipes (Admin / Manager)
- **Recipes** tab: tayyar item (jaise Double Roti) → "1 batch mein kitna banta hai" (jaise 20 pcs) → kacha maal
  per batch (Maida 2 kg, Cheeni 200 g, Khameer 20 g ...). Miqdaar har item ki smallest unit mein.
- **Bake** tab: batch ginti → app dikhati hai kitna kacha maal lagega, kya kam hai (laal), aur laagat (per piece
  bhi). Save = tayyar item ka stock +, kacha maal ka stock − (Stock History: PRODUCTION / USED IN PRODUCTION).
  Kacha maal kam ho to rokti hai; "Bake anyway" se stock minus mein ja sakta hai.
- **Log** tab: pichle 7 din ki production aur kache maal ki laagat.
- Pehle Items mein kacha maal (Maida, Cheeni, Anday, Ghee...) aur tayyar items dono bana lein; kacha maal
  Purchase se aata hai.

## 3. Wastage (Admin / Manager)
- Add Wastage → item → miqdaar → wajah (Baasi, Toot gaya, Jal gaya, Bacha hua, Customer wapsi, Staff / sample).
- Stock kam hota hai (Stock Adjustment "Damage / Loss" ki tarah) aur aaj / 7 din / mahine ka **nuqsan (cost par)**
  item-wise nazar aata hai. Inventory Insights ki Damage report mein bhi aata hai.

## 4. Weight se bikne wale items
Items mein unit `kg` / `g` rakhein (cake, mithai, biscuit) — Sale screen par wazan ke hisaab se rate lagta hai.

## Kya hataya gaya
Qist, Wasooli / Collection hub, Due reminders & follow-ups, Amanat / Loan, Zakat, Shop Rents, Utility Bills,
Shell Ledger, Bill Scan (OCR — APK bhi chhota). Purani DB tables schema mein hain (migration / sync safe).
