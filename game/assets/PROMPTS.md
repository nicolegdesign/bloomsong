# Bloomsong — Art Spec & AI Prompt Kit

The single source of truth for generating game art. Every asset session starts here.
Rule of thumb: **consistency beats beauty** — one coherent, slightly-imperfect style looks
better in-game than fifteen gorgeous images in fifteen styles.

---

## 1. The look (say this the same way every time)

- **Storybook / hand-painted gouache**, balanced, natural color palette with neutral whites (no warm yellow tint), rich greens, soft edges, gentle outlines,
  rounded friendly shapes. Inspired by *Legend of Mana* and modern cozy indie games.
  No pixel art. No photorealism. No hard black outlines.
- **Three-quarter (3/4) view**: seen from about 35° above — the ground plane is slightly
  tilted, so every object shows its **front and sides**, with just a hint of its top.
  Trees show trunks, a bird bath shows its pedestal, characters face the viewer.
- **Clean readable silhouette** — each object must be identifiable from shape alone.
- Objects sit on a **fully transparent background** with a **subtle soft oval contact
  shadow** baked in beneath them (this grounds them on the terrain for free).
- **Minimal bases.** Plants grow from a small rounded soil mound; trees and decorations get
  at most a tiny grass tuft. No flowers, lavender, acorns, or props at the base — the player
  places objects on any terrain, so baked-in scenery would clash (grass tufts on a dirt
  path, lavender sprigs on sand). The style board's decorated bases are fine as a style
  reference, but production assets should be cleaner.

## 2. Master style anchor — paste this at the top of EVERY prompt

> Storybook illustration for a cozy gardening game. Soft hand-painted gouache texture with   visible brushstrokes. Simplified, stylized shapes with clean readable silhouettes and minimal surface detail. Balanced, natural color palette with neutral whites (no warm yellow tint), rich greens, and vibrant flowers. Gentle colored linework instead of black outlines. rounded shapes, clean readable silhouette. Three-quarter view seen from about 35 degrees above, so the object shows its front and sides plus a hint of its top. Single object only, centered, on a fully transparent background (PNG with alpha). Subtle soft oval shadow directly beneath the object. No text, no watermark, no border, no background scenery.

(Exception: **terrain tiles** — see §5.1 — are seamless opaque squares, not transparent objects.)

## 3. Sizes & specs

Generate large (AI tools output ~1024 px) on a transparent background. Keep the original
in `assets/art/_source/` (for the diary, marketing, re-exports), then create the in-game
copy with a one-line proportional downscale — no exact-size cropping needed, because the
game **aspect-fits** each sprite into its display box:

    sips -Z 192 <original.png> --out game/assets/art/<category>/<id>.png

192 px max-dimension is ~2–3× the on-screen size: crisp when zoomed, tiny on disk.
**Never crop or trim growth stages individually** — all stages of one plant must share the
same source canvas, because that shared canvas is exactly what keeps a sprout correctly
small relative to the mature plant when both render in the same box. The table below gives
the display boxes the game fits sprites into (at the 64 px-cell art scale):

| Category | In-game target (px) | Canvas & anchoring |
|---|---|---|
| Terrain tile | 64×64 | Seamless/tileable, opaque, square-on (no tilt on the ground itself), flat soft lighting, low contrast so objects read on top |
| Flower / small plant | 64×96 | Base (roots) at bottom-center; plant may fill upward |
| Bush | 96×96 | Base at bottom-center |
| Tree | 128×192 | Trunk base at bottom-center; canopy overflows upward |
| Decoration (upright: bird bath, lamp) | 64×128 | Base at bottom-center |
| Decoration (wide: log, bench, pond) | 96×64 | Base at bottom-center |
| Player character | 64×96 | Feet at bottom-center, mostly front-facing, face clearly visible |
| Resident (small: snail, bee, butterfly) | 48×48 | Centered |
| Resident (medium: bird, rabbit, frog) | 64×64 | Feet at bottom-center |
| Resident (large: fox, turtle) | 96×80 | Feet at bottom-center |
| Item icon (berry, feather, honey) | 64×64 | Centered, reads at small size |
| Diary illustration | 512×512 | Framed vignette portrait — the one place a soft painted background IS wanted |

