# Keyboard-aware login screen (Flutter)

A minimal, runnable companion to the article
**[Flutter: A not so simple login form — keyboard-adaptive layout with RenderShiftedBox][article]**.

When the keyboard opens, the hero image shrinks by exactly the keyboard's height
— **in sync with the keyboard's own motion**, not on a separate tween — and the
submit button parks directly on top of the keyboard instead of hiding behind it.
If the form still doesn't fit (small screens), it scrolls; the button never does.

[article]: ADD-YOUR-MEDIUM-LINK-HERE

<!-- Optional: drop a demo GIF here.
![Demo](docs/demo.gif) -->

## Run it

```bash
flutter run
```

Requires Flutter 3.10+ (uses `View.of`). Tap the phone field and watch the logo.

## What's here

Two files. That's the whole thing.

| File | What it is |
| --- | --- |
| [`lib/keyboard_aware_header.dart`](lib/keyboard_aware_header.dart) | The reusable pieces — copy this one file into your project |
| [`lib/main.dart`](lib/main.dart) | A plain login screen wired up with those pieces |

## The three pieces

**`KeyboardHeightBuilder`** — rebuilds with the live keyboard height, updated on
every frame of the slide via `WidgetsBindingObserver.didChangeMetrics`. It reads
the raw `FlutterView` (and divides by `devicePixelRatio`, since that value is in
physical pixels) so it stays correct regardless of how an ancestor `Scaffold` is
configured.

**`KeyboardAwareHeader`** — shrinks its child by the keyboard height, clipping
from the top. Backed by a ~20-line `RenderShiftedBox` that reports a height
shorter than its child's measured height — something no stock widget can express
(`Align.heightFactor` only does fractions; `Transform` moves paint, not layout;
`CustomSingleChildLayout` can't size a parent from its child).

**`KeyboardAwarePadding`** — pads the body's bottom by the keyboard height, so
the content ends where the keyboard begins and the bottom child sits flush above
it. Its `child` is captured once and reused every frame, so the reconciler skips
the whole subtree while the keyboard animates.

## Using it in your own app

```dart
Scaffold(
  resizeToAvoidBottomInset: false,   // important — see below
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
  replaces the Scaffold's resize. Leave both on and the content lifts twice.
- **Don't put `KeyboardAwareHeader` inside an `IntrinsicHeight`.** It reports its
  child's full *intrinsic* height, so `IntrinsicHeight` grants it the full slot
  and silently pins the shrink open.
- **Avoid `MediaQuery.of(context)` in the page's `build`.** With the Scaffold's
  resize off, `MediaQueryData` changes every frame of the slide — depending on
  all of it rebuilds the page each frame and defeats the captured-child
  optimization. Use scoped accessors like `MediaQuery.sizeOf` instead.
- **The per-frame glide needs iOS or Android 11+** (`WindowInsetsAnimation`). On
  older Android the inset arrives in one jump: the layout still lands correctly,
  it just doesn't animate.

## License

MIT — take it, ship it.
