# SourceBase — App Store Submission Runbook

**Prepared:** 2026-06-04 (night before submission)
**App:** MedAsi SourceBase · `tr.com.medasi.sourcebase` · ASC app id `6770117628`
**This build:** 1.0.0 (31) — fresh archive created tonight, validated for store.

---

## ✅ Done (verified tonight by Claude)

- [x] SourceBaseiOS package builds clean
- [x] All tests pass — **iOS 10/10, Backend 47/47** (57 total, 0 failures)
- [x] **Xcode app target `BUILD SUCCEEDED`** (Debug, simulator)
- [x] **Fresh `ARCHIVE SUCCEEDED`** for `generic/platform=iOS`, passed `-validate-for-store`
- [x] Build number bumped **30 → 31** (so re-upload isn't rejected as a duplicate)
- [x] Archive installed into Organizer → shows as **"SourceBase 1.0.0 (31)"** under `~/Library/Developer/Xcode/Archives/2026-06-04/`
- [x] App icon 1024×1024, **no alpha** (App Store requirement)
- [x] `PrivacyInfo.xcprivacy` embedded in the built app (declares Name, Email, UserID, OtherUserContent, PurchaseHistory; UserDefaults + FileTimestamp API reasons)
- [x] `ITSAppUsesNonExemptEncryption = false` (export compliance — no prompt at upload)
- [x] Launch screen wired (`LaunchBackground` color)
- [x] Signing configured: `DEVELOPMENT_TEAM = 489N9D2VTC`, automatic signing
- [x] IAP code path complete: `SBStoreKitManager` → `DriveAPI.redeemAppStorePurchase` → backend `redeem_appstore_purchase` action (deployed). Product IDs `tr.com.medasi.sourcebase.<code>` (mc_10/mc_20/mc_50). Subscriptions filtered out of in-app store.
- [x] Zero TODO/FIXME/fatalError in iOS source
- [x] Stale product-ID comment in `SBStoreKitManager.swift` fixed

---

## 🔴 YOU must do — in order (Apple account, can't be automated for you)

### 1. Paid Applications Agreement (the #1 blocker)
App Store Connect → **Business** → Agreements, Tax, and Banking.
- The **Paid Applications** agreement must show **Active** (requires Account Holder + completed Tax + Banking).
- Until active, **no IAP can be created or sold**, and an app that contains IAP will be **rejected**.
- Confirmed tonight: your account currently has **0 IAP products** → this is almost certainly still gated here.

### 2. The 3 consumable IAP products — ✅ MOSTLY DONE (created via ASC API tonight)

Agreement is **Active** (confirmed — creation returned 201). All 3 created with name + Turkish localization + Turkish price:

| Product ID | ASC id | Price (TR) | Grants | State |
|---|---|---|---|---|
| `tr.com.medasi.sourcebase.mc_10` | 6776442434 | 40,00 TL | 10 MC | name+loc+price set |
| `tr.com.medasi.sourcebase.mc_20` | 6776442590 | 65,00 TL | 20 MC | name+loc+price set |
| `tr.com.medasi.sourcebase.mc_50` | 6776442506 | 179,99 TL | 50 MC | name+loc+price set |

**⚠️ One step left per product — the review screenshot (you must add):**
ASC → your app → **In-App Purchases** → open each product → drag in **one screenshot** of the in-app coin store (the StoreView). Take it on a real device/simulator during QA. **The same image can be reused for all three.** Once added, state moves out of `MISSING_METADATA` and the product can be submitted with the app version.
> Don't change the product IDs — they match the app code and your backend `store_products.code` rows.

### 3. Upload the build
Xcode → **Window → Organizer** → select **SourceBase 1.0.0 (31)** → **Distribute App** → **App Store Connect** → **Upload**.
- Let Xcode manage distribution signing (it will create the Distribution cert + profile via your account — you currently only have a Development cert, which is normal; Organizer handles this).
- After upload, the build appears in ASC under TestFlight/Build in ~5–30 min after processing.

### 4. App Store version metadata (ASC → App Store tab, version 1.0)
- [ ] **Screenshots** — 6.9" (1320×2868) and 6.5"/6.7" iPhone required; iPad 13" if you keep iPad enabled. (You can record clean ones from the app; the tour video has the recording dot in the status bar — re-capture clean.)
- [ ] **Description, keywords, promotional text, support URL, marketing URL**
- [ ] **Privacy Policy URL** → `https://sourcebase.medasi.com.tr/gizlilik` (must match what's in the app)
- [ ] **App Privacy questionnaire** — answer to match `PrivacyInfo.xcprivacy`: Email, Name, User ID, User Content, Purchase History → all "linked to user, app functionality, not tracking."
- [ ] **Age rating**, **category** (Education / Medical), **pricing** (Free, with IAP)
- [ ] Attach **build 31** to the version.
- [ ] Add the IAP(s) to the version ("In-App Purchases and Subscriptions" on the version page) so they're reviewed together.
- [ ] **App Review notes**: provide a **demo account** (email + password) — reviewers must log in. Mention that AI generation costs Medasi Coins and how to obtain test coins, or grant the demo account a coin balance server-side.

### 5. Submit for Review.

---

## 🟡 Strongly recommended before you submit (device QA — can't be done from this machine)

The backend AI fixes from yesterday were verified to compile/deploy but **not** exercised end-to-end with a real authenticated generation. On a real device, confirm:
- [ ] Upload a PDF → it processes to "hazır" → generate **flashcards / 5-choice questions / summary** → output is real & correct (questions have **5 options, answer not always A**, per-option rationales).
- [ ] **Infographic** shows a real image; **Podcast** plays real audio (or honest "metni oku" fallback).
- [ ] **Sandbox IAP**: buy mc_10 with a sandbox tester → coin balance increases → no double-credit on relaunch.
- [ ] **Account deletion** + **sign out** flow.
- [ ] MedasiChat input not covered by keyboard; PDF export multi-page.

---

## Notes / risks
- Archive is **dev-signed**; Organizer re-signs for distribution at upload. This is expected.
- The Jun-2 archive (build 30) is **stale** (predates yesterday's fixes) — do not upload it.
- Backend = self-hosted Supabase (Coolify, `46.225.100.139`); `redeem_appstore_purchase` deployed. If a sandbox purchase fails to credit, check the edge function logs there.
- Anon key baked into the app is public/safe (RLS-enforced).
