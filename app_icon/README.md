# Hanna Bakery POS — app icon

Hanna Software Series ka Bakery icon: espresso `#2A1A12` chokor, cream `#F7F0E3` "H", champagne gold `#D4A24C`
2 manzila cake + mom batti (series ka "H + beech mein nishaan" andaaz; Hanna POS = barcode, Pharmacy = cross).

- `hanna_bakery_icon.svg` — poora icon (master). `hanna_bakery_foreground.svg` — bina background (Android adaptive).
- `android/` — CI (`build.yml` › Set Android app icon) `android/app/src/main/res/` mein copy karta hai; adaptive background `#2A1A12`.
- `ios/icon_<px>.png` — CI AppIcon.appiconset ki har PNG ko usi size se badalta hai (alpha nahi).
- Windows: `../windows_assets/app_icon.ico` (16–256 px).
- App ke andar (About / License / Settings) wahi logo `lib/widgets/hanna_bakery_logo.dart` mein CustomPaint se.

Icon badalna ho to SVG badal kar ye PNG/ICO dobara banayein (rsvg-convert + ImageMagick).
