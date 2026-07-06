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
| UI screen background (shop, diary) | 1280×720 (viewport width, not the 64 px cell scale) | A full illustrated scene — background IS wanted here too. Opaque, no transparency. Downscale to 1280 max-dimension, not the usual 192 — it fills most of the screen, so it needs real resolution. Fit with `STRETCH_KEEP_ASPECT_COVERED` (crops overflow, never distorts) behind a dim overlay for panel legibility |

**File naming = content id** (they must match — saves reference ids forever):
`assets/art/plants/sunflower_0.png … sunflower_2.png` (one per growth stage, count from the
`.tres`), `assets/art/residents/robin.png`, `assets/art/terrain/short_grass.png`,
`assets/art/items/berry.png`, `assets/art/diary/robin.png`. UI backgrounds aren't tied to a
content id (they're not game content, just a screen's backdrop) — name them for the screen:
`assets/art/ui/shop_background.png`.

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
> sunflower 3, blackberry bush 3, oak 4. For fruiting plants, also ask for the mature stage
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
- **Blackberry bush (stages 0–2 + fruiting variant):** ✅ 2026-07-05 — §5.2 template + style
  board; same-canvas series, plus a mature **with-ripe-fruit** image per §5.2's fruit_ready
  note. Wired in `content/plants/blackberry_bush.tres` (renamed from `berry_bush`) via
  `stage_textures` (0–2) + the new `PlantData.fruiting_texture` override, which `PlantView`
  swaps in whenever `fruit_ready` is true instead of the plain mature sprite.
- **First resident + decoration art (butterfly, snail, robin, bird bath):** ✅ 2026-07-05 —
  §5.5/§5.4 templates + style board. First non-plant textures, so `ResidentData`/
  `DecorationData` gained a `texture` field and `PlantView`'s aspect-fit/baseline-anchor math
  was extracted into a shared `SpriteAnchor.draw_fitted()` for all three view types. Butterfly
  and snail are the "small resident" category (§3 table) — `display_box_cells = (0.75, 0.75)`
  and `texture_centered = true`, since a flier/tiny critter has no meaningful "feet" point.
  Robin and the bird bath use the default medium/upright boxes with normal bottom-anchoring.
  **Rabbit was rejected** on the first pass: that export had no alpha channel — a literal
  checkerboard baked in as opaque pixels instead of real transparency.
- **Rabbit (idle), re-exported:** ✅ 2026-07-05 — same §5.5 template + style board, this time
  with a real alpha channel. Wired in `content/residents/rabbit.tres` with the default
  medium/bottom-anchored box (no `texture_centered`, unlike butterfly/snail).
- **Terrain tiles (dirt, long grass, short grass, water):** ✅ 2026-07-05 — §5.1 template
  (seamless, opaque, square-on, no transparency). First terrain art, so `TerrainData` gained a
  `texture` field; `Garden._draw()` stretches it to fill each 64×64 cell exactly (no aspect-fit
  or baseline anchoring needed — a tileable texture just fills its cell edge-to-edge). Falls
  back to the flat `placeholder_color` rect when a terrain has no texture, same pattern as
  every other content type.
- **Fallen log:** ✅ 2026-07-05 — §5.4 template (wide decoration), style board. Wired in
  `content/decorations/log.tres`, which already had its 2×1 footprint/display box set up.
- **Item icons (berry, feather, sunflower bloom) + generic seed packet:** ✅ 2026-07-05 —
  §5.7 template. First icon art, so `ItemData` gained an `icon` field, used in the shop's
  Sell tab and anywhere inventory is listed. Plants don't get a per-plant icon — the shop's
  Buy tab and the palette's Plant mode both show one shared `assets/art/icons/seed.png`
  packet instead (you're buying/selecting a seed, not the grown plant), while Decoration/
  Terrain rows reuse each item's own world texture as its icon. `Button.icon` (with an
  `icon_max_width` theme override, since Godot doesn't auto-scale it) handles the palette;
  the shop uses a small shared `_make_icon()` helper building a TextureRect or a
  placeholder-color ColorRect fallback.
- **Shop background:** ✅ 2026-07-05 — new §3 category (UI screen background), first of its
  kind: a full painted scene rather than a transparent object, downscaled to 1280 max instead
  of the usual 192. Wired in `scripts/ui/shop_ui.gd` behind a lighter dim overlay (0.35 alpha,
  down from the old plain-black 0.55 — the scene reads fine on its own) via
  `STRETCH_KEEP_ASPECT_COVERED` so it fills the screen without distorting.
- **Diary rework (book background + handwritten font):** ✅ 2026-07-05 — `diary_open.png` is a
  UI screen background (§3, downscaled to 1024 max) wired into `scripts/ui/diary_ui.gd`. The
  book's safe-to-write-on page area isn't eyeballed — it was measured by sampling the art for
  paper-colored pixels (cream/tan, excluding the green cover and brown page-edge shading),
  giving `LEFT_PAGE`/`RIGHT_PAGE` as fractional rects mapped onto Control anchors, so text/art
  always sits inside the painted page regardless of how big the book is ever displayed. Each
  entry's own resident/plant texture is now shown large on the left page (tinted near-black as
  a silhouette until discovered) instead of the old small icon grid, which moved to a slim
  strip below the book. Body text switched from plain white to a warm ink-brown
  (`INK_COLOR`) and to **Patrick Hand**, a handwriting-style font — not AI-generated art, so
  logged differently: downloaded from Google Fonts
  (`github.com/google/fonts/ofl/patrickhand`), SIL Open Font License (free to embed/ship),
  license copy kept at `assets/fonts/PatrickHand-OFL.txt`. It has no bold weight, so `[b]` tags
  use a `FontVariation` with `variation_embolden` for a synthetic bold instead.
