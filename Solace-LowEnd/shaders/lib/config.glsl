/* Solace - lib/config.glsl

Every option this pack has lives here, as a define with the allowed values in a
bracket comment so Iris and OptiFine can build the options screen from it.

Nothing is left out for being expensive: every effect the pack has belongs to a cheap
setting as well as an expensive one, so none of them has to be switched off.
The `Everything` profile in shaders.properties is exactly that - everything enabled,
all samples at their minimum, the shadow map at 512 px over 75 blocks.
*/

#ifndef SOLACE_CONFIG
#define SOLACE_CONFIG

// ---- Diagnostics ---------------------------------------------------------
// Not an option: it has no value list, so it does not appear on the options screen.
// The release workflow builds a second zip with this set to 1, which bypasses the
// whole post chain and switches the sky fill off, so a frame is just the geometry
// and a copy of it. If that build renders and the normal one freezes, the fault is
// in the post chain; if both freeze, it is in the geometry stages. See ERRORS.txt in
// the repository root.
#ifndef SOLACE_DIAG
#define SOLACE_DIAG 0
#endif

// ---- Shader constants the mod reads --------------------------------------
// Not options: values Iris and OptiFine look for in any included file and then
// apply to the whole pipeline.

/* Two things that used to be declared here are declared at the end of the file
   instead: sunPathRotation, because it is now the SUN_PATH option and a const cannot
   be read before the option exists, and ambientOcclusionLevel, because it depends on
   AO. A const written above the option it reads takes the wrong branch every time and
   does it silently, because the preprocessor treats an identifier it has not met yet
   as 0. */

/* How quickly the two smoothed values the terrain shader reads catch up with the
   real ones: sky exposure (which drives the fog) and the depth under the crosshair
   (which drives the focus). The engine's defaults are much slower, which leaves the
   fog lagging behind a cave and the focus lagging behind the crosshair. */
const float eyeBrightnessHalflife = 3.0;
const float centerDepthHalflife = 0.66;

/* Shadow projection snapping and filtering. The interval size keeps the shadow
   texel grid from crawling as the player walks. Hardware filtering is declared
   further down, after the option it depends on - a `const` decided here would read a
   SHADOWS that the preprocessor has not seen yet, which it treats as 0. */
const float shadowIntervalSize = 3.0;
const bool shadowtex1Nearest = false;

// ---- Water ---------------------------------------------------------------
#define PACK_TEXTURES 0        // [0 1] Read textures/noise.png and clouds.png instead of computing the noise. Run textures/generate_textures.py first.
#define WATER_WAVES 0          // [0 1] Animated water surface. Off as shipped: this is the most expensive per-pixel thing the pack does, and the Default profile turns it on.
#define WAVE_SPEED 0.55        // [0.2 0.35 0.55 0.8 1.1]
#define WAVE_SCALE 1.0         // [0.5 1.0 1.5 2.0]
#define WATER_OPACITY 0.72     // [0.40 0.55 0.65 0.72 0.85 1.0]
#define WATER_REFLECTION 0     // [0 1] Reflect the sky on the water surface.
#define WATER_GLINT 0          // [0 1] Sun and moon highlight on water.
#define REFRACTION 0           // [0 1] Bend what is behind water. Needs a scene copy.
#define WATER_ABSORPTION 0.10  // [0.02 0.05 0.10 0.16 0.24] How fast light dies in water.
#define WATER_SSR 0            // [0 1] Reflect the world, not just the sky, on water.
#define SSR_STEPS 6            // [4 6 8 12] Steps of that march.
#define WATER_TEXTURE 1        // [0 1] Let the resource pack's water texture show.
#define VANILLA_WATER 0        // [0 1] Use vanilla's water colour instead of the pack's tint.

// ---- Air ----------------------------------------------------------------
#define FOG_DENSITY 1.0        // [0.4 0.6 0.8 1.0 1.3 1.6]
#define UNDERWATER_FOG 1       // [0 1] Dense blue-green fog while submerged.

