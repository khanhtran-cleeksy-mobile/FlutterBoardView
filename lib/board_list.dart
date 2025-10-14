import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:boardview/board_item.dart';
import 'package:boardview/boardview.dart';
import 'package:boardview/loadmore.dart';

const triggerScrollVertical = 100.0;

typedef OnDropList = void Function(int? listIndex, int? oldListIndex);
typedef OnTapList = void Function(int? listIndex);
typedef OnStartDragList = void Function(int? listIndex);
typedef FutureCallBack = Future<bool> Function(int listIndex);

const timerDuration = Duration(milliseconds: 270);
const scrollDuration = Duration(milliseconds: 250);

class BoardList extends StatefulWidget {
  final List<Widget>? header;
  final Widget? customWidget;
  final Widget? footer;
  final List<BoardItem>? items;
  final bool loadMore;
  final bool movable;
  final Color? backgroundColor;
  final Color? headerBackgroundColor;
  final BoardViewState? boardView;
  final OnDropList? onDropList;
  final OnTapList? onTapList;
  final Widget? immovableWidget;
  final OnStartDragList? onStartDragList;
  final FutureCallBack? onLoadMore;
  final Decoration? decoration;
  final EdgeInsets? padding;
  final bool draggable;
  final bool isDraggingItem;
  final Widget Function(Widget Function(ScrollController) list)? builder;

  const BoardList({
    super.key,
    this.header,
    this.items,
    this.loadMore = false,
    this.movable = true,
    this.footer,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.boardView,
    this.padding = EdgeInsets.zero,
    this.draggable = true,
    this.index,
    this.onDropList,
    this.onTapList,
    this.onStartDragList,
    this.onLoadMore,
    this.customWidget,
    this.immovableWidget,
    this.decoration,
    this.isDraggingItem = false,
    this.builder,
  });

  final int? index;

  @override
  State<StatefulWidget> createState() {
    return BoardListState();
  }
}

class BoardListState extends State<BoardList>
    with AutomaticKeepAliveClientMixin<BoardList> {
  List<BoardItemState> itemStates = [];
  late ScrollController scrollController;
  bool scrollControllerInitialized = false;
  final listKey = GlobalKey();
  Timer? _timer;

  void onDropList(int? listIndex) {
    final boardView = widget.boardView;
    widget.onDropList?.call(listIndex, boardView!.startListIndex);
    boardView!.draggedListIndex = null;
    if (boardView.mounted) {
      boardView.setState(() {});
    }
  }

  void _startDrag(Widget item, BuildContext context) {
    final boardView = widget.boardView;
    if (boardView != null && widget.draggable) {
      widget.onStartDragList?.call(widget.index);
      boardView.startListIndex = widget.index;
      boardView.height = context.size!.height;
      boardView.draggedListIndex = widget.index;
      boardView.draggedListItem = item;
      boardView.onDropList = onDropList;
      boardView.run();
      if (boardView.mounted) {
        boardView.setState(() {});
      }
    }
  }

  void autoScrollDown() {
    if (_timer?.isActive == true) return;
    //
    cancelTimer();
    _timer = Timer.periodic(timerDuration, (timer) {
      if (scrollController.offset <
          scrollController.position.maxScrollExtent - 15) {
        scrollController.animateTo(
          scrollController.offset + triggerScrollVertical,
          duration: scrollDuration,
          curve: Curves.linear,
        );
      } else {
        cancelTimer();
      }
    });
  }

  void autoScrollUp() {
    if (_timer?.isActive == true) return;
    //
    cancelTimer();
    _timer = Timer.periodic(timerDuration, (timer) {
      if (scrollController.offset > scrollController.position.minScrollExtent) {
        scrollController.animateTo(
          scrollController.offset - triggerScrollVertical,
          duration: scrollDuration,
          curve: Curves.linear,
        );
      } else {
        cancelTimer();
      }
    });
  }

  void cancelTimer() {
    if (_timer?.isActive == true) {
      _timer?.cancel();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Color? backgroundColor = const Color.fromARGB(255, 255, 255, 255);

    if (widget.backgroundColor != null) {
      backgroundColor = widget.backgroundColor;
    }
    final boardView = widget.boardView;
    if (boardView!.listStates.length > widget.index!) {
      boardView.listStates.removeAt(widget.index!);
    }
    boardView.listStates.insert(widget.index!, this);

    return widget.customWidget ??
        Container(
          padding: EdgeInsets.only(
              top: widget.padding?.top ?? 0,
              bottom: widget.padding?.bottom ?? 0),
          decoration:
              widget.decoration ?? BoxDecoration(color: backgroundColor),
          child: Column(
            // children: listWidgets as List<Widget>,
            children: [
              GestureDetector(
                onTap: () => widget.onTapList?.call(widget.index),
                onTapDown: (otd) {
                  if (widget.draggable) {
                    final RenderBox object =
                        context.findRenderObject() as RenderBox;
                    final Offset pos = object.localToGlobal(Offset.zero);
                    boardView.initialX = pos.dx;
                    boardView.initialY = pos.dy;

                    boardView.rightListX = pos.dx + object.size.width;
                    boardView.leftListX = pos.dx;
                  }
                },
                onTapCancel: () {},
                onLongPress: () {
                  if (widget.draggable) {
                    _startDrag(widget, context);
                  }
                },
                child: Container(
                  color: widget.headerBackgroundColor,
                  padding: EdgeInsets.only(
                      right: widget.padding?.right ?? 0,
                      left: widget.padding?.left ?? 0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: widget.header!),
                ),
              ),
              Expanded(
                key: listKey,
                child: widget.movable
                    ? widget.builder?.call(_buildMovableList) ??
                        _buildMovableList(scrollController)
                    : widget.immovableWidget ?? const SizedBox(),
              ),
            ],
          ),
        );
  }

  Widget _buildMovableList(ScrollController scrollController) {
    if (!scrollControllerInitialized) {
      this.scrollController = scrollController;
      scrollControllerInitialized = true;
    }
    final length = widget.items!.length;
    //if isDraggingItem, +1 to add last ghost item
    final itemCount = widget.isDraggingItem ? length + 1 : length;
    return CupertinoScrollbar(
      radius: const Radius.circular(10),
      controller: scrollController,
      child: LoadMore(
        isFinish: !widget.loadMore,
        onLoadMore: () {
          return widget.onLoadMore!(widget.index!);
        },
        child: ListView.builder(
          padding: EdgeInsets.only(
              right: widget.padding?.right ?? 0,
              left: widget.padding?.left ?? 0),
          physics: const AlwaysScrollableScrollPhysics(),
          controller: scrollController,
          itemCount: itemCount,
          itemBuilder: (ctx, index) {
            if (widget.isDraggingItem && index == length) {
              //Build ghost item for drag/drop to last of list
              return BoardItem(
                boardList: this,
                item: SizedBox(
                  height: scrollController.position.viewportDimension - 150,
                ),
                draggable: false,
                index: index,
              );
            }
            //
            final item = widget.items![index];
            return BoardItem(
              boardList: this,
              item: item.item,
              draggable: item.draggable,
              index: index,
              onItemDraggingChanged: item.onItemDraggingChanged,
            );
          },
        ),
      ),
    );
  }
}
