# FinFlow — Full Development Roadmap

> This is the working engineering roadmap for taking FinFlow from its current
> partial state through to a Play Store launch. It complements
> `FinFlow_Project_Plan.txt` and `FinFlow_Requirements_SRS.txt` (the original
> product spec) with a phase-by-phase implementation plan, kept up to date as
> work lands.

## Progress

| Phase | Status | Notes |
|---|---|---|
| 1 — Foundation & Auth | ✅ Done | Git/CI, Drift migration, real Firebase (Auth: Google + Email/Password, Firestore), migration data-loss bug fixed, app branding |
| 2 — Core Transactions | ✅ Done | Edit flow, detail screen, date-range filter, recurring transactions, `isPro` stub |
| 3 — SMS Parsing | ✅ Done | Real device SMS scan+listen, review sheet, SRS-composite duplicate detection, free-tier cap |
| 4 — Budgeting | ✅ Done (client-side) | Derived spend, monthly history, create/edit/delete UI, cross-bucket warning. Scheduled reset + push alerts deliberately deferred until Blaze is worth adopting for multiple phases at once |
| 5 — Accounts & Cards | ✅ Done | Full accounts UI built from scratch (list/add/edit/detail/close), credit utilization + due-date banner, 3-account free-tier gate |
| 6 — Loans & EMI | ✅ Done (client-side) | Real AmortizationEngine (unit-tested) replaces fudge-factor debt math, loan CRUD UI built from scratch, 2-loan free-tier gate, Pro-gated Snowball/Avalanche. EMI auto-posting deferred with the rest of the Cloud Functions work |
| 7 — Savings Goals | ⬜ Not started | |
| 8 — Investments | ⬜ Not started | |
| 9 — Analytics | ⬜ Not started | |
| 10 — AI & Tips | ⬜ Not started | |
| 11 — Pro Features | ⬜ Not started | |
| 12 — Polish & Launch | ⬜ Not started | |

---

## Context

FinFlow is a Flutter personal-finance app with two detailed spec docs
(`FinFlow_Project_Plan.txt`, `FinFlow_Requirements_SRS.txt`) describing a full
12-module vision. An initial audit of the codebase found genuine working
functionality (guest mode, local SQLite storage, a solid SMS-parsing regex
engine, Firestore write-through sync, five feature tabs with live data)
alongside real gaps: functional bugs, several modules with fake/simulated
data instead of real logic, two SRS modules with zero code, and a project
that had never been placed under version control or CI.

This roadmap is a single ordered backlog (solo developer + Claude Code, not a
team) that takes FinFlow from that partial state through to launch, built in
an order where nothing depends on work that comes later. It keeps the
original 12 phase names/order from the Project Plan so it stays legible
against the docs, but each phase explicitly separates **already-done**
(verify only), **partially-done** (fix/complete), and **net-new** work, and
pulls infrastructure the original doc left implicit (Drift migration, Cloud
Functions, CI) forward into the phase where it's cheapest to build.

**Decisions confirmed before this plan was finalized:**
- **Platform: Android only.** `windows/`, `linux/`, `macos/`, `web/`
  scaffolding removed — iOS/Web are out of scope for this roadmap (SMS
  parsing, a core feature, is Android-only anyway).
- **Data layer: migrated from raw `sqflite` to Drift in Phase 1**, not
  later — cheapest while there were only 6 tables and little UI depended on
  raw SQL maps.
- **AI Tips (Phase 10): Google Vertex AI / Gemini** via Firebase AI Logic,
  not Claude API — tighter integration with the existing Firebase project.
- **Bank-account sync (Account Aggregator / Plaid): deferred entirely, out
  of scope for this plan.** No adapter, no sandbox integration. Transaction
  capture relies on SMS parsing + manual entry.

---

## Cross-cutting bugs fixed in Phase 1 (before anything else built on them)

1. **Guest→Firebase migration data-loss bug** (`lib/src/database/migration_service.dart`):
   the Firestore batch-write was wrapped in a try/catch that only logged a
   "simulating cloud backup" message on failure, then `clearAllData()` ran
   **unconditionally** afterward regardless of whether the batch actually
   committed. Fixed: `clearAllData()` now only runs after a verified
   successful commit; on failure, the UI surfaces an error and local data is
   left untouched.
