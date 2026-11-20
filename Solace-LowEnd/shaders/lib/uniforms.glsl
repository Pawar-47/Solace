/* Solace - lib/uniforms.glsl

The uniforms Iris and OptiFine provide that this pack uses, declared once so no
program has to repeat them. Declaring one a program does not use costs nothing.
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

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float nightVision;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;
uniform int moonPhase;

#endif
