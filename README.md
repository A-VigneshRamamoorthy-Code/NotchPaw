<div align="center">

# 🐾 NotchPaw

### A playful critter lives under your MacBook notch — and it wants to play.

Sweep your cursor toward the notch and a furry paw (or a swishing tail) springs
out to *catch* it, with fluid, springy, genuinely animal-like motion.
Wander off and it curls back up to sleep at **0% CPU**.

<br/>

[![Download for macOS](https://img.shields.io/badge/Download%20for%20macOS-NotchPaw.dmg-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/A-VigneshRamamoorthy-Code/NotchPaw/releases/latest/download/NotchPaw.dmg)

**Free · Open-source · macOS 14+ · Apple Silicon &amp; Intel**

</div>

---

<div align="center">

### 🎬 See it in action

[![NotchPaw demo — click to watch the full video with sound](assets/NotchPaw_demo.gif)](https://github.com/A-VigneshRamamoorthy-Code/NotchPaw/blob/main/assets/NotchPaw_Launch.mp4)

<sub>▶ The looping preview above plays for everyone — <b><a href="https://github.com/A-VigneshRamamoorthy-Code/NotchPaw/blob/main/assets/NotchPaw_Launch.mp4">click it for the full-quality video with sound</a></b>.</sub>

</div>

---

## ⬇️ Get NotchPaw

<div align="center">

### 👉 **[Download NotchPaw.dmg](https://github.com/A-VigneshRamamoorthy-Code/NotchPaw/releases/latest/download/NotchPaw.dmg)**

</div>

You're three steps from playing:

1. **Open** the downloaded `NotchPaw.dmg`.
2. **Drag NotchPaw** into your **Applications** folder.
3. **Right-click NotchPaw → Open** the first time (see [First launch](#️-first-launch-on-macos) below).

Now sweep your cursor up to the notch to wake the critter. **Hover the notch and
click** to switch animals or quit. No setup, no account, no menu-bar clutter.

> Looking for older builds? Browse **[all releases](https://github.com/A-VigneshRamamoorthy-Code/NotchPaw/releases)**.

---

## ✨ Why you'll love it

- 🐾 **It catches your cursor.** A Verlet-rope limb springs from the notch point
  nearest your pointer and bats at it with real spring physics.
- 🎭 **It's actually alive.** The critter keeps acting even when your cursor is
  still — anticipation → strike → follow-through → pause — built on real
  animation principles, not a cheap zoom.
- 🐱 **7 critters, each with personality.** Pick your favorite from a polished
  menu with live thumbnails — your choice is remembered.
- 🪶 **Featherweight.** **0% CPU when idle**, ~4–6% only while actively playing
  (capped at 30 fps), ~35 MB RAM.
- 👻 **Invisible by design.** Runs as a background agent — no Dock icon, no
  menu-bar icon. It never blocks your clicks; only the tiny notch zone is live.
- 🛠️ **Native &amp; dependency-free.** Pure Swift + AppKit/CoreGraphics. Every
  pixel of art (including the app icon) is drawn in code.

---

## 🐾 Meet the critters

🐱 **Cat** · 🐶 **Dog** · 🐰 **Bunny** · 🦊 **Fox** · 🐻 **Bear** · 🐈 **Cat tail** · 🦊 **Fox tail**

Hover the notch (your cursor turns into a little menu indicator) and click to
switch any time.

---

## ⚠️ First launch on macOS

NotchPaw is open-source and ad-hoc signed (not yet notarized), so macOS
Gatekeeper may block the very first open:

> **Right-click NotchPaw → Open → Confirm.**

You only need to do this once. Requires **macOS 14 (Sonoma) or later**, Apple
Silicon or Intel.

---

## ❤️ Love it?

If NotchPaw made you smile, **[⭐ star the repo](https://github.com/A-VigneshRamamoorthy-Code/NotchPaw)** —
it genuinely helps. Found a bug or want a new critter?
**[Open an issue](https://github.com/A-VigneshRamamoorthy-Code/NotchPaw/issues)**.

---

<details>
<summary><b>🧑‍💻 Build from source (for developers)</b></summary>

<br/>

No Xcode required — just the Swift toolchain (Command Line Tools are enough).

```bash
git clone https://github.com/A-VigneshRamamoorthy-Code/NotchPaw.git
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

**Project layout**

- `Sources/NotchPawCore/` — pure, testable engine: gesture system, Verlet-rope
  physics, per-animal styles, and all CoreGraphics drawing.
- `Sources/NotchPaw/` — the AppKit app: transparent notch overlay, mouse
  tracking, the picker menu, and the app lifecycle.
- `Sources/notchpaw-selftest/` — a no-XCTest assertion harness.
- `scripts/` — `build_app.sh` (assemble the `.app`) and `make_dmg.sh`.

</details>

<div align="center">
<sub>Made with 🐾 and Swift.</sub>
</div>