2. **Google Sign-In was entirely mocked** (`lib/src/features/auth/presentation/login_screen.dart`):
   hardcoded `mockUid`/`mockEmail`/`mockName` with a fake delay, no real
   `GoogleSignIn`/`FirebaseAuth` call. Fixed: real `google_sign_in` →
   `FirebaseAuth.instance.signInWithCredential`, plus Email/Password
   sign-in/registration.

---

## Phase 1 — Foundation & Auth ✅

**Verify/keep:** Riverpod + go_router shell, dark-first design system
(`AppColors`/`AppSizes`), guest mode end-to-end, Android `applicationId
com.finflow.app`.

**Fixed:**
- Both cross-cutting bugs above.
- No `onUpgrade` migration path, no FK constraints, no indexes, no
  soft-delete, no audit timestamps in the old raw-sqflite schema.
- `.gitignore` didn't exclude secrets; repo wasn't under version control.
- No CI at all.
- No app branding (default Flutter launcher icons; generic pubspec name).

**Net-new (all done):**
1. `git init`, hardened `.gitignore`, baseline commit.
2. Deleted `windows/`, `linux/`, `macos/`, `web/`.
3. Real Firebase project (`finflow-3ae88`): Auth (Google + Email/Password),
   Firestore. Registered the Android app, downloaded real
   `google-services.json`/`firebase_options.dart`, registered the debug
   keystore's SHA-1/SHA-256 (required for Google Sign-In to work at all —
   without it, sign-in fails with `DEVELOPER_ERROR`), deployed Auth provider
   config and Firestore security rules to the live project.
4. **Migrated `db_service.dart` → Drift.** New `AppDatabase` with tables for
   `accounts`, `transactions`, `budgets`, `loans`, `investments`,
   `sms_inbox`. Every table has `id`, `created_at`, `updated_at`,
   `deleted_at` (soft-delete), and a `currency` column (default `INR`,
   unused until Phase 11 but painful to retrofit later). Real FKs
   (`transactions.account_id → accounts.id`, `ON DELETE RESTRICT`) and
   indexes (`transactions(account_id, date)`, `transactions(category)`).
   Caught and fixed a real bug in the process: income transactions were
   silently treated as debits due to a `'Income'` vs `'income'` casing
   mismatch, decrementing balance instead of increasing it.
5. Rewrote `auth_repository.dart`: `authStateChanges()` drives `authProvider`
   for real accounts; guest mode layered on top as a local-only concept.
6. Firestore Security Rules deployed (per-user ownership, default-deny
   fallback) — a reasonable prototype, not yet field-validated/hardened.
7. GitHub Actions CI (`flutter analyze`, `dart format` check, `flutter
   test`, debug APK build).
8. Real app branding: logo rasterized into launcher icon (incl. Android
   adaptive icon) + splash screen via `flutter_launcher_icons`/
   `flutter_native_splash`.

**Key files:** `lib/src/database/app_database.dart`, `lib/src/database/tables/*.dart`,
`lib/src/database/migration_service.dart`, `lib/src/features/auth/data/auth_repository.dart`,
`lib/src/features/auth/presentation/login_screen.dart`, `firestore.rules`, `.github/workflows/ci.yaml`.

---

## Phase 2 — Core Transactions ✅

**Verify/keep:** manual entry, 50/30/20 bucket tagging, account-balance
auto-adjust on insert/delete, offline-first writes.

**Fixed:**
- No edit-transaction flow anywhere — the single biggest CRUD gap in the app.
- `is_recurring` flag existed in the schema but nothing acted on it.
- No date-range filters, no tap-through/detail view.
- Found while touching this code: swipe-to-delete in the ledger never
  refreshed `accountListProvider`, leaving the account balance stale
  elsewhere in the app until something else happened to refresh it.

**Net-new (all done):**
1. `updateTransaction` (repository + UI): reverses the old transaction's
   balance impact and applies the new one inside one Drift transaction,
   correctly compounding even when amount/bucket/account all change
   together. `add_transaction_sheet.dart` renamed to
   `transaction_form_sheet.dart` and generalized into add/edit mode.
2. `TransactionDetailScreen` (tap-through from ledger + dashboard) with
   Edit/Delete actions; reads live from the provider so edits/deletes made
   while it's open are reflected immediately.
