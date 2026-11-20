/* Solace - prepare.fsh

The first pass of the frame: it fills the scene buffer with the horizon colour before
the sky and the geometry are drawn. That is what a pixel with nothing drawn over it
ends up as - the void under the world, or a gap between chunks - and it is cheaper
than a ray per pixel because the colour does not depend on the view direction.
*/

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/sky_model.glsl"

varying vec2 texcoord;

void main() {
    float day = dayFactor();
    float dusk = duskFactor();
    vec3 background = fogColour(day, dusk);
    gl_FragData[0] = vec4(background, 1.0);
}
