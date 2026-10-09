# Hotwire Native readiness

Read this when the app ships, or will ship, Hotwire Native iOS or Android shells. Hotwire Native (1.3 in 2026) replaces Turbo Native and Strada: "Strada components" are now Bridge Components from `@hotwired/hotwire-native-bridge`.

## What the Rails app does

- **Detect the app:** `hotwire_native_app?` (controller and view helper; matches "Hotwire Native" or "Turbo Native" in the user agent; `turbo_native_app?` is the old name). Prefer CSS over many conditionals: put a platform marker on `<html>` (`data-platform="native ios"`) and hide web-only chrome with CSS.
- **Titles:** the native screen title comes from `<title>`; give every page a good one and hide the duplicate `<h1>` on native.
- **Navigation after forms:** `recede_or_redirect_to`, `refresh_or_redirect_to`, `resume_or_redirect_to` (and `_back_or_to` variants) close or refresh native screens and redirect normally on the web. Forms keep returning 422 on failure and 303 on success.
- **Path configuration:** serve versioned JSON per platform (`/configurations/ios_v1.json`), cached briefly, and bundle a copy in the app. Rules match URL patterns in order; common properties: `context` (`default`, `modal`), `presentation` (`push`, `replace`, `replace_root`, `clear_all`, `refresh`, `none`), `pull_to_refresh_enabled`. Present `/new` and `/edit` as modals. Version the file name for breaking changes and keep old versions online.
- **Bridge components:** Stimulus controllers that extend `BridgeComponent` (`static component = "form"`), in `app/javascript/controllers/bridge/`. Hide the web element only when the app supports the component (the user agent lists supported components).
- **Sessions:** cookie sessions that survive an app relaunch ("remember me" for app sign-ins).
- **Every screen has a URL.** Tabs, wizards, and dialogs that are reachable only by client-side state do not work in native shells; the same discipline as the rest of this skill.
- Avoid hover-only UI and `target="_blank"` assumptions.