3. Date-range filter chip on the transactions list (`showDateRangePicker`),
   composable with the existing bucket filter and search.
4. `RecurringRules` table (schema v3) + `RecurringRepository`:
   `materializeDueRules()` runs on app-open (wired into `splash_screen.dart`),
   catching up every due occurrence — including multiple periods missed
   while the app was closed — into a real transaction. Reliable app-closed
   execution moves to a Cloud Function once Phase 4 stands up that infra.
   The transaction form's "Repeat this transaction" toggle (add mode only)
   creates the rule alongside the first occurrence.
5. `LocalSettings` table (schema v2) + `isProProvider`: a real field every
   later free/Pro gate reads from day one, manually toggleable via a debug
   switch in the profile menu until Phase 11 wires up real billing.
6. Free-tier gate: recurring transactions capped at 5 active rules
   (`kFreeRecurringLimit`), enforced in `RecurringRepository.canAddRule()`.

**Key files:** `lib/src/features/transactions/data/transaction_repository.dart`,
`lib/src/features/transactions/data/recurring_repository.dart`,
`transaction_form_sheet.dart`, `transaction_detail_screen.dart`,
`lib/src/database/tables/recurring_rules_table.dart`,
`lib/src/database/tables/local_settings_table.dart`.

---

## Phase 3 — SMS Parsing ✅

Since bank-sync is deferred, this module is the app's **primary automated
transaction-capture path** — higher priority than the original doc implied.

**Verify/keep:** the regex parser (`sms_parser.dart`, 30+ bank formats,
confidence scoring) is solid, unchanged. The manual-paste SMS Sandbox stays
permanently as a dev/QA tool.

**Fixed:**
- The glue code turning an accepted parsed SMS into a real transaction
  turned out to already exist (wired during the Phase 1 Drift rewrite) —
  verified rather than assumed stale from the original doc.
- No real device SMS listener existed.

**Net-new (all done):**
1. Real device SMS integration via `another_telephony` (chosen over the
   abandoned `telephony` package and read-only `flutter_sms_inbox` — the
   only actively-maintained option supporting both inbox queries and a live
   listener): scans the inbox for bank/UPI-looking messages on app
   open/resume, listens live while foregrounded. True always-on background
   capture (app fully closed) deliberately not attempted — the package has
   no manifest-declared receiver and reliability is questionable given
   Android's broadcast restrictions since Android 8; scan-on-resume reliably
   catches up anything missed instead. **Decision confirmed with the user:**
   build real SMS capture despite the Play Store policy risk (READ_SMS is
   restricted to apps whose core function requires it) rather than fall
   back to a share-intent pattern or skip it.
