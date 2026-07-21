# Flutter: keyboard-aware login screen

**Stop your login button from hiding behind the keyboard.** When the keyboard
opens, the hero image shrinks by exactly the keyboard's height — in sync with the
keyboard's own motion, not on a separate tween — and the submit button parks
directly on top of the keyboard. If the form still doesn't fit on a small screen,
it scrolls; the button never does.

Minimal and runnable: two Dart files, no dependencies beyond Flutter itself.

Companion repo to the article
**[Flutter: A not so simple login form — keyboard-adaptive layout with RenderShiftedBox][article]**.

[article]: ADD-YOUR-MEDIUM-LINK-HERE

<!-- Optional: drop a demo GIF here.
![Flutter login screen: the hero image shrinks as the keyboard opens, keeping the Get OTP button visible above it](docs/demo.gif) -->

## Symptoms this fixes

If you're hitting any of these, you're in the right place:

- The submit button is **hidden behind the keyboard** when a text field is focused.
- `BOTTOM OVERFLOWED BY 214 PIXELS` (the yellow-and-black striped bar), or in the
  console: `A RenderFlex overflowed by 214 pixels on the bottom.`
- **`resizeToAvoidBottomInset` isn't working** — or it works, but the content is
  cut off / overflows instead of fitting.
- `MediaQuery.of(context).viewInsets.bottom` **returns 0** even though the
  keyboard is clearly open.
- The header image collapse is animated, but **feels out of sync** with the
  keyboard, especially on dismiss.
- `Vertical viewport was given unbounded height` after wrapping a form in a
  scroll view.

## Run it

```bash
flutter run
```

Tap the phone field and watch the logo. Requires Flutter 3.10+ (uses `View.of`).

## What's here

Two files. That's the whole thing.

| File | What it is |
| --- | --- |
| [`lib/keyboard_aware_header.dart`](lib/keyboard_aware_header.dart) | The reusable pieces — copy this one file into your project |
| [`lib/main.dart`](lib/main.dart) | A plain login screen wired up with those pieces |

---

## Why isn't `resizeToAvoidBottomInset` enough?

**Because it resizes the viewport, not your content.** `Scaffold` defaults to
`resizeToAvoidBottomInset: true`, which shrinks the body so nothing sits under
the keyboard. But if your column was already close to full height — hero image +
title + form + button — the shrunken body can't hold it. The layout overflows
(`BOTTOM OVERFLOWED BY … PIXELS`), and the widget that gets pushed off the edge
is the last child: your button.

Something still has to make the content shorter. That's what this repo does: it
shrinks the hero image by the keyboard's height so everything below it moves up.

## Why does `MediaQuery.viewInsets.bottom` return 0 when the keyboard is open?

