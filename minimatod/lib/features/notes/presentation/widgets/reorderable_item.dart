import 'package:flutter/material.dart';

import '../../data/note_model.dart';
import '../notes_controller.dart';

enum _Zone { none, before, nest, after }

/// Wraps a row with a position-aware drop target so one long-press drag can both
/// **nest** (drop on the middle) and **reorder** (drop on the top/bottom edge),
/// without the two gestures conflicting.
///
/// Reorder is offered only when the dragged item is a sibling of the same type
/// (so it stays within its displayed group); nesting works across types. The row
/// itself (drag source, swipe, tap) is built by [rowBuilder], which receives
/// whether it's currently the hovered nest target.
class ReorderableItem extends StatefulWidget {
  const ReorderableItem({
    super.key,
    required this.controller,
    required this.item,
    required this.parentId,
    required this.group,
    required this.rowBuilder,
  });

  final NotesController controller;
  final Item item;

  /// Parent id of the displayed group (null at root).
  final String? parentId;

  /// The same-type sibling group in display order (top → bottom).
  final List<Item> group;

  final Widget Function(bool nestHighlight) rowBuilder;

  @override
  State<ReorderableItem> createState() => _ReorderableItemState();
}

class _ReorderableItemState extends State<ReorderableItem> {
  _Zone _zone = _Zone.none;

  bool _sameGroup(Item dragged) =>
      dragged.parentId == widget.parentId &&
      dragged.type == widget.item.type &&
      dragged.id != widget.item.id;

  bool _canNest(Item dragged) =>
      dragged.id != widget.item.id &&
      !widget.controller.isDescendant(widget.item.id, dragged.id);

  _Zone _zoneFor(DragTargetDetails<Item> d) {
    final dragged = d.data;
    final box = context.findRenderObject() as RenderBox?;
    final sameGroup = _sameGroup(dragged);
    final canNest = _canNest(dragged);

    if (box != null && sameGroup) {
      final f = (box.globalToLocal(d.offset).dy / box.size.height).clamp(
        0.0,
        1.0,
      );
      if (f < 0.28) return _Zone.before;
      if (f > 0.72) return _Zone.after;
    }
    if (canNest) return _Zone.nest;
    if (sameGroup) return _Zone.before; // descendant edge-case fallback
    return _Zone.none;
  }

  void _handleDrop(Item dragged, _Zone zone) {
    switch (zone) {
      case _Zone.nest:
        widget.controller.reparent(dragged, widget.item.id);
      case _Zone.before:
      case _Zone.after:
        final ids = widget.group.map((e) => e.id).toList()..remove(dragged.id);
        final target = ids.indexOf(widget.item.id);
        if (target == -1) return;
        ids.insert(zone == _Zone.before ? target : target + 1, dragged.id);
        widget.controller.reorderGroup(ids);
      case _Zone.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DragTarget<Item>(
      onWillAcceptWithDetails: (d) => _sameGroup(d.data) || _canNest(d.data),
      onMove: (d) {
        final z = _zoneFor(d);
        if (z != _zone) setState(() => _zone = z);
      },
      onLeave: (_) {
        if (_zone != _Zone.none) setState(() => _zone = _Zone.none);
      },
      onAcceptWithDetails: (d) {
        final zone = _zone;
        setState(() => _zone = _Zone.none);
        _handleDrop(d.data, zone);
      },
      builder: (context, candidate, rejected) {
        return Stack(
          children: [
            widget.rowBuilder(_zone == _Zone.nest),
            if (_zone == _Zone.before) _line(cs, top: true),
            if (_zone == _Zone.after) _line(cs, top: false),
          ],
        );
      },
    );
  }

  Widget _line(ColorScheme cs, {required bool top}) {
    return Positioned(
      left: 14,
      right: 14,
      top: top ? 2 : null,
      bottom: top ? null : 2,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
