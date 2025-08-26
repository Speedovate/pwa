import 'package:flutter/material.dart';

class ListViewWidget<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollController? controller;
  final bool isLoadingMore;
  final Future<void> Function()? onRefresh;
  final int currentPage;

  const ListViewWidget({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.controller,
    this.isLoadingMore = false,
    this.onRefresh,
    this.currentPage = 1,
  });

  @override
  Widget build(BuildContext context) {
    double computedBottomPadding = isLoadingMore
        ? 50
        : (currentPage == 1 && items.isNotEmpty
            ? MediaQuery.of(context).size.height * 0.5
            : 8);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification &&
            notification.overscroll < 0 &&
            onRefresh != null) {
          onRefresh!();
        }
        return false;
      },
      child: Stack(
        children: [
          ListView.builder(
            controller: controller,
            padding: EdgeInsets.fromLTRB(20, 8, 20, computedBottomPadding),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? 12 : 0,
                  bottom: 12,
                ),
                child: itemBuilder(context, item, index),
              );
            },
          ),
          if (isLoadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 15,
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
