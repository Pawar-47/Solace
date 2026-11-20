# Solace LowEnd - MakeUp Ultra Fast v9.6, rebuilt for one machine

A complete, offline copy of the pack in this project, with every file carried
over (344 files under `shaders/`) and the settings set for:

- **Intel Core i3-5005U** - 2 cores / 4 threads, 15 W, no turbo headroom worth counting
- **Intel HD Graphics 5500** - 24 EUs, no dedicated VRAM, shares the system RAM
- **8 GB RAM**, **Linux Mint**

Nothing in it needs the internet: it is a folder of GLSL, PNG and `.properties`
files, and it is read by Iris/OptiFine from disk.

Licence: MakeUp is **GNU LGPL-3.0** by Javier Garduño (KDXavier). This is a
modified copy; keep the credit and the links if you pass it on:
<https://github.com/javiergcim/MakeUpUltraFast>,
<https://modrinth.com/shader/makeup-ultra-fast-shaders>,
<https://www.planetminecraft.com/mod/makeup-ultra-fast-shader/>,
<https://www.curseforge.com/minecraft/customization/makeup-ultra-fast-shader>.
The upstream `LICENSE` and `Credits` files are not inside this folder - add them
back before redistributing.

---

## Install (Linux Mint)

1. Use **Iris** (the pack needs Iris 1.5.1 or newer; OptiFine works too but is
   slower on an Intel iGPU through Mesa). Prism Launcher or the official launcher,
   Minecraft 1.20-1.21 is the comfortable range for this GPU.
2. Put this whole folder in the instance's `shaderpacks` folder:
   `~/.minecraft/shaderpacks/Solace-LowEnd` for the official launcher, or
   `~/.local/share/PrismLauncher/instances/<instance>/.minecraft/shaderpacks/Solace-LowEnd`
   for Prism. A folder works as-is; zipping it also works.
3. In game: **Options > Video Settings > Shader Packs**, select
   `Solace-LowEnd`, and apply.
4. Open **Shader Pack Settings** and pick the profile:
   - `lowend_hd5500` - the setting this pack ships with.
   - `lowend_hd5500_nofog` - the same with distance fog off: one less full-screen
     fetch per block pixel, at the cost of chunks popping in with no haze.
   - `MAX_FPS` - the same values without the profile wrapper.
   Anything else (`low`, `medium`, `high`) turns effects back on and will drop
   you under 30 fps on this GPU.

## Minecraft and launcher settings that matter more than the shader

1. **Render distance 6, simulation distance 4.** The i3-5005U has two cores; chunk
   building is where the frame time goes.
2. **Resolution 1600x900 or 1366x768, fullscreen if the panel allows it.** The HD
   5500 is fill-rate bound; 1080p costs about twice the pixels of 720p for no
   visible gain on a laptop panel.
3. **Allocate 2 GB, not more** (`-Xmx2G`). Of 8 GB the desktop needs ~2 GB and the
   iGPU takes its VRAM from the same pool; a larger heap only starves the GPU.
   Leave the rest of the JVM arguments at the launcher default (G1GC).
4. **Graphics: Fast**, clouds **Fast** (the pack draws vanilla clouds when
   `V_CLOUDS = 0`), particles **Decreased**, entity distance 50%, mipmap 4x,
   VSync **off**, max framerate **unlimited**.
5. **Linux side:** set the CPU governor to `performance`
   (`sudo cpupower frequency-set -g performance`), keep the desktop compositor off
   while playing, and try `mesa_glthread=true` in the launch environment - it moves
   GL calls off the main thread and helps on Mesa. Keep Mesa up to date; the HD
   5500 gets real driver work in Mesa, unlike the old Windows driver.

## What was changed from the stock pack

Every change is a value in `shaders/lib/config.glsl` or a switch in
`shaders/shaders.properties`. No shader logic was rewritten, so the pack stays
updatable and each effect can be switched back on from its own options screen.

| Option | Stock | Here | Why |
| --- | --- | --- | --- |
| `SHADOW_CASTING` | on | **off** | a whole second scene render |
| `SHADOW_QTY_SLIDER` / `SHADOW_DISTANCE_SLIDER` | 2 / 1 | 1 / 0 | so re-enabling shadows later is affordable (300 px map, 75 blocks) |
| `V_CLOUDS` | 1 | 0 | a raymarch per pixel plus a cloud reflection pass |
| `CLOUD_STEPS_AVG` | 10 | 7 | the minimum |
| `REFLECTION_SLIDER` | 2 | 0 | up to ten screen-space raymarch steps |
| `CLOUD_REFLECTION`, `END_CLOUDS` | on | off | re-renders the cloud layer |
| `AA_TYPE` | 2 | 0 | history buffer plus a full-screen resolve |
| `BLOOM` | on | off | extra passes and a mipmap chain |
| `AO` / `AOSTEPS` | 1 / 5 | 0 / 3 | falls back to vanilla's baked AO |
| `VOL_LIGHT` / `GODRAY_STEPS` / `RAYMARCH_STEPS` | 1 / 6 / 10 | 0 / 4 / 5 | depth-based marches |
| `MATERIAL_GLOSS` | on | off | per-pixel gloss |
| `REFRACTION`, `SUN_REFLECTION` | on | off | water sampling |
| `COLORED_SHADOW` | on | off | meaningless with no shadow pass |
| `CHROMA_ABER`, `IMAGE_SHARPENING` | off | off | left at the stock value |
| `WAVING` | 1 | **0** | per-vertex work on every grass and leaf vertex |
| `program.composite1.enabled` | always | `BLOOM \|\| DOF` | bloom/DOF only: the pass is skipped |
| `program.composite2.enabled` | always | `AA_TYPE \|\| MOTION_BLUR` | AA/motion blur only: the pass is skipped |

## Want some of it back

In this order, one at a time, measuring with F3 each time:

1. `REFLECTION_SLIDER = 1` - flipped-image water reflection: one screen read, no
   raymarch. Cheapest visible win.
2. `AO = 1` with `AOSTEPS = 3`.
3. `AA_TYPE = 2` if foliage shimmer bothers you (it brings `composite2` back).
4. `SHADOW_CASTING` with both shadow sliders left at `1 / 0`.
5. `FOG_ACTIVE` off is the last real per-pixel saving left - compare it with the
   `lowend_hd5500_nofog` profile before deciding.

## What has not been checked

The pack was not compiled or rendered here: this environment has no GPU, no
Minecraft and no Iris. Every value above is a supported option of MakeUp v9.6 read
from its own `config.glsl` and `shaders.properties`; the framerate on your machine
is unmeasured, so measure before and after with F3 and revert anything you dislike
- each change is a single value.
