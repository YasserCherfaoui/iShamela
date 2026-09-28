# SPEC-026 — Liquid Glass Interface Style

- **Status:** Draft
- **Depends on:** DESIGN-001 (Warm Manuscript tokens), SPEC-004 (app foundation / theming), SPEC-016 (app language & About — settings screen structure), SPEC-024 (profile → synced preferences)
- **Feeds:** every screen that owns chrome (tab bar, app bars, toolbars, sheets, search fields)
- **Design canvas:** "Liquid Glass — interface style (SPEC-026)" row on the iShamela UI Redesign canvas (GlassTokens, GlassHome, GlassCatalog, GlassReader, GlassReaderNight, GlassSettings)

## 1. Purpose

Add a second **interface style**, *Liquid Glass*, that the user can switch to from Settings. Warm Manuscript stays the default. Liquid Glass changes only the app's **chrome** (bars, toolbars, sheets, search fields, floating cards); reading surfaces and body text are untouched.

Platform rule, fixed by the product owner:

| Platform | Glass implementation |
|---|---|
| iOS 26+, macOS 26+ | **Native** — real UIKit/AppKit/SwiftUI glass embedded as platform views |
| iOS < 26, macOS < 26 | **Drawn** glass (native API unavailable) |
| Android, Web, Windows, Linux | **Drawn** glass |

Both implementations sit behind one Flutter abstraction (§5) so screens never know which one they got.

## 2. Settings model

Appearance in Settings gets a new axis, orthogonal to the existing reading theme:

```
Appearance
├── Reading theme      فاتح · سيبيا · ليلي   (existing — unchanged)
└── Interface style    المخطوطة · الزجاج     (new, SPEC-026)
```

- `InterfaceStyle { manuscript, liquidGlass }` — default `manuscript`.
- Stored in the same local prefs store as the reading theme (`prefs.interfaceStyle`).
- **Synced** with the account as part of the appearance preferences (SPEC-024 §"Preferences" doc, LWW on `updatedAt`), exactly like `readingTheme`. Guests keep it local.
- Reading theme × interface style = 3 × 2 combinations, but there is **one** glass material per reading theme (§4), not six separate themes.
- Beneath the picker, one line of helper copy on Apple platforms: «على iOS وmacOS يُستخدم زجاج النظام الأصلي» (system glass is used). Never shown elsewhere.
- Follows the OS *Reduce Transparency* accessibility flag (§7). No app-level toggle — the OS one is the source of truth.

## 3. Which surfaces get glass

Glass **is applied to** (in this order of priority for implementation):

1. Bottom tab bar → becomes a **floating pill** inset 16 px from the edges, 22 px above the safe area, with the active tab drawn as a soft filled capsule (see GlassHome board).
2. Reader top bar and bottom page-nav pill (GlassReader / GlassReaderNight boards) — text scrolls underneath.
3. Catalog / Library / Search: the search field and the sticky category chips row.
4. Bottom sheets (font picker, page jump, download preflight, share): the sheet surface itself.
5. Floating actions: profile avatar button on Home, download-progress snackbar (SPEC-020), "continue reading" card on Home.

Glass **is never applied to**:

- The reading page surface, footnotes area, or any container whose primary content is body Arabic text. The reader page stays opaque cream/sepia/night — legibility of tashkeel over a moving blurred backdrop is not acceptable in a reading app.
- List rows and cards inside scrolling lists (one glass layer per screen at most over a scrolling list — see §6 performance rules).
- Splash, auth screens, App Store screenshots (marketing keeps Warm Manuscript).

## 4. Glass material tokens

One material per reading theme. All values are the *drawn* recipe; native glass takes only the tint and the shape (radius) and derives the rest from the OS.

