import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stacked/stacked.dart';
import 'package:pwa/views/details.view.dart';
import 'package:pwa/models/order.model.dart';
import 'package:pwa/requests/order.request.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class HistoryViewModel extends BaseViewModel {
  int queryPage = 1;
  List<Order> orders = [];
  StreamSubscription? refreshOrderStream;
  OrderRequest orderRequest = OrderRequest();
  RefreshController refreshController = RefreshController();

  void initialise() async {
    await getOrders();
  }

  Future<void> getOrders({
    bool initialLoading = true,
  }) async {
    if (initialLoading) {
      setBusy(true);
      refreshController.refreshCompleted();
      queryPage = 1;
    } else {
      queryPage++;
    }
    try {
      final List<Order> orderList = await orderRequest.getOrdersRequest(
        page: queryPage,
      );
      if (!initialLoading) {
        orders.addAll(orderList);
        refreshController.loadComplete();
      } else {
        orders = orderList;
      }
      clearErrors();
    } catch (e) {
      setError(e);
    }
    setBusy(false);
  }

  openOrderDetails({required Order order}) {
    Navigator.push(
      Get.overlayContext!,
      PageRouteBuilder(
        reverseTransitionDuration: Duration.zero,
transitionDuration: Duration.zero,
pageBuilder: (context, a, b) => DetailsView(order: order),
      ),
    );
  }
}
