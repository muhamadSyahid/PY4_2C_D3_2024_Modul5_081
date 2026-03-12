class User {
  final String id;
  final String username;
  final String role;
  final String teamId;

  User({
    required this.id,
    required this.username,
    required this.role,
    required this.teamId,
  });

  static User? current;
}