// ---- Solid geometry -----------------------------------------------------
#define WAVING 1               // [0 1] Plants and leaves sway. Uses the ids in block.properties.
#define WAVE_STRENGTH 1.0      // [0.4 0.7 1.0 1.3 1.7]
#define SUN_SHADING 1          // [0 1] Cheap directional sun on lit surfaces.
#define BLOCK_LIGHT 1.0        // [0.5 0.75 1.0 1.25 1.5] Torch and lava light strength.
#define BLOCKLIGHT_TEMP 1      // [0 1 2 3 4] Torch colour: 0 orange, 2 warm white, 4 neutral.
#define NIGHT_AMBIENT 0.055    // [0.03 0.045 0.055 0.07 0.09]
#define AVOID_DARK_LEVEL 0.045 // [0.000 0.015 0.030 0.045 0.060] The floor under the light in caves.
#define EYE_LIGHT 1            // [0 1] Night vision adds light, and tints it.
#define NV_COLOR_R 1.05        // [0.9 1.0 1.05 1.15 1.3]
#define NV_COLOR_G 1.00        // [0.9 1.0 1.05 1.15 1.3]
#define NV_COLOR_B 1.30        // [0.9 1.0 1.1 1.3 1.5]
#define HAND_LIGHT 1           // [0 1] A held torch throws light on nearby surfaces.
#define ENTITY_TINT 1          // [0 1] The red flash on a damaged mob.
#define MATERIAL_GLOSS 1       // [0 1] Highlight on metal, polished and fabric blocks.
#define GLOSS_STRENGTH 0.60    // [0.30 0.45 0.60 0.80 1.0]
#define EMISSIVE_GLOW 1        // [0 1] Glowstone, lava, lanterns and the rest never look dimmed.
#define BLACK_ENTITY_FIX 0     // [0 1] Lift pure-black geometry to a floor. A workaround for old drivers that draw some entities black, not an effect.

// ---- Shadows (opt in) ---------------------------------------------------
#define SHADOWS 0              // [0 1] Cast shadows: a second scene render.
#define SHADOW_QTY_SLIDER 1    // [1 2 3] Shadow map resolution: 512, 1024, 2048.
#define SHADOW_DISTANCE_SLIDER 0 // [0 1 2] Shadow distance: 75, 105, 255 blocks.
#define SHADOW_SOFT 1          // [0 1] Four-tap filtered lookup instead of one hard tap.
#define SHADOW_BLUR 1.0        // [0.5 1.0 1.5 2.0] How far the taps spread.
#define COLORED_SHADOW 0       // [0 1] Tint a shadow with the colour of the glass or water above it.
#define SHADOW_LOCK 0          // [0 16 32 64 128 256] Redraw shadows every N frames instead of every frame.

/* Hardware filtering makes Iris build the shadow map as a depth-comparison texture,
   which is a second sampler and a second allocation for a pass that may not exist.
   Only ask for it when the pass does. Declared after SHADOWS so the guard reads the
   value above rather than the preprocessor's 0 for an identifier it has not seen. */
/* Hardware filtering turns shadowtex0/1 into depth-comparison samplers
   (`sampler2DShadow`), and a comparison sampler cannot be read as an ordinary depth
   texture: `texture2D(shadowtex1, vec2)` does not exist for one. lib/shadowmap.glsl
   reads them as plain depth so it can apply its own bias and its four-tap kernel, so
   asking the mod for hardware filtering is what would stop the shadow profiles
   compiling. It stays off; the filtered lookup in lib/shadowmap.glsl is the soft path.
   Deliberately declared without a guard on SHADOWS: the value has to be the same in
   every program, and the pass being off must not change the sampler type. */
const bool shadowHardwareFiltering = false;

// ---- Sky ----------------------------------------------------------------
#define SKY_SUN_GLOW 1         // [0 1] Sun halo, moon halo.
#define SKY_STARS 1            // [0 1] Stars at night.

// ---- Sun ----------------------------------------------------------------
#define SUN_PATH -25           // [-40 -30 -25 -20 -10 0 10 20 25 30 40] Tilt of the sun's path across the sky, in degrees. This is what makes sunsets swing round instead of every day crossing overhead.
#define SUN_SIZE 1.0           // [0.7 1.0 1.3 1.8] How large the sun and its halo read.
#define SUN_HALO_SHAPE 1       // [0 1 2] 0 tight point, 1 soft glow, 2 wide haze.
#define SUN_R 100              // [85 92 100 108 115] Red gain of sunlight, percent.
#define SUN_G 100              // [85 92 100 108 115] Green gain of sunlight, percent.
#define SUN_B 100              // [85 92 100 108 115] Blue gain of sunlight, percent.

