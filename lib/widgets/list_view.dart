import 'package:flutter/material.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';

class ListViewWidget extends StatelessWidget {
  final ScrollController? scrollController;
  final Widget? title;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final List<dynamic> dataSet;
  final bool isLoading;
  final bool hasError;
  final bool justList;
  final bool reversed;
  final bool noScrollPhysics;
  final Axis scrollDirection;
  final EdgeInsets? padding;
  final Widget Function(BuildContext, int) itemBuilder;
  final Widget Function(BuildContext, int)? separatorBuilder;
  final bool canRefresh;
  final RefreshController? refreshController;
  final VoidCallback? onRefresh;
  final VoidCallback? onLoading;
  final bool canPullUp;

  const ListViewWidget({
    required this.dataSet,
    this.scrollController,
    this.title,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.isLoading = false,
    this.hasError = false,
    this.justList = true,
    this.reversed = false,
    this.noScrollPhysics = false,
    this.scrollDirection = Axis.vertical,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.canRefresh = false,
    this.refreshController,
    this.onRefresh,
    this.onLoading,
    this.canPullUp = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return justList
        ? _getBody()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title ?? const SizedBox(),
              _getBody(),
            ],
          );
  }

  Widget _getBody() {
    final contentBody = isLoading
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              (loadingWidget ??
                  SizedBox(
                      width: double.infinity,
                      child: LinearProgressIndicator(
                        color: const Color(
                          0xFF007BFF,
                        ),
                        backgroundColor: const Color(
                          0xFF007BFF,
                        ).withOpacity(
                          0.25,
                        ),
                      ))),
            ],
          )
        : hasError
            ? (errorWidget ?? const Text("There is an error"))
            : (dataSet.isEmpty)
                ? (emptyWidget ?? const SizedBox())
                : justList
                    ? _getListView()
                    : Expanded(
                        child: _getListView(),
                      );

    return canRefresh
        ? SmartRefresher(
            scrollDirection: scrollDirection,
            enablePullDown: true,
            enablePullUp: canPullUp,
            controller: refreshController!,
            onRefresh: onRefresh,
            onLoading: onLoading,
            child: contentBody,
          )
        : contentBody;
  }

  Widget _getListView() {
    return ListView.separated(
      controller: scrollController,
      padding: padding,
      shrinkWrap: true,
      reverse: reversed,
      physics: noScrollPhysics
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      scrollDirection: scrollDirection,
      itemBuilder: itemBuilder,
      itemCount: dataSet.length,
      separatorBuilder: separatorBuilder ??
          (context, index) => scrollDirection == Axis.vertical
              ? const SizedBox(height: 12)
              : const SizedBox(width: 12),
    );
  }
}
