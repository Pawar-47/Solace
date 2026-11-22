/* Solace - shadow.fsh

The shadow pass writes depth, and with COLORED_SHADOW it also writes the colour of
whatever it draws into shadowcolor0, which is what lets a stained-glass pane or a
sheet of water tint the shadow it casts.

Two things are thrown away, both for the same reason - they would cast a shadow they
should not:

  * alpha-tested geometry below the same 0.10 threshold the solid pass uses, so a
    leaf does not cast a solid square;
  * emissive blocks: fire, torches and lanterns are their own light and must not
    drop a shadow on the ground under them: a torch that shadowed its own pool of
    light would look wrong.

The tint goes to the FIRST colour attachment, which in this pass is shadowcolor0.
lib/shadowmap.glsl samples exactly that buffer in shadowTintAt(), so writing the tint
to the second attachment meant the colour was stored where nothing ever read it.

The albedo comes from `gtexture`, the block atlas - the same sampler the geometry
programs read. `gcolor` is not the atlas: it is the alias for colortex0, the screen
buffer, so sampling it here returned the scene instead of the block and every surface
passed the alpha test as opaque.
*/

#version 120

/* shadowtex0 (depth of everything) and shadowcolor0 (colour of the translucent part
   of it). shadowtex1, which the geometry pass samples, keeps the opaque depth.

   No DRAWBUFFERS line belongs here: the attachments of this pass are fixed - the first
   is shadowcolor0 and the second shadowcolor1 - and a DRAWBUFFERS list names colortex
   targets the shadow pass cannot write. */

#include "/lib/config.glsl"
#include "/lib/blockids.glsl"
#include "/lib/shadowmap.glsl"
#include "/lib/buffers.glsl"

uniform sampler2D gtexture;

varying vec2 texcoord;
varying vec4 tint;
varying float blockId;

void main() {
    if (blockId == SOLACE_EMISSIVE) discard;

    vec4 albedo = texture2D(gtexture, texcoord) * tint;
    if (albedo.a < 0.10) discard;

    #if COLORED_SHADOW == 1
        /* Only the translucent part writes a colour; an opaque block writes white, so
           the tint a player sees is the one the light actually passed through. The
           factor of 1 - 0.35a keeps a very transparent pane from tinting fully. */
        if (albedo.a < 0.95) {
            gl_FragData[0] = vec4(albedo.rgb * (1.0 - albedo.a * 0.35), 1.0);
        } else {
            gl_FragData[0] = vec4(1.0);
        }
    #else
        gl_FragData[0] = vec4(1.0);
    #endif
}
