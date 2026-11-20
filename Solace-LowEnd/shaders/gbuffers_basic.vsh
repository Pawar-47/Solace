/* Solace - gbuffers_basic.vsh

Untextured vanilla geometry: the block outline, the hitting box, debug shapes. They
carry their colour in the vertex colour, and they are lit here, per vertex: the day
or night light plus the candle curve from the lightmap. Without it a block outline
glows in a cave and a leash is the brightest thing in the picture.

Per vertex, not per pixel: these are lines and boxes, and one lit colour for each is
all they can show.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/sky_model.glsl"

varying vec4 tint;
varying vec3 basicLight;

void main() {
    gl_Position = ftransform();
    tint = gl_Color;

    vec2 lightCoord = sat((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    float skyLight = sat(max(lightCoord.y - 0.065, 0.0) * 1.06951871657754);
    float blockCurve = lightCoord.x * lightCoord.x
                     + solPow6(lightCoord.x * 1.165);

    float sunUp = sunHeight();
    basicLight = ambientColour(dayFrom(sunUp), duskFrom(sunUp))
                 * (0.30 + 0.70 * skyLight * skyLight)
               + blockLightColour() * blockCurve * BLOCK_LIGHT;
}
