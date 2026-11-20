/* Solace - lib/config.glsl

Every option this pack has lives here, as a define with the allowed values in a
bracket comment so Iris and OptiFine can build the options screen from it.

Nothing is left out for being expensive: every effect the reference has exists, and
each heavy one has a cheap setting that keeps it on instead of switching it off.
The `PerformancePlus` profile in shaders.properties is exactly that - everything
enabled, all samples at their minimum, the shadow map at 512 px over 75 blocks.
*/

#ifndef SOLACE_CONFIG
#define SOLACE_CONFIG

// ---- Water ---------------------------------------------------------------
#define WATER_WAVES 1          // [0 1] Animated water surface.
#define WAVE_SPEED 0.55        // [0.2 0.35 0.55 0.8 1.1]
#define WAVE_SCALE 1.0         // [0.5 1.0 1.5 2.0]
#define WATER_OPACITY 0.72     // [0.40 0.55 0.65 0.72 0.85 1.0]
#define WATER_REFLECTION 1     // [0 1] Reflect the sky on the water surface.
#define WATER_GLINT 1          // [0 1] Sun and moon highlight on water.
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
#define EYE_LIGHT 1            // [0 1] Night vision adds light, and tints it.
#define NV_COLOR_R 1.05        // [0.9 1.0 1.05 1.15 1.3]
#define NV_COLOR_G 1.00        // [0.9 1.0 1.05 1.15 1.3]
#define NV_COLOR_B 1.30        // [0.9 1.0 1.1 1.3 1.5]
#define HAND_LIGHT 1           // [0 1] A held torch throws light on nearby surfaces.
#define ENTITY_TINT 1          // [0 1] The red flash on a damaged mob.
#define MATERIAL_GLOSS 1       // [0 1] Highlight on metal, polished and fabric blocks.
#define GLOSS_STRENGTH 0.60    // [0.30 0.45 0.60 0.80 1.0]
#define EMISSIVE_GLOW 1        // [0 1] Glowstone, lava, lanterns and the rest never look dimmed.

// ---- Shadows (opt in) ---------------------------------------------------
#define SHADOWS 0              // [0 1] Cast shadows: a second scene render.
#define SHADOW_QTY_SLIDER 1    // [1 2 3] Shadow map resolution: 512, 1024, 2048.
#define SHADOW_DISTANCE_SLIDER 0 // [0 1 2] Shadow distance: 75, 105, 255 blocks.
#define SHADOW_SOFT 1          // [0 1] Four-tap filtered lookup instead of one hard tap.
#define SHADOW_BLUR 1.0        // [0.5 1.0 1.5 2.0] How far the taps spread.

// ---- Sky ----------------------------------------------------------------
#define SKY_SUN_GLOW 1         // [0 1] Sun halo, moon halo.
#define SKY_STARS 1            // [0 1] Stars at night.
#define V_CLOUDS 0             // [0 1] Volumetric clouds: a slab march in the sky pass.
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
#define BLOOM 0                // [0 1] Bright-pass glow: mipmap taps, as the reference does it.
#define BLOOM_STRENGTH 0.14    // [0.05 0.09 0.14 0.20 0.28]
#define BLOOM_RADIUS 1.6       // [1.0 1.6 2.4 3.4 4.6]
#define BLOOM_LOD 3.0          // [1.0 2.0 3.0 4.0 5.0] Mip level the glow is gathered from: higher is wider.

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
#define COLOR_SCHEME 1         // [0 1 2 3 4 5 6 7 99] 0 Ethereal, 1 Shoka, 2 Classic, 3 Legacy, 4 Captain, 5 Psychedelic, 6 Cocoa, 7 Testigo, 99 Custom.
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
#define DITHER 1               // [0 1] Break up banding in the sky gradient.
#define CHROMA_ABER 0          // [0 1] Chromatic aberration towards the edges.
#define CHROMA_STRENGTH 0.35   // [0.15 0.25 0.35 0.50]
#define IMAGE_SHARPENING 0     // [0 1] Unsharp mask against the four neighbours.
#define SHARPEN 0.35           // [0.15 0.25 0.35 0.50 0.70]
#define COLOR_BLINDNESS 0      // [0 1] Colour-blindness aid.
#define COLOR_BLIND_MODE 0     // [0 1 2 3] 1 red-weak, 2 green-weak, 3 blue-weak.

#endif
