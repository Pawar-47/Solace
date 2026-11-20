/* Solace - gbuffers_beaconbeam.fsh
The beam is its own light source, so it is brightened and left unfogged. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"

/* DRAWBUFFERS:0 */

uniform sampler2D gcolor;

void main() {
    vec4 albedo = texture2D(gcolor, texcoord) * tint;
    if (albedo.a < 0.01) discard;

    gl_FragData[0] = vec4(albedo.rgb * 1.60, albedo.a);
}