// ---- Clouds -------------------------------------------------------------
#define V_CLOUDS 0             // [0 1] Volumetric clouds: a slab march in the sky pass.
#define CLOUD_STYLE 0          // [0 1 2 3] 0 natural, 1 blocky, 2 pack texture from textures/noise.png, 3 vanilla flat.
#define CLOUD_SPEED 1.0        // [0.0 0.5 1.0 2.0] How fast the cloud deck drifts.
#define CLOUD_STEPS 6          // [4 6 8 10] Samples through the cloud slab.
#define CLOUD_HEIGHT 190.0     // [150.0 190.0 240.0] Height of the cloud slab.
#define CLOUD_THICKNESS 26.0   // [16.0 26.0 40.0] Thickness of the slab.
#define CLOUD_COVERAGE 0.52    // [0.42 0.48 0.52 0.58 0.66]

// ---- Ambient occlusion (opt in) -----------------------------------------
#define AO 0                   // [0 1] Screen-space ambient occlusion from the depth buffer.
#define AO_STRENGTH 0.65       // [0.30 0.45 0.55 0.65 0.80]
#define AO_RADIUS 0.055        // [0.030 0.045 0.055 0.080 0.110]
#define AO_TAPS 6              // [4 6] Ring samples. Four is the cheap setting that keeps it on.
#define AO_FADE 36.0           // [12.0 24.0 36.0 60.0] Distance at which the occlusion fades out.

// ---- Bloom (opt in) -----------------------------------------------------
#define BLOOM 0                // [0 1] Bright-pass glow, eight taps in the final pass.
#define BLOOM_STRENGTH 0.14    // [0.05 0.09 0.14 0.20 0.28]
#define BLOOM_RADIUS 1.6       // [1.0 1.6 2.4 3.4 4.6]
#define BLOOM_LOD 3.0          // [1.0 2.0 3.0 4.0 5.0] How wide the glow spreads.

// ---- Depth of field (opt in) --------------------------------------------
#define DOF 0                  // [0 1] Blurs away from the block you are looking at.
#define DOF_STRENGTH 0.09      // [0.05 0.07 0.09 0.11 0.13]
#define DOF_SAMPLES 6          // [4 6 8 10]
// ---- Anti-aliasing (opt in) ---------------------------------------------
#define AA_TYPE 0              // [0 1 2 3] 0 none, 1 temporal, 2 temporal + FXAA, 3 FXAA only.
#define TAA_WEIGHT 0.88        // [0.75 0.82 0.88 0.93] How much of the history survives.
#define FXAA_EDGE 0.12         // [0.06 0.12 0.20 0.30]

// ---- Motion blur (opt in) ----------------------------------------------
#define MOTION_BLUR 0          // [0 1] Blur along the path the camera moved.
#define MOTION_BLUR_SAMPLES 4  // [3 4 5 6]
#define MOTION_BLUR_STRENGTH 1.0 // [0.5 0.75 1.0 1.5 2.0]

// ---- Auto exposure and godrays (opt in) ---------------------------------
#define AUTO_EXPOSURE 0        // [0 1] Adapt the exposure to the brightness of the scene.
#define AUTO_EXPOSURE_SPEED 0.12 // [0.05 0.08 0.12 0.20]
#define VOL_LIGHT 0            // [0 1] Light shafts from the sun, march per pixel.
#define VOL_LIGHT_SAMPLES 4    // [3 4 5 6]
#define VOL_LIGHT_STRENGTH 0.55 // [0.25 0.40 0.55 0.75 1.0]

