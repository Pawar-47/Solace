/* Solace - gbuffers_beaconbeam.fsh
The beam is its own light source, so it is brightened and left unfogged. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"

uniform sampler2D gtexture;

void main() {
    vec4 albedo = texture2D(gtexture, texcoord) * tint;
    if (albedo.a < 0.01) discard;

    gl_FragData[0] = vec4(albedo.rgb * 1.60, albedo.a);
}


/* DRAWBUFFERS:0 */
