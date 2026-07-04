# Bloomsong — Art Spec & AI Prompt Kit

The single source of truth for generating game art. Every asset session starts here.
Rule of thumb: **consistency beats beauty** — one coherent, slightly-imperfect style looks
better in-game than fifteen gorgeous images in fifteen styles.

---

## 1. The look (say this the same way every time)

- **Storybook / hand-painted gouache**, warm saturated colors, soft edges, gentle outlines,
  rounded friendly shapes. Inspired by *Legend of Mana* and modern cozy indie games.
  No pixel art. No photorealism. No hard black outlines.
- **Three-quarter (3/4) view**: seen from about 35° above — the ground plane is slightly
  tilted, so every object shows its **front and sides**, with just a hint of its top.
  Trees show trunks, a bird bath shows its pedestal, characters face the viewer.
- **Clean readable silhouette** — each object must be identifiable from shape alone.
- Objects sit on a **fully transparent background** with a **subtle soft oval contact
  shadow** baked in beneath them (this grounds them on the terrain for free).

## 2. Master style anchor — paste this at the top of EVERY prompt

> Storybook illustration for a cozy gardening game: soft hand-painted gouache texture,
> warm saturated colors, gentle colored outlines, rounded shapes, clean readable
> silhouette. Three-quarter view seen from about 35 degrees above, so the object shows
> its front and sides plus a hint of its top. Single object only, centered, on a fully
> transparent background (PNG with alpha). Subtle soft oval shadow directly beneath the
> object. No text, no watermark, no border, no background scenery.

(Exception: **terrain tiles** — see §5.1 — are seamless opaque squares, not transparent objects.)

## 3. Sizes & specs

The game uses **64 px ground cells**. Generate large (AI tools output ~1024 px), then
downscale to the target before importing (macOS: open PNG in Preview → Tools → Adjust Size).
Keep the original 1024 px file in `assets/art/_source/` — you'll want it for the diary,
marketing, or re-exports.

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
> bottom-center. Simplified cozy proportions (about 3 heads tall).

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

- **Style board:** —

## 7. Importing into Godot (beginner steps)

1. Downscale the PNG to its target size (§3 table) and name it after the content id.
2. In Finder, drag it into the matching folder under `game/assets/art/` — Godot
   auto-imports it (you'll see it appear in the **FileSystem dock**, bottom-left).
3. Wiring textures into `PlantData`/`ResidentData` and swapping the placeholder renderer
   for sprites is roadmap task **8.2** (a code task — ask your AI session to do it and it
   will find this spec).
