import 'package:flutter/material.dart';

class EmployeeOnboardingUi {
  static const Color primary = Color(0xFF4F46E5);
  static const Color textMuted = Color(0xFF64748B);

  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE2E8F0)),
  );

  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'ongoing':
        return 'Ongoing';
      case 'done':
        return 'Done';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
