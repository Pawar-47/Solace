# Changelog

Versions are `MAJOR.MINOR.PATCH`, and the release notes for each one list the commits
since the previous tag. A major version means the options a player has set might need
looking at again; a minor one adds options or effects without breaking the old values;
a patch one fixes something and changes no setting.

## 1.0.1

The first build anyone actually looked at. 1.0.0 loaded, stopped freezing, and then
showed what no check in this repository can see: the picture. These are the faults
behind the four things that were reported - a box where the sun should be, settings
that did nothing, light that did not come from anywhere, and water that was one flat
blue.

- **The sky was rebuilt from the wrong coordinates.** The sky pass derived its view ray
  from `texcoord`, which for the sky is the dome's own texture coordinate, not the
  pixel's place on the screen. Interpolated across the dome's triangles, that turned the
  gradient, the sun and its halo into large flat patches: the rectangle where the sun
  should have been, and a sky whose settings could not show. The ray comes from
  `gl_FragCoord` now, so it is per pixel.
- **The sun and the moon were the game's textured quads.** A quad whose alpha goes wrong
  is a rectangle, and no setting in the pack could change its size or its shape.
  `sun = false` and `moon = false` in shaders.properties; both are discs built in the
  sky pass from a dot product, scaled by SUN_SIZE and surrounded by the halo that
  SUN_HALO_SHAPE describes. That is also why those three settings did nothing.
- **The halo exponents were two orders of magnitude too tight** - 110 and 190 against a
  `cos()` that only reaches 1.0 within a few degrees - so there was no visible glow
  anywhere and the shape setting had nothing to move.
- **Ambient light was the sky colour itself.** Every surface took the palette's blue as
  its fill, so the world looked lit from under water, and the sun contributed less than
  the fill, so nothing had a sunny side. The ambient term is the palette desaturated
  towards its own luma and normalised to the theme's brightness; the sun is now the
  brightest thing in a lit scene, which is what gives a face facing it its own shading.
- **Water was vanilla's blue three times over**: the biome tint multiplied by the
  texture, by a blue-biased factor, and by that blue ambient term. With
  WATER_REFLECTION off there was also no sky on the surface at all, which leaves flat
  paint. The base is the palette's water colour now, with the texture carrying the
  pattern and a little of the biome tint, and the sky is reflected at every setting -
  the option decides how much of the mirror is taken, not whether there is one.
- **One water colour instead of three.** The fog on solid geometry, the water surface
  and the sky seen from below held three separate constants a few thousandths apart,
  which is why the surface and the water below it disagreed. They share
  `underwaterFogColour()`.

## 1.0.0

First versioned release. Before this the release page carried a rolling "latest" build
that was rewritten on every push and a folder of diagnostic zips from a long debugging
session; that history is deleted rather than kept, because none of those builds was a
version.

The pack is `Solace-LowEnd`: a shader pack written for an Intel Core i3-5005U with HD
5500 graphics, 8 GB of RAM and no dedicated GPU. Every effect has a setting that keeps
it on at its cheapest cost, and five profiles name what each one costs.

### What it does

- Sun, moon, sky gradient and fog come from one colour model, so nothing disagrees
  with anything else.
- A stylised diffuse model: de-biased lightmap, a candle curve for block light, and
  fake shadows from sky exposure, which looks like a shadowed world without a shadow
  map.
- Water with ripples, sky reflection and a sun glint; optional depth-aware refraction
  and screen-space reflections.
- Eight colour presets named for what they look like - Natural, Vivid, Game, Soft,
  Cinematic, Neon, Warm, Bright - plus a custom one, each with its own sky light and
  water colour.
- Sun and cloud controls: the sun's arc, its size, the shape of its halo, separate
  red/green/blue gains for sunlight, and four cloud styles with their own drift speed.
- Optional cast shadows with coloured shadows and a refresh lock, volumetric clouds,
  light shafts, ambient occlusion, bloom, depth of field, temporal AA, FXAA, motion
  blur, auto exposure, chromatic aberration and sharpening.
- Distant Horizons and Voxy support.
- 103 options in fifteen sub-screens, nine languages, five profiles.

### Fixed before this release

Nine defects, every one of which on its own stopped the pack from working. They are
listed because the audit that found them is the most useful thing this release has to
say about itself: none of them was visible to the structural checks that were in place
before it, and only the last was silent.

- **Buffer formats written as GLSL.** `const int colortex4Format = R11F_G11F_B10F;`
  reached the compiler as an undeclared identifier, so no program compiled. They are
  directives the mod reads out of the source, and they belong in a block comment.
- **`sat()` missing its `vec2` overload.** The lightmap coordinate is a `vec2`, and three
  places clamp it, so every vertex stage that touches the lightmap failed to link. The
  error the game printed was `no matching function for call to 'sat (vec2)'`.
- **The integer `%` operator**, which is GLSL 1.30, in the composite and shadow passes.
  The pack targets 1.20; `mod()` does the same job everywhere.
- **`depthtex0` declared twice** in `final` whenever ambient occlusion was on, once by
  the pass and once by the ambient-occlusion library it includes.
- **`texture2DLod` in a vertex stage** without the extension, in the armour-glint
  program. Implicit-LOD sampling does not exist in a vertex shader at all; the exposure
  is read in the fragment stage now.
- **`ftransform()` in all sixteen vertex stages.** The reference pack never calls it —
  it writes `gl_ModelViewProjectionMatrix * gl_Vertex` — and on a core-profile driver the
  built-in does not exist until the mod rewrites it. Written out, there is nothing to
  rewrite.
- **Eight colour attachments bound for every draw.** No program declared its outputs, so
  the mod bound the first eight, and the GPU this pack targets supports seven. Every
  program now names its single target in its own file. The directives had also been put
  inside shared libraries, which only works if the mod inlines includes before it looks
  for them.
- **A 2048 shadow map with the shadow pass switched off.** The shadow constants were
  declared only when shadows were on, so the mod fell back to its default and allocated
  roughly 67 MB of render targets on every world load, on a GPU with no memory of its
  own. They are declared always, small, as the reference does.
- **The antialiasing pass read its history buffer and wrote it again inside one draw**,
  every frame, in every profile, whether antialiasing was on or not. That is undefined
  behaviour, and on an Intel driver it is a hung GPU: a frozen game with nothing in the
  log. The sampler, the attachment and the write are now inside the option that uses
  them, which is what the reference does — with the effects off the pass is a copy.

### Known limits

Nobody has judged the picture on real hardware yet. Every stage of every program
compiles under all seven option sets with a real GLSL front end, and the structural
checks pass, but those say the pack loads, not that it looks right. Start on `Smooth`.

If the game freezes, [ERRORS.txt](ERRORS.txt) says which log to send and where it is,
and the **Diagnose** workflow builds one zip per post-chain program — the whole pack
minus exactly that file — so a single run names the file responsible.
