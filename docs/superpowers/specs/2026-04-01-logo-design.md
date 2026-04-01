# Trays Social -- Logo Design Spec

## Overview

The Trays Social logo is a stylized lunch tray icon with three compartments, paired with the "trays" wordmark. Inspired by American/Korean school cafeteria trays, the design uses the V2 layout: a circular bowl (bottom-left), a small rectangular section (top-left), and a tall rectangular section (right).

## Design Decisions

- **Layout:** V2 asymmetric tray with circular bowl -- chosen for its real-world lunch tray feel
- **Style:** Flat solid fills only -- no gradients, no shadows, no tier system. One version for all contexts
- **Compartment sizing:** Tightened from original V2 to fill more of the tray interior (midpoint between original and edge-to-edge)
- **Color mapping follows role hierarchy:** Primary = largest section, Accent = focal circle, Secondary = supporting rect

## Color Palette (Modern Kitchen)

| Compartment | Color | Hex | Role |
|---|---|---|---|
| Tray border (stroke) | Emerald Light | `#2E7D32` | Primary Light |
| Top-left rect | Mint Whisper | `#A5D6A7` | Secondary |
| Bottom-left circle (bowl) | Golden Amber | `#FFB300` | Accent |
| Right tall rect | Emerald Chef | `#1B5E20` | Primary |

## Canonical SVG

### Icon Mark (56x56 viewBox)

```svg
<svg viewBox="0 0 56 56" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="3" y="6" width="50" height="44" rx="10" stroke="#2E7D32" stroke-width="2.5" fill="none"/>
  <rect x="7.5" y="10.5" width="18.5" height="13.5" rx="5" fill="#A5D6A7"/>
  <circle cx="17" cy="36" r="8" fill="#FFB300"/>
  <rect x="29" y="10.5" width="19.5" height="34" rx="5" fill="#1B5E20"/>
</svg>
```

### Wordmark

- Font: Instrument Serif (Google Fonts)
- Weight: 400 (Regular)
- Text: "trays" (lowercase)
- Color: `#212121` on light backgrounds, `#E0E0E0` on dark backgrounds
- Letter-spacing: -0.01em

### Full Logo (Icon + Wordmark)

Icon placed to the left of the wordmark with 10-16px gap depending on size. Icon and wordmark vertically centered.

## Usage Contexts

### App Icon

- Full-color logo on `#FAFAFA` background
- Rounded corners (22% border-radius, per platform convention)
- Logo scaled to fill the icon with minimal padding

### Website Header

- Icon (36px wide) + wordmark, left-aligned in nav bar
- Light mode: icon as-is, wordmark `#212121`
- Dark mode: icon as-is, wordmark `#E0E0E0`

### Favicon

- Icon mark only, no wordmark
- At very small sizes (16px), the tray border stroke may be dropped for clarity

### Marketing / Social

- Full logo (icon + wordmark) at larger sizes
- Same flat style -- no embellishments

## What This Spec Does NOT Cover

- Animated logo variants
- Monochrome / single-color versions for special contexts
- Print specifications (CMYK values, minimum size requirements)
- Brand guidelines beyond the logo itself

These can be addressed in a future brand guidelines document if needed.
