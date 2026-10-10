# SPEC-031 — Web Google & Apple sign-in

**Status:** Withdrawn by ADR-004 and SPEC-032. Web Google and Apple sign in through Firebase Auth. The operator checklist below is not the client session. · **Depends on:** ADR-003, SPEC-027 §5.1, SPEC-028 §7 · **Deliverable:** superseded. The web app does not post a Google ID token or an Apple identity token to `POST /v1/auth/*`.

## Problem

Native Google and Apple sign-in still call `google_sign_in` and `sign_in_with_apple`, then `POST /v1/auth/google` and `POST /v1/auth/apple`. The web build does not finish that handoff:

- `signInApple()` never passes `WebAuthenticationOptions`. On web the plugin reads `clientId` from that object and throws.
- `app/web/index.html` does not load Apple’s JS (`appleid.auth.js`). Without it, `AppleID.auth` is missing.
- The web Google client ID is only passed from Dart. The page has no `google-signin-client_id` meta tag, which `google_sign_in_web` reads before Dart runs.

The Railway API is already up and allows `https://app.ishamela.online`. This spec does not change the API contract. Email OTP is unchanged.

## Client IDs

One copy of each public client ID, in `app/lib/core/config.dart`. These are OAuth client identifiers, not secrets.

| Constant | Value |
|---|---|
| `googleWebClientId` | `940987204287-i32s08v3mlpngvn98v58q133m2h5kpt3.apps.googleusercontent.com` |
| `googleIosClientId` | `940987204287-638kvo2uo56bj712ospf2cso3prhfvpq.apps.googleusercontent.com` |
| `googleAndroidClientId` | `940987204287-05mer02npo5b9t0i8c901j6aitooincf.apps.googleusercontent.com` |
| `appleBundleId` | `org.ishamela.ishamela` |
| `appleWebServiceId` | `online.ishamela.web` |

`AuthController.signInGoogle` uses `googleWebClientId` as `clientId` on web and as `serverClientId` on every other platform, and `googleIosClientId` as `clientId` on iOS and macOS. Android keeps `clientId: null` (the Android package name selects the client). Scopes stay `email` and `profile`.

## Apple on the web

`app/web/index.html` `<head>` includes:

```html
<script type="text/javascript" src="https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js"></script>
<meta name="google-signin-client_id" content="940987204287-i32s08v3mlpngvn98v58q133m2h5kpt3.apps.googleusercontent.com">
```

The meta content is `googleWebClientId`. The Apple script is the one `sign_in_with_apple` requires; it loads on every web page. A failure to load it does not block reading.

`signInApple()` on web passes:

```dart
WebAuthenticationOptions(
  clientId: appleWebServiceId,
  redirectUri: appleWebRedirectUri(Uri.base),
)
```

On iOS and macOS, `webAuthenticationOptions` stays null. Android still has no Apple button (`supportsAppleSignIn` is unchanged).

`appleWebRedirectUri` and `appleWebRedirectIsPublic` live in a file with no plugin import, so tests can call them.

`appleWebRedirectUri(page)` returns `page` with query and fragment removed, default ports 80 and 443 omitted, and `path` ending in `/`. An empty path becomes `/`.

Examples:

| Page | Redirect URI |
|---|---|
| `https://app.ishamela.online/` | `https://app.ishamela.online/` |
| `https://app.ishamela.online/#/auth` | `https://app.ishamela.online/` |
| `https://yassercherfaoui.github.io/iShamela/` | `https://yassercherfaoui.github.io/iShamela/` |
| `https://yassercherfaoui.github.io/iShamela/#/auth` | `https://yassercherfaoui.github.io/iShamela/` |

`appleWebRedirectIsPublic` is true only for `https` whose host is not `localhost`, `127.0.0.1`, or `::1`. On web, if it is false, `signInApple()` throws `AuthUnavailable` and does not open Apple’s popup. Apple rejects localhost return URLs.

The identity token is still posted with `signInWithApple` exactly as on iOS. Name patching after sign-in is unchanged.

## Operator checklist

Code cannot register these. Sign-in stays broken until they are set.

Google Cloud → the web OAuth client (`googleWebClientId`) → Authorized JavaScript origins:

- `https://app.ishamela.online`
- `https://yassercherfaoui.github.io`

Apple Developer → Services ID `online.ishamela.web` → Sign in with Apple:

- Domains: `app.ishamela.online`, `yassercherfaoui.github.io`
- Return URLs: `https://app.ishamela.online/`, `https://yassercherfaoui.github.io/iShamela/`

Railway API environment (SPEC-027 §3):

- `GOOGLE_CLIENT_IDS` = the three Google IDs above, comma-separated. Web tokens carry the web client in `aud`; iOS tokens carry the iOS client.
- `APPLE_CLIENT_IDS` = `org.ishamela.ishamela,online.ishamela.web`. A web Apple token’s `aud` is the Services ID, not the bundle ID.
- `CORS_ORIGINS` includes `https://app.ishamela.online` (already) and `https://yassercherfaoui.github.io` if Pages should sign in.

## Acceptance criteria

- [x] `googleWebClientId` is the only web client ID string in `auth_controller.dart` and `web/index.html` (the HTML meta matches the constant; a test reads the file).
- [x] `index.html` loads `appleid.auth.js`.
- [x] Unit tests cover the four redirect examples above, a non-public localhost URI, and trailing-slash normalization.
- [x] `signInApple()` passes `WebAuthenticationOptions` only when `kIsWeb` is true.
- [x] `flutter analyze` and `flutter test` pass. No new pub dependency.

## Out of scope

- Email OTP, session refresh, and the sync outbox.
- Replacing `google_sign_in` or `sign_in_with_apple`.
- Removing Firebase packages (SPEC-028).
- A custom Apple redirect page. Popup mode uses the app origin.
- Android Apple sign-in.
