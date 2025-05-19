import 'package:boardview/board_list.dart';
import 'package:boardview/boardview.dart';
import 'package:boardview/custom_drag_drop_item.widget.dart';
import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

typedef OnItemDraggingChanged = void Function(
    int? listIndex, int? itemIndex, bool isDragging);

class BoardItem extends StatefulWidget {
  final BoardListState? boardList;
  final Widget? item;
  final int? index;
  final OnItemDraggingChanged? onItemDraggingChanged;
  final bool draggable;

  const BoardItem({
    super.key,
    this.boardList,
    this.item,
    this.index,
    this.onItemDraggingChanged,
    this.draggable = true,
  }) : assert(draggable && onItemDraggingChanged !=
      null, "onItemDraggingChanged can't be null if draggable is true", );

  @override
  State<StatefulWidget> createState() {
    return BoardItemState();
  }
}

class BoardItemState extends State<BoardItem>
    with AutomaticKeepAliveClientMixin<BoardItem> {
  BoardListState get boardList => widget.boardList!;

  BoardViewState get boardView => boardList.widget.boardView!;

  List<BoardListState> get listStates => boardView.listStates;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final boardList = widget.boardList!;

    return DragAndDropItemWrapper(
      parameters: _dragAndDropItemParameters(),
      child: CustomDragDropItemWidget(
        canDrag: widget.draggable,
        data: ItemOrderParam(
            listIndex: boardList.widget.index!, itemIndex: widget.index!),
        child: SizedBox(
          width: double.infinity,
          child: widget.item,
        ),
      ),
    );
  }

  DragAndDropBuilderParameters _dragAndDropItemParameters() {
    return DragAndDropBuilderParameters(
      onItemReordered: _onItemReordered,
      onItemDraggingChanged: _onItemDraggingChanged,
      itemOnWillAccept: (incoming, target) {
        final ItemOrderParam data = (target as CustomDragDropItemWidget).data;
        boardView.setTargetList(data.listIndex);
        return true;
      },
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      axis: Axis.horizontal,
    );
  }

  void _onItemReordered(DragAndDropItem reorderedItem,
      DragAndDropItem receiverItem) {
    final ItemOrderParam oldItem =
        (reorderedItem as CustomDragDropItemWidget).data;
    final ItemOrderParam newItem =
        (receiverItem as CustomDragDropItemWidget).data;
    final newListIndex = newItem.listIndex;
    var newItemIndex = newItem.itemIndex;
    final oldListIndex = oldItem.listIndex;
    final oldItemIndex = oldItem.itemIndex;
    if (newListIndex == oldListIndex &&
        newItemIndex > oldItemIndex &&
        newItemIndex > 0) {
      newItemIndex--;
    }
    //debugPrint(newItemIndex.toString());
    boardView.widget.onDropItem!(
      newListIndex,
      newItemIndex,
      oldListIndex,
      oldItemIndex,
      this,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    boardView.onItemPointerMove(event);
    boardView.onItemPointerTriggerScrollList(event);
  }

  void _onItemDraggingChanged(DragAndDropItem item, bool dragging) {
    boardView.setIsDraggingItem(dragging);
    widget.onItemDraggingChanged!(
      boardList.widget.index,
      widget.index,
      dragging,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    boardView.onItemPointerUp();
  }
}

class ItemOrderParam {
  final int listIndex;
  int itemIndex;

  ItemOrderParam({
    required this.listIndex,
    required this.itemIndex,
  });

  @override
  String toString() {
    return "{stageIndex: $listIndex, itemIndex: $itemIndex}";
  }
}
