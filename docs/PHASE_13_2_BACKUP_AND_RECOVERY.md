# TOURMATE — PHASE 13.2 BACKUP AND RECOVERY GUIDE

**Project:** TourMate — Smart Tourism Guide App  
**Firebase Project:** `tourmate-70d03`  
**Date:** November 18, 2026  

---

## 1. Overview & Free-Tier (Spark) Backup Assessment

In accordance with safety rules, no paid billing resources or Cloud Storage export buckets have been created. On the Firebase Spark (free) plan:
- Managed automated Cloud Firestore export to Cloud Storage requires the Blaze (Pay-as-you-go) plan.
- Therefore, automated managed database exports are unavailable on the free plan.
- To guarantee zero risk to existing production data:
  1. No production database deletions or mutations are executed.
  2. Attraction seeding enforces strict dry-run mode and explicit document preservation for `Charminar`.
  3. All critical local configuration files and build assets are archived locally prior to deployment.

---

## 2. Local Configuration Archive

Pre-deployment configuration snapshots have been preserved in:
`scratch/phase13-backups/`

Archived files include:
- `scratch/phase13-backups/.firebaserc`
- `scratch/phase13-backups/firebase.json`
- `scratch/phase13-backups/firestore.rules`
- `scratch/phase13-backups/index.html`
- `scratch/phase13-backups/manifest.json`
- `scratch/phase13-backups/android-build.gradle.kts`

---

## 3. Rollback & Recovery Procedures

### 3.1 Reverting Firestore Security Rules
If deployed Firestore security rules cause unexpected permission errors:
1. Restore the pre-deployment rules file from backup:
   ```bash
   Copy-Item scratch/phase13-backups/firestore.rules firestore.rules
   ```
2. Redeploy the previous rules version immediately:
   ```bash
   firebase deploy --only firestore:rules --project tourmate-70d03
   ```
3. Alternatively, use the Firebase Console:
   - Navigate to **Firestore Database** -> **Rules**.
   - Select **Rules History** and revert to the previous verified release with one click.

### 3.2 Restoring Previous Firebase Hosting Version
Firebase Hosting maintains versioned deployment history:
1. **Via Firebase Console:**
   - Navigate to **Hosting** in Firebase Console.
   - Under **Release History**, find the previous stable deployment.
   - Click the three dots (`...`) and select **Rollback**.
2. **Via Firebase CLI:**
   - If a previous build folder was preserved, redeploy it:
     ```bash
     firebase deploy --only hosting --project tourmate-70d03
     ```

### 3.3 Application Configuration Recovery
If local configuration files (`firebase.json`, `.firebaserc`, `web/index.html`) become corrupted:
```bash
Copy-Item scratch/phase13-backups/* .
```

### 3.4 Protecting User and Attraction Data
1. Document `Charminar` (`attractions/Charminar`) and its associated reviews (`attractions/Charminar/reviews/*`) are programmatically protected in `SeedService` against overwrite.
2. User profile records (`users/{uid}`) have immutability checks in `firestore.rules`.
3. All production data modifications require separate explicit administrative authorization.
