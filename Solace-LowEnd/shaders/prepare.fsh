/* Solace - prepare.fsh

The first pass of the frame: it fills the scene buffer with the horizon colour before
the sky and the geometry are drawn. That is what a pixel with nothing over it ends up
as - the void under the world, a gap between chunks - and it is cheaper than a ray per
pixel because the colour does not depend on the view direction.

The pack this one replaces has this pass too, and fills the same role with it. Reading
the sky model directly here is what keeps the gaps the same colour as the horizon they
sit under, in every dimension.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/sky_model.glsl"

/* DRAWBUFFERS:0 */

varying vec2 texcoord;

void main() {
    float sunUp = sunHeight();
    float day = dayFrom(sunUp);
    float dusk = duskFrom(sunUp);
    gl_FragData[0] = vec4(fogColour(day, dusk), 1.0);
}
