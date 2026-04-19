# So Break style guide

Design system for the So Break macOS menu bar app. Part of the AI Wow family.

## Personality

Warm, playful, companionable. So Break is a friendly doge tapping your shoulder, not a system alert or a corporate wellness popup. The escalating copy does the personality work; the visual design supports it with warmth and polish.

## Colour palette

The AI Wow palette. Warm cream foundation with vivid accents used sparingly.

### Surfaces

| Token | Hex | Use |
|-------|-----|-----|
| Paper | `#FFF9E3` | Primary background — the warm cream that defines the brand |
| Paper Dark | `#F2F0E5` | Subtle background variation, radial gradient edges |
| Ink | `#100F0F` | Primary text — near-black with warmth, never pure `#000` |
| Gray | `#878580` | Secondary text, subtle labels, snooze button text |

### Accents

Used at the 10% rule — accents work because they're rare. Each has a specific semantic role.

| Token | Hex | Role |
|-------|-----|------|
| Pink | `#E8368F` | Primary action ("Take a break" button) |
| Orange | `#E8750A` | Warning/countdown — amber timer, overdue states |
| Yellow | `#F0C430` | Reserved — available for future delight moments |
| Cyan | `#14B8A6` | Secondary action ("Lock now" button), grace countdown |
| Purple | `#9B6DD7` | Reserved — available for pomodoro/focus states |

### Colour rules

1. Never use pure black (`#000`) or pure white (`#FFF`). The palette's warmth depends on tinted neutrals.
2. Gray text on the cream background only — never on coloured surfaces. Use a tinted shade of the surface colour instead.
3. The pink and cyan accents carry the most weight. Don't introduce new accent colours without good reason.
4. Dim overlay uses `black` at `0.4` opacity for full interrupts (break alert, nag) and `0.1` for passive reminders (grace countdown).

## Typography

System font only — SF Pro Rounded (`.system(.rounded)`) keeps the app native and avoids bundling font files.

### Type scale

| Element | Size | Weight | Design |
|---------|------|--------|--------|
| Heading (center) | 21pt | Semibold | Rounded |
| Heading (compact) | 15pt | Semibold | Rounded |
| Body / subtitle | 13pt | Regular | Rounded |
| Countdown (center) | 40pt | Light | Rounded, monospacedDigit |
| Countdown (compact) | 28pt | Light | Rounded, monospacedDigit |
| Button label (pill) | 14pt | Semibold | Rounded |
| Button label (text) | 13pt | Medium | Rounded |
| Toast heading | 16pt | Semibold | Rounded |
| Toast body | 14pt | Regular | Rounded |

### Type rules

1. The jump from 13pt body to 21pt heading (1.6x ratio) creates clear hierarchy without needing many sizes.
2. Countdown timers use `.light` weight — the large size carries the emphasis, the light weight keeps them from overpowering.
3. All text is multiline-safe. Headings centre-align in the full layout, left-align in compact.
4. Messages max at ~40 characters per line at current widths — well within comfortable reading range.

## Spacing

A 4pt base with intentional rhythm — not uniform padding everywhere.

### Key dimensions

| Element | Value | Notes |
|---------|-------|-------|
| Center window | 420 x 420pt | Square — feels intentional, not arbitrary |
| Compact window | 340 x 130pt | Wide strip for top-of-screen positioning |
| Toast window | 340 x 104pt | Matches compact width for visual consistency |
| Corner radius | 16pt | All windows and containers |
| Outer padding (center) | 32pt horizontal | Text breathing room |
| Outer padding (compact) | 20pt left, 16pt right | Tighter for the compact strip |
| Section gap (center) | 20pt | Between doge, text, countdown, buttons |
| Button gap | 14pt horizontal, 10pt vertical | Between pill buttons and between pill/text rows |

### Spacing rules

