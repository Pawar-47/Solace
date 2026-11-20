/* Solace - shadow.fsh

Depth only. Two things are thrown away here, both for the same reason - they would
cast a shadow they should not:

  * alpha-tested geometry below the same 0.10 threshold the solid pass uses, so a
    leaf does not cast a solid square;
  * emissive blocks: fire, torches and lanterns are their own light and must not
    drop a shadow on the ground under them, which is what the reference does with
    its `is_noshadow` flag.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/blockids.glsl"
#include "/lib/shadowmap.glsl"

uniform sampler2D gcolor;

varying vec2 texcoord;
varying vec4 tint;
varying float blockId;

void main() {
    if (blockId == SOLACE_EMISSIVE) discard;

    vec4 albedo = texture2D(gcolor, texcoord) * tint;
    if (albedo.a < 0.10) discard;

    gl_FragData[0] = vec4(1.0);
}
