/* Solace - deferred.fsh

Copies the finished scene into gaux1 (colortex4). That copy is what the water shader
reads when REFRACTION or WATER_SSR is on, so the surface can bend what is behind it
and reflect the world instead of only the sky.

This pass runs between the opaque and the translucent gbuffers, so the copy it takes is
the finished opaque scene of the *current* frame - which is exactly what refraction
needs: the water is drawn after this pass, and must bend what is behind it rather than
itself. The earlier note here had the order the other way round and concluded the copy
was a frame old; it is not, and colortex4 is filled edge to edge before any water reads
it. It is still declared un-cleared (lib/buffers.glsl) because a cleared buffer would
read as black rather than as the frame if this pass were ever absent.

Only useful when one of those two options is 1: with both off the copy is made and
never read. It still runs, because every pass in this pack runs and gates its own work
internally - see the note in shaders.properties about why the pack does not switch
passes off by expression.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/buffers.glsl"

/* DRAWBUFFERS:4 */

uniform sampler2D colortex0;

varying vec2 texcoord;

void main() {
    vec4 scene = texture2D(colortex0, texcoord);
    gl_FragData[0] = vec4(scene.rgb, 1.0);
}
