# Feature Graphic Design Specs

## Dimensions
- **Size**: 1024 x 500 pixels
- **Format**: PNG (no transparency)
- **Safe Zone**: Keep important content within 924 x 400 (50px margin)

## Design Layout

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│    ┌─────────┐                                                   │
│    │  LOGO   │     Nurio                                         │
│    │  ICON   │     ─────────────────────                         │
│    └─────────┘     말이 트이는 순간을                             │
│                    만나보세요                                     │
│                                                                  │
│                    ○ 언어 교환  ○ 원어민  ○ 새 친구              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Color Palette

| Element | Color | Hex |
|---------|-------|-----|
| Background | Dark Navy | #0B1118 |
| Primary Accent | Orange | #FF6B35 |
| Text Primary | White | #FFFFFF |
| Text Secondary | Light Gray | #9CA3AF |
| Gradient Start | Dark Navy | #0B1118 |
| Gradient End | Dark Blue | #1E293B |

## Typography

| Element | Font | Size | Weight | Color |
|---------|------|------|--------|-------|
| App Name "Nurio" | DM Sans / Pretendard | 72px | Bold (700) | #FFFFFF |
| Tagline Korean | Pretendard | 36px | Medium (500) | #FFFFFF |
| Feature Pills | DM Sans / Pretendard | 18px | Regular (400) | #9CA3AF |

## Elements

### 1. Logo/Icon (Left Side)
- Position: Left 80px from edge, vertically centered
- Size: 120 x 120 pixels
- Use: `app-icon-512.png` scaled down
- Optional: Add subtle glow/shadow

### 2. App Name (Center-Left)
- Text: "Nurio"
- Position: Right of logo, 40px gap
- Style: Bold, white

### 3. Tagline (Below App Name)
- Korean: "말이 트이는 순간을 만나보세요"
- English alt: "Where language flows naturally"
- Position: Below app name, 16px gap

### 4. Feature Pills (Bottom)
- Layout: Horizontal row of 3 pills
- Content: "언어 교환" | "원어민" | "새 친구"
- Style: Rounded pills with subtle border
- Position: Bottom area, centered

### 5. Background
- Option A: Solid #0B1118
- Option B: Gradient from #0B1118 to #1E293B (left to right)
- Option C: Add subtle pattern/texture

## Alternative Layout (Photo-based)

```
┌──────────────────────────────────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│                                         │
│ ▓▓ BACKGROUND PHOTO ▓▓│     Nurio                                │
│ ▓▓ (people talking)  ▓▓│     ─────────────────                   │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│     말이 트이는 순간을                   │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│     만나보세요                           │
│        ↑ overlay      │                                         │
└──────────────────────────────────────────────────────────────────┘
```

- Left half: Event photo with dark gradient overlay
- Right half: Text content on solid dark background

## Canva Quick Setup

1. Create custom size: 1024 x 500
2. Background: #0B1118
3. Add logo image (left side)
4. Add text elements (right side)
5. Export as PNG

## Figma Quick Setup

1. Frame: 1024 x 500
2. Fill: #0B1118
3. Add components:
   - Logo (Auto Layout)
   - Text Stack (Auto Layout, gap: 16)
   - Feature Pills (Auto Layout, gap: 12)

## Do's and Don'ts

### Do
- Keep text legible at small sizes
- Use high contrast colors
- Center important content
- Test at 50% zoom (how it appears in Play Store)

### Don't
- Add borders or rounded corners
- Use transparency
- Place text too close to edges
- Overcrowd with too many elements