2. Duplicate detection (`SmsDuplicateDetector`): the actual SRS composite
   key — exact ref/UPI ID match, or same amount+account+type same-day, or
   same amount within ±5 minutes (collapsing "bank SMS + UPI app SMS for
   the same transaction" into one prompt) — replacing the sandbox's
   previous same-amount-same-day-only check.
3. `SmsReviewSheet`: permission rationale card (on-device-only parsing,
   permanently-denied → Settings deep link, always offers manual entry),
   per-item Add/Skip, batch "Add All High-Confidence" (≥70% per the SRS,
   skips duplicates). Auto-opens on app foreground/resume once SMS
   detection is already enabled — first-time enabling is a deliberate
   profile-menu action, not an auto-prompt, given how sensitive the
   permission is.
4. Free-tier gate: 100 SMS-parses/month (`kFreeSmsParseLimit`) via a new
   `LocalSettings` counter (schema v4).
5. CSV import: skipped for now (optional per the original plan).

**New dependencies:** `another_telephony`, `permission_handler`.

**Incidental fixes:** a Gradle "Inconsistent JVM Target Compatibility"
build failure from `another_telephony`'s Kotlin target defaulting to 1.8
(fixed by forcing every non-`:app` subproject to JVM 17); a real gitignore
gap where the root `.gitignore`'s `/build/` never covered
`android/build/`/`android/app/build/`, which almost committed Gradle build
output; and a Drift correctness lesson caught by a regression test rather
than assumed — SQLite's `last_insert_rowid()` is unchanged by an ignored
`INSERT OR IGNORE`, so `insertSms` checks existence explicitly instead of
trusting the insert's return value.

---

## Phase 4 — Budgeting

**Done (client-side, this phase):**
- Redesigned the `budgets` schema: primary key moved from `category` alone
  to `(category, monthYear)`, and the stored `spentAmount` column was
  dropped entirely — every month now gets its own row (enabling real
  history), and spend is always derived live from the `transactions` table
  instead of a manually maintained running total that nothing kept in sync.
  Schema version 5, migration drops and recreates `budgets` (no installed
  base pre-launch, so no data to preserve).
- `BudgetRepository.getBudgets()` computes `spentAmount` per category by
  summing that month's non-income transactions on every read, and lazily
  carries the previous month's *limits* forward into a new month on first
  read (the client-side half of "budgets reset on the 1st" — spend starts
  at zero automatically since a new month has no transactions yet).
- Budget create/edit/delete UI: an "Add Budget" dialog (category picker
  restricted to spending categories not already budgeted this month +
  limit), tapping an envelope card opens an edit/delete dialog.
- Envelope Transfer dialog now shows an explicit warning when the source
  and destination categories are in different 50/30/20 buckets (SRS:
  "Cross-bucket transfer allowed but flagged with a warning").
- Progress-bar color thresholds (amber ≥80%, red ≥100%) — already correct,
  verified.
- Basic "Monthly History" view: a month picker sheet (via
  `getAvailableMonths()`) drilling into a read-only per-category breakdown
  for that month.

**Deferred (explicit decision: hold off on Blaze until more Cloud
Functions consumers — EMI auto-posting in Phase 6, price feeds in Phase 8,
AI tips in Phase 10 — are ready to justify standing up the infra together):**
1. Scaffold `functions/` (Node 20 + TypeScript) — would also be reused by
   Phase 6 (EMI posting), Phase 8 (price feeds), Phase 10 (AI tips).
2. Scheduled `resetMonthlyBudgets` function — not required for the core
   reset behavior (handled client-side above), but would still be the
   correct home for archiving/rollover enforcement that must run even if
   the user never opens the app on the 1st, plus consolidating Phase 2/3's
   client-side "reset on the 1st" counters (recurring transactions,
   SMS-parse quota) into one place.
3. FCM wiring for 80%/100% budget-threshold push notifications.

**New dependencies (client-side work only):** none — Firebase Messaging /
Cloud Functions dependencies are on hold pending the Blaze-plan decision
above.

---

## Phase 5 — Accounts & Cards

**Fix:** turned out there was no accounts UI at all, in either direction --
accounts could only be created by the demo seeder and selected (read-only)
from a dropdown when adding a transaction. No add/edit/detail screen, no
navigation entry point, existed anywhere in the app.

**Done:**
1. `AccountsListScreen` (entry points: a new "Accounts & Cards" drawer item,
   and tapping the dashboard's Net Worth card) -- lists all active accounts
   with balance, type, and credit-utilization bar for cards.
2. `AccountFormSheet` -- shared add/edit form (name, type, balance, and for
   credit cards, credit limit + due date + a color swatch picker).
3. `AccountDetailScreen` -- balance/utilization header, a due-date banner
   ("Due in N days" / "Overdue by N days", color-coded) for credit cards,
   and the account's linked transaction history (tap-through to the
   existing transaction detail screen).
4. Close-account flow implemented as a **soft delete** (`deletedAt` locally,
   a `closed` flag in Firestore), not a hard delete: the accounts→
   transactions/loans foreign key is `ON DELETE RESTRICT`, so a real delete
   would be rejected the moment any history references the account (which
   is effectively always). Closing instead just hides the account from
   active lists while every transaction that references it keeps resolving
   normally.
5. Free-tier gate: `kFreeAccountLimit = 3`, unlimited on Pro -- same
   `canAddX()` pattern already used for recurring transactions and SMS
   parses.
6. Added a nullable `owner_uids` column to `accounts` now (schema version
   6) for Phase 11's joint wallet, so that feature won't need its own
   migration later.

**Deferred:** a true OS-level scheduled push reminder for card due dates
(would need `flutter_local_notifications` + timezone-aware scheduling +
Android 13 notification permission) was scoped down to the in-app due-date
banner above -- that scheduling code isn't something I could verify
actually fires without a real device/emulator to advance the clock on, so
shipping it unverified felt worse than shipping the deterministic in-app
version and revisiting real push reminders alongside Phase 4's FCM work
once Cloud Functions are stood up.

---

## Phase 6 — Loans & EMI

**Fix -- the debt-math bug:** `debt_planner_sheet.dart` computed Snowball vs.
Avalanche interest with hardcoded fudge factors (`interest * 0.95` /
`* 0.98`) applied to the *same* per-loan simple-interest estimate, plus a
hardcoded "pays off 3 months faster" recommendation string -- so it always
declared the same winner by the same made-up margin regardless of the
user's actual loan mix. Also, like Accounts before Phase 5, there was no
loan add/edit UI anywhere -- only the demo seeder ever created a loan.

**Done:**
1. `AmortizationEngine` (`lib/src/features/debt/domain/amortization_engine.dart`,
   pure Dart, no Flutter/Riverpod dependency): the standard reducing-balance
   EMI formula, a full per-loan amortization schedule, `outstandingBalance()`
   that derives a loan's current principal live from (amount, rate, tenure,
   start date) instead of storing a running balance anywhere, and a genuine
   Snowball/Avalanche portfolio simulator. The simulator holds the combined
   EMI budget fixed and redirects a paid-off loan's freed EMI to whichever
   loan the strategy prioritizes next -- the mechanism that actually makes
   loan order affect total interest (paying loans independently with no
   redirection gives identical interest regardless of order, so a
   from-scratch model had to include this to be a real comparison at all).
   Covered by `test/amortization_engine_test.dart`, including a textbook
   reference-EMI check and a 3-loan scenario that verifies Snowball and
   Avalanche genuinely diverge (and agree when every loan shares one rate).