| Token | Light (فاتح) | Sepia (سيبيا) | Night (ليلي) |
|---|---|---|---|
| `glass.blur` | 28 px | 28 px | 24 px |
| `glass.saturation` | 1.70 | 1.60 | 1.40 |
| `glass.brightness` | 1.05 | 1.03 | 1.00 |
| `glass.tint` | `#FBF7EC` @ 58 % | `#F1E5CC` @ 60 % | `#101B17` @ 52 % |
| `glass.stroke` | `#FFFFFF` @ 60 % | `#FFFFFF` @ 50 % | `#F2E8CF` @ 16 % |
| `glass.highlight` (inset top 1 px) | `#FFFFFF` @ 70 % | `#FFFFFF` @ 60 % | `#F2E8CF` @ 18 % |
| `glass.shadow` | `#0E3B30` @ 12 %, y 8, blur 24 | `#5A4A1E` @ 12 %, y 8, blur 24 | `#000000` @ 35 %, y 8, blur 24 |
| `glass.radius.pill` | 999 | 999 | 999 |
| `glass.radius.bar` | 20 px | 20 px | 20 px |
| `glass.radius.sheet` | 28 px (top corners) | 28 px | 28 px |
| `glass.activeCapsule` | `#0E3B30` @ 12 % | `#6B5220` @ 12 % | `#F2E8CF` @ 14 % |
| Foreground on glass | ink `#1F2A24`, accent green `#0E3B30`, gold `#A67C2E` | same, gold `#8F6A1F` | cream `#F2E8CF`, mint `#8FC7AC`, gold `#C6A15B` |

**Reduce Transparency / fallback material** (§7): same tokens with `blur = 0`, `saturation = 1`, tint opacity raised to 94 %. This is a *frosted opaque* surface, visually consistent with glass but static.

Tokens live next to the DESIGN-001 palette in the theme module (`lib/theme/glass_tokens.dart`), one `GlassTokens` object per `ReadingTheme`.

## 5. Architecture

```
lib/ui/glass/
├── interface_style.dart          enum + InheritedWidget/Riverpod provider
├── glass_tokens.dart             §4 tables
├── glass_surface.dart            GlassSurface (facade) + GlassCapability
├── drawn/
│   ├── drawn_glass_surface.dart  BackdropFilter recipe
│   └── glass_highlight_shader.frag (optional, §5.3)
├── native/
│   ├── native_glass_surface.dart platform-view wrapper
│   └── native_glass_channel.dart method channel contract (§5.2)
└── chrome/
    ├── glass_tab_bar.dart
    ├── glass_app_bar.dart
    ├── glass_toolbar.dart        reader bottom pill
    ├── glass_search_field.dart
    └── glass_sheet.dart
```

### 5.1 `GlassSurface` facade

```dart
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    required this.shape,          // GlassShape.pill | bar(radius) | sheet
    this.tintOverride,            // rarely — e.g. snackbar success tint
    this.interactive = false,     // true = native control; false = passive backdrop
  });
}
```

`GlassSurface` resolves, once per app start, a `GlassCapability`:

```dart
enum GlassCapability { native, drawn, frosted }
```

- `native` → `InterfaceStyle.liquidGlass` **and** platform is iOS/macOS **and** `NativeGlassChannel.isAvailable()` returned `true` (OS 26+ SDK check done in Swift with `#available`).
- `drawn` → `liquidGlass` on any other platform, or Apple platform below OS 26.
- `frosted` → OS Reduce Transparency on, or the performance governor (§6) tripped.
- `InterfaceStyle.manuscript` → `GlassSurface` renders the plain Warm Manuscript container (no blur at all). Screens therefore always use the chrome components; the style switch is invisible to them.

Chrome components (`chrome/`) are the only widgets screens import. They take the same props in both styles (items, onSelected, title, actions…).

### 5.2 Native implementation (iOS 26+, macOS 26+)

**Strategy:** each glass chrome element is one platform view (`UiKitView` on iOS, `AppKitView` on macOS) backed by a SwiftUI view using `.glassEffect(...)` / `GlassEffectContainer`, or the UIKit/AppKit glass material where a control is cheaper (tab bar). Flutter keeps **all** navigation and state; native views are presentation only and report events back.

Evaluate the pub package `liquid_glass_native` first — it already ships buttons, tab bar, sheets and pickers as `UiKitView`s with a `#available` guard and iOS 26 SDK requirement. If it covers the tab bar, toolbar pill and passive backdrop shapes, adopt it behind `NativeGlassSurface`; otherwise implement the thin plugin below in the app's own `ios/` and `macos/` runners (Swift Package, no CocoaPods). Either way the Dart API is the facade in §5.1 — the package must stay swappable.

