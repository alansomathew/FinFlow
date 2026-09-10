import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

class DemoDataSeeder {
  static Future<void> seedData() async {
    final db = AppDatabase.instance;
    await db.clearAllData();
    await db.transaction(() async {
      final uuid = const Uuid();

      // 1. Seed Accounts
      final hdfcId = uuid.v4();
      final sbiId = uuid.v4();
      final cashId = uuid.v4();
      final cardId = uuid.v4();

      await db.into(db.accounts).insert(AccountsCompanion.insert(
            id: hdfcId,
            name: 'HDFC Salary Account',
            type: 'bank',
            balance: 54200.0,
            creditLimit: const Value(0.0),
            cardDueDate: const Value(''),
            colorHex: '#1A56DB', // HDFC Blue
          ));

      await db.into(db.accounts).insert(AccountsCompanion.insert(
            id: sbiId,
            name: 'SBI Savings Account',
            type: 'bank',
            balance: 18500.0,
            creditLimit: const Value(0.0),
            cardDueDate: const Value(''),
            colorHex: '#059669', // SBI Green
          ));

      await db.into(db.accounts).insert(AccountsCompanion.insert(
            id: cashId,
            name: 'Physical Cash',
            type: 'cash',
            balance: 3450.0,
            creditLimit: const Value(0.0),
            cardDueDate: const Value(''),
            colorHex: '#7C3AED', // Cash Purple
          ));

      await db.into(db.accounts).insert(AccountsCompanion.insert(
            id: cardId,
            name: 'ICICI Coral Credit Card',
            type: 'credit_card',
            balance: -12450.0, // Outstanding balance
            creditLimit: const Value(150000.0),
            cardDueDate: const Value('2026-06-15'),
            colorHex: '#D97706', // ICICI Orange
          ));

      // 2. Seed Budgets for current month
      const currentMonth = '2026-05';
      final categoriesToSeed = [
        ('Rent', 18000.0, 18000.0),
        ('Groceries', 8000.0, 5400.0),
        ('Utilities', 4000.0, 3200.0),
        ('EMI', 15000.0, 14780.0),
        ('Dining Out', 6000.0, 5850.0),
        ('Shopping', 10000.0, 7200.0),
        ('Subscriptions', 2000.0, 1490.0),
        ('SIP', 12000.0, 10000.0),
        ('Stocks', 6000.0, 5000.0),
      ];

      for (final (category, limit, spent) in categoriesToSeed) {
        await db.into(db.budgets).insert(BudgetsCompanion.insert(
              category: category,
              limitAmount: limit,
              spentAmount: spent,
              monthYear: currentMonth,
            ));
      }

      // 3. Seed Loans
      await db.into(db.loans).insert(LoansCompanion.insert(
            id: uuid.v4(),
            lenderName: 'HDFC Bank',
            loanAmount: 2500000.0,
            interestRate: 8.65,
            tenureMonths: 240,
            startDate: '2025-01-10',
            emiAmount: 21920.0,
            debitAccountId: hdfcId,
          ));

      await db.into(db.loans).insert(LoansCompanion.insert(
            id: uuid.v4(),
            lenderName: 'SBI Finance',
            loanAmount: 600000.0,
            interestRate: 9.2,
            tenureMonths: 60,
            startDate: '2026-02-15',
            emiAmount: 12518.0,
            debitAccountId: sbiId,
          ));

      // 4. Seed Investments
      await db.into(db.investments).insert(InvestmentsCompanion.insert(
            id: uuid.v4(),
            type: 'SIP',
            name: 'Parag Parikh Flexi Cap Fund',
            unitsQuantity: 184.22,
            purchasePrice: 54.28,
            currentPrice: 62.45,
            datePurchased: '2026-05-05',
          ));

      await db.into(db.investments).insert(InvestmentsCompanion.insert(
            id: uuid.v4(),
            type: 'Mutual Fund',
            name: 'Quant Small Cap Fund',
            unitsQuantity: 112.5,
            purchasePrice: 178.40,
            currentPrice: 195.20,
            datePurchased: '2026-04-12',
          ));

      await db.into(db.investments).insert(InvestmentsCompanion.insert(
            id: uuid.v4(),
            type: 'Stock',
            name: 'Reliance Industries Ltd.',
            unitsQuantity: 15.0,
            purchasePrice: 2450.0,
            currentPrice: 2865.0,
            datePurchased: '2026-03-20',
          ));

      await db.into(db.investments).insert(InvestmentsCompanion.insert(
            id: uuid.v4(),
            type: 'Stock',
            name: 'HDFC Bank Ltd.',
            unitsQuantity: 25.0,
            purchasePrice: 1420.0,
            currentPrice: 1512.0,
            datePurchased: '2026-02-18',
          ));

      // 5. Seed Transactions (over last 30 days)
      final now = DateTime.now();
      final transactions = [
        (80000.0, 'Salary', 'Income', hdfcId, 28, 'Monthly Salary Credit', 'TechCorp Solutions', true, 'TXN87624190823'),
        (18000.0, 'Rent', 'Needs', hdfcId, 27, 'House Rent', 'Rajesh Sharma (Landlord)', true, 'TXN87652930291'),
        (10000.0, 'SIP', 'Savings', hdfcId, 25, 'Monthly Mutual Fund SIP', 'Parag Parikh Mutual Fund', true, 'TXN87711200234'),
        (5400.0, 'Groceries', 'Needs', hdfcId, 20, 'Monthly pantry restock', 'Reliance Smart Bazaar', false, 'TXN88927492048'),
        (3200.0, 'Utilities', 'Needs', hdfcId, 15, 'Electricity Bill', 'State Electricity Board', true, 'TXN88290382902'),
        (14780.0, 'EMI', 'Needs', hdfcId, 10, 'HDFC Home Loan EMI', 'HDFC Loan Dept', true, 'TXN89123891290'),
        (2400.0, 'Dining Out', 'Wants', cardId, 8, 'Weekend dinner with family', 'Barbeque Nation', false, 'TXN91283908232'),
        (3450.0, 'Dining Out', 'Wants', cardId, 5, 'Office party dinner', 'The Social Club', false, 'TXN92318029381'),
        (7200.0, 'Shopping', 'Wants', cardId, 4, 'Summer clothing', 'Zara Store', false, 'TXN93489182390'),
        (1490.0, 'Subscriptions', 'Wants', cardId, 2, 'Netflix & Spotify annual', 'Google Play Store Subscription', true, 'TXN95029302918'),
        (5000.0, 'Stocks', 'Savings', hdfcId, 1, 'Stock buy order', 'Zerodha Kite', false, 'TXN96029302932'),
      ];

      for (final (amount, category, bucket, accountId, daysAgo, note, payee, isRecurring, refId) in transactions) {
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
              id: uuid.v4(),
              amount: amount,
              category: category,
              bucket: bucket,
              accountId: accountId,
              date: now.subtract(Duration(days: daysAgo)),
              note: Value(note),
              payee: payee,
              isRecurring: Value(isRecurring),
              refId: Value(refId),
            ));
      }

      // 6. Seed SMS alerts in simulated queue
      await db.into(db.smsInbox).insert(SmsInboxCompanion.insert(
            id: uuid.v4(),
            messageBody: 'Alert: Rs 1,850.00 debited from HDFC A/c xx8712 to SWIGGY. Ref 61502939. Bal: Rs 52,350.00',
            sender: 'AD-HDFCBK',
            date: now.subtract(const Duration(hours: 1)),
          ));

      await db.into(db.smsInbox).insert(SmsInboxCompanion.insert(
            id: uuid.v4(),
            messageBody: 'Dear Customer, SBI A/c xx5678 debited by Rs 500.00 via UPI to RAJESH STORES. Ref 61503120.',
            sender: 'HP-SBIPG',
            date: now.subtract(const Duration(hours: 3)),
          ));

      await db.into(db.smsInbox).insert(SmsInboxCompanion.insert(
            id: uuid.v4(),
            messageBody: 'ICICI Bank Card xx2001 debited by Rs 2,450.00 at AMAZON INDIA on 29-May-2026. Limit Avail: Rs 1,35,100.',
            sender: 'AD-ICICIBK',
            date: now.subtract(const Duration(days: 1)),
          ));
    });
  }
}
