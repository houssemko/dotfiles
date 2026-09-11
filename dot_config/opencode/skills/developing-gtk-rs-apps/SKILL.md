---
name: developing-gtk-rs-apps
description: Use when building GTK 4/libadwaita apps in Rust (gtk-rs); before writing UI code, app boilerplate, or reviewing for GNOME HIG compliance; when debugging threading, signals, lifecycle, GSettings, actions, packaging; when solving Rust ownership, lifetimes, error handling, or async issues in GTK apps.
---

# Developing gtk-rs Apps

Build robust GTK 4/libadwaita apps in Rust the best way. One skill, three layers: Rust foundation → GTK architecture → GNOME UI.

**Core principles:**
1. No UI code without design decisions (pattern first, code second).
2. Foundation before UI — lifecycle, threading, and resource bugs kill most GTK apps.
3. Idiomatic Rust — borrow over clone, `Result` over panic, `cargo clippy` clean.

**Stacks and replaces:** `designing-gnome-ui` + `developing-gtk-apps` + `rust-engineer` + `rust-skills` (for gtk-rs work, use this skill alone; the sources remain as deep references, see bottom).

## Router

| Task | Section |
|------|---------|
| Which widget / layout / HIG pattern? | UI & HIG |
| App crashes on startup, freezes, signal leak | Architecture |
| Save prefs, actions, shortcuts, resources, Flatpak | Architecture |
| Ownership / borrow checker / lifetimes in callbacks | Rust for gtk-rs |
| `Result`/`Option`, thiserror/anyhow, async | Rust for gtk-rs |
| New boilerplate / project setup | Start here |

## 0. Start here — versions + scaffold

Resolve latest stable first, never hardcode. Check system packages / Flathub runtime / crates.io for `gtk4`, `libadwaita`, `glib`, `gio`.

```toml
[dependencies]
gtk = { version = "0.x", package = "gtk4" }
adw = { version = "0.x", package = "libadwaita" }
gio = "0.x"
glib = "0.x"
anyhow = "1"
thiserror = "2"
tracing = "0.1"
```

```rust
use adw::prelude::*;
use gtk::{gio, glib};

fn main() -> glib::ExitCode {
    let app = adw::Application::builder()
        .application_id("com.example.App") // reverse-domain, ≥2 segments, matches .desktop
        .build();
    app.connect_activate(build_ui);
    app.run()
}

fn build_ui(app: &adw::Application) {
    let window = adw::ApplicationWindow::builder()
        .application(app)
        .default_width(800)
        .default_height(600)
        .build();
    window.present();
}
```

Lifecycle: `startup` (actions, CSS, GSettings — chain up first) → `activate` (create/present window) → `shutdown` (save state) → `open` (file args).

## 1. Rust for gtk-rs (condensed rust-engineer + rust-skills)

Apply full `rust-skills` rules; these are the ones gtk-rs violates most:

- `own-borrow-over-clone` / `own-slice-over-vec`: `&str` not `&String`, `&[T]` not `&Vec<T>`. Exception: GTK objects are ref-counted (`clone!(@weak)`, see below) — that clone is cheap and required.
- `err-no-unwrap-prod` / `err-result-over-panic`: no `unwrap()` in production; `?` + `thiserror` (libs) / `anyhow` (app bins, with `.context()`). Error strings lowercase, no trailing punctuation.
- `async-no-lock-await` / `anti-lock-across-await`: never hold `Mutex`/`RwLock` across `.await`. In GTK also never block the main thread.
- `closure-move-capture` / `closure-fn-trait-bounds`: `move` closures that outlive scope; weakest `FnOnce/FnMut/Fn` bound that fits.
- `api-parse-dont-validate`, `type-newtype-ids`: parse/validate at boundaries (app IDs, GSettings keys, file paths).
- `obs-tracing-over-log`: `tracing`, never `println!` in app code.

Validate every change:

```bash
cargo fmt --check
cargo clippy --all-targets --all-features
cargo test
```

Fix all clippy warnings before finishing. Details live in sibling skills — don't duplicate, read them: `../rust-skills/rules/` (265 rules), `../rust-engineer/references/` (ownership, traits, error-handling, async, testing).

## 2. Architecture (gtk-rs plumbing)

### Threading — the critical rule

GTK is single-threaded. All UI calls on the main thread.

