/* Solace - gbuffers_skytextured.fsh
The sun disc and the moon disc. Brighter by day, lifted a little at night so
the moon stays readable through the fog colour. */

#version 120

/* One target. The directive below is alone on its line, and nothing may follow it: the
   mod reads every character between its colon and its closing marker as a buffer index,
   so a dash and a note are read as index -1 and the game stops with
   "Index -1 out of bounds for length 32". Explanations go above it, like this one. */
/* DRAWBUFFERS:0 */

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/sky_model.glsl"

uniform sampler2D gtexture;

varying vec2 texcoord;
varying vec4 tint;

void main() {
    vec4 disc = texture2D(gtexture, texcoord);
    if (disc.a < 0.01) discard;

    float sunUp = sunHeight();
    float bright = 1.0 + sat(sunUp) * 0.80 + (1.0 - dayFrom(sunUp)) * 0.25;
    vec3 colour = disc.rgb * tint.rgb * bright;

    gl_FragData[0] = vec4(colour, disc.a * tint.a);
}
