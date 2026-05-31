import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String currency;
  final double monthlyIncome;
  final bool isProUser;
  final bool smsParsingEnabled;
  final bool biometricEnabled;
  final int autoLockMinutes;
  final int budgetResetDay;
  final bool isGuestMode;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.currency = 'INR',
    this.monthlyIncome = 0,
    this.isProUser = false,
    this.smsParsingEnabled = false,
    this.biometricEnabled = false,
    this.autoLockMinutes = 2,
    this.budgetResetDay = 1,
    this.isGuestMode = false,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      currency: data['currency'] ?? 'INR',
      monthlyIncome: (data['monthlyIncome'] ?? 0).toDouble(),
      isProUser: data['isProUser'] ?? false,
      smsParsingEnabled: data['smsParsingEnabled'] ?? false,
      biometricEnabled: data['biometricEnabled'] ?? false,
      autoLockMinutes: data['autoLockMinutes'] ?? 2,
      budgetResetDay: data['budgetResetDay'] ?? 1,
      isGuestMode: data['isGuestMode'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'currency': currency,
        'monthlyIncome': monthlyIncome,
        'isProUser': isProUser,
        'smsParsingEnabled': smsParsingEnabled,
        'biometricEnabled': biometricEnabled,
        'autoLockMinutes': autoLockMinutes,
        'budgetResetDay': budgetResetDay,
        'isGuestMode': isGuestMode,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? currency,
    double? monthlyIncome,
    bool? isProUser,
    bool? smsParsingEnabled,
    bool? biometricEnabled,
    int? autoLockMinutes,
    int? budgetResetDay,
    bool? isGuestMode,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      currency: currency ?? this.currency,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      isProUser: isProUser ?? this.isProUser,
      smsParsingEnabled: smsParsingEnabled ?? this.smsParsingEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      budgetResetDay: budgetResetDay ?? this.budgetResetDay,
      isGuestMode: isGuestMode ?? this.isGuestMode,
      createdAt: createdAt,
    );
  }

  /// Guest mode placeholder
  static UserModel guest({String name = 'Guest'}) => UserModel(
        uid: 'guest',
        name: name,
        email: '',
        isGuestMode: true,
        createdAt: DateTime.now(),
      );
}
