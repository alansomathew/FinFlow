import 'db_service.dart';
import 'package:uuid/uuid.dart';

class DemoDataSeeder {
  static Future<void> seedData() async {
    final db = DbService.instance;
    await db.clearAllData();

    final uuid = const Uuid();

    // 1. Seed Accounts
    final hdfcId = uuid.v4();
    final sbiId = uuid.v4();
    final cashId = uuid.v4();
    final cardId = uuid.v4();

    await db.insertAccount({
      'id': hdfcId,
      'name': 'HDFC Salary Account',
      'type': 'bank',
      'balance': 54200.0,
      'credit_limit': 0.0,
      'card_due_date': '',
      'color_hex': '#1A56DB' // HDFC Blue
    });

    await db.insertAccount({
      'id': sbiId,
      'name': 'SBI Savings Account',
      'type': 'bank',
      'balance': 18500.0,
      'credit_limit': 0.0,
      'card_due_date': '',
      'color_hex': '#059669' // SBI Green
    });

    await db.insertAccount({
      'id': cashId,
      'name': 'Physical Cash',
      'type': 'cash',
      'balance': 3450.0,
      'credit_limit': 0.0,
      'card_due_date': '',
      'color_hex': '#7C3AED' // Cash Purple
    });

    await db.insertAccount({
      'id': cardId,
      'name': 'ICICI Coral Credit Card',
      'type': 'credit_card',
      'balance': -12450.0, // Outstanding balance
      'credit_limit': 150000.0,
      'card_due_date': '2026-06-15',
      'color_hex': '#D97706' // ICICI Orange
    });

    // 2. Seed Budgets for current month
    final currentMonth = '2026-05';
    final categoriesToSeed = [
      {'category': 'Rent', 'limit': 18000.0, 'spent': 18000.0},
      {'category': 'Groceries', 'limit': 8000.0, 'spent': 5400.0},
      {'category': 'Utilities', 'limit': 4000.0, 'spent': 3200.0},
      {'category': 'EMI', 'limit': 15000.0, 'spent': 14780.0},
      {'category': 'Dining Out', 'limit': 6000.0, 'spent': 5850.0},
      {'category': 'Shopping', 'limit': 10000.0, 'spent': 7200.0},
      {'category': 'Subscriptions', 'limit': 2000.0, 'spent': 1490.0},
      {'category': 'SIP', 'limit': 12000.0, 'spent': 10000.0},
      {'category': 'Stocks', 'limit': 6000.0, 'spent': 5000.0},
    ];

    for (var cat in categoriesToSeed) {
      await db.insertBudget({
        'category': cat['category'],
        'limit_amount': cat['limit'],
        'spent_amount': cat['spent'],
        'month_year': currentMonth,
      });
    }

    // 3. Seed Loans
    final loan1Id = uuid.v4();
    final loan2Id = uuid.v4();
    await db.insertLoan({
      'id': loan1Id,
      'lender_name': 'HDFC Bank',
      'loan_amount': 2500000.0,
      'interest_rate': 8.65,
      'tenure_months': 240,
      'start_date': '2025-01-10',
      'emi_amount': 21920.0,
      'debit_account_id': hdfcId,
    });

    await db.insertLoan({
      'id': loan2Id,
      'lender_name': 'SBI Finance',
      'loan_amount': 600000.0,
      'interest_rate': 9.2,
      'tenure_months': 60,
      'start_date': '2026-02-15',
      'emi_amount': 12518.0,
      'debit_account_id': sbiId,
    });

    // 4. Seed Investments
    await db.insertInvestment({
      'id': uuid.v4(),
      'type': 'SIP',
      'name': 'Parag Parikh Flexi Cap Fund',
      'units_quantity': 184.22,
      'purchase_price': 54.28,
      'current_price': 62.45,
      'date_purchased': '2026-05-05',
    });

    await db.insertInvestment({
      'id': uuid.v4(),
      'type': 'Mutual Fund',
      'name': 'Quant Small Cap Fund',
      'units_quantity': 112.5,
      'purchase_price': 178.40,
      'current_price': 195.20,
      'date_purchased': '2026-04-12',
    });

    await db.insertInvestment({
      'id': uuid.v4(),
      'type': 'Stock',
      'name': 'Reliance Industries Ltd.',
      'units_quantity': 15.0,
      'purchase_price': 2450.0,
      'current_price': 2865.0,
      'date_purchased': '2026-03-20',
    });

    await db.insertInvestment({
      'id': uuid.v4(),
      'type': 'Stock',
      'name': 'HDFC Bank Ltd.',
      'units_quantity': 25.0,
      'purchase_price': 1420.0,
      'current_price': 1512.0,
      'date_purchased': '2026-02-18',
    });

    // 5. Seed Transactions (over last 30 days)
    final now = DateTime.now();
    final List<Map<String, dynamic>> transactions = [
      {
        'id': uuid.v4(),
        'amount': 80000.0,
        'category': 'Salary',
        'bucket': 'Income',
        'account_id': hdfcId,
        'date': now.subtract(const Duration(days: 28)).toIso8601String(),
        'note': 'Monthly Salary Credit',
        'payee': 'TechCorp Solutions',
        'is_recurring': 1,
        'ref_id': 'TXN87624190823'
      },
      {
        'id': uuid.v4(),
        'amount': 18000.0,
        'category': 'Rent',
        'bucket': 'Needs',
        'account_id': hdfcId,
        'date': now.subtract(const Duration(days: 27)).toIso8601String(),
        'note': 'House Rent',
        'payee': 'Rajesh Sharma (Landlord)',
        'is_recurring': 1,
        'ref_id': 'TXN87652930291'
      },
      {
        'id': uuid.v4(),
        'amount': 10000.0,
        'category': 'SIP',
        'bucket': 'Savings',
        'account_id': hdfcId,
        'date': now.subtract(const Duration(days: 25)).toIso8601String(),
        'note': 'Monthly Mutual Fund SIP',
        'payee': 'Parag Parikh Mutual Fund',
        'is_recurring': 1,
        'ref_id': 'TXN87711200234'
      },
      {
        'id': uuid.v4(),
        'amount': 5400.0,
        'category': 'Groceries',
        'bucket': 'Needs',
        'account_id': hdfcId,
        'date': now.subtract(const Duration(days: 20)).toIso8601String(),
        'note': 'Monthly pantry restock',
        'payee': 'Reliance Smart Bazaar',
        'is_recurring': 0,
        'ref_id': 'TXN88927492048'
      },
      {
        'id': uuid.v4(),
        'amount': 3200.0,
        'category': 'Utilities',
        'bucket': 'Needs',
        'account_id': hdfcId,
        'date': now.subtract(const Duration(days: 15)).toIso8601String(),
        'note': 'Electricity Bill',
        'payee': 'State Electricity Board',
        'is_recurring': 1,
        'ref_id': 'TXN88290382902'
      },
      {
        'id': uuid.v4(),
        'amount': 14780.0,
        'category': 'EMI',
        'bucket': 'Needs',
        'account_id': hdfcId,
        'date': now.subtract(const Duration(days: 10)).toIso8601String(),
        'note': 'HDFC Home Loan EMI',
        'payee': 'HDFC Loan Dept',
        'is_recurring': 1,
        'ref_id': 'TXN89123891290'
      },
      {
        'id': uuid.v4(),
        'amount': 2400.0,
        'category': 'Dining Out',
        'bucket': 'Wants',
        'account_id': cardId,
        'date': now.subtract(const Duration(days: 8)).toIso8601String(),
        'note': 'Weekend dinner with family',
        'payee': 'Barbeque Nation',
        'is_recurring': 0,
        'ref_id': 'TXN91283908232'
      },
      {
        'id': uuid.v4(),
        'amount': 3450.0,
        'category': 'Dining Out',
        'bucket': 'Wants',
        'account_id': cardId,
        'date': now.subtract(const Duration(days: 5)).toIso8601String(),
        'note': 'Office party dinner',
        'payee': 'The Social Club',
        'is_recurring': 0,
        'ref_id': 'TXN92318029381'
      },
      {
        'id': uuid.v4(),
        'amount': 7200.0,
        'category': 'Shopping',
        'bucket': 'Wants',
        'account_id': cardId,
        'date': now.subtract(const Duration(days: 4)).toIso8601String(),
        'note': 'Summer clothing',
        'payee': 'Zara Store',
        'is_recurring': 0,
        'ref_id': 'TXN93489182390'
      },
      {
        'id': uuid.v4(),
        'amount': 1490.0,
        'category': 'Subscriptions',
        'bucket': 'Wants',
        'account_id': cardId,
        'date': now.subtract(const Duration(days: 2)).toIso8601String(),
        'note': 'Netflix & Spotify annual',
        'payee': 'Google Play Store Subscription',
        'is_recurring': 1,
        'ref_id': 'TXN95029302918'
      },
      {
        'id': uuid.v4(),
        'amount': 5000.0,
        'category': 'Stocks',
        'bucket': 'Savings',
        'account_id': hdfcId,
        'date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'note': 'Stock buy order',
        'payee': 'Zerodha Kite',
        'is_recurring': 0,
        'ref_id': 'TXN96029302932'
      }
    ];

    for (var tx in transactions) {
      await db.insertTransaction(tx);
    }

    // 6. Seed SMS alerts in simulated queue
    await db.insertSms({
      'id': uuid.v4(),
      'message_body': 'Alert: Rs 1,850.00 debited from HDFC A/c xx8712 to SWIGGY. Ref 61502939. Bal: Rs 52,350.00',
      'sender': 'AD-HDFCBK',
      'date': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'is_parsed': 0,
      'is_skipped': 0,
    });

    await db.insertSms({
      'id': uuid.v4(),
      'message_body': 'Dear Customer, SBI A/c xx5678 debited by Rs 500.00 via UPI to RAJESH STORES. Ref 61503120.',
      'sender': 'HP-SBIPG',
      'date': now.subtract(const Duration(hours: 3)).toIso8601String(),
      'is_parsed': 0,
      'is_skipped': 0,
    });

    await db.insertSms({
      'id': uuid.v4(),
      'message_body': 'ICICI Bank Card xx2001 debited by Rs 2,450.00 at AMAZON INDIA on 29-May-2026. Limit Avail: Rs 1,35,100.',
      'sender': 'AD-ICICIBK',
      'date': now.subtract(const Duration(days: 1)).toIso8601String(),
      'is_parsed': 0,
      'is_skipped': 0,
    });
  }
}
