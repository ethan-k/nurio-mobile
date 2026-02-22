class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final int id;
  final String email;
  final String displayName;

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    return AccountSummary(
      id: json['id'] as int,
      email: (json['email'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
    );
  }
}
