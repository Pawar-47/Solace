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

    #if defined VOXY_WATER
        /* A sky reflection without the reflection functions: those want a world-space
           ray built from gbufferModelViewInverse, which Voxy does not provide. The
           dome gradient is close enough at this distance to be indistinguishable. */
        vec3 skyProxy = mix(horizonColour(day, dusk), zenithColour(day, dusk), 0.45);
        vec3 toEye = normalize(-view.xyz);
        float fresnel = pow(1.0 - sat(dot(normal, toEye)), 5.0);
        colour = mix(colour, skyProxy * 0.85, sat(0.08 + fresnel * 0.92));
    #endif

    /* Fog. The far plane has to come out of the projection matrix: Voxy hands over the
       matrices but not the distance. For a standard projection, depth 1 lands on
       P[3][2] / (P[2][2] + 1). */
    float fogDist = length(view.xyz);
    float sight = max(vxProj[3][2] / (vxProj[2][2] + 1.0), 64.0);
    float skyExposure = max(float(eyeBrightnessSmooth.y) * 0.004166666666666667,
                            skyLight);
    float fogAmount = pow(sat(fogDist / sight) * skyExposure, FOG_DENSITY * 2.0);
    colour = mix(colour, fogColour(day, dusk), sat(fogAmount));

    /* Blindness and the Warden's darkness reach out here too. */
    float darkness = max(blindness, darknessFactor * darknessLightFactor);
    if (darkness > 0.01) {
        colour = mix(colour, vec3(0.0), sat(darkness * fogDist * 0.0016));
    }

    colour = clamp(colour, vec3(0.0), vec3(50.0));

    #if defined VOXY_WATER
        float alpha = sat(albedo.a * 0.85 + 0.15);
        voxyColour = vec4(colour, alpha);
    #else
        voxyColour = vec4(colour, albedo.a);
        /* The scene copy the water reads: far land has to be in it, or a reflection
           that lands on the horizon finds nothing. */
        voxySceneCopy = vec4(colour, 1.0);
    #endif
}
