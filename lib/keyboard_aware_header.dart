import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Rebuilds [builder] with the current keyboard height (logical pixels, 0 when
/// hidden), refreshed every frame of the keyboard's slide.
///
/// The height comes from the raw `FlutterView` rather than the ambient
/// [MediaQuery]: a [Scaffold] with `resizeToAvoidBottomInset: true` strips
/// `viewInsets.bottom` from its body subtree, so this widget stays correct no
/// matter how an ancestor Scaffold is configured.
///
/// Per-frame updates go through a [ValueNotifier] + [ValueListenableBuilder]
/// rather than `setState`, so only [builder]'s output rebuilds each frame.
class KeyboardHeightBuilder extends StatefulWidget {
  const KeyboardHeightBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, double keyboardHeight) builder;

  @override
  State<KeyboardHeightBuilder> createState() => _KeyboardHeightBuilderState();
}

class _KeyboardHeightBuilderState extends State<KeyboardHeightBuilder>
    with WidgetsBindingObserver {
  final ValueNotifier<double> _keyboard = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboard.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    // viewInsets on the raw view is in physical pixels; the layout wants
    // logical pixels.
    _keyboard.value = view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: _keyboard,
        builder: (context, keyboard, _) => widget.builder(context, keyboard),
      );
}

/// Pads [child] from the bottom by the current keyboard height (plus any
/// [padding]), so the content ends exactly where the keyboard begins.
///
/// Pair with `resizeToAvoidBottomInset: false` — otherwise the Scaffold lifts
/// the content too and everything moves twice.
///
/// [child] is captured once and reused across frames, so only the surrounding
/// `Padding` rebuilds as the keyboard moves — not the child subtree.
class KeyboardAwarePadding extends StatelessWidget {
  const KeyboardAwarePadding({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Constant insets applied in addition to the keyboard height at the bottom.
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyboardHeightBuilder(
      builder: (context, keyboard) => Padding(
        padding: padding.copyWith(bottom: padding.bottom + keyboard),
        child: child,
      ),
    );
  }
}

/// Shrinks [child] by the current keyboard height so everything below it moves
/// up by the same amount.
///
/// Driven straight off the per-frame keyboard height — no `AnimatedSize`, no
/// tween — so the child tracks the keyboard's own motion exactly, on open,
/// dismiss, and interrupted drags alike.
///
/// Note: this reports the child's *full* intrinsic height, so keep it out of an
/// [IntrinsicHeight], which would grant it the full slot and pin the shrink.
class KeyboardAwareHeader extends StatelessWidget {
  const KeyboardAwareHeader({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyboardHeightBuilder(
      builder: (context, keyboard) => ClipRect(
        child: _ShrinkTop(by: keyboard, child: child),
      ),
    );
  }
}

/// Reports a height [by] pixels shorter than its child's (floored at 0) and
/// shifts the child up, so the trimmed slice falls above the box and is clipped
/// by the enclosing [ClipRect].
class _ShrinkTop extends SingleChildRenderObjectWidget {
  const _ShrinkTop({required this.by, required super.child});

  final double by;

  @override
  _RenderShrinkTop createRenderObject(BuildContext context) =>
      _RenderShrinkTop(by);

  @override
  void updateRenderObject(BuildContext context, _RenderShrinkTop renderObject) {
    renderObject.shrinkBy = by;
  }
}

class _RenderShrinkTop extends RenderShiftedBox {
  _RenderShrinkTop(this._shrinkBy) : super(null);

  double _shrinkBy;
  double get shrinkBy => _shrinkBy;
  set shrinkBy(double value) {
    if (_shrinkBy == value) return;
    _shrinkBy = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    // Measure the child at its natural size...
    child.layout(constraints.loosen(), parentUsesSize: true);
    // ...then report a shorter box to our parent. This is what pulls the rest
    // of the screen upward.
    final visible =
        (child.size.height - _shrinkBy).clamp(0.0, child.size.height);
    size = constraints.constrain(Size(child.size.width, visible));
    // Slide the child up so the trimmed slice sits above our box.
    (child.parentData! as BoxParentData).offset =
        Offset(0, visible - child.size.height);
  }
}