1. The doge gets generous space above and below — it's the visual anchor, not a sidebar icon.
2. Tighter spacing between subtitle and heading (they're a unit). Wider spacing before buttons (they're a separate decision).
3. The compact layout uses 16pt vertical padding — just enough to not feel cramped.

## Components

### Doge display

The doge illustrations are transparent PNGs designed as bust/full-body characters. Display them at their natural proportions — never clip to a circle or constrain to a square frame.

- **Center layout**: 120pt wide, aspect-fit, with a subtle drop shadow (`y: 4, radius: 8, opacity: 0.10`)
- **Compact layout**: 64pt wide, aspect-fit, same shadow treatment
- **Toast**: 56pt wide, aspect-fit

The warm cream background naturally complements the doge's colour palette (golden fur, pink cheeks). No backing shape needed.

### Pill buttons

Capsule-shaped with solid fill colour. No gradients — the flat colour is cleaner against the textured cream background.

- **Primary (pink)**: Solid `#E8368F` fill, white text, subtle shadow (`color: pink at 0.25 opacity, y: 3, radius: 6`)
- **Secondary (cyan)**: Solid `#14B8A6` fill, white text, same shadow treatment
- **Padding**: 26pt horizontal, 11pt vertical
- **Hover**: Scale to 1.04x with a spring animation (response: 0.3, damping: 0.6)
- **Press**: No additional state needed — the spring bounce on hover communicates interactivity

### Text buttons

Plain text for secondary actions (snooze, "5 more minutes"). Gray colour, medium weight. Disabled state at 0.4 opacity. No underline, no border — the pill buttons above establish context.

### Overlay window

- Borderless, transparent background
- Level: screensaver window (above everything)
- Movable by window background (user can drag it)
- 16pt corner radius with a 1pt border at `black 0.08` opacity
- Shadow: ink colour at 0.08 opacity, 30pt radius, 12pt y-offset
- Joins all spaces, works in fullscreen

### Toast (confirmation)

Same visual treatment as the compact overlay but at floating window level (not screensaver). Auto-dismisses after 2 seconds. Plays the "Blow" system sound.

## Animation

### Entrance

Overlays appear with a gentle spring: scale from 0.92 to 1.0, opacity from 0 to 1, over ~0.4s with light damping. This replaces an instant pop-in and makes the app feel crafted.

### Hover

Pill buttons scale to 1.04x on hover with a spring (response: 0.3, damping: 0.6). Subtle but responsive.

### Countdown

The countdown timer updates every second with no animation on the text change — the monospacedDigit modifier prevents layout jitter.

### Rules

1. Prefer `transform` and `opacity` — never animate layout properties directly.
2. Use exponential easing (spring with moderate damping). No bounce or elastic.
3. Respect `prefers-reduced-motion` if macOS provides it — degrade to instant transitions.
4. One well-executed entrance is better than scattered micro-interactions.

## Menu bar states

The menu bar icon communicates state through symbol and colour, never text labels longer than 3 characters.

| State | Display | Colour |
|-------|---------|--------|
| Working (normal) | `●` | Label colour (adapts to light/dark menu bar) |
| Warning (5 min left) | `5m` | System orange, monospacedDigit semibold |
| Break overdue | `●` | System red, bold |
| Grace countdown | `2:00` | Vivid cyan (#14B8A6), monospacedDigit semibold |
| Screen locked | Sun emoji | Default |

## Interaction principles

1. **One decision at a time.** The break alert presents two choices: take a break or snooze. Nothing else.
2. **Escalation through copy, not chrome.** The visual design stays consistent as messages escalate. The doge expression and message text do the emotional work.
3. **Snooze requires a beat.** The snooze button is disabled for a few seconds after the alert appears — prevents reflexive dismissal. The countdown label communicates the delay.
4. **Grace period is gentle.** Lower dim opacity (0.1 vs 0.4), compact top-of-screen position, no sound. You said you'd take a break — we believe you.
5. **Lock screen resets everything.** The simplest possible feedback loop: lock your screen, timer resets. No tracking, no stats, no guilt.
