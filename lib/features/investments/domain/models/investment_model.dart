import 'package:cloud_firestore/cloud_firestore.dart';

enum InvestmentType { sip, mutualFund, stock, fd, gold }

class SipModel {
  final String id;
  final String userId;
  final String accountId;
  final String categoryId;
  final String fundName;
  final String amc;
  final double sipAmount;
  final String frequency; // monthly, weekly, quarterly
  final DateTime startDate;
  final double totalInvested;
  final double currentValue;
  final double? stepUpPercent;
  final bool isActive;
  final DateTime? nextSipDate;

  const SipModel({
    required this.id,
    required this.userId,
    this.accountId = '',
    this.categoryId = 'investment',
    required this.fundName,
    required this.amc,
    required this.sipAmount,
    this.frequency = 'monthly',
    required this.startDate,
    this.totalInvested = 0,
    this.currentValue = 0,
    this.stepUpPercent,
    this.isActive = true,
    this.nextSipDate,
  });

  double get absoluteReturn => currentValue - totalInvested;
  double get returnPercent =>
      totalInvested > 0 ? (absoluteReturn / totalInvested * 100) : 0;

  factory SipModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SipModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      accountId: d['accountId'] ?? '',
      categoryId: d['categoryId'] ?? 'investment',
      fundName: d['fundName'] ?? '',
      amc: d['amc'] ?? '',
      sipAmount: (d['sipAmount'] as num).toDouble(),
      frequency: d['frequency'] ?? 'monthly',
      startDate: (d['startDate'] as Timestamp).toDate(),
      totalInvested: (d['totalInvested'] as num?)?.toDouble() ?? 0,
      currentValue: (d['currentValue'] as num?)?.toDouble() ?? 0,
      stepUpPercent: (d['stepUpPercent'] as num?)?.toDouble(),
      isActive: d['isActive'] ?? true,
      nextSipDate: (d['nextSipDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'accountId': accountId,
        'categoryId': categoryId,
        'fundName': fundName,
        'amc': amc,
        'sipAmount': sipAmount,
        'frequency': frequency,
        'startDate': Timestamp.fromDate(startDate),
        'totalInvested': totalInvested,
        'currentValue': currentValue,
        'stepUpPercent': stepUpPercent,
        'isActive': isActive,
        'nextSipDate':
            nextSipDate != null ? Timestamp.fromDate(nextSipDate!) : null,
      };

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'userId': userId,
        'accountId': accountId,
        'categoryId': categoryId,
        'fundName': fundName,
        'amc': amc,
        'sipAmount': sipAmount,
        'frequency': frequency,
        'startDate': startDate.toIso8601String(),
        'totalInvested': totalInvested,
        'currentValue': currentValue,
        'stepUpPercent': stepUpPercent,
        'isActive': isActive ? 1 : 0,
        'nextSipDate': nextSipDate?.toIso8601String(),
      };

  factory SipModel.fromLocalMap(Map<String, dynamic> d) => SipModel(
        id: d['id'] as String,
        userId: d['userId'] as String? ?? '',
        accountId: d['accountId'] as String? ?? '',
        categoryId: d['categoryId'] as String? ?? 'investment',
        fundName: d['fundName'] as String,
        amc: d['amc'] as String? ?? '',
        sipAmount: (d['sipAmount'] as num).toDouble(),
        frequency: d['frequency'] as String? ?? 'monthly',
        startDate: DateTime.parse(d['startDate'] as String),
        totalInvested: (d['totalInvested'] as num?)?.toDouble() ?? 0,
        currentValue: (d['currentValue'] as num?)?.toDouble() ?? 0,
        stepUpPercent: (d['stepUpPercent'] as num?)?.toDouble(),
        isActive: (d['isActive'] == 1 || d['isActive'] == true),
        nextSipDate: d['nextSipDate'] != null
            ? DateTime.parse(d['nextSipDate'] as String)
            : null,
      );
}

class MutualFundModel {
  final String id;
  final String userId;
  final String fundName;
  final String amc;
  final String isinCode;
  final double units;
  final double purchaseNav;
  final double currentNav;
  final DateTime purchaseDate;
  final String fundCategory; // Equity, Debt, Hybrid, ELSS, International

  const MutualFundModel({
    required this.id,
    required this.userId,
    required this.fundName,
    required this.amc,
    this.isinCode = '',
    required this.units,
    required this.purchaseNav,
    required this.currentNav,
    required this.purchaseDate,
    this.fundCategory = 'Equity',
  });

