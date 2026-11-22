/* Solace - world-1/prepare.fsh
Nether: the fog colour behind the world, taken from the Nether palette. */

#version 120

#define SOLACE_DIM_NETHER 1

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/sky_model.glsl"

/* DRAWBUFFERS:0 */

varying vec2 texcoord;

void main() {
    float sunUp = sunHeight();
    float day = dayFrom(sunUp);
    float dusk = duskFrom(sunUp);
    gl_FragData[0] = vec4(fogColour(day, dusk), 1.0);
}
