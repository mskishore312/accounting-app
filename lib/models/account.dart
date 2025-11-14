// Removed unused import: 'package:flutter/material.dart'

/// Account class definition
class Account {
  final int id;
  final String name;

  Account({
    required this.id,
    required this.name,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

// ... rest of the file content remains unchanged
