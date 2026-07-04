import 'package:flutter/material.dart';

const Color orderStatusActiveColor = Color(0xFF007BFF);

String orderStatusLabel(
  String? status, {
  String? reason,
}) {
  final normalizedStatus = (status ?? '').trim().toLowerCase();
  final normalizedReason = (reason ?? '').trim().toLowerCase();

  if (normalizedStatus == 'pending') {
    return 'Searching';
  } else if (normalizedStatus == 'preparing') {
    return 'Waiting';
  } else if (normalizedStatus == 'ready') {
    return 'Arrived';
  } else if (normalizedStatus == 'ongoing' || normalizedStatus == 'enroute') {
    return 'Navigating';
  } else if (normalizedStatus == 'failed') {
    return 'Failed';
  } else if (normalizedStatus == 'cancelled') {
    if (normalizedReason == 'rebook') {
      return 'Rebooked';
    } else if (normalizedReason == 'pass') {
      return 'Passed';
    }
    return 'Cancelled';
  } else if (normalizedStatus == 'delivered' ||
      normalizedStatus == 'completed' ||
      normalizedStatus == 'successful') {
    return 'Completed';
  }

  return 'Connecting';
}

Color orderStatusTextColor(
  String? status, {
  String? reason,
}) {
  final normalizedStatus = (status ?? '').trim().toLowerCase();
  final normalizedReason = (reason ?? '').trim().toLowerCase();

  if (normalizedStatus == 'cancelled' || normalizedStatus == 'failed') {
    if (normalizedReason == 'rebook' || normalizedReason == 'pass') {
      return Colors.orange;
    }
    return Colors.red;
  }

  if (normalizedStatus == 'ongoing' || normalizedStatus == 'enroute') {
    return Colors.orange;
  }

  if (normalizedStatus == 'delivered' ||
      normalizedStatus == 'completed' ||
      normalizedStatus == 'successful') {
    return Colors.green;
  }

  return orderStatusActiveColor;
}

Color orderStatusBackgroundColor(
  String? status, {
  String? reason,
}) {
  return orderStatusTextColor(
    status,
    reason: reason,
  ).withValues(alpha: 0.16);
}

Color orderStatusChipBackgroundColor(
  String? status, {
  String? reason,
}) {
  final color = orderStatusTextColor(
    status,
    reason: reason,
  );

  if (color == Colors.orange) {
    return Colors.orange.shade100;
  }
  if (color == Colors.red) {
    return Colors.red.shade100;
  }
  if (color == Colors.green) {
    return Colors.green.shade100;
  }
  return Colors.blue.shade100;
}
