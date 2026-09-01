---
name: css-expert
description: Writes clean, maintainable CSS using modern features (Grid, Flexbox, custom properties, clamp(), logical properties). Use when building responsive layouts, creating animations, optimizing performance, or working with design systems.
license: MIT
compatibility: opencode
metadata:
  author: opencode
  version: "1.0.0"
  domain: language
  triggers: CSS, responsive design, Flexbox, Grid, custom properties, animations, media queries, design system
  role: specialist
  scope: implementation
  output-format: code
  related-skills: fullstack-guardian, react-expert
---

# CSS Expert

## When to Use This Skill

- Building responsive layouts with modern CSS
- Creating performant animations and transitions
- Working with design systems and component libraries
- Optimizing CSS for performance and maintainability
- Implementing RTL support with logical properties

## Core Workflow

1. **Analyze requirements** — Understand layout needs, browser support, and design constraints
2. **Choose approach** — Select appropriate CSS features (Grid, Flexbox, custom properties)
3. **Implement** — Write clean, maintainable CSS following constraints
4. **Validate** — Check for performance issues, browser compatibility, and accessibility
5. **Document** — Add comments only when logic is non-obvious

## Constraints

### MUST DO
- Use modern CSS (Grid, Flexbox, custom properties, clamp())
- Mobile-first responsive design with min-width media queries
- Use logical properties (margin-inline, padding-block) for RTL support
- Prefer CSS over JS for animations and transitions
- Use semantic HTML as foundation
- Ensure color contrast meets WCAG AA standards
- Use `rem` for typography, `px` for borders and small details

### MUST NOT DO
- Use !important
- Use inline styles
- Use CSS frameworks unless explicitly requested
- Use !important or inline styles
- Use vendor prefixes unless targeting specific legacy browsers
- Use float for layout (use Grid or Flexbox)
- Nest more than 3 levels deep
- Use magic numbers without comments

## Key Patterns with Examples

### Mobile-First Responsive
```css
/* ✅ Correct — mobile-first with min-width */
.container {
  padding: 1rem;
}

@media (min-width: 768px) {
  .container {
    padding: 2rem;
    max-width: 1200px;
    margin-inline: auto;
  }
}

/* ❌ Incorrect — desktop-first with max-width */
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

@media (max-width: 768px) {
  .container {
    padding: 1rem;
  }
}
```

### Flexbox Layout
```css
/* ✅ Correct — semantic flex layout */
.nav {
  display: flex;
  gap: 1rem;
  align-items: center;
}

.nav-item {
  flex-shrink: 0;
}

/* ❌ Incorrect — magic numbers, no gap */
.nav {
  display: flex;
  align-items: center;
}

.nav-item {
  margin-right: 10px;
}

.nav-item:last-child {
  margin-right: 0;
}
```

### CSS Grid Layout
```css
/* ✅ Correct — responsive grid with auto-fit */
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
}

/* ❌ Incorrect — fixed columns, no responsiveness */
.grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
}
```

### Custom Properties
```css
/* ✅ Correct — semantic design tokens */
:root {
  --color-primary: oklch(0.7 0.15 250);
  --space-md: clamp(1rem, 0.5rem + 1vw, 1.5rem);
  --font-body: system-ui, -apple-system, sans-serif;
}

.button {
  background: var(--color-primary);
  padding: var(--space-md);
  font-family: var(--font-body);
}

/* ❌ Incorrect — hardcoded values */
.button {
  background: #3b82f6;
  padding: 16px;
  font-family: Arial, sans-serif;
}
```

### Logical Properties
```css
/* ✅ Correct — RTL-ready */
.card {
  margin-inline: auto;
  padding-block: 1rem;
  padding-inline: 1.5rem;
  border-inline-start: 4px solid var(--color-primary);
}

/* ❌ Incorrect — LTR-only */
.card {
  margin: 0 auto;
  padding: 1rem 1.5rem;
  border-left: 4px solid #3b82f6;
}
```

## Output Templates

When implementing CSS features, provide:
1. Clean CSS file with logical organization
2. Mobile-first responsive design
3. Custom properties for design tokens
4. Comments only for complex logic
