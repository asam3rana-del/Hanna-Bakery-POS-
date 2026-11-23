# Hanna Bakery POS (Flutter) — Hanna Solutions

Bakery ka POS: Android + iPad/iOS + Windows. Hanna POS (Kiryana) ke code se bana hai, lekin **alag app** hai:
Android `com.hannasolutions.bakery`, iOS bundle wahi, Windows data `%APPDATA%\Hanna Solutions\Hanna Bakery POS`,
installer `HannaBakeryPOS-Setup-<version>.exe` (apna AppId). Kiryana wali app ke saath ek hi phone / PC par chal sakti hai.

**Bakery modules:** Cake / custom orders (advance, delivery date, baqi wusooli, slip print / WhatsApp), Production
(recipes → kacha maal minus, tayyar maal plus), Wastage (baasi / kharab maal + nuqsan), aaj / kal ke orders ki notification.
Tafseel: `docs/BAKERY_GUIDE.md`.

**Design:** "Cocoa & Champagne" executive theme (Hanna Fitness jaisa premium) — espresso surfaces, champagne gold
accent, dark mode default. Dashboard: hero (aaj ki sale, aaj ke orders, order baqi, gold CTAs), Today's Bake Board,
performance KPIs, Bakery Control grid. Rang: `lib/theme/theme_manager.dart`, parts: `lib/widgets/bakery_premium.dart`.

**License:** offline, device-bound, Ed25519 signed key + 7 din trial. Key banane ka tareeqa: `docs/LICENSE_GUIDE.md`.

**Hata diye gaye (bakery ke liye ghair zaroori):** Qist / installments, Wasooli / Collection hub, Due reminders &
follow-ups, Amanat / Loan, Zakat, Shop Rents, Utility Bills, Shell Ledger, Bill Scan (OCR). Inki purani DB tables
schema mein maujood hain (migration / sync safe), lekin app mein koi screen nahi.

## Folder structure
- `lib/` — app (screens, db, sync, backup, services, models, utils, widgets, theme)
- `test/` — Dart tests (`*_test.dart`)
- `firebase/` — `firestore.rules` aur `firestore.indexes.json` (Firebase Console se deploy)
- `tools/` — `android_fix.sh` (CI mein Android native hissa: printer/USB channel, Kotlin/AGP/Gradle versions, signing), `import_zip.sh`, `check_root.sh`, `port_status.py`
- `docs/` — `APP_RULES.md` (roles, units, transactions), `GO_LIVE_CHECKLIST.md`, specs
- `.github/workflows/` — `build.yml` (analyze/test + iOS/Android/Windows), `import-zip.yml`

`android/`, `ios/`, `windows/` repo mein nahi hain; CI `flutter create` se banata hai.

## Design (Hanna premium)
- Poori app ka look ek jagah: `lib/theme/app_theme.dart` (Hanna navy `#0B2545` + gold `#F5B841`): cards, buttons, input boxes (gol konay), dialogs, bottom sheets, snackbars (floating), chips, tabs, switches, tables, scrollbar.
- Rang: `lib/theme/theme_manager.dart` (`AppPalette`, light/dark). Screen headers: `lib/widgets/premium_header.dart`.
- Sirf shape/rang/typography badli — button/field ki unchai nahi; jo screen apna style deti hai wo waise hi.

## Windows (PC)
- CI ka `windows-build` artifact: `HannaPOS-Setup-<version>.exe` (installer — yehi chalayein) aur `AH-Kiryana-Store-windows.zip` (portable; extract karke exe chalayein).
- Visual C++ runtime DLLs exe ke saath bundle hain (naye PC par "VCRUNTIME140_1.dll not found" nahi aata). Zip mein backup ke liye `vc_redist.x64.exe` bhi hai.
- Windows 10/11 64-bit. Admin ki zaroorat nahi. Ek waqt mein sirf ek app khulti hai (DB mehfooz).
- Data: `%APPDATA%\Hanna Solutions\Hanna POS` (DB + settings) — uninstall/update par nahi mitta. Ye naam `build.yml` (Runner.rc) se aata hai, **kabhi na badlein**. Purane `com.example` folder ka data pehli dafa khud copy ho jata hai.
- `windows_assets/`: `app_icon.ico` (Hanna POS icon), `installer.iss` (Inno Setup). Installer ka `AppId` kabhi na badlein.
- PC layout (`lib/desktop/`): window 1000 px se chauri ho to baayen sidebar menu (Urdu mein daayen), role ke hisaab se wahi screens jo dashboard/settings par. Login/lock screen par sidebar nahi. Content poori screen leta hai (1480 px tak). Dashboard ka alag PC layout (upar search patti, bara Quick Actions grid, daayen baqaya + wasooli). Tang window par purana mobile layout.
- PC settings (Settings › Computer (PC)): text size 85–145% (Ctrl + / Ctrl − / Ctrl 0), chhota sidebar, shortcuts list (F1). Shortcuts: Ctrl+D dashboard, Ctrl+N sale, Ctrl+I items, Ctrl+L parties, Ctrl+B day book, Alt+← / mouse back button = wapas; sale screen ke F2–F9 waise hi.
- App maximized khulti hai. Printer: Settings › Printer Setup se USB (Windows mein installed) ya network printer.
- Windows par nahi: Bluetooth printer, Bill Scan (OCR), notifications, background backup/sync service, contacts picker. Staff cloud login switch OFF rakhein.

## Build (GitHub Actions)
- `Build` workflow har push par chalta hai (sirf `.md` / `docs/` badalne par nahi). Naya push aane par purani chalti run cancel ho jati hai.
- Flutter ka version `build.yml` ke `FLUTTER_VERSION` mein ek hi jagah hai (abhi 3.24.0). Naya version aazmane ke liye Actions > Build > Run workflow mein `flutter_version` likhein (e.g. 3.47.2) — repo mein kuch badalna nahi parta. Naye Flutter par `tools/android_fix.sh` ke Kotlin/AGP/Gradle/compileSdk fixes dobara check karne parte hain.
- Android APK ke liye secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD` (fixed signing key, taake update ho sake).
- `pubspec.lock` repo mein nahi, is liye `flutter pub get` har build par `pubspec.yaml` ke caret ranges ke andar sab se naye packages uthata hai.

## Code zip se update karna
Zip mein exactly ek wrapper folder (`AH-Developer--main/`) hona chahiye; repo root par `.zip` daalein to `import-zip.yml` unzip karke files add/overwrite karta hai (delete nahi karta, aur `.github/` ko haath nahi lagata — workflow files GitHub par haath se badalni hongi). Phir `Build` workflow haath se chalayein.

## Checks (local)
`flutter analyze && flutter test`, aur `bash tools/check_root.sh` (root par faltu cheezein pakadta hai).


## Staff authentication backend
See `docs/STAFF_AUTH_BACKEND_SETUP.md` and `docs/STAFF_AUTH_TEST_PLAN.md`. Backend foundation only; Flutter login/sync migration and cashier server-side sale endpoint are not yet wired. Do not deploy claims rules to production yet.