**Method channel contract** (`ishamela/glass`):

| Method | Direction | Payload | Notes |
|---|---|---|---|
| `isAvailable` | Dart → native | — | `true` only when `#available(iOS 26, macOS 26, *)` |
| `reduceTransparency` | Dart → native | — | `UIAccessibility.isReduceTransparencyEnabled` / `NSWorkspace.accessibilityDisplayShouldReduceTransparency` |
| `reduceTransparencyChanged` | native → Dart (event) | bool | observe the OS notification, forward it |
| per view: `updateConfig` | Dart → native | `{tint, shape, radius, items?, selectedIndex?}` | tint from §4 for the current reading theme |
| per view: `setSelected` | Dart → native | index | tab bar / segmented controls |
| per view: `onSelected`, `onPressed` | native → Dart | index / id | Flutter performs navigation |
| per view: `getIntrinsicSize` | Dart → native | — | Flutter wraps the platform view in a `SizedBox` of that size |

**Rules for native views**

- Hybrid composition only. The glass must sample the Flutter content behind it, which requires the platform view to be composited above Flutter's layer; verify on device that the backdrop is the live Flutter scene, not a black/empty layer. If the OS refuses to sample across the Flutter layer, that element falls back to `drawn` (capability check per element, cached).
- One native view per chrome element; never a native view inside a scrolling Flutter list item.
- Safe-area insets: native tab bar/pill handles the bottom inset itself; Flutter passes `viewPadding` so the two agree.
- Text on native glass is drawn natively with the app's fonts (bundle Amiri / IBM Plex Sans Arabic in the runner; `UIFont` names registered via `Info.plist` `UIAppFonts`). RTL: set `semanticContentAttribute = .forceRightToLeft` from Flutter's `Directionality`.
- Dark mode: pass the reading theme explicitly; do **not** let the native view follow `traitCollection`, or Sepia would render as light glass with the wrong tint.

### 5.3 Drawn implementation (everything else)

Recipe per `GlassTokens` (top to bottom, all inside one `ClipRRect(shape)`):

1. `BackdropFilter(filter: ImageFilter.compose(outer: blur(σ = blur/2.4), inner: ColorFilter.matrix(saturation × brightness)))` — compose both into one filter, one backdrop pass.
2. Tint layer: `DecoratedBox(color: tint)`.
3. Highlight: a 1 px inset top stroke at `glass.highlight`, plus an optional refraction highlight — a `FragmentShader` (`glass_highlight_shader.frag`) drawing a soft specular band along the top-leading edge. Ship without the shader first; add it only if it measures under 1 ms/frame on a mid-range Android (Impeller).
4. Outer stroke `glass.stroke`, outer shadow `glass.shadow`.

Do **not** depend on a third-party glass package for the drawn path — the recipe is 60 lines and the tokens must match §4 exactly.

Web: `BackdropFilter` works on CanvasKit and Skwasm; on the HTML renderer it is unreliable — the web build already uses CanvasKit/Skwasm, keep it that way.

## 6. Performance rules (drawn path)

- **Max two live backdrop layers per screen** (e.g. reader top bar + bottom pill). Sheets replace, not add: when a glass sheet opens, the bar under it is repainted opaque for the duration.
- Never nest a `BackdropFilter` inside another.
- Glass chrome is `RepaintBoundary`-wrapped; the scrolling content under it is its own boundary.
- **Governor:** measure the first 120 frames after the style is switched to glass or the app launches in glass. If > 10 % of frames exceed 16 ms (or 8 ms on 120 Hz displays), the capability downgrades to `frosted` for the session and a one-time, dismissible notice explains it («تم تبسيط الزجاج للحفاظ على سلاسة التصفح»). The user's setting is not changed.
- Battery saver on (Android `isPowerSaveMode`, iOS `isLowPowerModeEnabled`) → `frosted` for the session.
- Blur radius scales with `devicePixelRatio` only up to 3×; beyond that clamp.

