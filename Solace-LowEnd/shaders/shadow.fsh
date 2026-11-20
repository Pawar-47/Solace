/* Solace - shadow.fsh

The shadow pass writes depth, and with COLORED_SHADOW it also writes the colour of
whatever it draws into shadowcolor0, which is what lets a stained-glass pane or a
sheet of water tint the shadow it casts.

Two things are thrown away, both for the same reason - they would cast a shadow they
should not:

  * alpha-tested geometry below the same 0.10 threshold the solid pass uses, so a
    leaf does not cast a solid square;
  * emissive blocks: fire, torches and lanterns are their own light and must not
    drop a shadow on the ground under them, which is what the reference does with
    its `is_noshadow` flag.
*/

#version 120

/* shadowtex0 (depth of everything) and shadowcolor0 (colour of the translucent part
   of it). shadowtex1, which the geometry pass samples, keeps the opaque depth. */
/* DRAWBUFFERS:01 */

#include "/lib/config.glsl"
#include "/lib/blockids.glsl"
#include "/lib/shadowmap.glsl"
#include "/lib/buffers.glsl"

uniform sampler2D gcolor;

varying vec2 texcoord;
varying vec4 tint;
varying float blockId;

void main() {
    if (blockId == SOLACE_EMISSIVE) discard;

    vec4 albedo = texture2D(gcolor, texcoord) * tint;
    if (albedo.a < 0.10) discard;

    gl_FragData[0] = vec4(1.0);

    #if COLORED_SHADOW == 1
        /* Only the translucent part writes a colour; an opaque block writes white, so
           the tint a player sees is the one the light actually passed through. The
           factor of 1 - 0.35a keeps a very transparent pane from tinting fully. */
        if (albedo.a < 0.95) {
            gl_FragData[1] = vec4(albedo.rgb * (1.0 - albedo.a * 0.35), 1.0);
        } else {
            gl_FragData[1] = vec4(1.0);
        }
    #endif
}
