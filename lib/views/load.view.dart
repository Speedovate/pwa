import 'package:pwa/utils/data.dart';
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

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    await vm.getLoadBalance();
    await vm.getLoadTransactions(initialLoading: false);
    setState(() => _isLoadingMore = false);
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await vm.getLoadBalance();
    await vm.getLoadTransactions(initialLoading: true);
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<LoadViewModel>.reactive(
      viewModelBuilder: () => vm,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    WidgetButton(
                      onTap: () {
                        Navigator.pop(context);
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
                                            fontSize: 15,
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
                                                    Navigator.pop(context);
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
                                                    Navigator.pop(context);
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
                                                    Navigator.pop(context);
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
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFF030744).withOpacity(0.15),
                ),
                Expanded(
                  child: vm.isBusy
                      ? Column(
                          children: [
                            LinearProgressIndicator(
                              color: const Color(
                                0xFF007BFF,
                              ),
                              backgroundColor: const Color(
                                0xFF007BFF,
                              ).withOpacity(0.25),
                            ),
                          ],
                        )
                      : vm.hasError
                          ? _buildErrorWidget()
                          : ListViewWidget(
                              items: vm.loadTransactions,
                              controller: _scrollController,
                              isLoadingMore: _isLoadingMore,
                              onRefresh: _refresh,
                              currentPage: vm.queryPage,
                              itemBuilder: (context, order, index) {
                                return TransactionListItem(
                                  transaction: vm.loadTransactions[index],
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
