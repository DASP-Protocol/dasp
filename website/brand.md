---
title: Brand & assets
description: DASP logo, colors, typography, icons, and social preview assets.
---

<script setup>
import { withBase } from 'vitepress'
</script>

# One identity. Every surface.

DASP is the **Durable Actor Session Protocol**. It gives agent builders a shared contract for actor commands, saved outcomes, and recovery. The visual identity is clear, restrained, and independent of any programming language.

## The session mark

The open D forms a session boundary. The separate vertical bar represents saved state. The two parts remain clear at small sizes. This is a visual metaphor, not a protocol diagram or a claim of certification.

<div class="brand-pair">
  <div class="brand-sample brand-light"><img :src="withBase('/brand/dasp-horizontal-light.svg')" alt="Blue DASP logo on a light background" /><span>Light surfaces</span></div>
  <div class="brand-sample brand-dark"><img :src="withBase('/brand/dasp-horizontal-dark.svg')" alt="Light blue DASP logo on a dark background" /><span>Dark surfaces</span></div>
</div>

[Download light logo](/brand/dasp-horizontal-light.svg) · [Download dark logo](/brand/dasp-horizontal-dark.svg) · [Black](/brand/dasp-horizontal-black.svg) · [White](/brand/dasp-horizontal-white.svg)

The name is always **DASP**. In prose, expand it to **Durable Actor Session Protocol** on first use. Keep the existing DM Sans type family. Use IBM Plex Mono only for code and technical values. Exported logo lettering uses vector paths, so it does not depend on installed fonts.

## Color system

| Role | Light mode | Dark mode |
| --- | --- | --- |
| Page | `#F7F8FA` | `#151B24` |
| Raised surface | `#EEF1F6` | `#1E2938` |
| Primary text | `#202938` | `#EDF1F8` |
| Secondary text | `#526176` | `#B8C4D6` |
| Brand accent | `#315DA8` | `#93B8F5` |
| Border | `#D5DCE6` | `#35465D` |

Use one blue accent for links, controls, and diagram activity. Use neutral surfaces for reading. Do not use color alone to show protocol status.

## Small sizes and icons

<div class="brand-icons">
  <img :src="withBase('/brand/dasp-icon-16.png')" width="16" height="16" alt="16 pixel favicon" />
  <img :src="withBase('/brand/dasp-icon-32.png')" width="32" height="32" alt="32 pixel favicon" />
  <img :src="withBase('/brand/dasp-icon-48.png')" width="48" height="48" alt="48 pixel icon" />
  <img :src="withBase('/brand/dasp-icon-180.png')" width="90" height="90" alt="Touch icon" />
</div>

The icon uses the same mark on a blue square. The site supplies SVG, PNG, and ICO favicons, a 180 pixel Apple touch icon, and 192 and 512 pixel manifest icons.

[SVG icon](/brand/dasp-icon.svg) · <a :href="withBase('/brand/dasp-favicon.ico')" download>ICO favicon</a> · [512 pixel PNG](/brand/dasp-icon-512.png) · [Transparent 1024 pixel mark](/brand/dasp-mark-1024.png)

## Social preview

<img :src="withBase('/brand/dasp-social.png')" width="1200" height="630" alt="DASP social preview with the full protocol name and the line Commands. Saved outcomes. Recovery." />

The 1200 × 630 PNG is used for Open Graph and large social cards. Each document supplies its own page title, description, and canonical URL.

[Download social PNG](/brand/dasp-social.png) · [Download editable SVG](/brand/dasp-social.svg)

## Use rules

- Keep clear space of at least one bar width around the mark.
- Use the bare mark at 24 pixels or larger. Use the square favicon below that size.
- Use the horizontal logo at 124 pixels wide or larger.
- Keep the original proportions and the gap between the bar and the curve.
- Use the supplied light, dark, black, or white version.
- Do not add gradients, shadows, outlines, or extra symbols.
- Do not use the mark to imply conformance or security certification.

## Other directions considered

The session mark is the working identity. Two alternatives explore a return path and a bounded state. They are review assets, not production logos.

<div class="brand-pair">
  <div class="brand-sample brand-light"><img :src="withBase('/brand/concept-continuity-horizontal-light.svg')" alt="Alternative DASP mark with a return path" /><span>Continuity — more detail at small sizes</span></div>
  <div class="brand-sample brand-light"><img :src="withBase('/brand/concept-ledger-horizontal-light.svg')" alt="Alternative DASP mark with a bounded state" /><span>Bounded state — less direct link to the name</span></div>
</div>

## Source and maintenance

Run `npm run brand:build` to rebuild the assets. The canonical geometry is in `scripts/build-brand.mjs`. All production variants come from the same path. DM Sans is included under the SIL Open Font License.

New site asset paths replace the old `mark.svg` references. The old path also contains the new blue icon for compatibility. Social services can retain their own cached previews after a deployment.

<style>
.brand-pair { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 28px 0; }
.brand-sample { min-width: 0; padding: 32px 24px; border: 1px solid #35465d; border-radius: 10px; }
.brand-sample img { width: 100%; max-width: 248px; height: auto; margin: 0 auto 24px; }
.brand-sample span { display: block; font-size: 13px; line-height: 1.6; }
.brand-light { background: #f7f8fa; color: #526176; border-color: #d5dce6; }
.brand-dark { background: #151b24; color: #b8c4d6; }
.brand-icons { display: flex; align-items: center; gap: 28px; flex-wrap: wrap; margin: 28px 0; }
@media (max-width: 600px) { .brand-pair { grid-template-columns: 1fr; } }
</style>
