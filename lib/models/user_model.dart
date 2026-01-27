class User {
  final String username;
  final String password;
  // Add other fields if needed, e.g., email, phone

  User({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    return {'username': username, 'password': password};
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(username: json['username'], password: json['password']);
  }
}
