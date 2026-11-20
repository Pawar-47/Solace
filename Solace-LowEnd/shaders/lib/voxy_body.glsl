/* Solace - lib/voxy_body.glsl

Voxy draws the terrain past the Distant Horizons distance with its own pipeline: no
gbuffer matrices, no mc_Entity, and a fragment entry point that takes the tint, the
lightmap, the face and the block id as a struct instead of varyings. Iris supplies the
`vx*` uniforms and the samplers listed in voxy.json; everything else has to be worked
out here.

The lighting is the same model as the near terrain, because that is the whole point:
same de-biased lightmap, same candle curve, same palette, same fog. What it cannot
have is the shadow map (the far terrain lies past it), so the sky-exposure stand-in
takes that place.

Two entry points use this file:
  VOXY_BLOCK  opaque far terrain - it also fills the scene copy that water refraction
              reads, so an ocean reflecting the horizon shows the far land
  VOXY_WATER  far water - ripples, a sky reflection and a translucent alpha
*/

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/blockids.glsl"
#include "/lib/sky_model.glsl"

/* The struct is declared by the pack, not by Iris: Voxy hands the fragment its data
   in this shape, and the layout has to match it field for field. */
struct VoxyFragmentParameters {
    vec4 sampledColour;
    vec2 tile;
    vec2 uv;
    uint face;
    uint modelId;
    vec2 lightMap;
    vec4 tinting;
    uint customId;
};

layout(location = 0) out vec4 voxyColour;

#if defined VOXY_BLOCK
layout(location = 1) out vec4 voxySceneCopy;
#endif