- **Diary rework #2 (tabbed book + page-flip nav):** ✅ 2026-07-05 — superseded `diary_open.png`
  with 4 UI screen backgrounds (`diary_residents/plants/flowers/achievements.png`), each the
  same book art with one of 4 painted tab icons (paw/seedling/flower/star) along the left edge
  shown "pressed in" — swapping the whole background image per tab, rather than a separate
  overlay, since the active-tab highlight is baked into the art. Invisible button hotspots sit
  over the 4 tab icons at a measured, fixed position (identical across all 4 images). Residents
  = paw; Plants = seedling, filtered to non-flower categories (trees/bushes); Flowers = flower,
  filtered to the flower category; Achievements = star, a "coming soon" placeholder page (no
  backing system yet). The old bottom icon-grid strip is gone — small ◀/▶ placeholder-text
  arrows in the pages' outer top corners now cycle entries within a tab (wrapping at either
  end, matching the game's no-dead-ends design guardrail). Right-page text is now centered
  (both the block as a whole, via `fit_content` + a centered VBox, and each line via bbcode
  `[center]`) and widened, with `scroll_active` off — no scrollbar. Removed the header/footer
  rows entirely so the book is the only thing being centered on screen.
- **Resident/plant sprite resolution bump (diary blur fix):** ✅ 2026-07-05 — the diary's left
  page shows each entry's existing `texture`/`stage_textures` sprite large (§3's "Diary
  illustration" row still describes a dedicated, separate 512×512 `assets/art/diary/` vignette
  portrait — that never got made), and those sprites were only ever downscaled to the old
  192 px garden convention, so blowing them up to fill the page looked blurry. Re-ran
  `sips -Z 512` from the existing `_source/` originals (all ≥543 px, so this is a real
  downscale everywhere, never an upscale) for every resident and plant/growth-stage PNG.
  Confirmed safe for the garden view too: `SpriteAnchor.draw_fitted()` aspect-fits into each
  content's fixed `display_box_cells * Garden.CELL` box every draw call, recomputing the scale
  from the texture's current pixel size — so on-screen size in the garden is unchanged, only
  sampling quality improves. This is a stopgap, not the originally-planned dedicated diary
  portrait art — that would still need new AI-generated vignette portraits per entry plus a
  data-model field to hold them, which is a separate future task if the shared-sprite look
  isn't good enough once seen in-editor.

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
   always still runs. Sprites are Y-sorted and **baseline-anchored automatically**: the
   game finds each texture's bottom-most visible pixel (`SpriteAnchor`) and plants THAT
   on the ground point, so uneven empty canvas margins never make the plant float or the
   ground point wander between stages. No manual alignment — the only rule is: nothing
   visible below the true base (the contact shadow/soil mound IS the base). The display
   box per category is the `BOX_CELLS` constant in the view script.
5. **Verify.** Run the test suite, then F5: plant it, press N through every stage.
   Check that it sits on its cell, the sprout is smaller than the mature plant, and the
   farmer occludes/is occluded correctly walking around it.

The player character is `assets/art/player/farmer.png`, preloaded in
`scripts/player/player.gd` — replacing that file replaces the character. Residents,
decorations, terrain tiles, and item icons still render placeholders; when their art
arrives, add a texture field to their data class and textured drawing to their view,
the same way `PlantView._draw_texture_anchored()` does it.
