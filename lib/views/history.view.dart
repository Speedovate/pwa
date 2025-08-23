import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:flutter/material.dart';
import 'package:pwa/widgets/list_view.dart';
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
  HistoryViewModel historyViewModel = HistoryViewModel();

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HistoryViewModel>.reactive(
      viewModelBuilder: () => historyViewModel,
      onViewModelReady: (vm) => vm.initialise(),
      builder: (context, vm, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            Get.back();
                          },
                          icon: const Padding(
                            padding: EdgeInsets.only(
                              top: 2,
                              right: 4,
                              bottom: 2,
                            ),
                            child: Icon(
                              MingCuteIcons.mgc_left_line,
                              color: Color(0xFF030744),
                              size: 38,
                            ),
                          ),
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
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: ListViewWidget(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          canRefresh: true,
                          canPullUp: true,
                          refreshController: vm.refreshController,
                          onRefresh: () {
                            vm.getOrders();
                          },
                          onLoading: () {
                            vm.getOrders(initialLoading: false);
                          },
                          dataSet: vm.orders,
                          isLoading: vm.isBusy,
                          hasError: vm.hasError,
                          errorWidget: Column(
                            children: [
                              const Expanded(child: SizedBox()),
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
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Please try again later",
                                style: TextStyle(
                                  height: 1,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
                                ),
                              ),
                              const Expanded(child: SizedBox()),
                              const SizedBox(height: 40),
                            ],
                          ),
                          emptyWidget: Column(
                            children: [
                              const Expanded(child: SizedBox()),
                              Icon(
                                MingCuteIcons.mgc_empty_box_line,
                                color: const Color(0xFF030744).withOpacity(0.5),
                                size: 75,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "No bookings yet",
                                style: TextStyle(
                                  height: 1,
                                  fontSize: 20,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Your bookings will appear here",
                                style: TextStyle(
                                  height: 1,
                                  color:
                                      const Color(0xFF030744).withOpacity(0.5),
                                ),
                              ),
                              const Expanded(child: SizedBox()),
                              const SizedBox(height: 40),
                            ],
                          ),
                          itemBuilder: (context, index) {
                            final order = vm.orders[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                top: index == 0 ? 20 : 0,
                              ),
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
                          separatorBuilder: (context, index) => const SizedBox(
                            height: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
