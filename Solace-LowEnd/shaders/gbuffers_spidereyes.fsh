/* Solace - gbuffers_spidereyes.fsh
Eyes glow on their own: no lightmap, no fog, just their texture lifted. */

#version 120

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


/* DRAWBUFFERS:0 */