void voxy_emitFragment(VoxyFragmentParameters parameters) {
    vec4 albedo = parameters.sampledColour * parameters.tinting;
    vec2 lm = sat(parameters.lightMap);

    float day = dayFactor();
    float dusk = duskFactor();

    /* Where this fragment is, in view space, rebuilt from its own depth. Everything
       below needs it: the fog distance, the water ripples and the eye vector. */
    vec2 ndc = gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0;
    vec4 view = vxProjInv * vec4(ndc, gl_FragCoord.z * 2.0 - 1.0, 1.0);
    view /= view.w;
    vec3 worldPos = (vxModelViewInv * view).xyz + cameraPosition;

    /* Face normal from Voxy's index: face >> 1 picks the axis, face & 1 the side. It
       is in the same view space as sunPosition, so no conversion is needed for the
       sun and one for the world-space wave direction. */
    vec3 normal = vec3(float((parameters.face >> 1u) == 2u),
                       float((parameters.face >> 1u) == 0u),
                       float((parameters.face >> 1u) == 1u));
    normal *= float(parameters.face & 1u) * 2.0 - 1.0;
    normal = normalize(mat3(vxModelView) * normal);

    float skyLight = sat(max(lm.y - 0.065, 0.0) * 1.06951871657754);
    float blockCurve = lm.x * sqrt(lm.x) + solPow6(lm.x * 1.17);

    #if defined VOXY_WATER
        /* Only water ripples, and only when the waves are on. The slope comes from the
           same two noise layers the near water uses. */
        #if WATER_WAVES == 1
            vec2 base = worldPos.xz * (0.42 * WAVE_SCALE);
            float t = frameTimeCounter * WAVE_SPEED;
            vec2 p1 = base + vec2(t * 0.85, t * 0.55);
            vec2 p2 = base * 2.10 - vec2(t * 0.65, t * 0.95);

            float e = 0.08;
            float a0 = solFbm(p1);
            float ax = solFbm(p1 + vec2(e, 0.0));
            float az = solFbm(p1 + vec2(0.0, e));
            float b0 = solFbm3(p2);
            float bx = solFbm3(p2 + vec2(e, 0.0));
            float bz = solFbm3(p2 + vec2(0.0, e));

            vec2 slope = vec2(ax - a0, az - a0) * 4.0
                       + vec2(bx - b0, bz - b0) * 2.0;
            slope *= (1.0 - rainStrength * 0.35) * 0.45;

            vec3 worldNormal = normalize(vec3(-slope.x, 1.0, -slope.y));
            normal = normalize(mat3(vxModelView) * worldNormal);
        #endif
    #endif

    vec3 sunDir = normalize(mix(moonPosition, sunPosition, day));
    float facing = sat(dot(normal, sunDir));

    #if !defined VOXY_WATER
        /* The shadow map covers the near world only, so the sky-exposure stand-in
           takes over out here - the same term the near terrain uses when shadows are
           off, one power lower because a far vertex has less sky data. */
        facing *= skyLight * skyLight * skyLight * skyLight;
    #endif

    vec3 light = ambientColour(day, dusk) * (0.045 + 0.955 * skyLight * skyLight)
               + blockLightColour() * blockCurve * BLOCK_LIGHT
               + mix(moonColour() * 2.5, sunColour(), day) * facing * 0.85
                 * (1.0 - rainStrength * 0.75);

    vec3 colour = albedo.rgb * light;

    /* Voxy hands the block.properties id in customId, so the far world gets the same
       four material classes and the same emissive rule as the near one. Without this,
       a distant copper roof and a distant stone floor were the same material. */
    float customId = float(parameters.customId);

    #if MATERIAL_GLOSS == 1
        float gloss = 0.0;
        if (customId == SOLACE_GLOSS_METAL) {
            gloss = 0.85;
        } else if (customId == SOLACE_GLOSS_POLISHED) {
            gloss = 0.45;
        } else if (customId == SOLACE_GLOSS_FABRIC) {
            gloss = 0.16;
        } else if (customId == SOLACE_GLOSS_SAND) {
            gloss = 0.08;
        }

        if (gloss > 0.0) {
            vec3 halfway = normalize(sunDir + normalize(view.xyz));
            float highlight = pow(sat(dot(normal, halfway)), 44.0);
            colour += mix(moonColour() * 2.5, sunColour(), day) * highlight * gloss
                    * GLOSS_STRENGTH * facing * skyLight * (1.0 - rainStrength);
        }
    #endif

    #if EMISSIVE_GLOW == 1
        if (customId == SOLACE_EMISSIVE) {
            colour = max(colour, albedo.rgb * (0.90 + 0.35 * sat(lm.x)));
        }
    #endif

    #if defined VOXY_WATER
        /* Voxy's translucent pass carries water and glass together, told apart by the
           same block id the near water uses. Only water ripples. */
        bool voxyGlass = (customId == SOLACE_GLASS);
        vec3 toEye = normalize(-view.xyz);
        float fresnel = pow(1.0 - sat(dot(normal, toEye)), 5.0);
        float voxyAlpha = sat(albedo.a * 0.85 + 0.15);

        /* The dome gradient stands in for the sky, and the only world it can reflect is
           the copy of the frame it can see - projected 768 blocks along the mirror
           direction, because there is no depth buffer here to march. */
        vec3 skyProxy = mix(horizonColour(day, dusk), zenithColour(day, dusk), 0.45);
        vec3 mirror = skyProxy * 0.85;
        float mirrorBorder = 0.0;

        #if WATER_SSR == 1 && WATER_REFLECTION == 1
            vec4 mirrorClip = vxProj * vec4(view.xyz + reflect(-toEye, normal) * 768.0, 1.0);
            if (mirrorClip.w > 0.0001) {
                vec2 mirrorUV = mirrorClip.xy / mirrorClip.w * 0.5 + 0.5;
                mirrorBorder = sat((1.0 - max(0.0, abs(mirrorUV.y - 0.5)) * 2.0) * 50.0);

                mirrorUV.x = abs(mirrorUV.x);
                if (mirrorUV.x > 1.0) mirrorUV.x = 2.0 - mirrorUV.x;

                mirror = texture2D(gaux1, clamp(mirrorUV, vec2(0.002), vec2(0.998))).rgb;
            }
        #endif

        if (voxyGlass) {
            /* Glass: a flat sheet that blends into the sky and then into the mirror
               image, and closes to opaque at grazing angles. */
            colour = mix(colour, skyProxy, fresnel);
            colour = mix(colour, mix(skyProxy, mirror, mirrorBorder), fresnel * 0.5);
            voxyAlpha = mix(voxyAlpha, 1.0, fresnel * 0.9);
        } else {
            float strength = sat(0.08 + fresnel * 0.92);
            colour = mix(colour, mix(skyProxy, mirror, mirrorBorder), strength);

            #if REFRACTION == 1
                /* Voxy documents its depth as lying between 16 and 48000 blocks, so the
                   thickness of water behind this pixel is worked out in that projection
                   rather than the vanilla one. */
                vec2 voxyUV = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
                vec2 bent = clamp(voxyUV
                                  + normal.xy * (0.09 / (1.0 + length(view.xyz) * 0.25)),
                                  vec2(0.002), vec2(0.998));
                vec3 behind = texture2D(gaux1, bent).rgb;

                const float voxyNear = 16.0;
                const float voxyFar = 48000.0;
                float surfaceDistance = 2.0 * voxyNear * voxyFar
                    / (voxyFar + voxyNear
                       - (2.0 * gl_FragCoord.z - 1.0) * (voxyFar - voxyNear));
                float behindDistance = 2.0 * voxyNear * voxyFar
                    / (voxyFar + voxyNear
                       - (2.0 * texture2D(vxDepthTexTrans, bent).r - 1.0)
                         * (voxyFar - voxyNear));
                float thickness = max(behindDistance - surfaceDistance, 0.0);

                float absorbed = 1.0 - exp(-thickness * thickness
                                           * WATER_ABSORPTION * 0.5);
                colour = mix(behind, colour, absorbed);
            #endif
        }
    #endif

    /* Fog. Voxy draws to its own render distance, in chunks, so that is what the fade
       is normalised by - and its curve is as soft as the one far terrain uses, because
       this is the same horizon seen by a different renderer. */
    float fogDist = length(view.xyz);
    float sight = max(float(vxRenderDistance) * 16.0, 64.0);
    float skyExposure = max(float(eyeBrightnessSmooth.y) * 0.004166666666666667,
                            skyLight);
    float fogAmount = pow(sat(fogDist / sight) * skyExposure,
                          mix(0.30, 0.50, rainStrength));
    colour = mix(colour, fogColour(day, dusk), sat(fogAmount));

    /* Night vision has to reach out here too, or drinking a potion lights the near
       world and leaves the horizon black. Lifting towards the unlit albedo is the same
       thing as lifting the light towards white. */
    colour = mix(colour, albedo.rgb, sat(nightVision * 0.125));
    colour *= mix(vec3(1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);

    /* Blindness and the Warden's darkness reach out here too. */
    float darkness = max(blindness, darknessFactor * darknessLightFactor);
    if (darkness > 0.01) {
        colour = mix(colour, vec3(0.0), sat(darkness * fogDist * 0.0016));
    }

    colour = clamp(colour, vec3(0.0), vec3(50.0));

    #if defined VOXY_WATER
        voxyColour = vec4(colour, sat(voxyAlpha));
    #else
        voxyColour = vec4(colour, albedo.a);
        /* The scene copy the water reads: far land has to be in it, or a reflection
           that lands on the horizon finds nothing. */
        voxySceneCopy = vec4(colour, 1.0);
    #endif
}
