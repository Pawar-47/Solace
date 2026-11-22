# Changelog

Versions are `MAJOR.MINOR.PATCH`, and the release notes for each one list the commits
since the previous tag. A major version means the options a player has set might need
looking at again; a minor one adds options or effects without breaking the old values;
a patch one fixes something and changes no setting.

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
