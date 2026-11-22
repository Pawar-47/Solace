/* Solace - deferred.fsh

Copies the finished scene into gaux1 (colortex4). That copy is what the water shader
reads when REFRACTION or WATER_SSR is on, so the surface can bend what is behind it
and reflect the world instead of only the sky.

The copy is taken after the translucent geometry, so it contains the water surface
itself; a reflection that lands on water therefore shows water. It also means the copy
water reads is one frame old, because this pass runs after gbuffers_water - the reason
colortex4 is never cleared (see lib/buffers.glsl).

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
