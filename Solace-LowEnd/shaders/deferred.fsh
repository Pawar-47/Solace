/* Solace - deferred.fsh
Copies the scene, as it stands before any translucent geometry, into gaux1
(colortex4). That copy is what the water shader reads when REFRACTION is on, so
the surface can bend what is behind it instead of only tinting it.

Only runs when REFRACTION is 1; with it off the pass is switched off in
shaders.properties and costs nothing.
*/

#version 120

#include "/lib/config.glsl"

/* DRAWBUFFERS:4 */

uniform sampler2D colortex0;

varying vec2 texcoord;

void main() {
    vec4 scene = texture2D(colortex0, texcoord);
    gl_FragData[0] = vec4(scene.rgb, 1.0);
}
