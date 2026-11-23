/* Solace - lib/fragment_clouds.glsl

Vanilla cloud geometry, lit from the palette, with the fog amount the vertex stage
already computed. Kept in a library so the cloud pass and the sky's own cloud deck read
one copy of the colour model.
*/

#ifndef SOLACE_CLOUDS
#define SOLACE_CLOUDS

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"
#include "/lib/sky_model.glsl"

uniform sampler2D gtexture;

void main() {
    vec4 albedo = texture2D(gtexture, texcoord) * tint;
    if (albedo.a < 0.02) discard;

    float sunUp = sunHeight();
    float day = dayFrom(sunUp);
    float dusk = duskFrom(sunUp);
    vec3 astroColour = mix(moonColour() * 2.5, sunColourAt(sat(sunUp)), day);

    vec3 light = ambientColour(day, dusk) * 1.05 + astroColour * 0.30 + vec3(0.04);
    vec3 colour = albedo.rgb * light;

    colour = mix(colour, fogColour(day, dusk), fogFactor);

    /* Blindness and the Warden's darkness reach the cloud deck too: a deck that
       stayed bright over a dark world would give the effect away. */
    float darkness = max(blindness, darknessFactor * darknessLightFactor);
    if (darkness > 0.01) {
        colour = mix(colour, vec3(0.0), sat(darkness * 0.85));
    }

    gl_FragData[0] = vec4(colour, albedo.a);
}

#endif


/* The DRAWBUFFERS directive for this pass is in each gbuffers_clouds program file, not
   here: it belongs to the program. */
