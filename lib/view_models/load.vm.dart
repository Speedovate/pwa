import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:pwa/utils/functions.dart';
import 'package:stacked/stacked.dart';
import 'package:pwa/requests/load.request.dart';
import 'package:pwa/models/load_transaction.model.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class LoadViewModel extends BaseViewModel {
  int queryPage = 1;
  LoadRequest loadRequest = LoadRequest();
  List<LoadTransaction> loadTransactions = [];
  RefreshController refreshController = RefreshController();

  void initialise() async {
    await getLoadBalance();
    await getLoadTransactions();
  }

  Future<void> getLoadBalance() async {
    try {
      gLoad = await loadRequest.loadBalanceRequest();
      Get.forceAppUpdate();
    } catch (_) {}
  }

  Future<void> getLoadTransactions({
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
      // launchUrlString(
      //   link,
      //   mode: LaunchMode.inAppBrowserView,
      // );
    } catch (_) {}
  }
}