## 7. Accessibility

- OS **Reduce Transparency** → capability `frosted` (both native and drawn; native glass already honours it, but the Dart side must switch to the frosted tokens for foreground contrast).
- Contrast: all foreground colours in §4 are checked against the *worst-case* backdrop (a page of ink text at 18 px behind the glass). Minimum 4.5:1 for labels, 3:1 for 24 px+ numerals. If a screen cannot guarantee it, the active capsule (`glass.activeCapsule`) is raised to 24 % behind that label.
- Reduce Motion → no morph animation on the style switch, no capsule slide on tab change.
- Screen readers: chrome semantics identical in both styles (same `Semantics` labels; native views expose the same `accessibilityLabel`s).

## 8. Switching behaviour

- The switch is immediate, no restart. Chrome cross-fades over 220 ms (skipped under Reduce Motion).
- Native path: platform views are created lazily per screen the first time it is shown in glass; switching back to Manuscript disposes them.
- The reading theme picker keeps working independently; changing the theme while in glass re-tints every live glass surface via `updateConfig` (native) or a token rebuild (drawn).
- On a fresh install the style is `manuscript`. On sign-in, the synced value wins over the local default (SPEC-022 merge), not over a local explicit choice made after install (LWW on `updatedAt`).

## 9. Screens to update (checklist)

| Screen | Chrome that becomes glass | Board |
|---|---|---|
| Home (SPEC-023) | floating tab bar, profile button, continue-reading card | GlassHome |
| Catalog / search (SPEC-005) | search field, category chips row, tab bar | GlassCatalog |
| Library, Downloads | tab bar, sort/filter pill | — (same components) |
| Reader (SPEC-005) | top bar, bottom page-nav pill, TOC sheet, font sheet | GlassReader, GlassReaderNight |
| Settings (SPEC-016) | new "interface style" picker; tab bar | GlassSettings |
| Download snackbar (SPEC-020) | snackbar surface | — |
| Profile (SPEC-024) | tab bar, sync sheet | — |
| iPad / desktop reader | top bar + bottom pill only (no floating tab bar; sidebar stays opaque) | — |

## 10. Acceptance criteria

1. Settings → Appearance shows «نمط الواجهة» with المخطوطة / الزجاج; changing it restyles chrome on every screen without restart; the choice survives relaunch and syncs to a second signed-in device.
2. On an iPhone/iPad/Mac running OS 26+, the tab bar, reader bars and sheets are native platform glass (verify with Xcode's view debugger: `UIGlassEffect` / `.glassEffect` present) and the backdrop is the live Flutter content.
3. On the same devices below OS 26, and on Android/web/desktop, the drawn recipe renders and matches the GlassTokens board within visual tolerance (side-by-side screenshot review, light + sepia + night).
4. Body text is never rendered over a translucent surface, in either style.
5. Reduce Transparency on → frosted chrome, no blur, all labels still ≥ 4.5:1.
6. Reader scroll in glass on a mid-range Android (e.g. 2023 A-series) keeps ≥ 90 % of frames under 16 ms; otherwise the governor downgrades to frosted and shows the one-time notice.
7. RTL layout, Arabic fonts and semantics are identical in native and drawn chrome.
8. Manuscript style is byte-for-byte unchanged (golden tests for the existing chrome pass unmodified).

## 11. Test matrix

| | iOS 26 | iOS 17/18 | macOS 26 | Android (mid) | Android (low) | Web (Chrome/Safari) |
|---|---|---|---|---|---|---|
| Capability expected | native | drawn | native | drawn | drawn → frosted (governor) | drawn |
| Reduce Transparency | frosted | frosted | frosted | frosted | frosted | n/a → drawn |
| Light / Sepia / Night | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## 12. Out of scope

Glass on marketing assets and App Store screenshots; Windows Mica/Acrylic native materials (drawn glass is used there); per-screen opt-out for users; an app-level transparency slider; morphing glass transitions between screens (Apple's `glassEffectID` morphs) — candidate follow-up once the native path is stable.