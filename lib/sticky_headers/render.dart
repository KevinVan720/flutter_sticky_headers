// Copyright 2018 Simon Lightfoot. All rights reserved.
// Use of this source code is governed by a the MIT license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'dart:math' show min, max;

/// Called every layout to provide the amount of stickyness a header is in.
/// This lets the widgets animate their content and provide feedback.
///
typedef void RenderStickyHeaderCallback(double stuckAmount);

/// RenderObject for StickyHeader widget.
///
/// Monitors given [Scrollable] and adjusts its layout based on its offset to
/// the scrollable's [RenderObject]. The header will be placed above content
/// unless overlapHeaders is set to true. The supplied callback will be used
/// to report the
///
class RenderStickyHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {

  RenderStickyHeaderCallback _callback;
  ScrollPosition _scrollPosition;
  bool _overlapHeaders;
  bool _headerOnTop;
  Axis _scrollDirection;

  RenderStickyHeader({
    @required ScrollPosition scrollPosition,
    RenderStickyHeaderCallback callback,
    bool overlapHeaders: false,
    bool headerOnTop: false,
    Axis scrollDirection: Axis.vertical,
    RenderBox header,
    RenderBox content,
  })  :
        _scrollPosition = scrollPosition,
        _callback = callback,
        _overlapHeaders = overlapHeaders,
        _headerOnTop = headerOnTop,
        _scrollDirection = scrollDirection{
    if(_headerOnTop) {
      if (content != null) add(content);
      if (header != null) add(header);
    }else{
      if (header != null) add(header);
      if (content != null) add(content);
    }

  }

  set scrollPosition(ScrollPosition newValue) {
    if (_scrollPosition == newValue) {
      return;
    }
    final ScrollPosition oldValue = _scrollPosition;
    _scrollPosition = newValue;
    markNeedsLayout();
    if (attached) {
      oldValue?.removeListener(markNeedsLayout);
      newValue?.addListener(markNeedsLayout);
    }
  }

  set callback(RenderStickyHeaderCallback newValue) {
    if (_callback == newValue) {
      return;
    }
    _callback = newValue;
    markNeedsLayout();
  }

  set overlapHeaders(bool newValue) {
    if (_overlapHeaders == newValue) {
      return;
    }
    _overlapHeaders = newValue;
    markNeedsLayout();
  }

  set headerOnTop(bool newValue) {
    if (_headerOnTop == newValue) {
      return;
    }
    _headerOnTop = newValue;
    markNeedsLayout();
  }

  set scrollDirection(Axis newValue) {
    if (_scrollDirection == newValue) {
      return;
    }
    _scrollDirection = newValue;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scrollPosition?.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _scrollPosition?.removeListener(markNeedsLayout);
    super.detach();
  }

  // short-hand to access the child RenderObjects
  RenderBox get _headerBox => _headerOnTop ? lastChild : firstChild;

  RenderBox get _contentBox =>  _headerOnTop ? firstChild : lastChild;

  bool get isVerticalAxis => _scrollDirection==Axis.vertical;

  @override
  void performLayout() {
    // ensure we have header and content boxes
    assert(childCount == 2);

    // layout both header and content widget
    final childConstraints = constraints.loosen();
    _headerBox.layout(childConstraints, parentUsesSize: true);
    _contentBox.layout(childConstraints, parentUsesSize: true);

    double headerHeight, contentHeight;
    double headerWidth, contentWidth;
    double width, height;
    if(isVerticalAxis) {
     headerHeight = _headerBox.size.height;
     contentHeight = _contentBox.size.height;
      width = max(constraints.minWidth, _contentBox.size.width);
      height = max(constraints.minHeight,
          _overlapHeaders ? contentHeight : headerHeight + contentHeight);
    }else{
      headerWidth = _headerBox.size.width;
      contentWidth = _contentBox.size.width;
      height = max(constraints.minHeight, _contentBox.size.height);
      width = max(constraints.minWidth,
          _overlapHeaders ? contentWidth : headerWidth + contentWidth);
    }
    //double headerHeight = _headerBox.size.height;
    //double contentHeight = _contentBox.size.height;

    // determine size of ourselves based on content widget
    //final width = max(constraints.minWidth, _contentBox.size.width);
    //final height = max(constraints.minHeight,
    //    _overlapHeaders ? contentHeight : headerHeight + contentHeight);
    size = new Size(width, height);
    assert(size.width == constraints.constrainWidth(width));
    assert(size.height == constraints.constrainHeight(height));
    assert(size.isFinite);

    // place content underneath header
    final contentParentData = _contentBox.parentData as MultiChildLayoutParentData;
    if(isVerticalAxis) {
      contentParentData.offset = new Offset(0.0, _overlapHeaders ? 0.0 : headerHeight);
    }else{
      contentParentData.offset = new Offset( _overlapHeaders ? 0.0 : headerWidth, 0.0);
    }

    // determine by how much the header should be stuck to the top
    final double stuckOffset = determineStuckOffset();

    // place header over content relative to scroll offset
    final double maxOffset = isVerticalAxis ? (height - headerHeight) : (width-headerWidth);
    final headerParentData = _headerBox.parentData as MultiChildLayoutParentData;
    headerParentData.offset = isVerticalAxis ? Offset(0.0, max(0.0, min(-stuckOffset, maxOffset))) : Offset(max(0.0, min(-stuckOffset, maxOffset)), 0.0);

    // report to widget how much the header is stuck.
    if (_callback != null) {
      final stuckAmount = isVerticalAxis ? max(min(headerHeight, stuckOffset), -headerHeight) / headerHeight : max(min(headerWidth, stuckOffset), -headerWidth) / headerWidth;
      _callback(stuckAmount);
    }
  }

  double determineStuckOffset() {
    final scrollBox = _scrollPosition.context.notificationContext.findRenderObject();
    if (scrollBox?.attached ?? false) {
      try {
        return isVerticalAxis ? localToGlobal(Offset.zero, ancestor: scrollBox).dy : localToGlobal(Offset.zero, ancestor: scrollBox).dx;
      } catch (e) {
        // ignore and fall-through and return 0.0
      }
    }
    return 0.0;
  }

  @override
  void setupParentData(RenderObject child) {
    super.setupParentData(child);
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = new MultiChildLayoutParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if(!isVerticalAxis) {
      return _overlapHeaders ? _contentBox.getMinIntrinsicWidth(height)
          : (_headerBox.getMinIntrinsicWidth(height) +
          _contentBox.getMinIntrinsicWidth(height));
    }else{
      return _contentBox.getMinIntrinsicWidth(height);
    }
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if(!isVerticalAxis) {
      return _overlapHeaders ? _contentBox.getMaxIntrinsicWidth(height)
          : (_headerBox.getMaxIntrinsicWidth(height) +
          _contentBox.getMaxIntrinsicWidth(height));
    }else{
      return _contentBox.getMaxIntrinsicWidth(height);
    }
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if(isVerticalAxis) {
      return _overlapHeaders ? _contentBox.getMinIntrinsicHeight(width)
          : (_headerBox.getMinIntrinsicHeight(width) +
          _contentBox.getMinIntrinsicHeight(width));
    }else{
      return _contentBox.getMinIntrinsicHeight(width);
    }
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if(isVerticalAxis) {
    return _overlapHeaders ? _contentBox.getMaxIntrinsicHeight(width)
        : (_headerBox.getMaxIntrinsicHeight(width) +
            _contentBox.getMaxIntrinsicHeight(width));
    }else{
      return _contentBox.getMaxIntrinsicHeight(width);
    }
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  @override
  bool hitTestChildren(HitTestResult result, {Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