```rust
use gtk::glib;

// WRONG: touching widgets from a worker thread → crash.
// RIGHT: hop back via idle_add, or stay on main loop with spawn_future_local.
glib::spawn_future_local(async move {
    let result = gio::spawn_blocking(slow_computation).await.unwrap();
    label.set_text(&result);
});
```

- Never `std::thread::sleep` / blocking I/O on main thread. CPU/blocking work → `gio::spawn_blocking` (or `glib::MainContext::spawn`), UI update in `spawn_future_local` / `idle_add`.
- For cancellable work use `gio::Cancellable` (see `../developing-gtk-apps` patterns).

### Weak refs in callbacks — the gtk-rs ownership pattern

```rust
use gtk::glib::clone;

button.connect_clicked(clone!(
    #[weak] window,
    #[weak] toast_overlay,
    move |_| {
        window.close();
        toast_overlay.add_toast(adw::Toast::new("Saved"));
    }
));
```

`#[weak]` = downgrade, breaks ref cycles. `#[strong]` only when you mean shared ownership. If the object may be gone, the closure just doesn't run.

### Actions + shortcuts

```rust
// app-level (in startup / activate setup)
let quit = gio::SimpleAction::new("quit", None);
quit.connect_activate(clone!(#[weak] app, move |_, _| app.quit()));
app.add_action(&quit);
app.set_accels_for_action("app.quit", &["<Control>q"]);

// window-level
let save = gio::SimpleAction::new("save", None);
save.connect_activate(|_, _| { /* ... */ });
window.add_action(&save);
app.set_accels_for_action("win.save", &["<Control>s"]);
```

Stateful toggles / parameterized actions: same API with `SimpleAction::new_stateful` / `new` + `VariantTy`. Menus bind to `app.*` / `win.*` names.

### GSettings

```rust
let settings = gio::Settings::new("com.example.App");
settings.bind("window-width", &window, "default-width", gio::SettingsBindFlags::DEFAULT);
let dark = settings.boolean("dark-mode");
settings.connect_changed(Some("dark-mode"), |s, _| { /* react */ });
```

Schema XML + install/compile steps: unchanged from `../developing-gtk-apps` — follow it.

### Debug

```bash
GTK_DEBUG=interactive myapp      # Inspector (Ctrl+Shift+D)
G_MESSAGES_DEBUG=all myapp
G_DEBUG=fatal-criticals myapp    # abort on criticals
GSETTINGS_BACKEND=memory myapp   # no-persist test run
```

## 3. UI & HIG (designing-gnome-ui, gtk-rs flavor)

Process: 1. Context (goal, app type, constraints) → 2. Patterns (containers, navigation, controls, feedback) → 3. Details (type, spacing, icons, copy) → 4. Checklist below → implement.

Current API (libadwaita 1.6–1.8): `AdwToggleGroup` (exclusive toggles), `AdwSpinner` (not `GtkSpinner`), `AdwBottomSheet`, `AdwWrapBox`, `AdwInlineViewSwitcher`, `AdwShortcutsDialog` (not `GtkShortcutsWindow`). `.dimmed` class (not `.dim-label`). Accent color + system fonts automatic via portal/`AdwStyleManager`.

### Containers / navigation / controls

| Scenario | Default |
|----------|---------|
| App window | `AdwApplicationWindow` + `AdwHeaderBar` (~800×600, remember size) |
| Settings | `AdwPreferencesWindow` (groups, search, subpages) |
| List of items | `AdwPreferencesGroup` + rows (boxed list) |
| 2–4 views | `AdwViewSwitcher` in header |
| Many/dynamic | `AdwNavigationSplitView` |
| Hierarchical | `AdwNavigationView` |
| On/Off | `AdwSwitchRow` |
| Choose one | `AdwComboRow` (+ search when long) |
| Text / number / date | `AdwEntryRow` / `AdwSpinRow` / `GtkCalendar` in popover |
| Action in list | `AdwActionRow` + one suffix button |
| Search | `GtkSearchBar` + toggle, `Ctrl+F`, type-to-search |
| Settings/preferences list | `AdwPreferencesGroup` |
| Large/dynamic data | `GtkListView` + `SingleSelection`/`MultiSelection` (virtualized) |
| Grid | `GtkGridView` |

Validation: `.error` CSS class + tooltip on invalid; format checks on change, expensive on focus-out, final on submit.

### Feedback

