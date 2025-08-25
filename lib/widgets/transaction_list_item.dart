// ignore_for_file: depend_on_referenced_packages

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/models/load_transaction.model.dart';

class TransactionListItem extends StatefulWidget {
  const TransactionListItem({
    required this.transaction,
    super.key,
  });

  final LoadTransaction transaction;

  @override
  State<TransactionListItem> createState() => _TransactionListItemState();
}

class _TransactionListItemState extends State<TransactionListItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(
          Radius.circular(12),
        ),
        border: Border.all(
          width: 1,
          color: const Color(0xFF09244B).withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 16),
              Text(
                capitalizeWords(
                  widget.transaction.status,
                ),
                style: const TextStyle(
                  height: 1,
                  fontSize: 14,
                  color: Color(0xFF09244B),
                ),
              ),
              const Expanded(child: SizedBox()),
              Text(
                "${isBool(widget.transaction.isCredit) ? "+" : "-"} ₱${widget.transaction.amount?.toStringAsFixed(0)}",
                style: TextStyle(
                  height: 1,
                  fontSize: 14,
                  color: isBool(widget.transaction.isCredit)
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  capitalizeWords(
                    widget.transaction.reason?.toLowerCase() == "topup" ||
                            widget.transaction.reason?.toLowerCase() == "top up"
                        ? "buy load"
                        : widget.transaction.reason,
                    alt: isBool(widget.transaction.isCredit)
                        ? "Credit"
                        : "Debit",
                  ),
                  style: const TextStyle(
                    height: 1,
                    fontSize: 14,
                    color: Color(0xFF09244B),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                DateFormat("dd/MM/yyyy - h:mm a").format(
                  widget.transaction.createdAt!,
                ),
                style: const TextStyle(
                  height: 1,
                  fontSize: 14,
                  color: Color(0xFF09244B),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
