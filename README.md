# EstateSathi

Rent owners ke liye Flutter app + Node.js/MongoDB backend.

```
estate_sathi/
├── backend/   Node.js + Express + MongoDB Atlas (API)
└── app/       Flutter app (lib/, pubspec.yaml)
```

## 1) Backend chalana (pehle ye)

1. https://www.mongodb.com/atlas par free cluster banao. Database user banao aur Network Access me `0.0.0.0/0` allow karo.
   "Connect > Drivers" se connection string copy karo.
2. `backend/` folder me:
   ```
   cp .env.example .env      # phir .env kholkar MONGODB_URI, ADMIN_USER, ADMIN_PASS bharo
   npm install
   npm start
   ```
   Server start hote hi `ADMIN_USER` / `ADMIN_PASS` wala login database me ban jata hai.
   Password badalna ho to `.env` me badal kar server restart karo.
3. Photos bhi MongoDB me hi store hoti hain.

**Phone se kaise connect kare?**
- Ghar/dukan ke WiFi par: PC me backend chalao, PC ka IP dekho (jaise `192.168.1.5`), app ke login screen par
  "Server settings" me `http://192.168.1.5:5000` daalo.
- Kahin se bhi chalana ho: backend ko Render / Railway jaisi service par deploy karo aur uska URL app me daalo.

## 2) Flutter app banana

Flutter 3.24+ chahiye. `app/` folder ke andar:

```
flutter create --org com.estatesathi --project-name estate_sathi .
rm -f test/widget_test.dart
python3 patch_manifest.py       # permissions + http + app naam set karta hai
flutter pub get
flutter run                     # test ke liye
flutter build apk --release     # final APK
```

APK yahan milegi: `build/app/outputs/flutter-apk/app-release.apk`

Agar `flutter pub get` version conflict de to: `flutter pub upgrade --major-versions`

## Design (reference mockup ke hisaab se)

Dark green + gold theme, bottom tabs: Home / Properties / Tenants / Bills / More.
- Property: photo, type, floors, description, Archive/Active filter, rooms tab (floor, rent, Occupied/Vacant)
- Add Room & Tenant: 2 steps (Tenant Details, phir Rent & Utilities)
- Tenant Profile: Details / Family / Bills / Payments tabs, Generate Bill aur Record Payment buttons
- Bill Preview: invoice jaisa, Send Reminder (WhatsApp/SMS) aur Save Bill (PDF share)
- Bill ka status Paid / Partial / Pending (payments purane bill me pehle adjust hoti hain)

## Features

- Login (database me userid/password)
- Dashboard: is mahine ka collection, bill, kul baaki, pending payments ka alert, bill banana baaki wale tenants, haal ki payments
- Properties: naam/location manually ya current location se auto
- Property > Rooms > Tenant (photo, aadhar, family, entry date, rent, paani, kachra, bijli rate, meter reading)
- Tenant profile me: Generate Bill (date + nayi reading + meter photo), Record Payment, payment/bill history, reminder (WhatsApp + seedha SMS)
- Har jagah delete buttons (property, room, tenant, bill, payment)

## Dhyan dene wali baatein

- Payment tenant ke kul hisaab me adjust hoti hai (Bill total - Payments = Baaki). Zyada payment advance dikhegi.
- Latest bill delete karne par meter reading pichli value par wapas aa jati hai.
- Seedha SMS ke liye Android ki SMS permission lagti hai. Permission na mile to SMS app khul jata hai.
- WhatsApp message pehle se likha hua khulta hai, bhejne ke liye aapko send dabana hota hai.
- Ye personal use ke liye bana hai. Public internet par chalane ho to strong password rakho.
