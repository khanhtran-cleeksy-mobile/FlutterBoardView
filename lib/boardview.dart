library boardview;

import 'dart:math';

import 'package:boardview/board_item.dart';
import 'package:boardview/boardview_controller.dart';
import 'package:flutter/material.dart';
import 'dart:core';
import 'package:boardview/board_list.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

const triggerScrollHorizontal = 20.0;

class BoardView extends StatefulWidget {
  final List<BoardList> lists;
  final double width;
  final double margin;
  final bool showBottomScrollBar;
  final BoardViewController? boardViewController;
  final OnDropItem? onDropItem;

  const BoardView({
    super.key,
    this.showBottomScrollBar = true,
    this.boardViewController,
    required this.lists,
    this.width = 350,
    required this.margin,
    required this.onDropItem,
  });

  @override
  State<StatefulWidget> createState() {
    return BoardViewState();
  }
}

typedef OnDropItem = void Function(int? listIndex, int? itemIndex,
    int? oldListIndex, int? oldItemIndex, BoardItemState state);
typedef OnDropList = void Function(int? listIndex);

class BoardViewState extends State<BoardView>
    with AutomaticKeepAliveClientMixin<BoardView> {
  Widget? draggedListItem;
  int? draggedListIndex;
  double? dx;
  double? dxInit;
  double? dyInit;
  double? dy;
  double? offsetX;
  double? offsetY;
  double? initialX = 0;
  double? initialY = 0;
  double? rightListX;
  double? leftListX;
  double? height;
  int? startListIndex;

  bool canDrag = true;

  ScrollController scrollController = ScrollController();

  List<BoardListState> listStates = [];

  OnDropList? onDropList;

  PointerDownEvent? pointer;

  List<BoardList> get lists => widget.lists;
  AutoScrollController scrollBarController = AutoScrollController();

  double get scrollSinglePixels => scrollController.positions.single.pixels;

  double get width => widget.width - widget.margin * 4;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.boardViewController != null) {
      widget.boardViewController!.state = this;
    }
  }

  void moveListRight() {
    final list = lists[draggedListIndex!];
    final listState = listStates[draggedListIndex!];
    lists.removeAt(draggedListIndex!);
    listStates.removeAt(draggedListIndex!);
    if (draggedListIndex != null) {
      draggedListIndex = draggedListIndex! + 1;
    }
    lists.insert(draggedListIndex!, list);
    listStates.insert(draggedListIndex!, listState);
    canDrag = false;
    if (scrollController.hasClients) {
      final int? tempListIndex = draggedListIndex;
      _animateTo(_nextPage).whenComplete(() {
        _setCurrentPos();
        _setCurrentPage(_nextPage);
        _rebuild();
        final RenderBox object = _findListStateRenderObject(tempListIndex!);
        final Offset pos = object.localToGlobal(Offset.zero);
        leftListX = pos.dx;
        rightListX = pos.dx + object.size.width;
        _resetCanDrag();
      });
    }
    _rebuild();
  }

  RenderBox _findListStateRenderObject(int tempListIndex) =>
      listStates[tempListIndex].context.findRenderObject() as RenderBox;

  void _setCurrentPage(int value) {
    currentPage = value;
    //
    if (widget.showBottomScrollBar)
      scrollBarController.scrollToIndex(currentPage,
          preferPosition: AutoScrollPosition.middle);
  }

  Future<void> _animateTo(int currentIndex) {
    return scrollController.animateTo(currentIndex * (width + widget.margin),
        duration: const Duration(milliseconds: 400), curve: Curves.ease);
  }

  void _resetCanDrag() async {
    Future.delayed(const Duration(milliseconds: 600), () {
      canDrag = true;
    });
  }

  void moveListLeft() {
    final list = lists[draggedListIndex!];
    final listState = listStates[draggedListIndex!];
    lists.removeAt(draggedListIndex!);
    listStates.removeAt(draggedListIndex!);
    if (draggedListIndex != null) {
      draggedListIndex = draggedListIndex! - 1;
    }
    lists.insert(draggedListIndex!, list);
    listStates.insert(draggedListIndex!, listState);
    canDrag = false;
    if (scrollController.hasClients && currentPage > 0) {
      final int? tempListIndex = draggedListIndex;
      _animateTo(_previousPage).whenComplete(() {
        _setCurrentPos();
        _setCurrentPage(_previousPage);
        _rebuild();
        final RenderBox object = _findListStateRenderObject(tempListIndex!);
        final Offset pos = object.localToGlobal(Offset.zero);
        leftListX = pos.dx;
        rightListX = pos.dx + object.size.width;
        _resetCanDrag();
      });
    }
    _rebuild();
  }

  int get _previousPage => max(0, currentPage - 1);

  int get _nextPage => currentPage + 1;

  double currentPos = 0;
  int currentPage = 0;

  final GlobalKey boardKey = GlobalKey();
  double? boardHeight;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      if (!scrollController.hasClients) return;
      try {
        _setBoardHeight();
        if (isMovingItemToOtherList) return;
        if (!canDrag) return;
        if (scrollSinglePixels > width * .01 + currentPos) {
          canDrag = false;
          _animateTo(_nextPage).then((value) {
            _setCurrentPos();
            _setCurrentPage(_nextPage);
            canDrag = true;
            _rebuild();
          });
        } else {
          if (scrollSinglePixels < currentPos - width * .01) {
            canDrag = false;
            _animateTo(_previousPage).then((value) {
              _setCurrentPos();
              _setCurrentPage(_previousPage);
              canDrag = true;
              _rebuild();
            });
          } else {
            _animateTo(currentPage).whenComplete(() {
              _setCurrentPos();
            });
          }
        }
      } catch (e) {}
    });
    final Widget listWidget = ListView.builder(
      physics: const ClampingScrollPhysics(),
      itemCount: lists.length,
      scrollDirection: Axis.horizontal,
      controller: scrollController,
      itemBuilder: (BuildContext context, int index) {
        var list = lists[index];
        list = BoardList(
          items: list.items,
          loadMore: list.loadMore,
          headerBackgroundColor: list.headerBackgroundColor,
          backgroundColor: list.backgroundColor,
          footer: list.footer,
          header: list.header,
          movable: list.movable,
          immovableWidget: list.immovableWidget,
          boardView: this,
          draggable: list.draggable,
          index: index,
          onDropList: list.onDropList,
          onTapList: list.onTapList,
          onStartDragList: list.onStartDragList,
          onLoadMore: list.onLoadMore,
          customWidget: list.customWidget,
          decoration: list.decoration,
          padding: list.padding,
          listPadding: list.listPadding,
          isDraggingItem: isDraggingItem,
        );
        return Opacity(
          opacity: draggedListIndex == index ? 0.4 : 1,
          child: Container(
            width: width,
            margin: EdgeInsets.only(
              left: index == 0 ? widget.margin * 2 : widget.margin,
              right: index == lists.length - 1 ? widget.margin * 2 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[Expanded(child: list)],
            ),
          ),
        );
      },
    );

    final List<Widget> stackWidgets = <Widget>[listWidget];

    if (initialX != null &&
        initialY != null &&
        offsetX != null &&
        offsetY != null &&
        dx != null &&
        dy != null &&
        height != null) {
      if (canDrag && dxInit != null && dyInit != null) {
        _handleDragging();
      }
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _rebuild();
      });
      stackWidgets.add(Positioned(
        width: width,
        height: height,
        child: draggedListItem!,
        left: (dx! - offsetX!) + initialX!,
        top: (dy! - offsetY!) + initialY!,
      ));
    }

    return SizedBox(
      height: boardHeight,
      key: boardKey,
      child: Listener(
        onPointerMove: (opm) {
          if (draggedListItem != null) {
            dxInit ??= opm.position.dx;
            dyInit ??= opm.position.dy;
            dx = opm.position.dx;
            dy = opm.position.dy;
            _rebuild();
          }
        },
        onPointerDown: (opd) {
          final RenderBox box = context.findRenderObject() as RenderBox;
          final Offset pos = box.localToGlobal(opd.position);
          offsetX = pos.dx;
          offsetY = pos.dy;
          pointer = opd;
          _rebuild();
        },
        onPointerUp: (opu) {
          if (onDropList != null) {
            final int? tempDraggedListIndex = draggedListIndex;
            onDropList!(tempDraggedListIndex);
          }
          draggedListItem = null;
          offsetX = null;
          offsetY = null;
          initialX = null;
          initialY = null;
          dx = null;
          dy = null;
          draggedListIndex = null;
          onDropList = null;
          dxInit = null;
          dyInit = null;
          leftListX = null;
          rightListX = null;
          startListIndex = null;
          _rebuild();
        },
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: stackWidgets,
              ),
            ),
            if (widget.showBottomScrollBar) _buildScrollBar()
          ],
        ),
      ),
    );
  }

  void _handleDragging() {
    _handleDraggingList();
  }

  void _handleDraggingList() {
    if ((lists.length > draggedListIndex! + 1 &&
            (lists[draggedListIndex! + 1].customWidget == null &&
                lists[draggedListIndex! + 1].draggable)) &&
        dx! > rightListX!) {
      //move right
      moveListRight();
    }

    if (0 <= draggedListIndex! - 1 && (dx! < 32)) {
      //move left
      moveListLeft();
    }
  }

  bool isMovingItemToOtherList = false;

  BoardListState? targetList;
  bool isDraggingItem = false;

  void onItemPointerMove(PointerMoveEvent event) {
    _moveToList(int page) {
      if (scrollController.hasClients) {
        isMovingItemToOtherList = true;
        _animateTo(page).whenComplete(() {
          _setCurrentPos();
          _setCurrentPage(page);
          _rebuild();
          Future.delayed(const Duration(milliseconds: 500)).then(
            (value) => isMovingItemToOtherList = false,
          );
        });
      }
    }

    if (isMovingItemToOtherList) return;
    //
    final listWidth = widget.width;
    final trigger = widget.margin * 4 + triggerScrollHorizontal;
    final dx = event.position.dx;
    if ((lists.length > currentPage + 1 &&
            lists[currentPage + 1].customWidget == null) &&
        dx > listWidth - trigger) {
      _moveToList(_nextPage);
    }
    if (currentPage - 1 >= 0 && dx < trigger) {
      _moveToList(_previousPage);
    }
  }

  void _setCurrentPos() {
    if (!scrollController.hasClients) return;
    currentPos = scrollSinglePixels;
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Widget _buildScrollBar() {
    final length =
        lists.length - lists.where((e) => e.customWidget != null).length;
    final barLength = length > 5 ? 5 : length;

    const itemSize = 11.0;
    return SizedBox(
      height: 30,
      width: itemSize * barLength,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        controller: scrollBarController,
        scrollDirection: Axis.horizontal,
        itemCount: length,
        itemBuilder: (context, index) {
          final isHighlight = currentPage == index;
          final double dotSize = isHighlight ? 7 : 5;
          return AutoScrollTag(
            key: ValueKey(index),
            controller: scrollBarController,
            index: index,
            child: Container(
              height: itemSize,
              width: itemSize,
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isHighlight
                      ? const Color(0xFFA3AABB)
                      : const Color(0xFFD7DBE4),
                  borderRadius: BorderRadius.circular(100),
                ),
                height: dotSize,
                width: dotSize,
              ),
            ),
          );
        },
      ),
    );
  }

  ///This method to set height for Board View to improve performance
  ///Because of Widget with specific height perform better than Expanded by default
  void _setBoardHeight() async {
    final isKeyboardOpen = View.of(context).viewInsets.bottom != 0.0;
    //if isKeyboardOpen, return and wait for next frame run this method automatically
    if (isKeyboardOpen) return;
    if (boardHeight != null) return;
    if (boardKey.currentContext == null) return;
    //
    final box = boardKey.currentContext?.findRenderObject() as RenderBox?;
    final newHeight = box?.size.height;
    boardHeight = newHeight;
    _rebuild();
  }

  void run() {
    if (pointer != null) {
      dx = pointer!.position.dx;
      dy = pointer!.position.dy;
      _rebuild();
    }
  }

  void setTargetList(int stageIndex) {
    targetList = listStates[stageIndex];
  }

  void onItemPointerTriggerScrollList(PointerMoveEvent event) {
    if (targetList == null) return;
    final box =
        targetList!.listKey.currentContext!.findRenderObject() as RenderBox;
    final listHeight = box.size.height;
    final listDyOffset = box.localToGlobal(Offset.zero).dy;
    final itemPos = event.position.dy - listDyOffset;
    //
    if (itemPos >= listHeight) {
      return targetList!.autoScrollDown();
    }
    if (itemPos < 0) {
      return targetList!.autoScrollUp();
    }
    targetList!.cancelTimer();
  }

  void setIsDraggingItem(bool dragging) {
    if (isDraggingItem != dragging) {
      isDraggingItem = dragging;
      setState(() {});
    }
  }

  void onItemPointerUp() {
    if (targetList == null) return;
    targetList!.cancelTimer();
  }
}
