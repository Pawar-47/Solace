/* Solace - lib/fragment_clouds.glsl

Vanilla cloud geometry, lit from the palette with a lighter fog than the ground so
distant clouds stay visible. A library, so each dimension folder can compile the
same body with its own palette.
*/

#ifndef SOLACE_CLOUDS
#define SOLACE_CLOUDS

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"
#include "/lib/sky_model.glsl"

uniform sampler2D gcolor;

void main() {
    vec4 albedo = texture2D(gcolor, texcoord) * tint;
    if (albedo.a < 0.02) discard;

    vec3 light = ambientColour() * 1.05 + sunColour() * 0.30 + vec3(0.04);
    vec3 colour = albedo.rgb * light;

    float viewDist = length(viewSpacePos);
    float fogAmount = 1.0 - exp(-viewDist * (1.4 * FOG_DENSITY) / max(far, 64.0));
    colour = mix(colour, fogColour(), sat(fogAmount));

    gl_FragData[0] = vec4(colour, albedo.a);
}

#endif
