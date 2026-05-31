import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/investment_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/local/local_database.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

CollectionReference<Map<String, dynamic>> _sipCol() =>
    FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colSips);

CollectionReference<Map<String, dynamic>> _stockCol() =>
    FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colStocks);

final _localDb = LocalDatabase.instance;

// ── SIP Providers ──────────────────────────────────────────────────────────
final sipsStreamProvider = StreamProvider<List<SipModel>>((ref) async* {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final rows = await _localDb.getAll('investments');
    yield rows
        .map(SipModel.fromLocalMap)
        .where((s) => s.isActive)
        .toList();
    return;
  }
  yield* _sipCol()
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => SipModel.fromFirestore(d)).toList());
});

// ── Stock Providers ────────────────────────────────────────────────────────
// Stocks share the 'investments' table with a discriminator field when local
final stocksStreamProvider = StreamProvider<List<StockModel>>((ref) async* {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    // Stocks don't have a local table in the base schema; yield empty for guests
    yield const [];
    return;
  }
  yield* _stockCol()
      .snapshots()
      .map((s) => s.docs.map((d) => StockModel.fromFirestore(d)).toList());
});

// ── Portfolio Summary ──────────────────────────────────────────────────────
class PortfolioSummary {
  final double totalInvested;
  final double currentValue;
  final double sipValue;
  final double stockValue;

  const PortfolioSummary({
    required this.totalInvested,
    required this.currentValue,
    required this.sipValue,
    required this.stockValue,
  });

  double get absoluteReturn => currentValue - totalInvested;
  double get returnPercent =>
      totalInvested > 0 ? (absoluteReturn / totalInvested * 100) : 0;
}

final portfolioSummaryProvider =
    Provider<AsyncValue<PortfolioSummary>>((ref) {
  final sips = ref.watch(sipsStreamProvider);
  final stocks = ref.watch(stocksStreamProvider);

  if (sips.isLoading || stocks.isLoading) {
    return const AsyncValue.loading();
  }
  if (sips.hasError) return AsyncValue.error(sips.error!, sips.stackTrace!);
  if (stocks.hasError) {
    return AsyncValue.error(stocks.error!, stocks.stackTrace!);
  }

  final sipList = sips.value ?? [];
  final stockList = stocks.value ?? [];

  double sipInvested = sipList.fold(0.0, (s, i) => s + i.totalInvested);
  double sipValue = sipList.fold(0.0, (s, i) => s + i.currentValue);
  double stockInvested =
      stockList.fold(0.0, (s, i) => s + i.investedAmount);
  double stockValue =
      stockList.fold(0.0, (s, i) => s + i.currentValue);

  return AsyncValue.data(PortfolioSummary(
    totalInvested: sipInvested + stockInvested,
    currentValue: sipValue + stockValue,
    sipValue: sipValue,
    stockValue: stockValue,
  ));
});

// ── Investment Notifier ────────────────────────────────────────────────────
class InvestmentNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  InvestmentNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addSip(SipModel sip) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final isGuest = _ref.read(guestSessionProvider);
      final newSip = SipModel(
        id: id,
        userId: isGuest ? 'guest' : _uid,
        accountId: sip.accountId,
        categoryId: sip.categoryId,
        fundName: sip.fundName,
        amc: sip.amc,
        sipAmount: sip.sipAmount,
        frequency: sip.frequency,
        startDate: sip.startDate,
        stepUpPercent: sip.stepUpPercent,
      );
      if (isGuest) {
        await _localDb.upsert('investments', id, newSip.toLocalMap());
      } else {
        await _sipCol().doc(id).set(newSip.toFirestore());
      }
      _ref.invalidate(sipsStreamProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addStock(StockModel stock) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final isGuest = _ref.read(guestSessionProvider);
      final newStock = StockModel(
        id: id,
        userId: isGuest ? 'guest' : _uid,
        accountId: stock.accountId,
        categoryId: stock.categoryId,
        tickerSymbol: stock.tickerSymbol,
        companyName: stock.companyName,
        exchange: stock.exchange,
        quantity: stock.quantity,
        purchasePrice: stock.purchasePrice,
        currentPrice: stock.currentPrice,
        purchaseDate: stock.purchaseDate,
        sector: stock.sector,
      );
      if (isGuest) {
        // Stocks are not stored locally in guest mode (no table defined)
        // Silently succeed so UI doesn't break
      } else {
        await _stockCol().doc(id).set(newStock.toFirestore());
      }
      _ref.invalidate(stocksStreamProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updateStockPrice(String stockId, double newPrice) async {
    final isGuest = _ref.read(guestSessionProvider);
    if (!isGuest) {
      await _stockCol().doc(stockId).update({'currentPrice': newPrice});
    }
    _ref.invalidate(stocksStreamProvider);
  }

  Future<void> stopSip(String sipId) async {
    final isGuest = _ref.read(guestSessionProvider);
    if (isGuest) {
      await _localDb.update('investments', sipId, {'isActive': 0});
    } else {
      await _sipCol().doc(sipId).update({'isActive': false});
    }
    _ref.invalidate(sipsStreamProvider);
  }
}

final investmentNotifierProvider =
    StateNotifierProvider<InvestmentNotifier, AsyncValue<void>>(
  (ref) => InvestmentNotifier(ref),
);
