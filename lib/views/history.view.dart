import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/view_models/history.vm.dart';
import 'package:pwa/widgets/order_list_item.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final HistoryViewModel vm = HistoryViewModel();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    vm.initialise();

    // Detect scroll to bottom for load more
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !_isLoadingMore &&
          !vm.isBusy) {
        _loadMore();
      }
    });
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    await vm.getOrders(initialLoading: false);
    setState(() => _isLoadingMore = false);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await vm.getOrders();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HistoryViewModel>.reactive(
      viewModelBuilder: () => vm,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                /// Header
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(MingCuteIcons.mgc_left_line,
                          color: Color(0xFF030744), size: 38),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      "History",
                      style: TextStyle(
                        height: 1,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF030744),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFF030744).withOpacity(0.15),
                ),

                /// List
                Expanded(
                  child: vm.isBusy
                      ? const Center(
                    child: LinearProgressIndicator(
                      color: Color(0xFF007BFF),
                      backgroundColor: Color(0xFF007BFF),
                    ),
                  )
                      : vm.hasError
                      ? _buildErrorWidget()
                      : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is OverscrollNotification &&
                          notification.overscroll < 0) {
                        _refresh(); // Pull-down refresh
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: vm.orders.length +
                          (_isLoadingMore ? 1 : 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      itemBuilder: (context, index) {
                        // Show loading indicator at bottom
                        if (index == vm.orders.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final order = vm.orders[index];
                        return Padding(
                          padding: EdgeInsets.only(
                              top: index == 0 ? 8 : 0, bottom: 8),
                          child: OrderListItem(
                            order: order,
                            onTap: () {
                              if (!AuthService.inReviewMode()) {
                                vm.openOrderDetails(order: order);
                              }
                            },
                          ),
                        );
                      },
                    ),
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
          MingCuteIcons.mgc_alert_line,
          color: const Color(0xFF030744).withOpacity(0.5),
          size: 75,
        ),
        const SizedBox(height: 12),
        Text(
          "An error occurred",
          style: TextStyle(
            height: 1,
            fontSize: 20,
            color: const Color(0xFF030744).withOpacity(0.5),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Please try again later",
          style: TextStyle(
            height: 1,
            color: const Color(0xFF030744).withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
