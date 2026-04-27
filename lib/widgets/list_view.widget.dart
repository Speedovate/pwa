import 'package:flutter/material.dart';

class ListViewWidget<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollController? controller;
  final bool isLoadingMore;
  final Function()? onRefresh;
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
    final computedBottomPadding = isLoadingMore ? 8.0 : 16.0;

    Widget list = ListView.builder(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, computedBottomPadding),
      itemCount: items.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 10),
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeCap: StrokeCap.round,
                  color: Color(0xFF007BFF),
                ),
              ),
            ),
          );
        }
        final item = items[index];
        return Padding(
          padding: EdgeInsets.only(
            top: index == 0 ? 12 : 0,
            bottom: 12,
          ),
          child: itemBuilder(context, item, index),
        );
      },
    );

    if (onRefresh != null) {
      list = RefreshIndicator(
        color: const Color(0xFF007BFF),
        onRefresh: () async {
          await onRefresh!();
        },
        child: list,
      );
    }

    return list;
  }
}
