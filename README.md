# FinFlow — Smart Personal Finance Manager

<div align="center">
  <img src="assets/logo/app_icon_512.png" width="128" height="128" alt="FinFlow Logo" />

  ### Modern, offline-first personal finance tracking, automated bank SMS parsing, and 50/30/20 budgeting for India.

  [![Flutter](https://img.shields.io/badge/Flutter-3.44.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.12.0-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
  [![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://developer.android.com/)
  [![Database](https://img.shields.io/badge/Database-Drift%20%7C%20SQLite-4169E1?logo=sqlite&logoColor=white)](https://drift.simonbinder.eu/)
  [![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
  [![CI](https://github.com/alansomathew/FinFlow/actions/workflows/ci.yaml/badge.svg)](https://github.com/alansomathew/FinFlow/actions)
  [![License](https://img.shields.io/badge/License-Proprietary-blue.svg)](#)
</div>

---

## 📌 Overview

**FinFlow** is an intelligent personal finance application designed for the Indian financial ecosystem. Built with Flutter, it bridges the gap between daily manual expense recording and automated account tracking by combining an on-device regex-based SMS parsing engine, a disciplined 50/30/20 budget framework, loan/EMI schedules, and investment portfolio tracking.

FinFlow is built **offline-first**: all core data lives in a high-performance local SQLite database powered by **Drift ORM**. Users can explore all features with zero friction in **Guest Mode**, with seamless, lossless data migration to **Firebase Cloud Firestore** whenever they choose to sign in.

---

## ✨ Key Features

### 🏠 1. Smart Home Dashboard & Net Worth
* **Unified Financial Hub**: Real-time snapshot of your total Net Worth, monthly expenses, budget health, and top spending categories.
* **50/30/20 Rule Breakdown**: Visual progress gauges categorizing monthly outflows into Needs (50%), Wants (30%), and Savings (20%).
* **AI Financial Coach**: Context-aware daily insights and actionable suggestions dynamically computed from spending habits.
* **Upcoming Bills & EMIs**: 7-day glance widget alerting on upcoming recurring commitments.

### 📨 2. On-Device Bank SMS & UPI Parsing Engine
* **Privacy-Preserving**: Runs 100% locally on-device without sharing financial messages with external servers.
* **35+ Indian Banks & Wallets**: Pre-configured parsing patterns for SBI, HDFC, ICICI, Axis, Kotak, PNB, BOB, YES Bank, IndusInd, Federal Bank, Paytm, PhonePe, Google Pay, and UPI handles.
* **Smart Duplicate Detection**: Multi-layer deduplication engine matching reference IDs, calendar days, transaction types, and a ±5-minute window for matching bank & UPI notifications.
* **SMS Review Inbox**: Dedicated inbox sheet to review, approve, or discard captured transactions before adding them to your books.

### 💳 3. Multi-Account & Card Management
* **Diverse Asset Types**: Track Savings accounts, Current accounts, Credit Cards, Digital Wallets (Paytm, Amazon Pay), and Cash.
* **Live Balance Recalculation**: Balances automatically adjust as transactions are added, edited, or deleted.
* **Credit Limit & Billing Cycles**: Track available credit limits and bill due dates.
* **Credit Card EMI Tracking**: Convert a card purchase into an EMI plan and see it reflected on the card itself — a monthly breakdown of regular card spend vs. active EMI installments, both on the account detail screen and as a compact summary in the accounts list.
* **Exact SMS Account Matching**: Optionally save an account's last 4 digits so incoming bank/card SMS alerts are matched to the *correct* account automatically instead of a best-effort guess — with an explicit account picker whenever a confident match isn't found.

### 📊 4. 50/30/20 Budgeting Rule Engine
* **Needs (50%)**: Rent, Groceries, Utilities, Healthcare, Transport, Education, and EMIs.
* **Wants (30%)**: Dining Out, Entertainment, Subscriptions, Shopping, Travel, and Hobbies.
* **Savings & Investments (20%)**: Emergency Funds, SIPs, Stocks, Gold, FDs, and Prepayments.
* **Category Limits**: Set monthly monetary limits per category with real-time warning thresholds (80% warning, 100% exceeded).
* **Salary-Based Planner**: Enter a monthly income figure to see each bucket's 50/30/20 target pool, then allocate real category limits against it — the app's suggested starting point whenever no budget exists yet for the month.
* **Custom Categories**: Create categories beyond the built-in presets with your own icon and color, right from the salary planner — they show up correctly (icon, color) everywhere else in the app from that point on.

### 📝 5. Comprehensive Transaction Manager
* **Fast Manual Entry**: Quick-action bottom sheet with category auto-suggestion and dedicated numeric keypad.
* **Recurring Transactions**: Daily, weekly, monthly, or yearly automated schedules with notifications.
* **Advanced Filters & Search**: Filter by date range, account, budget bucket, transaction type (Debit/Credit), and full-text keyword search.
* **PDF Statements**: Export styled transaction statements and share them directly via `share_plus` and `printing`.

### 🎯 6. Savings Goals & Milestones
* **Goal Tracker**: Create customized savings targets with target amounts, target dates, and emoji icons.
* **Milestone Progress**: Real-time progress bars calculating daily and monthly savings velocity.
* **Celebrations**: Integrated confetti particle animations upon reaching savings milestones.

### 📉 7. Loan & Debt Planner (EMI Manager)
* **Debt Repayment Strategies**: Compare **Snowball** (lowest balance first) and **Avalanche** (highest interest first) payoff strategies.
* **Amortization Calculators**: Calculate monthly EMIs, total interest payable, and principal breakdowns.

### 📈 8. Investment Portfolio
* **Asset Allocation**: Track Mutual Funds, Indian Equities (Stocks), Fixed Deposits (FD), Sovereign Gold / Digital Gold, PPF/EPF, and Real Estate.
* **Gain / Loss Tracking**: Monitor invested capital vs. current market valuation with profit & loss percentages.

### 🌐 9. Multi-Language Localization
* Comprehensive support for Indian regional languages:
  * 🇬🇧 English (`en`)
  * 🇮🇳 Hindi (`hi` - हिन्दी)
  * 🇮🇳 Tamil (`ta` - தமிழ்)
  * 🇮🇳 Kannada (`kn` - ಕನ್ನಡ)
  * 🇮🇳 Malayalam (`ml` - മലയാളം)
  * 🇮🇳 Marathi (`mr` - मराठी)
* Quick language switching directly in the user profile menu.

### 🌓 10. Theming & Design System
* **Dark-First Modern UI**: Bespoke dark theme with vibrant emerald/teal accents, subtle borders, and glassmorphism.
* **Dynamic Theme Switcher**: Toggle seamlessly between Dark Mode and Light Mode.
* **Typography**: Powered by Google Fonts (Poppins / Inter).

### 🔐 11. Account & Data Control
* **Guest Mode**: Explore every feature offline with zero sign-up, backed by rich seeded demo data.
* **One-Tap Cloud Upgrade**: The profile menu's "Upgrade to Cloud Sync" jumps straight into the Google sign-in prompt, with an optional guest-data migration dialog and a lossless local fallback if the cloud write ever fails.
* **Clear All Data**: Permanently wipe every account, transaction, budget, loan, investment, and goal — locally and in the cloud for signed-in users — behind an explicit destructive-action confirmation.

---

## 🏗️ Architecture & Technology Stack

FinFlow follows a modular, **feature-first clean architecture** ensuring high maintainability, testability, and separation of concerns.

```text
lib/
├── firebase_options.dart         # FlutterFire CLI generated configuration
├── main.dart                     # App entry point, ProviderScope initialization
└── src/
    ├── app.dart                  # MaterialApp.router, theme & localization setup
    ├── constants/                # AppColors, AppSizes, design tokens
    ├── database/                 # Drift SQLite database, tables, DAOs & migrations
    ├── features/                 # Modular feature domains
    │   ├── accounts/             # Account models, repositories, providers & UI
    │   ├── analytics/            # FL Chart analytics & category spending breakdowns
    │   ├── auth/                 # Google Sign-In, Email/Password & Guest migration
    │   ├── budget/               # 50/30/20 budget framework & category limits
    │   ├── dashboard/            # Home dashboard, AI coach & quick action cards
    │   ├── debt/                 # Loan/EMI calculators & repayment strategies
    │   ├── goals/                # Savings goals tracker & milestone celebrations
    │   ├── investments/          # Portfolio asset allocation & ROI tracking
    │   ├── sms/                  # Local SMS receiver, regex parser & duplicate detector
    │   └── transactions/         # Transaction CRUD, recurring jobs & PDF export
    ├── l10n/                     # ARB localization files (en, hi, ta, kn, ml, mr)
    ├── routing/                  # Declarative GoRouter configuration
    ├── services/                 # Firebase Cloud Firestore sync services
    ├── utils/                    # Currency formatting (₹), SMS regex engine, date utils
    └── widgets/                  # Reusable UI components & bottom sheet wrappers
```

### Core Technologies

| Layer | Technology | Description |
|---|---|---|
| **Framework** | [Flutter 3.44.0](https://flutter.dev/) | Cross-platform UI toolkit targeting Android (API 26+) |
| **Language** | [Dart 3.12.0](https://dart.dev/) | Null-safe, modern reactive programming |
| **State Management** | [Flutter Riverpod 2.5](https://riverpod.dev/) | Compile-safe, reactive state and dependency injection |
| **Local Database** | [Drift 2.23](https://drift.simonbinder.eu/) + [SQLite](https://sqlite.org/) | Type-safe SQL ORM with migrations, foreign keys, and indexes |
| **Cloud Backend** | [Firebase Core](https://firebase.google.com/) | Auth (Google & Email/Password), Cloud Firestore write-through sync |
| **Navigation** | [GoRouter 14.2](https://pub.dev/packages/go_router) | Declarative URL-based routing with deep-link support |
| **Charts & Visuals** | [FL Chart 0.66](https://pub.dev/packages/fl_chart) | Dynamic financial line, bar, and donut charts |
| **Telephony & Permissions** | [another_telephony](https://pub.dev/packages/another_telephony) | Android SMS inbox reading and permissions handling |
| **PDF & Sharing** | [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing) | Native document generation and statement sharing |

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the following tools installed on your development machine:
1. **Flutter SDK**: `^3.44.0` ([Installation Guide](https://docs.flutter.dev/get-started/install))
2. **Android SDK & Build Tools**: Android Studio with SDK Platform 34+ and Command-line Tools
3. **Java Development Kit**: OpenJDK 17 or 21 (bundled with modern Android Studio)
4. **Git**: Version control

Verify your environment:
```bash
flutter doctor -v
```

---

### Installation & Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/alansomathew/FinFlow.git
   cd FinFlow
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate Code & Database Schema**:
   Run `build_runner` to generate Drift database classes, tables, and models:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Firebase Configuration**:
   * FinFlow is configured with Firebase Authentication and Cloud Firestore.
   * Android configuration file: `android/app/google-services.json`
   * In case you wish to link your own Firebase project:
     ```bash
     flutterfire configure
     ```

5. **Generate Localization Files**:
   ```bash
   flutter gen-l10n
   ```

---

## 📱 Running the Application

### Connect an Android Device
Ensure USB Debugging is enabled on your Android device:
```bash
flutter devices
```

### Run in Debug Mode (with Hot Reload)
```bash
flutter run -d android
```
* Press **`r`** for Hot Reload.
* Press **`R`** for Hot Restart.
* Press **`q`** to quit.

### Build Production Release APK
```bash
flutter build apk --release
```
The compiled APK will be available at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🧪 Testing & Code Quality

FinFlow includes unit tests for the Drift local database, SMS parser regex engine, duplicate detection algorithms, and the amortization/EMI engine (reference EMI figures, schedule generation, Snowball vs. Avalanche payoff simulation).

```bash
# Run all unit and widget tests
flutter test

# Verify code formatting
dart format --output=none --set-exit-if-changed .

# Static analysis
flutter analyze
```

---

## 🔄 CI/CD Pipeline

Continuous Integration is automated using **GitHub Actions** (`.github/workflows/ci.yaml`):
1. **Analyze & Test**:
   * Checks code formatting with `dart format`.
   * Lints code using `flutter analyze`.
   * Executes test suite via `flutter test`.
2. **Build Debug APK**:
   * Assembles `app-debug.apk` to verify build integrity on every push to `main` and `master`.

---

## 🗺️ Project Roadmap

| Phase | Milestone | Status |
|:---:|---|:---:|
| **1** | **Foundation & Auth**: Drift migration, real Firebase Auth (Google & Email), Guest Mode migration bugfix | ✅ Complete |
| **2** | **Core Transactions**: Edit flow, detail screens, date-range filters, recurring schedules | ✅ Complete |
| **3** | **SMS Parsing Engine**: 35+ Bank regexes, duplicate detection algorithm, permission handlers, exact account matching via saved card digits | ✅ Complete |
| **4** | **Budgeting Module**: 50/30/20 budget allocations, category thresholds, budget progress | ✅ Complete |
| **5** | **Accounts & Cards**: Bank accounts, credit cards, wallet balances, balance audit | ✅ Complete |
| **6** | **Loans & EMI**: Snowball & Avalanche debt repayment planner, amortization calculations | ✅ Complete |
| **7** | **Savings Goals**: Milestone progress, daily/monthly velocity, celebration animations | ✅ Complete |
| **8** | **Investments**: Portfolio allocation, asset tracking, profit/loss calculations | ✅ Complete |
| **9** | **Analytics & Reports**: FL Chart visualizations, spending breakdowns, PDF export | ✅ Complete |
| **10** | **AI Financial Insights**: Gemini API / Vertex AI integration for smart spending tips | ⏳ Planned |
| **11** | **Pro Features**: Receipt OCR scanning with ML Kit, unlimited recurring schedules | ⏳ Planned |
| **12** | **Polish & Play Store Launch**: App bundle signing, Play Store listing & release | ⏳ Planned |

In addition to the 12 numbered phases, a number of features landed as direct
ad-hoc requests between phases: dark/light theming, multi-language support,
the salary-based budget planner, custom categories, credit card EMI
tracking, and exact SMS-to-account matching among them. See
[`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md) for the full,
detailed engineering log of everything built, fixed, and deliberately
deferred — this README stays at the feature-overview level.

---

## 🤝 Collaboration Manual

We welcome contributions and collaborative development on FinFlow! To maintain code quality, architecture consistency, and smooth code reviews, please follow this collaboration manual.

### 1. Branching Strategy & Workflow

1. **Branching Model**:
   * All active development branches diverge from and merge back into `master`.
   * Keep your local `master` branch up to date:
     ```bash
     git checkout master
     git pull origin master
     ```
   * Create a descriptive topic branch:
     ```bash
     git checkout -b <type>/<short-description>
     ```
   * **Branch Naming Conventions**:
     * `feat/<feature-name>`: Net-new capabilities or enhancements (e.g. `feat/sms-upi-filters`)
     * `fix/<bug-description>`: Bug fixes (e.g. `fix/balance-negative-overflow`)
     * `refactor/<scope>`: Code refactoring without behavioral changes (e.g. `refactor/drift-daos`)
     * `docs/<topic>`: Documentation and manuals (e.g. `docs/collaboration-guide`)
     * `test/<scope>`: Adding or fixing test suites (e.g. `test/duplicate-detector`)

2. **Code Generation & Drift DB Changes**:
   * If you introduce or modify Drift tables (`lib/src/database/tables/`) or add code-generated dependencies:
     ```bash
     flutter pub get
     dart run build_runner build --delete-conflicting-outputs
     ```
   * Commit both the table definitions and the generated files (`.g.dart`) together.
   * Add database migration logic to `lib/src/database/app_database.dart` whenever schema version increments.

### 2. Coding & Architectural Standards

* **Feature-First Organization**: Group all code by feature under `lib/src/features/<feature>/` split across:
  * `data/`: Repositories, local database DAOs, remote API/Firestore services.
  * `domain/`: Pure Dart business models, validation entities, value objects.
  * `presentation/`: Riverpod providers, UI screens, widgets, and dialog sheets.
* **State Management**:
  * Use **Flutter Riverpod** (`StateNotifierProvider` / `NotifierProvider` / `FutureProvider`).
  * Avoid storing business logic inside StatefulWidget state.
* **Localization & Strings**:
  * Never hardcode user-facing strings in UI widgets.
  * Add all new text strings to `lib/l10n/app_en.arb` and generate classes via `flutter gen-l10n`.
* **Theme Compliance**:
  * Use `Theme.of(context)` and semantic colors (`colors.surface`, `colors.textPrimary`, `colors.primary`) to ensure dark/light mode compatibility.

### 3. Commit Message Guidelines

We enforce the **Conventional Commits** specification:

```text
<type>(<scope>): <concise description in imperative mood>

[optional body explaining context and rationale]

[optional footer(s), e.g., Closes #24]
```

#### Commit Types:
* `feat`: A new user-facing feature.
* `fix`: A bug fix.
* `docs`: Documentation updates.
* `style`: Code formatting, semicolons, whitespace (no functional changes).
* `refactor`: Restructuring code without changing behavior or fixing bugs.
* `perf`: Performance optimizations.
* `test`: Adding or updating test cases.
* `chore`: Dependency updates, tooling, CI workflows, gradle adjustments.

#### Examples:
```bash
git commit -m "feat(budget): add rollover surplus toggle for category limits"
git commit -m "fix(sms): resolve race condition in insertOrIgnore row ID check"
git commit -m "docs: add collaboration manual to README"
```

### 4. Local Quality Assurance (Pre-PR Checklist)

Every pull request must pass the automated CI suite. Before pushing your branch, run the local verification pipeline:

```bash
# 1. Check code formatting (fails if any file needs reformatting)
dart format --output=none --set-exit-if-changed .

# 2. Run static analyzer (must report zero errors and zero warnings)
flutter analyze

# 3. Run all unit and widget tests
flutter test
```

### 5. Pull Request (PR) & Code Review Process

1. **Create Focused PRs**: Keep PRs focused on a single responsibility to enable swift reviews.
2. **PR Description**:
   * **Context**: Explain the problem or feature objective.
   * **Implementation**: Summarize the changes made.
   * **Testing**: Detail steps taken to verify correctness (include test results).
   * **Screenshots / Recordings**: Required for any UI modifications (both Dark & Light modes).
3. **CI Validation**: Ensure all GitHub Actions checks (`analyze-and-test`, `build-debug-apk`) are green.
4. **Peer Review**: At least one maintainer approval is required before merging into `master`.

---

## 📄 License & Author

* **Author**: Alanso Mathew ([@alansomathew](https://github.com/alansomathew))
* **Project**: FinFlow — Smart Personal Finance Manager
* **License**: Private / Proprietary (All rights reserved).

