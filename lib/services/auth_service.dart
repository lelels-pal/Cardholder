import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _fileName = 'users.json';

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  Future<File> _getFile() async {
    final path = await _getFilePath();
    return File(path);
  }

  Future<List<User>> _readUsers() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      print('Error reading users: $e');
      return [];
    }
  }

  Future<void> _writeUsers(List<User> users) async {
    final file = await _getFile();
    final jsonList = users.map((user) => user.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  Future<bool> register(String username, String password) async {
    final users = await _readUsers();

    // Check if user already exists
    if (users.any((user) => user.username == username)) {
      return false; // User already exists
    }

    final newUser = User(username: username, password: password);
    users.add(newUser);
    await _writeUsers(users);
    return true;
  }

  Future<User?> login(String username, String password) async {
    final users = await _readUsers();
    try {
      return users.firstWhere(
        (user) => user.username == username && user.password == password,
      );
    } catch (e) {
      return null;
    }
  }
}
