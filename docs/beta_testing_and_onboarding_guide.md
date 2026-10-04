# 🪣 Bucket Beta Onboarding & Testing Guide

Welcome to the **Bucket** Beta Program! This guide walks you through the core concepts, recommended testing scenarios, and feedback reporting channels.

---

## 💡 Core Philosophy: What is Bucket?

Bucket is a **goal-based virtual allocation layer** on top of your existing bank account.
* **Non-Custodial:** Bucket **never** holds your money and never moves funds between accounts.
* **Virtual Ledger:** Money allocated to a goal is logically committed and deducted from your spendable balance.
* **Waterfall Protection:** If an external spend (ATM, debit card, non-Bucket UPI) occurs in your bank account, Bucket's reconciliation engine automatically absorbs the debit from your **lowest-priority want**, preserving your essential goals (like Rent or Emergency Fund).
* **Local-First Privacy:** All balances, allocations, and transaction ledgers remain strictly on your device.

---

## 🧪 5 Core Testing Scenarios for Beta Testers

### Scenario 1: Setup Goals with Mixed Priorities & Categories
1. Open the **Goals** tab.
2. Create a high-priority NEED goal:
   * Name: `House Rent`
   * Target: `₹12,000`
   * Priority: `5 (Protected)`
   * Category: `Need`
3. Create medium/low-priority WANT goals:
   * Name: `Weekend Trip` (Priority 2, Want, Target ₹4,000)
   * Name: `New Headphones` (Priority 1, Want, Target ₹6,000)
4. Verify on **Home**:
   * Total Bank Balance matches sum of Spendable + Committed.
   * Progress ring reflects committed amounts.

---

### Scenario 2: Scan & Pay with Live Deficit Prediction
1. On the **Home** tab, tap **Scan & Pay** (or the QR icon).
2. Point your camera at any UPI QR code, or use the quick test simulation presets:
   * Tap `☕ Coffee ₹280` — notice the **green safe banner** (within spendable pool).
   * Tap `🎧 ₹12,000` — notice the **amber/red deficit warning**!
3. Review the predicted deduction:
   * Shows exactly which lowest-priority goals (`New Headphones`, `Weekend Trip`) will be depleted if you proceed with this payment.
4. Tap **Pay** to initiate the transaction via NPCI Intent URI.

---

### Scenario 3: Bank Sync & Waterfall Reconciliation
1. Tap **Settings** ➔ **Launch Sync Simulator** (or navigate to the Simulator).
2. Choose a bank transaction preset:
   * **Preset A:** `-₹6,000 Grocery Spend`
   * **Preset B:** `-₹10,000 Multi-Goal Overflow Spend`
   * **Preset C:** `+₹15,000 Salary Credit`
3. Tap **Simulate Bank Reconciliation**:
   * Watch the 4-step sync progress animation.
   * Observe the waterfall breakdown card showing goals before and after.
   * Confirm that Priority 5 (`House Rent`) is completely untouched!

---

### Scenario 4: Portfolio & Goal Analytics
1. Navigate to the **Analytics** tab.
2. Review:
   * **Overall Goal Funding Progress** bar and total target amount.
   * **Need vs. Want Ratio** bar showing the split of your money.
   * **Per-Goal Run Rates**: Daily and monthly contributions needed to hit deadlines.
   * **Waterfall Activity Tracker**: Historical summary of bank spends absorbed.

---

### Scenario 5: Security, Biometrics & Zero-Knowledge Backup
1. Go to **Settings** ➔ Toggle **Biometric App Lock**.
2. Set **Auto-Lock Delay** to `Immediately`.
3. Background the app and reopen it:
   * Verify the **Bucket is Locked** overlay appears with fingerprint/FaceID prompt.
4. Test Cloud Backup:
   * Tap **Zero-Knowledge Cloud Backup**.
   * Note: The app encrypts your snapshot with on-device AES-256 before transmitting the ciphertext to PostgreSQL. The backend cannot read your data.

---

## 🛡️ Security & Invariant Checklist

Please verify that:
* [x] No sensitive bank credentials, card numbers, or UPI PINs are ever asked for or stored.
* [x] No balance amounts appear in plaintext server logs.
* [x] Offline mode works seamlessly: all bucket balances and allocations are cached in local SQLite.

---

## 💬 How to Report Feedback & Bugs

1. **GitHub Issues:** [https://github.com/OmKsaga/Bucket/issues](https://github.com/OmKsaga/Bucket/issues)
2. **Issue Format:**
   * **Device Model & OS Version:** (e.g. Pixel 8, Android 14)
   * **Step-by-step reproduction steps**
   * **Expected vs Actual behavior**
   * **Screenshots / Screen recordings**
