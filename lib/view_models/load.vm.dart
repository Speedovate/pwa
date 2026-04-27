import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:pwa/utils/data.dart';
import 'package:stacked/stacked.dart';
import 'package:pwa/utils/functions.dart';
import 'package:pwa/requests/load.request.dart';
import 'package:pwa/services/auth.service.dart';
import 'package:pwa/models/load_transaction.model.dart';

class LoadViewModel extends BaseViewModel {
  int queryPage = 1;
  LoadRequest loadRequest = LoadRequest();
  List<LoadTransaction> loadTransactions = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      partnerMarkupStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      driverMarkupStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      partnerMarkupTransactionsStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      driverMarkupTransactionsStream;
  double claimablePartnerMarkupAmount = 0;
  double deductibleDriverMarkupAmount = 0;
  bool hasPartnerMarkup = false;
  bool hasDriverMarkup = false;
  List<Map<String, dynamic>> partnerMarkupTransactions = [];
  List<Map<String, dynamic>> driverMarkupTransactions = [];

  bool get hasMarkupHistoryAccess {
    return hasPartnerMarkup ||
        hasDriverMarkup ||
        partnerMarkupTransactions.isNotEmpty ||
        driverMarkupTransactions.isNotEmpty;
  }

  String get markupBalanceLabel {
    if (hasPartnerMarkup && hasDriverMarkup) {
      return "Available Markup";
    }
    if (hasPartnerMarkup) {
      return "Claimable Partner Markup";
    }
    if (hasDriverMarkup) {
      return "Deductable Driver Markup";
    }
    return "Markup Balance";
  }

  double get markupBalanceAmount {
    if (hasPartnerMarkup && hasDriverMarkup) {
      return claimablePartnerMarkupAmount + deductibleDriverMarkupAmount;
    }
    if (hasPartnerMarkup) {
      return claimablePartnerMarkupAmount;
    }
    if (hasDriverMarkup) {
      return deductibleDriverMarkupAmount;
    }
    return 0;
  }

  List<Map<String, dynamic>> get markupTransactions {
    final merged = [
      ...partnerMarkupTransactions,
      ...driverMarkupTransactions,
    ];
    merged.sort((a, b) {
      final aCreatedAt = a["created_at"];
      final bCreatedAt = b["created_at"];
      if (aCreatedAt is DateTime && bCreatedAt is DateTime) {
        return bCreatedAt.compareTo(aCreatedAt);
      }
      if (aCreatedAt is DateTime) {
        return -1;
      }
      if (bCreatedAt is DateTime) {
        return 1;
      }
      return 0;
    });
    return merged;
  }

  void initialise() async {
    startListeningToPartnerMarkup();
    await getLoadBalance();
    await getLoadTransactions();
  }

  @override
  void dispose() {
    partnerMarkupStream?.cancel();
    driverMarkupStream?.cancel();
    partnerMarkupTransactionsStream?.cancel();
    driverMarkupTransactionsStream?.cancel();
    super.dispose();
  }

  void startListeningToPartnerMarkup() {
    partnerMarkupStream?.cancel();
    driverMarkupStream?.cancel();
    partnerMarkupTransactionsStream?.cancel();
    driverMarkupTransactionsStream?.cancel();
    if (AuthService.currentUser?.id == null) {
      claimablePartnerMarkupAmount = 0;
      deductibleDriverMarkupAmount = 0;
      hasPartnerMarkup = false;
      hasDriverMarkup = false;
      partnerMarkupTransactions = [];
      driverMarkupTransactions = [];
      notifyListeners();
      return;
    }
    partnerMarkupStream = fbStore
        .collection("partners")
        .doc("${AuthService.currentUser?.id}")
        .snapshots()
        .listen(
      (event) {
        final data = event.data() ?? {};
        hasPartnerMarkup = event.exists;
        claimablePartnerMarkupAmount =
            (data["claimable_cash_markup_amount"] as num?)?.toDouble() ?? 0;
        notifyListeners();
      },
    );
    driverMarkupStream = fbStore
        .collection("drivers")
        .doc("${AuthService.currentUser?.id}")
        .snapshots()
        .listen(
      (event) {
        final data = event.data() ?? {};
        hasDriverMarkup = event.exists;
        deductibleDriverMarkupAmount =
            (data["deductible_cash_markup_amount"] as num?)?.toDouble() ?? 0;
        notifyListeners();
      },
    );
    partnerMarkupTransactionsStream = fbStore
        .collection("partners")
        .doc("${AuthService.currentUser?.id}")
        .collection("transactions_v2")
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
          data["source_type"] = "partner";
          return data;
        }).toList();
        notifyListeners();
      },
    );
    driverMarkupTransactionsStream = fbStore
        .collection("drivers")
        .doc("${AuthService.currentUser?.id}")
        .collection("transactions_v2")
        .orderBy("created_at", descending: true)
        .snapshots()
        .listen(
      (event) {
        driverMarkupTransactions = event.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          final createdAt = data["created_at"];
          if (createdAt is Timestamp) {
            data["created_at"] = createdAt.toDate();
          }
          data["source_type"] = "driver";
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
