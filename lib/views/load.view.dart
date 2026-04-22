// ignore_for_file: depend_on_referenced_packages

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/view_models/load.vm.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/widgets/button.widget.dart';
import 'package:pwa/services/alert.service.dart';
import 'package:pwa/widgets/list_view.widget.dart';
import 'package:pwa/widgets/transaction_list_item.dart';

class LoadView extends StatefulWidget {
  const LoadView({super.key});

  @override
  State<LoadView> createState() => _LoadViewState();
}

class _LoadViewState extends State<LoadView> {
  final LoadViewModel vm = LoadViewModel();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _showMarkupHistory = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !_isLoadingMore &&
          !vm.isBusy) {
        _loadMore();
      }
    });
  }

  _loadMore() async {
    setState(() => _isLoadingMore = true);
    await vm.getLoadBalance();
    await vm.getLoadTransactions(initialLoading: false);
    setState(() => _isLoadingMore = false);
  }

  _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    vm.startListeningToPartnerMarkup();
    await vm.getLoadBalance();
    await vm.getLoadTransactions(initialLoading: true);
    setState(() => _isRefreshing = false);
  }

  Widget _buildMarkupSummaryBar(LoadViewModel vm) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          width: 1,
          color: const Color(0xFF030744).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF030744).withValues(alpha: 0.06),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFF030744),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Claimable Partner Markup",
                  style: TextStyle(
                    height: 1,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF030744),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "₱${vm.claimablePartnerMarkupAmount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    height: 0.95,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF030744),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF030744) : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(1000)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(1000)),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                height: 1,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : const Color(0xFF030744).withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkupHistoryList(LoadViewModel vm) {
    if (vm.partnerMarkupTransactions.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: const Color(0xFF030744).withValues(alpha: 0.5),
            size: 75,
          ),
          const SizedBox(height: 12),
          Text(
            "No markup history yet",
            style: TextStyle(
              height: 1,
              fontSize: 20,
              color: const Color(0xFF030744).withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Your claimable partner markup history will appear here",
            style: TextStyle(
              height: 1,
              color: const Color(0xFF030744).withValues(alpha: 0.5),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: vm.partnerMarkupTransactions.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                width: 1,
                color: const Color(0xFF030744).withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              "Claimable partner markup came from bookings paid in cash and can be claimed via request.",
              style: TextStyle(
                height: 1.25,
                fontSize: 12,
                color: const Color(0xFF030744).withValues(alpha: 0.7),
              ),
            ),
          );
        }
        final transaction = vm.partnerMarkupTransactions[index - 1];
        final createdAt = transaction["created_at"] as DateTime?;
        final driverName = transaction["driver_name"]?.toString() ?? "Driver";
        final orderId = transaction["order_id"];
        final markup = (transaction["markup"] as num?)?.toDouble() ??
            (transaction["amount"] as num?)?.toDouble() ??
            0;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              width: 1,
              color: const Color(0xFF030744).withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 16),
                  Text(
                    _shortenDriverName(driverName),
                    style: const TextStyle(
                      height: 1,
                      fontSize: 14,
                      color: Color(0xFF030744),
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  Text(
                    "+ ₱${markup.toStringAsFixed(0)}",
                    style: const TextStyle(
                      height: 1,
                      fontSize: 14,
                      color: Colors.green,
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
                      orderId == null ? "-" : "Booking $orderId",
                      style: const TextStyle(
                        height: 1,
                        fontSize: 14,
                        color: Color(0xFF030744),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    createdAt == null
                        ? ""
                        : DateFormat("dd/MM/yyyy - h:mm a").format(createdAt),
                    style: const TextStyle(
                      height: 1,
                      fontSize: 14,
                      color: Color(0xFF030744),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _shortenDriverName(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return value;
    }
    if (parts.length == 1) {
      return parts.first;
    }
    return [
      parts.first,
      ...parts.skip(1).map((part) => part[0].toUpperCase()),
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<LoadViewModel>.reactive(
      viewModelBuilder: () => vm,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            toolbarHeight: 0,
            backgroundColor: Colors.white,
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    WidgetButton(
                      onTap: () {
                        Get.back();
                      },
                      child: const SizedBox(
                        width: 58,
                        height: 58,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 2,
                              right: 4,
                              bottom: 2,
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              color: Color(0xFF030744),
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Expanded(
                      child: Text(
                        "TODA Load",
                        style: TextStyle(
                          height: 1,
                          fontSize: 25,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF030744),
                        ),
                      ),
                    ),
                    WidgetButton(
                      onTap: () {
                        AlertService().showAppAlert(
                          isCustom: true,
                          customWidget: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(
                                  12,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width - 70,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 24),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        child: Text(
                                          "Buy TODA Load",
                                          style: TextStyle(
                                            height: 1,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: Color(
                                              0xFF09244B,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        child: Text(
                                          "Please select a load amount",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            height: 1.05,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Color(
                                              0xFF09244B,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 38,
                                                child: WidgetButton(
                                                  onTap: () {
                                                    Get.back();
                                                    vm.initiateLoadTopUp(
                                                      "100",
                                                    );
                                                  },
                                                  borderRadius: 8,
                                                  mainColor: const Color(
                                                    0xFF007BFF,
                                                  ),
                                                  useDefaultHoverColor: false,
                                                  child: const Center(
                                                    child: Text(
                                                      "₱100",
                                                      style: TextStyle(
                                                        height: 1,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: SizedBox(
                                                height: 38,
                                                child: WidgetButton(
                                                  onTap: () {
                                                    Get.back();
                                                    vm.initiateLoadTopUp(
                                                      "300",
                                                    );
                                                  },
                                                  borderRadius: 8,
                                                  mainColor: const Color(
                                                    0xFF007BFF,
                                                  ),
                                                  useDefaultHoverColor: false,
                                                  child: const Center(
                                                    child: Text(
                                                      "₱300",
                                                      style: TextStyle(
                                                        height: 1,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: SizedBox(
                                                height: 38,
                                                child: WidgetButton(
                                                  onTap: () {
                                                    Get.back();
                                                    vm.initiateLoadTopUp(
                                                      "500",
                                                    );
                                                  },
                                                  borderRadius: 8,
                                                  mainColor: const Color(
                                                    0xFF007BFF,
                                                  ),
                                                  useDefaultHoverColor: false,
                                                  child: const Center(
                                                    child: Text(
                                                      "₱500",
                                                      style: TextStyle(
                                                        height: 1,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      !isBool(AuthService
                                              .currentUser?.isProvider)
                                          ? const SizedBox()
                                          : Column(
                                              children: [
                                                const SizedBox(height: 24),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 24,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Expanded(
                                                        child: SizedBox(
                                                          height: 38,
                                                          child: WidgetButton(
                                                            onTap: () {
                                                              Get.back();
                                                              vm.initiateLoadTopUp(
                                                                "1000",
                                                              );
                                                            },
                                                            borderRadius: 8,
                                                            mainColor:
                                                                const Color(
                                                              0xFF007BFF,
                                                            ),
                                                            useDefaultHoverColor:
                                                                false,
                                                            child: const Center(
                                                              child: Text(
                                                                "₱1000",
                                                                style:
                                                                    TextStyle(
                                                                  height: 1,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: SizedBox(
                                                          height: 38,
                                                          child: WidgetButton(
                                                            onTap: () {
                                                              Get.back();
                                                              vm.initiateLoadTopUp(
                                                                "3000",
                                                              );
                                                            },
                                                            borderRadius: 8,
                                                            mainColor:
                                                                const Color(
                                                              0xFF007BFF,
                                                            ),
                                                            useDefaultHoverColor:
                                                                false,
                                                            child: const Center(
                                                              child: Text(
                                                                "₱3000",
                                                                style:
                                                                    TextStyle(
                                                                  height: 1,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: SizedBox(
                                                          height: 38,
                                                          child: WidgetButton(
                                                            onTap: () {
                                                              Get.back();
                                                              vm.initiateLoadTopUp(
                                                                "5000",
                                                              );
                                                            },
                                                            borderRadius: 8,
                                                            mainColor:
                                                                const Color(
                                                              0xFF007BFF,
                                                            ),
                                                            useDefaultHoverColor:
                                                                false,
                                                            child: const Center(
                                                              child: Text(
                                                                "₱5000",
                                                                style:
                                                                    TextStyle(
                                                                  height: 1,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            "₱${gLoad == null ? AuthService.isLoggedIn() ? "•••" : "0" : gLoad?.balance?.toStringAsFixed(0)}",
                            style: const TextStyle(
                              height: 1,
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF09244B),
                            ),
                          ),
                          const Icon(
                            Icons.add_circle,
                            color: Color(0xFF09244B),
                            size: 38,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                ),
                const SizedBox(height: 12),
                if (isBool(AuthService.currentUser?.isProvider))
                  _buildMarkupSummaryBar(vm),
                if (isBool(AuthService.currentUser?.isProvider))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          width: 1,
                          color:
                              const Color(0xFF030744).withValues(alpha: 0.15),
                        ),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(1000)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildFilterButton(
                              label: "Load History",
                              selected: !_showMarkupHistory,
                              onTap: () {
                                setState(() {
                                  _showMarkupHistory = false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildFilterButton(
                              label: "Markup History",
                              selected: _showMarkupHistory,
                              onTap: () {
                                setState(() {
                                  _showMarkupHistory = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFF030744).withValues(alpha: 0.15),
                ),
                Expanded(
                  child: isBool(AuthService.currentUser?.isProvider) &&
                          _showMarkupHistory
                      ? _buildMarkupHistoryList(vm)
                      : vm.isBusy
                          ? Column(
                              children: [
                                LinearProgressIndicator(
                                  color: const Color(
                                    0xFF007BFF,
                                  ),
                                  backgroundColor: const Color(
                                    0xFF007BFF,
                                  ).withValues(alpha: 0.25),
                                ),
                              ],
                            )
                          : vm.hasError
                              ? _buildErrorWidget()
                              : vm.loadTransactions.isEmpty
                                  ? _buildEmptyWidget()
                                  : ListViewWidget(
                                      items: vm.loadTransactions,
                                      controller: _scrollController,
                                      isLoadingMore: _isLoadingMore,
                                      onRefresh: _refresh,
                                      currentPage: vm.queryPage,
                                      itemBuilder: (context, order, index) {
                                        return TransactionListItem(
                                          transaction:
                                              vm.loadTransactions[index],
                                        );
                                      },
                                    ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.warning_amber_outlined,
          color: const Color(0xFF030744).withValues(alpha: 0.5),
          size: 75,
        ),
        const SizedBox(height: 12),
        Text(
          "An error occurred",
          style: TextStyle(
            height: 1,
            fontSize: 20,
            color: const Color(0xFF030744).withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Please try again later",
          style: TextStyle(
            height: 1,
            color: const Color(0xFF030744).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cancel_presentation,
          color: const Color(0xFF030744).withValues(alpha: 0.5),
          size: 75,
        ),
        const SizedBox(height: 12),
        Text(
          "No transactions yet",
          style: TextStyle(
            height: 1,
            fontSize: 20,
            color: const Color(0xFF030744).withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Your transactions will appear here",
          style: TextStyle(
            height: 1,
            color: const Color(0xFF030744).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