2. Debt Payoff Planner now shows each loan's real current outstanding
   balance (not the original principal), and the Snowball/Avalanche cards
   show real simulated total interest and months-to-debt-free with a
   dynamically computed recommendation -- no more hardcoded fudge factors
   or canned text.
3. Loan add/edit UI (`LoanFormSheet`): EMI auto-calculates from
   amount/rate/tenure via the new engine but can be manually overridden;
   tap a loan card to edit, long-press to delete.
4. Free-tier gate: `kFreeLoanLimit = 2`, unlimited on Pro. The Snowball/
   Avalanche comparison itself is Pro-only per the SRS -- free users still
   see their loan list and total debt, but get an upsell card instead of
   the simulation.

**Deferred:** EMI auto-posting via a scheduled Cloud Function -- same
Blaze-plan hold as Phase 4's scheduled reset; will be built alongside it
once Cloud Functions are worth standing up for multiple features at once.

---

## Phase 7 — Savings Goals *(zero code today — fully net-new)*

1. New `goals` table (name, target_amount, current_amount, target_date,
   icon/color, optional linked account).
2. Goal creation/edit UI, progress visualization, manual "contribute" action.
3. Celebration animation at 25/50/75/100% milestones.
4. Firestore sync via the established write-through pattern.
5. Free-tier gate: 3 goals (free) / unlimited (Pro).
6. Surface top 1–2 active goals on the dashboard.

**New dependencies:** a confetti/celebration package.

---

## Phase 8 — Investments

**Fix — the fake-feed bug:** `investments_tab.dart`'s "Update Feed" button
randomly jitters prices via `Random()` instead of fetching anything real.

**Net-new — real feeds via Cloud Functions:**
1. Scheduled `fetchMfNav`: downloads AMFI's free public `NAVAll.txt`.
2. Scheduled `fetchStockPrices` (market hours only) — concrete provider TBD
   (RapidAPI NSE wrapper vs. broker-partner API like Kite Connect).
3. Client reads from Firestore cache; "Update Feed" becomes a rate-limited
   on-demand refresh.
4. Portfolio P&L computation once real prices exist.
5. Investment add/edit form if missing.
6. Free-tier gate: entire module is Pro-only.

---

## Phase 9 — Analytics

**Fix:**
- CSV export hardcoded to a broken Windows dev path — replace with
  `path_provider` + `share_plus`.
- No date-range filtering at the analytics level.
- Inconsistent silent error states across the app — introduce one shared
  error/empty-state widget pattern here since Analytics reads from every
  other module.

**Net-new:**
1. Advanced Pro-tier charts (12+ per the docs) via `syncfusion_flutter_charts`
   — **flag:** confirm Community License eligibility first.