  double get investedAmount => units * purchaseNav;
  double get currentValue => units * currentNav;
  double get absoluteReturn => currentValue - investedAmount;
  double get returnPercent =>
      investedAmount > 0 ? (absoluteReturn / investedAmount * 100) : 0;

  bool get isLtcg {
    final now = DateTime.now();
    return now.difference(purchaseDate).inDays > 365;
  }

  factory MutualFundModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MutualFundModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      fundName: d['fundName'] ?? '',
      amc: d['amc'] ?? '',
      isinCode: d['isinCode'] ?? '',
      units: (d['units'] as num).toDouble(),
      purchaseNav: (d['purchaseNav'] as num).toDouble(),
      currentNav: (d['currentNav'] as num?)?.toDouble() ?? 0,
      purchaseDate: (d['purchaseDate'] as Timestamp).toDate(),
      fundCategory: d['fundCategory'] ?? 'Equity',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'fundName': fundName,
        'amc': amc,
        'isinCode': isinCode,
        'units': units,
        'purchaseNav': purchaseNav,
        'currentNav': currentNav,
        'purchaseDate': Timestamp.fromDate(purchaseDate),
        'fundCategory': fundCategory,
      };
}

class StockModel {
  final String id;
  final String userId;
  final String accountId;
  final String categoryId;
  final String tickerSymbol;
  final String companyName;
  final String exchange; // NSE, BSE
  final int quantity;
  final double purchasePrice;
  final double currentPrice;
  final DateTime purchaseDate;
  final String sector;

  const StockModel({
    required this.id,
    required this.userId,
    this.accountId = '',
    this.categoryId = 'investment',
    required this.tickerSymbol,
    required this.companyName,
    this.exchange = 'NSE',
    required this.quantity,
    required this.purchasePrice,
    required this.currentPrice,
    required this.purchaseDate,
    this.sector = 'Other',
  });

  double get investedAmount => quantity * purchasePrice;
  double get currentValue => quantity * currentPrice;
  double get absoluteReturn => currentValue - investedAmount;
  double get returnPercent =>
      investedAmount > 0 ? (absoluteReturn / investedAmount * 100) : 0;
  bool get isProfit => absoluteReturn >= 0;

  bool get isLtcg =>
      DateTime.now().difference(purchaseDate).inDays > 365;

  factory StockModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StockModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      accountId: d['accountId'] ?? '',
      categoryId: d['categoryId'] ?? 'investment',
      tickerSymbol: d['tickerSymbol'] ?? '',
      companyName: d['companyName'] ?? '',
      exchange: d['exchange'] ?? 'NSE',
      quantity: d['quantity'] as int,
      purchasePrice: (d['purchasePrice'] as num).toDouble(),
      currentPrice: (d['currentPrice'] as num?)?.toDouble() ?? 0,
      purchaseDate: (d['purchaseDate'] as Timestamp).toDate(),
      sector: d['sector'] ?? 'Other',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'accountId': accountId,
        'categoryId': categoryId,
        'tickerSymbol': tickerSymbol,
        'companyName': companyName,
        'exchange': exchange,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'currentPrice': currentPrice,
        'purchaseDate': Timestamp.fromDate(purchaseDate),
        'sector': sector,
      };

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'userId': userId,
        'accountId': accountId,
        'categoryId': categoryId,
        'tickerSymbol': tickerSymbol,
        'companyName': companyName,
        'exchange': exchange,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'currentPrice': currentPrice,
        'purchaseDate': purchaseDate.toIso8601String(),
        'sector': sector,
      };

  factory StockModel.fromLocalMap(Map<String, dynamic> d) => StockModel(
        id: d['id'] as String,
        userId: d['userId'] as String? ?? '',
        accountId: d['accountId'] as String? ?? '',
        categoryId: d['categoryId'] as String? ?? 'investment',
        tickerSymbol: d['tickerSymbol'] as String,
        companyName: d['companyName'] as String? ?? '',
        exchange: d['exchange'] as String? ?? 'NSE',
        quantity: d['quantity'] as int,
        purchasePrice: (d['purchasePrice'] as num).toDouble(),
        currentPrice: (d['currentPrice'] as num?)?.toDouble() ?? 0,
        purchaseDate: DateTime.parse(d['purchaseDate'] as String),
        sector: d['sector'] as String? ?? 'Other',
      );
}
