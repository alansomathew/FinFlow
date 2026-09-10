import 'package:another_telephony/telephony.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_repository.dart';

/// Bridges the device's real SMS inbox into the app's sms_inbox staging
/// table. Only messages that look like bank/UPI transaction alerts are
/// staged, to avoid flooding the review queue with unrelated texts.
///
/// True always-on background capture (app fully closed) is not attempted
/// here: another_telephony's background-isolate support has no
/// manifest-declared receiver of its own, and reliability varies across
/// Android versions/OEMs given the platform's broadcast restrictions since
/// Android 8. Instead, this scans the inbox fresh on every app open/resume
/// (reliably catches up anything missed) and additionally listens live
/// while the app is in the foreground.
class SmsDeviceService {
  final Ref _ref;
  SmsDeviceService(this._ref);

  final Telephony _telephony = Telephony.instance;
  bool _listening = false;

  Future<bool> hasPermission() async {
    return (await Permission.sms.status).isGranted;
  }

  Future<bool> isPermanentlyDenied() async {
    return (await Permission.sms.status).isPermanentlyDenied;
  }

  Future<PermissionStatus> requestPermission() {
    return Permission.sms.request();
  }

  /// Scans the inbox for bank/UPI-looking messages from the last [lookback]
  /// and stages any not already staged (by the OS's own row id, so
  /// re-scanning never double-stages the same physical message). Returns how
  /// many were newly staged.
  Future<int> scanInbox({Duration lookback = const Duration(days: 14)}) async {
    if (!await hasPermission()) return 0;

    final cutoff = DateTime.now().subtract(lookback);
    final messages = await _telephony.getInboxSms(
      columns: [
        SmsColumn.ID,
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    var staged = 0;
    for (final message in messages) {
      final date = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : null;
      if (date == null || date.isBefore(cutoff)) continue;
      final body = message.body;
      final sender = message.address;
      if (body == null || sender == null || message.id == null) continue;
      if (!_looksLikeBankMessage(body)) continue;

      final inserted = await _ref
          .read(smsRepositoryProvider)
          .insertSms(
            id: 'device_${message.id}',
            messageBody: body,
            sender: sender,
            date: date,
          );
      if (inserted) staged++;
    }
    return staged;
  }

  /// Starts a foreground-only live listener for new incoming SMS. Safe to
  /// call more than once; only registers one listener. Deliberately ignores
  /// the broadcast's own payload and re-scans the inbox instead -- by the
  /// time SMS_RECEIVED fires, Android has already persisted the message to
  /// the content provider, so a re-scan picks it up keyed by its real OS row
  /// id rather than a synthetic one that could later collide with a
  /// same-message row discovered by a normal scan.
  void startForegroundListening() {
    if (_listening) return;
    _listening = true;
    _telephony.listenIncomingSms(
      listenInBackground: false,
      onNewMessage: (_) => scanInbox(lookback: const Duration(minutes: 5)),
    );
  }

  bool _looksLikeBankMessage(String body) {
    final upper = body.toUpperCase();
    const keywords = [
      'DEBITED',
      'CREDITED',
      'SPENT',
      'CHARGED',
      'PAID',
      'A/C',
      'ACCOUNT',
      'UPI',
      'BALANCE',
      'RECEIVED',
      'TXN',
      'WITHDRAWN',
    ];
    return keywords.any(upper.contains);
  }
}

final smsDeviceServiceProvider = Provider<SmsDeviceService>((ref) {
  return SmsDeviceService(ref);
});