**Because a resizing `Scaffold` already consumed it.** When
`resizeToAvoidBottomInset` is `true`, `Scaffold` accounts for the inset itself and
then hands its body a `MediaQuery` with the bottom inset stripped out (see the
`removeViewInsets` call in Flutter's `scaffold.dart`). Any descendant asking "how
tall is the keyboard?" is told zero.

Two ways out:

1. Set `resizeToAvoidBottomInset: false` — then the ambient
   `MediaQuery.viewInsetsOf(context).bottom` reports the true value again.
2. Read the raw view, which is never stripped:

```dart
final view = View.of(context);
final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
```

This repo uses option 2, so the widgets stay correct no matter how an ancestor
`Scaffold` is configured.

## How do you get the keyboard height in Flutter?

**`View.of(context).viewInsets.bottom`, divided by `devicePixelRatio`.** The raw
`FlutterView` reports insets in *physical* pixels, while everything in your widget
code (`SizedBox`, `EdgeInsets`, font sizes) is in *logical* pixels. On a 3×
display a 900-physical-pixel keyboard is 300 logical pixels — skip the division
and every value you derive is 2–3× too large.

(`MediaQuery.viewInsetsOf(context).bottom` is already in logical pixels and needs
no conversion — but see the caveat above about resizing Scaffolds.)

To track it continuously, listen for metrics changes:

```dart
class _MyState extends State<MyWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
    // ...
  }
}
```

`didChangeMetrics` fires on every window-metrics change — including each frame of
the keyboard's slide.

## Why not just animate the header with `AnimatedSize`?

**Because it desynchronizes from the keyboard.** The OS animates the keyboard on
its own curve and duration; `AnimatedSize` runs a separate tween with its own
curve and duration. Two clocks, no coordination — the header lands early or late,
most visibly on dismiss, and the screen feels disconnected.

The keyboard is not an event, it's an animation: `viewInsets.bottom` sweeps
through every frame of the slide (0 → 14 → 43 → 96 → … → 300). Drive your layout
directly off that per-frame value and synchronization is automatic — there's no
tween to drift. That's why `KeyboardAwareHeader` contains no `AnimatedSize`, no
`Duration`, and no `Curve`.

## Why does shrinking a widget by an exact pixel amount need a custom render object?

**Because no stock widget can size a parent relative to its child's measured
height.** The requirement — "render at natural size, but occupy N fewer pixels,
clipping from the top" — defeats each obvious candidate:

| Approach | Why it fails |
| --- | --- |
| `SizedBox(height: …)` | Requires knowing the child's rendered height up front |
| `Align(heightFactor: …)` | Works in *fractions*; can't express "N pixels shorter" |
| `Transform.translate` | Moves painting, not layout — nothing below it moves up |
| `CustomSingleChildLayout` | Its delegate sizes the parent from *constraints*; it never sees the child's measured size |

So `KeyboardAwareHeader` drops one level down to a ~20-line `RenderShiftedBox`
with a single overridden method:

```dart
@override
void performLayout() {
  final child = this.child;
  if (child == null) {
    size = constraints.smallest;
    return;
  }
  child.layout(constraints.loosen(), parentUsesSize: true);       // measure natural size
  final visible =
      (child.size.height - _shrinkBy).clamp(0.0, child.size.height);
  size = constraints.constrain(Size(child.size.width, visible));  // report a shorter box
  (child.parentData! as BoxParentData).offset =
      Offset(0, visible - child.size.height);                     // slide child up
}
```

`size` is what this box reports to its parent — it's allowed to differ from the
child's actual height, and that mismatch is what pulls the rest of the screen
upward. The child still *paints* at full size, so a `ClipRect` wrapper trims the
overflow (layout and painting are separate passes).

## How do you keep a button above the keyboard?

**Pad the body's bottom by the keyboard height and make the button the last
child.** With `resizeToAvoidBottomInset: false`, the body keeps full height and
you control the inset yourself:

```dart
Padding(
  padding: EdgeInsets.only(bottom: keyboardHeight),
  child: Column(children: [ /* … */, YourButton() ]),
)
```

The padding deletes the keyboard's strip from the layout, so the body *ends*
exactly where the keyboard *begins* and the last child sits flush above it.

This is more robust than the common `Spacer` approach: in a column that's forced
to fill its viewport, a `Spacer` re-expands to absorb whatever space you free, so
collapsing a header and adding a filler cancel each other out and the button never
moves. Padding can't be absorbed.

## Why `Expanded` + `SingleChildScrollView` (and the "unbounded height" error)

**`Expanded` bounds the scroll view; the scroll view unbounds its child.** They
look contradictory but operate at different levels of the constraint system:

1. The outer `Column` has a bounded height.
2. `Expanded` measures the siblings (the button), subtracts them, and hands its
   child a **tight** height — e.g. "you are exactly 540px."
3. `SingleChildScrollView` takes that as its **viewport**, and passes
   `maxHeight: infinity` to *its* child.
4. The inner `Column` becomes its natural height. Taller than 540px → it scrolls.
   Shorter → it just sits there.

This pairing is also the standard fix for `Vertical viewport was given unbounded
height`, which you get when a scroll view is placed directly inside a `Column`: a
`Column` offers children infinite main-axis height, and a viewport can't work with
that. Wrap it in `Expanded` (or `Flexible`, or a fixed-size box) to re-bound it.

---

## The three pieces

**`KeyboardHeightBuilder`** — rebuilds with the live keyboard height, updated on
every frame of the slide via `WidgetsBindingObserver.didChangeMetrics`. Reads the
raw `FlutterView` and converts to logical pixels. Updates flow through a
`ValueNotifier` + `ValueListenableBuilder` rather than `setState`, so only the
builder's output rebuilds.

**`KeyboardAwareHeader`** — shrinks its child by the keyboard height, clipping
from the top, backed by the `RenderShiftedBox` shown above. No tween: it tracks
the keyboard's own motion on open, dismiss, and interrupted drags alike.

**`KeyboardAwarePadding`** — pads the body's bottom by the keyboard height so the
bottom child sits flush above the keyboard. Its `child` is captured once and
reused every frame; because Flutter's element reconciliation skips a child whose
widget instance is unchanged (`child.widget == newWidget`, and `Widget.operator==`
is `@nonVirtual` identity), the entire subtree is skipped while the keyboard
animates. Only the thin `Padding` rebuilds.

## Using it in your own app

Copy [`lib/keyboard_aware_header.dart`](lib/keyboard_aware_header.dart) into your
project, then:

```dart
Scaffold(
  resizeToAvoidBottomInset: false,   // required — see gotchas
  body: SafeArea(
    child: KeyboardAwarePadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  KeyboardAwareHeader(child: YourHeroImage()),
                  // ...your form
                ],
              ),
            ),
          ),
          YourSubmitButton(),   // last child → rides the keyboard
        ],
      ),
    ),
  ),
)
```

## Gotchas worth knowing

- **`resizeToAvoidBottomInset: false` is required.** `KeyboardAwarePadding`
  replaces the Scaffold's resize. Leave both on and the content lifts twice —
  the button will float a full keyboard-height above the keyboard.
- **Don't put `KeyboardAwareHeader` inside an `IntrinsicHeight`.** It reports its
  child's full *intrinsic* height (the shrink happens during real layout only), so
  `IntrinsicHeight` grants it the full slot and silently pins the shrink open.
- **Avoid `MediaQuery.of(context)` in the page's `build`.** With the Scaffold's
  resize off, `MediaQueryData` changes every frame of the slide — depending on all
  of it rebuilds the page each frame and defeats the captured-child optimization.
  Use scoped accessors like `MediaQuery.sizeOf` instead.
- **The per-frame glide needs iOS or Android 11+** (`WindowInsetsAnimation`). On
  Android 10 and below the inset arrives as a single jump: the layout still lands
  correctly, it just doesn't animate.
- **iPhone number pads have no Done key.** `TextInputType.phone` renders a 10-key
  grid with no return-key slot, so `textInputAction: TextInputAction.done` has
  nowhere to draw. For fixed-length input, dismiss on the last digit — see
  `_onPhoneChanged` in [`lib/main.dart`](lib/main.dart).

## Compatibility

| | |
| --- | --- |
| Flutter | 3.10+ (uses `View.of`) |
| Platforms | iOS, Android |
| Dependencies | none |

## License

MIT — take it, ship it.
