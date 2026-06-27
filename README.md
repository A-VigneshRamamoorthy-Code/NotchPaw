# 🐾 NotchPaw

**A playful critter lives under your MacBook notch.** When your cursor wanders up
near the notch, an animal paw (or tail!) springs out and tries to *catch* it —
with fluid, springy, genuinely animal-like motion. Move away and it tucks back
in, sleeping at **0% CPU**.

NotchPaw is a tiny, native macOS app. No Dock icon, no menu-bar clutter — it just
hides under the notch until you come to play.

---

## ✨ Features

- **Catches your cursor** — a Verlet-rope limb springs from the notch point
  nearest your pointer and bats at it with real spring physics.
- **It's alive** — the critter keeps acting even when your cursor is still
  (anticipation → strike → follow-through → pause), built on real animation
  principles, not a simple zoom.
- **7 critters, each with its own personality:**
  🐱 Cat · 🐶 Dog · 🐰 Bunny · 🦊 Fox · 🐻 Bear · 🐈 Cat tail · 🦊 Fox tail
- **Pick your critter** — hover the notch (the cursor turns into a contextual
  menu) and click for a polished picker with live thumbnails. Your choice is
  remembered.
- **Featherweight** — **0% CPU when idle**, ~4–6% only while actively playing
  (capped at 30fps), ~35 MB RAM.
- **Invisible by design** — runs as an agent (`LSUIElement`): no Dock icon, no
  menu-bar icon. It never blocks your clicks — only the small notch zone is
  interactive.
- **Native & dependency-free** — pure Swift + AppKit/CoreGraphics. All art is
  drawn in code (including the app icon).

---

## 📸 Screenshots
<!-- Add screenshots or a GIF of the paw catching the cursor here -->
_(Coming soon — drop a GIF of the paw in action.)_

---

## ⬇️ Download
👉 **[Download the latest release](https://github.com/VigneshRamamoorthy1992/NotchPaw/releases/latest)**

Requires macOS 14 or later (Apple Silicon or Intel).

---

## 🚀 Install
1. Download `NotchPaw.dmg`.
2. Open it.
3. Drag **NotchPaw** into **Applications**.
4. Right-click NotchPaw → **Open** (first launch only).

Move your cursor up to the notch to wake the critter. **Hover the notch and
click** to switch animals or quit.

---

## ⚠️ macOS Warning
NotchPaw is open-source and ad-hoc signed (not notarized), so macOS may block the
first launch:

> **Right-click NotchPaw → Open → Confirm**

You only need to do this once.

---

## 🛠 Build from source
No Xcode required — just the Swift toolchain (Command Line Tools are enough).

```bash
git clone https://github.com/VigneshRamamoorthy1992/NotchPaw.git
cd NotchPaw
./scripts/build_app.sh release      # → build/NotchPaw.app
./scripts/make_dmg.sh               # → NotchPaw.dmg (optional)
```

Run the tests and preview the art headlessly:

```bash
swift run notchpaw-selftest         # pure-logic checks
swift run NotchPaw --contact /tmp   # animation contact sheets
swift run NotchPaw --appicon /tmp/icon.png
```

### Project layout
- `Sources/NotchPawCore/` — pure, testable engine: gesture system, Verlet-rope
  physics, per-animal styles, and all CoreGraphics drawing.
- `Sources/NotchPaw/` — the AppKit app: transparent notch overlay, mouse
  tracking, the picker menu, and the app lifecycle.
- `Sources/notchpaw-selftest/` — a no-XCTest assertion harness.
- `scripts/` — `build_app.sh` (assemble the `.app`) and `make_dmg.sh`.

---

## ❤️ Feedback
Found a bug or want a new critter? **Open an issue** — and if NotchPaw made you
smile, **star the repo** ⭐
