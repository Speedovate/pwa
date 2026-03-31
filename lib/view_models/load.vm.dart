import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/requests/load.request.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/models/load_transaction.model.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class LoadViewModel extends BaseViewModel {
  int queryPage = 1;
  LoadRequest loadRequest = LoadRequest();
  List<LoadTransaction> loadTransactions = [];
  RefreshController refreshController = RefreshController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      partnerMarkupStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      partnerMarkupTransactionsStream;
  double claimablePartnerMarkupAmount = 0;
  List<Map<String, dynamic>> partnerMarkupTransactions = [];

  void initialise() async {
    startListeningToPartnerMarkup();
    await getLoadBalance();
    await getLoadTransactions();
  }

  @override
  void dispose() {
    partnerMarkupStream?.cancel();
    partnerMarkupTransactionsStream?.cancel();
    super.dispose();
  }

  void startListeningToPartnerMarkup() {
    if (!isBool(AuthService.currentUser?.isProvider)) {
      claimablePartnerMarkupAmount = 0;
      partnerMarkupTransactions = [];
      notifyListeners();
      return;
    }
    partnerMarkupStream?.cancel();
    partnerMarkupTransactionsStream?.cancel();
    partnerMarkupStream = fbStore
        .collection("partners")
        .doc("${AuthService.currentUser?.id}")
        .snapshots()
        .listen(
      (event) {
        final data = event.data() ?? {};
        claimablePartnerMarkupAmount =
            (data["claimable_cash_markup_amount"] as num?)?.toDouble() ?? 0;
        notifyListeners();
      },
    );
    partnerMarkupTransactionsStream = fbStore
        .collection("partners")
        .doc("${AuthService.currentUser?.id}")
        .collection("transactions")
        .orderBy("created_at", descending: true)
        .snapshots()
        .listen(
      (event) {
        partnerMarkupTransactions = event.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          final createdAt = data["created_at"];
          if (createdAt is Timestamp) {
            data["created_at"] = createdAt.toDate();
          }
          return data;
        }).toList();
        notifyListeners();
      },
    );
  }

  getLoadBalance() async {
    setBusy(true);
    try {
      gLoad = await loadRequest.loadBalanceRequest();
      Get.forceAppUpdate();
    } catch (_) {}
    setBusy(false);
  }

  getLoadTransactions({
    bool initialLoading = true,
  }) async {
    if (initialLoading) {
      setBusy(true);
      refreshController.refreshCompleted();
      queryPage = 1;
    } else {
      queryPage = queryPage + 1;
    }
    try {
      final mLoadTransactions = await loadRequest.loadTransactions(
        page: queryPage,
      );
      if (initialLoading) {
        loadTransactions = mLoadTransactions;
      } else {
        loadTransactions.addAll(mLoadTransactions);
        refreshController.loadComplete();
      }
      clearErrors();
    } catch (e) {
      setError(e);
    }
    setBusy(false);
  }

  initiateLoadTopUp(String amount) async {
    try {
      final link = await loadRequest.loadTopupRequest(amount);
      openWebview("Buy Load", link);
    } catch (_) {}
  }
}
