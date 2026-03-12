import 'package:logbook_app_081/features/auth/user_model.dart';

class LoginController {
  final Map<String, String> _validUsers = {"admin": "123", "member": "456"};
  // final String _validUsername = "admin";
  // final String _validPassword = "123";

  bool login(String username, String password) {
    if (_validUsers.containsKey(username) &&
        _validUsers[username] == password) {
      // Set User.current
      String role = username == 'admin' ? 'Ketua' : 'Anggota';
      User.current = User(
        id: username, // Using username as ID for simplicity
        username: username,
        role: role,
        teamId: 'team_alpha', // Default team
      );

      return true;
    } else {
      return false;
    }
  }
}
