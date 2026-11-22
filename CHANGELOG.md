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

- The pack could not compile: the buffer-format contract had been written as GLSL
  instead of as a directive comment, and `sat()` was missing the overload that clamps a
  lightmap coordinate.
- Every draw was going through a frame buffer with eight colour attachments bound,
  while the GPU supports seven, because no program declared its outputs.
- Iris was asked for a 2048 shadow map even with the shadow pass switched off - about
  67 MB of render targets on every world load, on a GPU with no memory of its own.
- The antialiasing pass read its history buffer and wrote it again in the same draw.
  That is undefined behaviour and, on an Intel driver, a hung GPU: a frozen game with a
  clean log. It should not have run at all, but the flag meant to switch it off was
  written in a form that leaves a pass enabled when the expression cannot be evaluated.
  It is now flipped, and the switches use the plain form.
- The sky-fill pass — `prepare` — is gone. It was the only program present in every
  configuration of the pack that froze and absent from every one that ran, and all it
  did was paint the horizon colour behind the world, so emptying it costs the colour
  behind the gaps between chunks and nothing else. Whatever is at fault, a pack without
  it is a pack shaped like the configurations that load.
- The last pass declared its scene buffer through a macro, which the mod cannot see
  when it scans for sampler names, so the buffer was never bound to it.

### Known limits

Nobody has judged the picture on real hardware yet. Every stage of every program
compiles under all seven option sets, and the structural checks pass, but those say the
pack loads, not that it looks right. Start on `Smooth`.