// ---- Sky palette --------------------------------------------------------
#define COLOR_SCHEME 0         // [0 1 2 3 4 5 6 7 99] 0 Natural, 1 Vivid, 2 Game, 3 Soft, 4 Cinematic, 5 Neon, 6 Warm, 7 Bright, 99 Custom.
#define CUSTOM_ZENITH_R 0.11   // [0.0 0.05 0.11 0.20 0.30 0.45 0.60]
#define CUSTOM_ZENITH_G 0.23   // [0.0 0.05 0.12 0.23 0.35 0.50 0.65]
#define CUSTOM_ZENITH_B 0.52   // [0.0 0.10 0.25 0.40 0.52 0.70 0.90]
#define CUSTOM_HORIZON_R 0.56  // [0.2 0.35 0.56 0.72 0.85 0.95]
#define CUSTOM_HORIZON_G 0.68  // [0.2 0.40 0.68 0.80 0.90 0.97]
#define CUSTOM_HORIZON_B 0.88  // [0.3 0.55 0.88 0.94 0.98 1.0]
#define CUSTOM_AMBIENT 0.45    // [0.20 0.30 0.40 0.45 0.55 0.70] Sky light of the custom theme.
#define CUSTOM_WATER_R 0.05    // [0.0 0.05 0.10 0.20 0.35]
#define CUSTOM_WATER_G 0.12    // [0.02 0.10 0.12 0.25 0.45]
#define CUSTOM_WATER_B 0.16    // [0.03 0.16 0.20 0.35 0.60]

// ---- Colour -------------------------------------------------------------
#define EXPOSURE 1.05          // [0.70 0.85 0.95 1.05 1.15 1.30 1.45]
#define SATURATION 1.06        // [0.80 0.90 1.00 1.06 1.15 1.25]
#define CONTRAST 1.02          // [0.95 1.00 1.02 1.06 1.10]
#define TONEMAP 1              // [0 1 2] 0 none, 1 soft, 2 gentle.
#define COLOR_R 100            // [50 75 90 100 110 125 150] Red channel gain, percent.
#define COLOR_G 100            // [50 75 90 100 110 125 150] Green channel gain, percent.
#define COLOR_B 100            // [50 75 90 100 110 125 150] Blue channel gain, percent.
#define GAMMA 100              // [80 90 95 100 105 110 120 130] Output gamma, percent. Above 100 lifts the midtones.
#define DITHER 1               // [0 1] Break up banding in the sky gradient.
#define CHROMA_ABER 0          // [0 1] Chromatic aberration towards the edges.
#define CHROMA_STRENGTH 0.35   // [0.15 0.25 0.35 0.50]
#define IMAGE_SHARPENING 0     // [0 1] Unsharp mask against the four neighbours.
#define SHARPEN 0.35           // [0.15 0.25 0.35 0.50 0.70]
#define COLOR_BLINDNESS 0      // [0 1] Colour-blindness aid.
#define COLOR_BLIND_MODE 0     // [0 1 2 3] 1 red-weak, 2 green-weak, 3 blue-weak.

// ---- Vanilla ambient occlusion -------------------------------------------
// Declared here, after AO, so the mod reads the value that matches the option:
// full vanilla darkening while this pack's screen-space AO is off would fight the
// ambient term, and none at all is right when the pack does it itself.

#if AO == 1
    const float ambientOcclusionLevel = 0.0;
#else
    const float ambientOcclusionLevel = 0.7;
#endif

// ---- Sun path ------------------------------------------------------------
// The one shader constant that is a choice rather than a tuning value, so it is an
// option. It is declared here, after SUN_PATH, for the same reason as AO above: a
// const written before its option would see 0 and tilt the wrong way forever. Iris
// and OptiFine read the first `sunPathRotation` they find in any included file, so
// its position in the file does not matter, only that it comes after the option.
#if SUN_PATH == -40
    const float sunPathRotation = -40.0;
#elif SUN_PATH == -30
    const float sunPathRotation = -30.0;
#elif SUN_PATH == -25
    const float sunPathRotation = -25.0;
#elif SUN_PATH == -20
    const float sunPathRotation = -20.0;
#elif SUN_PATH == -10
    const float sunPathRotation = -10.0;
#elif SUN_PATH == 0
    const float sunPathRotation = 0.0;
#elif SUN_PATH == 10
    const float sunPathRotation = 10.0;
#elif SUN_PATH == 20
    const float sunPathRotation = 20.0;
#elif SUN_PATH == 25
    const float sunPathRotation = 25.0;
#elif SUN_PATH == 30
    const float sunPathRotation = 30.0;
#else
    const float sunPathRotation = 40.0;
#endif

#endif
