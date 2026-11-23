/* Solace - lib/uniforms.glsl

The uniforms Iris and OptiFine provide that this pack uses, declared once so no
program has to repeat them. Declaring one a program does not use costs nothing, and
a uniform the running version does not provide simply reads as zero - which is why
blindness and darknessFactor can be declared without a version guard.
*/

#ifndef SOLACE_UNIFORMS
#define SOLACE_UNIFORMS

/* The options, because the jitter below reads AA_TYPE and a program may include this
   file before anything else. config.glsl has its own guard, so including it twice is
   free. */
#include "/lib/config.glsl"

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
/* Both are view-space directions with a length of 100, not unit vectors - the mod
   never normalises them for you. `normalize(sunPosition)` is the direction, and
   `0.01 * sunPosition` is the same vector at unit length. */
uniform vec3 sunPosition;      // towards the sun, view space, length 100
uniform vec3 moonPosition;     // towards the moon, view space, length 100

uniform vec4 entityColor;      // damage tint, only filled for entity programs
/* Filled from entity.properties for entity programs, and 0 everywhere else. This is
   the uniform entity ids are read through - mc_Entity is a terrain attribute. */
uniform int entityId;
uniform float heldBlockLightValue;
uniform int heldItemId;        // filled from item.properties, 0 when unknown

uniform float frameTimeCounter;
uniform float frameTime;
uniform float centerDepthSmooth;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform float nightVision;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

/* Vanilla's fog colour for the dimension. The Nether has no sky to take a colour
   from, so its palette is built from this instead of from a theme. */
uniform vec3 fogColor;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;
uniform int moonPhase;

/* Distant Horizons. The mod renders the far terrain into its own depth buffers, at
   its own near and far planes, and Iris only fills these when the mod is installed -
   which is why they are inside the guard. */
#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex0;   // far terrain, opaque
    uniform sampler2D dhDepthTex1;   // far terrain, with its translucent part
    uniform float dhNearPlane;
    uniform float dhFarPlane;
    /* The far terrain is projected with its own matrix and its own far plane, not
       the vanilla one. */
    uniform mat4 dhProjection;
    /* How far the mod draws, in blocks. It is usually much further than `far`, which
       is why the far fog cannot be normalised by the vanilla distance. Declared float:
       a uniform declared with the wrong type reads as 0, and a sight distance of 0
       turns the far world into a wall of fog at 32 blocks. */
    uniform float dhRenderDistance;
#endif

/* ---- The dimension ------------------------------------------------------

   This pack used to answer "which dimension is this?" with compile-time folders -
   world0, world-1, world1. The rule the mods actually implement is that if any worldN
   folder is present, shaders are loaded *only* from those folders and never from the
   shader root. Each folder therefore had to hold a copy of every program, and the three
   here did not: the Nether and End folders were missing final, composite2, deferred and
   shadow, so those dimensions ran with no tone curve, no antialiasing, no water copy
   and no cast shadows - and the Overworld ran the same thin set.

   So there is one pipeline now, and the dimension is a uniform. biome_category is the
   category of the biome the player is standing in, and the mod supplies the CAT_*
   names. A value is defined here for the two that matter in case an old build does not
   supply the name. On a loader that leaves biome_category at 0 (OptiFine only fills it
   for custom uniforms) both helpers read false, so every dimension uses the Overworld
   palette: a cosmetic difference, not a broken picture. */
#ifndef CAT_NETHER
    #define CAT_NETHER 16
#endif
#ifndef CAT_THE_END
    #define CAT_THE_END 8
#endif

uniform int biome_category;

bool solaceIsNether() { return biome_category == CAT_NETHER; }
bool solaceIsEnd()    { return biome_category == CAT_THE_END; }
bool solaceNoSky()    { return solaceIsNether() || solaceIsEnd(); }

/* ---- The temporal-antialiasing jitter ------------------------------------

   The sub-pixel offset every vertex stage adds while temporal antialiasing is on, as a
   fraction of a pixel in clip space. It is a function because it has to be *one* answer
   for the whole frame: the sky, the sun and the moon used to jitter on a four-phase
   square pattern while the geometry used this eight-phase one, and two patterns in the
   same frame is a mismatch the history cannot resolve - it shows as a smeared horizon
   and flickering on the sun's edge. Every stage that moves a vertex under AA_TYPE 1 or
   2 now calls this, and the multiply by w keeps the offset the same size at any depth. */
vec2 solaceJitter() {
    #if AA_TYPE == 1 || AA_TYPE == 2
        float phase = mod(float(frameCounter), 8.0);
        vec2 subPixel = fract(phase * vec2(0.75487766624669276, 0.569840290998) + 0.37)
                      * 2.0 - 1.0;
        return subPixel * 0.5 * vec2(2.0 / viewWidth, 2.0 / viewHeight);
    #else
        return vec2(0.0);
    #endif
}

#endif
