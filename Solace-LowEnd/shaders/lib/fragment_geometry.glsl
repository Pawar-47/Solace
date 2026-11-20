/* Solace - lib/fragment_geometry.glsl

Lighting for solid, textured geometry, without a lightmap texture fetch:

  ambient skylight  * lightmap sky channel squared
+ coloured sun      * how much the face looks at the sun * sky channel squared
+ torch light       * lightmap block channel squared
+ a little from night vision, and from the item in your hand
+ a gloss highlight on the metal, polished and fabric ids from block.properties

then the damage tint, the shadow term, distance fog, or underwater fog when the eye
is in water.
*/

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"
#include "/lib/sky_model.glsl"
#include "/lib/shadowmap.glsl"

uniform sampler2D gcolor;

void main() {
    vec4 albedo = texture2D(gcolor, texcoord) * tint;
    if (albedo.a < 0.10) discard;

    #if ENTITY_TINT == 1
        albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    #endif

    float skyLight = lmcoord.y;
    float blockLight = lmcoord.x;

    vec3 light = ambientColour() * (skyLight * skyLight);

    float facing = 1.0;
    #if SUN_SHADING == 1 || MATERIAL_GLOSS == 1 || SHADOWS == 1
        facing = sat(dot(normalize(normalView), normalize(sunPosition)));
    #endif

    #if SHADOWS == 1
        vec3 playerPosition = (gbufferModelViewInverse * vec4(viewSpacePos, 1.0)).xyz;
        facing *= shadowFactor(playerPosition, facing);
    #endif

    #if SUN_SHADING == 1
        light += sunColour() * facing * (skyLight * skyLight) * 0.85;
    #endif

    light += blockLightColour() * (blockLight * blockLight) * BLOCK_LIGHT;

    #if EYE_LIGHT == 1
        light += vec3(0.35, 0.45, 0.65) * nightVision * 0.45;
    #endif

    #if HAND_LIGHT == 1
        if (heldBlockLightValue > 0.5) {
            float nearness = sat(1.0 - length(viewSpacePos) / 6.0);
            light += blockLightColour() * nearness * (heldBlockLightValue / 15.0) * 0.80;
        }
    #endif

    vec3 colour = albedo.rgb * light;

    #if MATERIAL_GLOSS == 1
        float gloss = 0.0;
        if (blockId == SOLACE_GLOSS_METAL) {
            gloss = 0.85;
        } else if (blockId == SOLACE_GLOSS_POLISHED) {
            gloss = 0.45;
        } else if (blockId == SOLACE_GLOSS_FABRIC) {
            gloss = 0.16;
        }

        if (gloss > 0.0) {
            vec3 halfway = normalize(normalize(sunPosition) + normalize(-viewSpacePos));
            float highlight = pow(sat(dot(normalize(normalView), halfway)), 44.0);
            colour += sunColour() * highlight * gloss * GLOSS_STRENGTH * facing * skyLight;
        }
    #endif

    float viewDist = length(viewSpacePos);
    vec3 fogTint = fogColour();
    float fogAmount = 1.0 - exp(-viewDist * (2.2 * FOG_DENSITY) / max(far, 32.0));

    #if UNDERWATER_FOG == 1
        if (isEyeInWater == 1) {
            fogTint = vec3(0.050, 0.190, 0.250) * (0.35 + 0.65 * dayFactor());
            fogAmount = 1.0 - exp(-viewDist * 0.085);
        }
    #endif

    colour = mix(colour, fogTint, sat(fogAmount));

    gl_FragData[0] = vec4(colour, albedo.a);
}