2. Full export suite: PDF + Excel for Pro, CSV stays free.
3. Net worth tracker (Pro-only).
4. Rule-based spending insight text as a baseline (AI version is Phase 10).

---

## Phase 10 — AI & Tips (Google Vertex AI / Gemini)

**Net-new (entire module):**
1. Cloud Function `generateFinancialTips` (Callable, App Check-protected):
   pulls recent Firestore data, calls Gemini via Firebase AI Logic, returns
   structured JSON tips.
2. Server-side rate limiting: 3 tips/week free, unlimited Pro.
3. Auto-categorization: rule-based free tier, Gemini-backed batch
   classification for Pro.
4. Coaching nudges via Phase 4's FCM infrastructure.
5. Client "Tips" feed on the dashboard.

**Flag:** set up Cloud Billing budget alerts alongside this phase.

---

## Phase 11 — Pro Features (multi-currency, joint wallet, OCR, monetization)

Bank-API sync explicitly **out of scope**.

1. **Receipt OCR (Pro-only):** `google_ml_kit` on-device text recognition →
   pre-filled transaction form for confirmation.
2. **Multi-currency (Pro-only):** activates the `currency` column from
   Phase 1; scheduled `fetchExchangeRates` function.
3. **Joint wallet (Pro-only, up to 5 members):** activates `owner_uids` from
   Phase 5; restructures Firestore paths into `sharedAccounts/{accountId}`.
4. **Monetization/billing:** `isPro` (stubbed since Phase 2) gets its real
   source of truth via `in_app_purchase` + server-side receipt validation.
5. Optional: CSV import if it slipped from Phase 3.
6. Optional/lowest priority: minimal ads for free tier.

---

## Phase 12 — Polish & Launch

**Fix:**
- Debug-only Android signing → real release keystore + signing config.
- No accessibility semantics anywhere — dedicated audit pass.
- Roll out Phase 9's shared error-state pattern everywhere.

**Net-new:**
1. Biometric app-lock with configurable idle-timeout auto-lock.
2. Extend AES-256-at-rest coverage; mask raw account numbers to last-4.
3. Firebase Analytics + Crashlytics + Performance Monitoring.
4. **Settings module (zero code today — fully net-new):** theme,
   currency/region, notification preferences, biometric toggle, budget
   reset-day picker, data export, account deletion, sign-out.
5. Full onboarding wizard per the SRS's 7-step flow.
6. Expand testing: amortization engine, repository tests against an
   in-memory Drift DB, widget tests, guest→Google migration regression test.
7. CI/CD hardening: build-and-sign, Firebase App Distribution, Play Store
   closed-track upload.
8. Beta testing, Play Store listing assets, Data Safety form.
9. Cost/rate-limit review of every Cloud Function before public launch.

---

## Phase Dependency Summary

- Phase 1 gates everything (git/CI, real Firebase, Drift schema, both
  critical bug fixes).
- Phase 1's schema decisions (`currency`, audit columns) are consumed by
  Phase 11; Phase 5's `owner_uids` column is consumed by Phase 11 — added
  early specifically to avoid a second migration later.
- Phase 4's Cloud Functions scaffold is reused by Phases 6, 8, 10, 11.
- Phase 2's `isPro` stub is read by Phases 5/6/7/8 before Phase 11 wires up
  the real billing system that sets it for real — intentional.
- Phases 6/8 (real amortization math, real price feeds) must precede
  Phase 10 — tips generated over fudge-factor debt math or jittered stock
  prices would be actively misleading.
- Phase 9 (shared error-state pattern) should land before Phase 12's final
  accessibility/polish pass.

## Remaining Open Decisions

1. Concrete stock-price data provider for Phase 8.
2. Concrete FX-rate provider for Phase 11's multi-currency.
3. Syncfusion Community License eligibility for Phase 9's advanced charts.
4. Whether to keep Mixpanel alongside Firebase Analytics in Phase 12 (drop
   recommended for solo-maintenance simplicity).
5. Whether CSV import (Phase 3, optional) is worth building now.

## Verification Strategy

- Every phase's CI run must pass before merging that phase's work.
- Manual verification: run the app on a real Android device/emulator after
  each phase and exercise its new screens directly.
- Before Phase 12's store submission: a full clean-install walkthrough of
  onboarding → guest mode → sign-in → core feature tour.
