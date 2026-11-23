/* Solace - gbuffers_spidereyes.fsh
Eyes glow on their own: no lightmap, no fog, just their texture lifted. */

#version 120

/* One target. The directive below is alone on its line, and nothing may follow it: the
   mod reads every character between its colon and its closing marker as a buffer index,
   so a dash and a note are read as index -1 and the game stops with
   "Index -1 out of bounds for length 32". Explanations go above it, like this one. */
/* DRAWBUFFERS:0 */

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"

uniform sampler2D gtexture;

void main() {
    vec4 albedo = texture2D(gtexture, texcoord) * tint;
    if (albedo.a < 0.10) discard;

    gl_FragData[0] = vec4(albedo.rgb * 1.45, albedo.a);
}