**File naming = content id** (they must match — saves reference ids forever):
`assets/art/plants/sunflower_0.png … sunflower_2.png` (one per growth stage, count from the
`.tres`), `assets/art/residents/robin.png`, `assets/art/terrain/short_grass.png`,
`assets/art/items/berry.png`, `assets/art/diary/robin.png`.

## 4. Which AI to use

*(Recommendations as of my January 2026 knowledge — double-check current names/features when you sign up; this space moves fast.)*

1. **Start with ChatGPT's image generation** (you likely already have access). Why it fits
   you best: native **transparent backgrounds**, unusually good at **following written specs**
   (angle, framing, "no background"), and — the killer feature for a beginner — you iterate
   **conversationally**: "same sunflower, but as a younger sprout, same palette." Keep one
   long chat per asset category so it can see its own earlier images for consistency.
2. **Scenario (scenario.com)** — purpose-built for game assets: you train a custom style
   model on ~15–20 images you've approved, then everything it generates matches. Worth it
   at Phase 12 (the 25-plants/20-residents content wave), overkill for the ~15-item slice.
3. **Midjourney** — the most beautiful painterly output and style-reference support, but no
   native transparency (you'd add a background-removal step, e.g. remove.bg) and it follows
   precise instructions less reliably. Good for finding the style; clunkier for production.

**The workflow that keeps style consistent:**
1. **Style board first.** Before any real asset, generate one image containing ~6 objects
   (a flower, a tree, a bird, a fence, a character, a watering can) in the master style.
   Regenerate until you love it. This is your style bible — attach/reference it in every
   later session ("match the style of this image exactly").
2. **Batch by category** — all flowers in one session, all birds in another.
3. **Log every winner.** When an image is approved, paste its exact prompt into §6 below.
   The log is what makes the style reproducible months from now.

## 5. Per-category prompt templates

Copy the master anchor (§2), then append:

### 5.1 Terrain tile (different rules!)
> A seamless, tileable 1:1 texture of **{short mown grass / tall meadow grass / packed
> garden dirt / gently rippling pond water}**, hand-painted gouache style, warm saturated
> colors, soft flat lighting, low contrast, no objects, no shadows, no border. The texture
> must tile perfectly — edges continue seamlessly when repeated.

### 5.2 Plant with growth stages (generate mature first, then work backwards)
> …master anchor… A **{sunflower}** in full mature bloom: {tall stem, one large warm-yellow
> flower head, a few broad green leaves}. Base of the stem at the bottom-center of the image.
>
> Then, in the same conversation: "Now the same {sunflower}, same palette and style, as a
> **half-grown young plant** — shorter, budding, not yet flowering." And: "Same plant as a
> **tiny fresh sprout** — two small leaves." (Match the stage count in the plant's `.tres`:
> sunflower 3, berry bush 3, oak 4. For fruiting plants, also ask for the mature stage
> **with ripe fruit visible** — that's the `fruit_ready` variant.)

### 5.3 Tree
> …master anchor… A **{young oak tree}** with a {sturdy brown trunk and a round, layered
> canopy of warm green leaves}. Because of the three-quarter view, the trunk and the
> underside of the canopy are clearly visible. Trunk base at bottom-center.

### 5.4 Decoration
> …master anchor… A **{stone bird bath}**: {a weathered pedestal bowl with clear water,
> in soft warm grays with moss accents}. Shown from the three-quarter view so the pedestal
> and the water surface are both visible. Base at bottom-center.

### 5.5 Resident
> …master anchor… A **{robin}**, {plump and friendly with a rust-red chest}, standing in a
> relaxed idle pose, body angled slightly toward the viewer so its face and eye are clearly
> visible. Feet at bottom-center. Simplified, slightly cartoon proportions — big enough eyes
> to read as charming at small size.

### 5.6 Player character
> …master anchor… A **friendly gardener character**: {description from character design —
> e.g. sun hat, overalls, boots}, standing relaxed, drawn mostly front-facing so the face is
> clearly visible, with the slight downward camera tilt of the three-quarter view. Feet at
> bottom-center. Simplified cozy proportions (about 3 heads tall). Empty hands (tools are
> separate assets).

**Animation strategy:** the vertical slice needs only ONE idle sprite — movement feel comes
from a small code-driven bob/sway while walking (part of task 8.2), which reads charmingly
at this size. Don't attempt AI-generated frame-by-frame walk cycles yet; image models can't
keep a character consistent across frames. When directional sprites matter (post-slice),
generate a **turnaround sheet** — "the same character in the same pose seen from the front,
from the side, and from behind, side by side in one image" — front + back + one side
(mirror the side in Godot for the other direction). Worth generating the turnaround now
while the style chat is warm, even though the game won't use it yet.

### 5.7 Item icon
> …master anchor… A small pile of **{three ripe red berries}** as a collectible item icon,
> slightly oversized details so it reads clearly at small size.

### 5.8 Diary illustration
> Storybook illustration for a nature diary page: a **{robin}** perched {on a blossoming
> branch}, soft hand-painted gouache, warm saturated colors, gentle vignette edges fading
> to warm cream, square composition. Painted background wanted here. No text.

## 6. Approved prompt log

*(Paste the exact winning prompt + tool + date under each asset as art gets approved.
Empty until the style board session.)*

- **Style board:** ✅ approved 2026-07-05 — `assets/art/_source/styleboard.png`. Attach this
  image to every asset-generation session with "match this style exactly." Character canon:
  girl gardener, wide straw hat with daisy, brown braid, white shirt, green overalls, yellow
  neckerchief, brown gloves and boots.
- **Sunflower (stages 0–2) + planted_dirt:** ✅ 2026-07-05 — §5.2 template + style board;
  same-canvas series so relative stage scale is preserved. Wired in
  `content/plants/sunflower.tres`; `planted_dirt.png` is the shared day-0 mound for ALL plants.
- **Farmer (idle):** ✅ 2026-07-05 — §5.6 template + style board. In-game via
  `scripts/player/player.gd` preload. Turnaround sheet (front/side/back) still to generate.

## 7. Adding art to the game — the worked pipeline (follow this for every asset)

The sunflower and farmer are the reference implementation. For a new plant `foo`:

1. **Files in.** Save the transparent originals to `game/assets/art/_source/`, then
   downscale each into place, named by content id + stage index:
   `sips -Z 192 game/assets/art/_source/foo_0.png --out game/assets/art/plants/foo_0.png` … etc.
   Godot auto-imports them on next launch (they appear in the FileSystem dock).
2. **Wire the .tres.** Copy the pattern from `content/plants/sunflower.tres` exactly:
   one `[ext_resource type="Texture2D" …]` per stage PNG, a `stage_textures = [ExtResource…]`
   array (index = stage), and `load_steps` bumped by the number of textures.
   Beginner-friendly alternative, in the Godot editor: click the `.tres` in the FileSystem
   dock → in the Inspector expand **Stage Textures** → set the array size → drag each PNG
   from the FileSystem dock into its slot.
3. **Day 0 is free.** Every plant shows the shared `assets/art/plants/planted_dirt.png`
   mound on the day it's planted, before any growth — no per-plant art for that state.
4. **No code changes for plants.** `PlantView` renders `stage_textures` when present and
   falls back to placeholder circles when the array is empty — partially-arted content
   always still runs. Sprites are bottom-anchored (base on the cell's bottom edge) and
   Y-sorted so the player walks behind tall plants; the display box per category is the
   `BOX_CELLS` constant in the view script.
5. **Verify.** Run the test suite, then F5: plant it, press N through every stage.
   Check that it sits on its cell, the sprout is smaller than the mature plant, and the
   farmer occludes/is occluded correctly walking around it.

The player character is `assets/art/player/farmer.png`, preloaded in
`scripts/player/player.gd` — replacing that file replaces the character. Residents,
decorations, terrain tiles, and item icons still render placeholders; when their art
arrives, add a texture field to their data class and textured drawing to their view,
the same way `PlantView._draw_texture_anchored()` does it.
