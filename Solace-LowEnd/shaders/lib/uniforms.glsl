/* Solace - lib/uniforms.glsl

The uniforms Iris and OptiFine provide that this pack uses, declared once so no
program has to repeat them. Declaring one a program does not use costs nothing, and
a uniform the running version does not provide simply reads as zero - which is why
blindness and darknessFactor can be declared without a version guard.
*/

#ifndef SOLACE_UNIFORMS
#define SOLACE_UNIFORMS

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;      // unit vector towards the sun, view space
uniform vec3 moonPosition;     // unit vector towards the moon, view space

uniform vec4 entityColor;      // damage tint, only filled for entity programs
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
   from, so its palette is built from this instead of from a theme, which is what the
   reference does with the same uniform. */
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
#endif

#endif
