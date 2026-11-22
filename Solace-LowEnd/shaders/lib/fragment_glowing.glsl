/* Solace - lib/fragment_glowing.glsl

The glowing outline Minecraft draws around some mobs and items: its own colour,
lifted so it stays readable in the dark, still fading into the distance fog that the
vertex stage already measured.
*/

#ifndef SOLACE_GLOWING
#define SOLACE_GLOWING

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"
#include "/lib/sky_model.glsl"

uniform sampler2D gtexture;

void main() {
    vec4 albedo = texture2D(gtexture, texcoord) * tint;
    if (albedo.a < 0.10) discard;

    float sunUp = sunHeight();
    float day = dayFrom(sunUp);
    float dusk = duskFrom(sunUp);
    vec3 astroColour = mix(moonColour() * 2.5, sunColourAt(sat(sunUp)), day);

    vec3 light = ambientColour(day, dusk) + astroColour * 0.50 + blockLightColour() * 0.45;
    vec3 colour = albedo.rgb * light;

    colour = mix(colour, fogColour(day, dusk), fogFactor);

    gl_FragData[0] = vec4(colour, albedo.a);
}

#endif


/* The DRAWBUFFERS directive for this pass is in each gbuffers_entities_glowing program
   file, not here: it belongs to the program. */