| Scenario | Default |
|----------|---------|
| Done / recoverable error | `AdwToast` (+ Undo for destructive — prefer over confirm dialog) |
| Persistent state (offline, degraded, auth) | `AdwBanner` |
| Needs decision / blocking error | `AdwDialog`, verbs not OK/Yes ("Delete"), cancel left, action right, `destructive-action` class |
| Short wait <5s | `AdwSpinner` |
| Long >30s | Progress + "13 of 42 processed" |
| Empty list | `AdwStatusPage` (icon + title + description + action) + `GtkStack` switch |
| Right-click | `GtkPopoverMenu`, keep short |

Escalation: Toast (transient) → Banner (persists) → Dialog (action required).

### Icons / copy / style

- Symbolic icons only, from GNOME Icon Library: `list-add-symbolic`, `user-trash-symbolic`, `emblem-system-symbolic`, `open-menu-symbolic`, `system-search-symbolic`, `document-edit-symbolic`, `go-previous/next-symbolic`, `view-refresh-symbolic`, `dialog-warning/error-symbolic`, `emblem-ok-symbolic`, `window-close-symbolic`. Header buttons icon-only + tooltip. Dynamic icons follow state.
- Typography via classes (`title-1`, `heading`, `body`, `caption`), libadwaita spacing defaults, header-case labels / sentence-case descriptions. No custom styling where libadwaita has a pattern. Never text over images.

## 4. Checklists (run before finishing)

**Compliance:** correct container/header structure · navigation matches content · native widgets · symbolic icons · style classes · default spacing · label capitalization.
**Polish:** visual hierarchy · alignment · consistent patterns · empty + loading states (never frozen) · smooth resize · comfortable density.
**Rigor:** keyboard-accessible · accessible names · `GTK_THEME=Adwaita:hc` + 200% text + Orca/screen-reader pass · every input has error handling · empty/long-text/missing-data edges · undo for destructive · works at 800×600.

```bash
GTK_THEME=Adwaita:hc ./target/debug/myapp
# + large text in Settings > Accessibility, Orca, full keyboard-only run
```

```rust
button.update_property(&[gtk::AccessibleProperty::Label], &[&"Add new item"]);
```

## Red flags — STOP

UI thread touched from worker · missing `startup` chain-up · signal handlers never disconnected · blocking call in handler · `sleep` on main thread · `GtkShortcutsWindow` / `GtkSpinner` in adw apps · hardcoded paths (use XDG) · bad/missing app ID · multiple suggested/destructive buttons per view · confirm dialog for reversible action (use undo) · generic labels (OK/Yes/Submit) · missing tooltips on icon buttons · `unwrap()` in production · `#[strong]` captures creating cycles.

## References

Local `references/` are symlinks, not copies — single source of truth, zero drift:
- `ownership.md`, `traits.md`, `error-handling.md`, `async.md`, `testing.md` → `../rust-engineer/references/`
- `own-borrow-over-clone`, `own-slice-over-vec`, `err-no-unwrap-prod`, `err-result-over-panic`, `err-question-mark`, `err-thiserror-lib`, `err-anyhow-app`, `async-no-lock-await`, `anti-lock-across-await`, `async-spawn-blocking`, `closure-move-capture`, `closure-fn-trait-bounds`, `api-parse-dont-validate`, `type-newtype-ids`, `obs-tracing-over-log` → `../rust-skills/rules/` (gtk-rs subset; full 265 in source)

Deep dives (don't duplicate, read):

- `../rust-skills/rules/` — all 265 Rust rules + `SKILL.md` task→category table.
- `../rust-engineer/references/` — ownership, traits, error-handling, async, testing with full examples.
- `../designing-gnome-ui/SKILL.md` — HIG tables, search/validation/filter/grid/selection code, a11y, breakpoints, advanced (DnD, undo, tabs, notifications, media, split views, onboarding, popovers, shortcuts).
- `../developing-gtk-apps/SKILL.md` — lifecycle, `Gio.Task` async + cancellation, stateful/parameterized actions + menus, GSettings schema XML, Blueprint, resources, desktop/AppStream/Meson/Flatpak/icons, testing/i18n/DBus/portals, Inspector/profiling.
- External: [GTK 4 API](https://docs.gtk.org/gtk4/) · [libadwaita API](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1-latest/) · [Blueprint](https://jwestman.pages.gitlab.gnome.org/blueprint-compiler/) · [gtk-rs docs](https://gtk-rs.org/gtk4-rs/stable/latest/docs/) (verify crate names/versions against crates.io).
