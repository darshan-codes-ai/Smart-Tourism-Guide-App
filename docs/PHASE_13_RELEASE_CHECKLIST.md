# TOURMATE — PHASE 13 RELEASE CHECKLIST

**Project:** TourMate — Smart Tourism Guide App  
**Target Environment:** Firebase Production (`tourmate-70d03`)  
**Date:** November 18, 2026  

---

## 1. COMPLETED ✅

- [x] Pre-deployment inspection of Git status, FlutterFire, routes, and configs.
- [x] Local backup archive created in `scratch/phase13-backups/`.
- [x] Security review of `firestore.rules` (role escalation, ownership, admin gates).
- [x] Live deployment of Firestore security rules to `tourmate-70d03`.
- [x] Configuration of SPA rewrite rule in `firebase.json` for deep linking.
- [x] Web release compilation with `flutter build web --release`.
- [x] Live deployment of Flutter Web to Firebase Hosting (`https://tourmate-70d03.web.app`).
- [x] Edge probe verification confirming `HTTP/1.1 200 OK` on root and nested routes.
- [x] Validation of 829 global attraction records across 46 countries.
- [x] Execution of attraction seeding service in dry-run mode (`dryRun: true`).
- [x] Verification that zero writes were made to production Firestore.
- [x] Verification of explicit `Charminar` document preservation.
- [x] Full test execution: 256/256 automated tests passing with zero failures.
- [x] Static analysis: `flutter analyze` with 0 issues.
- [x] PWA installability verified with manifest and standalone display.
- [x] Performance optimizations verified (font tree-shaking, lazy list rendering, CDN Brotli).

---

## 2. AWAITING APPROVAL ⏳

- [ ] **Production Firestore Seeding:** 829 candidate attractions ready for batch insertion. Execution is paused awaiting separate explicit developer authorization.
- [ ] **Git Commit & Push:** Phase 13 changes staged locally; awaiting user review before committing and pushing to remote.

---

## 3. REQUIRES MANUAL CONFIGURATION 🛠️

- [ ] **Android Production Keystore:** Generate upload keystore (`upload-keystore.jks`) and configure `android/key.properties` for Google Play Store release App Bundle signing.
- [ ] **Custom Domain (Optional):** Attach custom domain (e.g. `tourmate.app`) in Firebase Hosting console.

---

## 4. WARNINGS ⚠️

- [ ] **40 Remote Battlefield Attractions:** 40 attractions out of 829 gracefully display category-specific fallback illustrations due to absence of verified public-domain photography.
- [ ] **Spark Free Tier Database Backups:** Automated Cloud Firestore exports to Cloud Storage require the paid Blaze plan. Database modifications are gated by dry-run verification.

---

## 5. FAILED ❌

- **None.** All authorized Phase 13 stages completed with zero failures.
