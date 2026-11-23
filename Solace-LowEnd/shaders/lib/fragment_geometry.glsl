/* Solace - lib/fragment_geometry.glsl

Lighting for solid, textured geometry:

  1. the vanilla lightmap is de-biased, so the sky channel really runs 0 to 1 and a
     cave can reach zero: max(y - 0.065) * 1.0695;
  2. block light grows faster than linearly - x^1.5 + (1.17x)^6 - the candle curve
     that makes a torch pool read correctly;
  3. the direct term is the face angle to the sun by day and to the moon by night,
     and with no shadow map it is crushed by sky exposure to the tenth power, so
     sunlight cannot leak into caves or under a tree;
  4. leaves take a softened direct term, because a leaf block is not an opaque wall;
  5. ambient light has a floor, so a cave is dark but not black;
  6. then the damage tint, emissive blocks, the end portal, night vision, blindness,
     the lava and powder-snow views, and fog - which is only *mixed* here, because
     the amount came from the vertex stage.
*/

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"
#include "/lib/sky_model.glsl"
#include "/lib/shadowmap.glsl"

uniform sampler2D gtexture;

void main() {
    #if defined SOLACE_DH_GEOMETRY && defined DISTANT_HORIZONS
        /* Distant Horizons draws untextured level-of-detail geometry, and it overlaps
           the near world by design. Two consequences: this fragment's colour arrives
           as the vertex tint, not as a texture, and anything inside the near range is
           already drawn by the near geometry at full detail. Dropping it here saves
           the whole fragment and removes the overlap. */
        if (length(viewSpacePos) < dhNearPlane + (far - dhNearPlane) * 0.90) discard;

        vec4 albedo = vec4(tint.rgb, 1.0);

        /* One hash per block keeps a distant hillside from being a single flat
           colour. It is the only texture a far block can have. */
        vec3 cell = floor(worldSpacePos * 6.0 + 0.01);
        albedo.rgb *= 0.95 + solHash(cell.xz + cell.y * 31.7) * 0.10;
    #else
        vec4 albedo = texture2D(gtexture, texcoord) * tint;
        if (albedo.a < 0.10) discard;
    #endif

    #if defined SOLACE_WEATHER
        albedo.a *= 0.5;
    #endif

    #if ENTITY_TINT == 1
        albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    #endif

    /* One sin() for the whole pixel: the day and dusk mixers and the sun colour are
       pure functions of the sun's height, so they are all taken from it here rather
       than recomputed inside each colour function. */
    float sunUp = sunHeight();
    float day = dayFrom(sunUp);
    float dusk = duskFrom(sunUp);
    vec3 astroColour = mix(moonColour() * 2.5, sunColourAt(sat(sunUp)), day);

    /* 1. De-biased lightmap. */
    float skyLight = sat(max(lmcoord.y - 0.065, 0.0) * 1.06951871657754);
    float rawBlock = lmcoord.x;

    #if UNDERWATER_FOG == 1
        if (isEyeInWater == 1) {
            skyLight = skyLight * 0.95 + 0.05;
        }
    #endif

    /* 2. Candle curve. */
    float blockCurve = rawBlock * sqrt(rawBlock) + solPow6(rawBlock * 1.17);
    vec3 candle = blockLightColour() * blockCurve * BLOCK_LIGHT;

    /* 3. Direct term: the sun by day, the moon by night. The normal is normalised
       once and reused by the gloss highlight below. */
    vec3 astroDir = normalize(mix(moonPosition, sunPosition, day));
    vec3 viewNormal = normalize(normalView);
    float facing = dot(viewNormal, astroDir);

    /* 4. Leaves are not walls. */
    if (blockId == SOLACE_WAVE_LEAVES) {
        facing = (sat(facing) * 0.5 + 0.5) * 0.75;
    } else {
        facing = sat(facing);
    }

    /* Colour of whatever the sunlight had to pass through to reach this pixel. */
    vec3 directTint = vec3(1.0);

    #if SHADOWS == 1
        vec3 playerPosition = (gbufferModelViewInverse * vec4(viewSpacePos, 1.0)).xyz;
        facing *= shadowFactor(playerPosition, facing);
        #if COLORED_SHADOW == 1
            directTint = shadowTintAt(playerPosition);
        #endif
    #else
        /* No shadow map: sky exposure to the tenth power is the stand-in, and it is
           built from squares rather than pow(). */
        float sky2 = skyLight * skyLight;
        float sky4 = sky2 * sky2;
        float sky8 = sky4 * sky4;
        facing *= (sky8 * sky2);
    #endif

    /* 5. Ambient: palette colour with a floor, so caves keep some light. The floor is
       the setting a player actually wants here - some machines and monitors turn a
       cave at 0.045 into a black screen. */
    float ambientFloor = AVOID_DARK_LEVEL;
    vec3 ambient = ambientColour(day, dusk) * (ambientFloor + (1.0 - ambientFloor) * (skyLight * skyLight));

    vec3 light = ambient + candle;

    #if SUN_SHADING == 1
        light += astroColour * directTint * facing * 0.85 * (1.0 - rainStrength * 0.75);
    #endif

    #if EYE_LIGHT == 1
        light += vec3(0.35, 0.45, 0.65) * nightVision * 0.45;
    #endif

    #if HAND_LIGHT == 1
        /* A light in the hand throws light on what is around you. `heldBlockLightValue`
           only reports a light-emitting *block* in hand, so a torch held as an item
           contributed nothing until item.properties existed; the two ids below are
           the ones that file defines. */
        float heldLight = heldBlockLightValue / 15.0;
        if (heldItemId == 11001) {
            heldLight = max(heldLight, 1.0);
        } else if (heldItemId == 11002) {
            heldLight = max(heldLight, 0.45);
        }

        if (heldLight > 0.03) {
            float nearness = sat(1.0 - length(viewSpacePos) / 6.0);
            light += blockLightColour() * nearness * heldLight * 0.80;
        }
    #endif

    vec3 colour = albedo.rgb * light;

    /* Distant Horizons names its far blocks with an int attribute, `dhMaterialId`, so
       that glowstone and lava out there can stay bright at night. It cannot be read in
       this pack: GLSL 1.20 has no integer attributes, and the whole pipeline is 1.20.
       Far glowstone is therefore shaded like any other far block. See
       lib/vertex_geometry.glsl for what it would take to bring it back. */

    #if MATERIAL_GLOSS == 1
        float gloss = 0.0;
        if (blockId == SOLACE_GLOSS_METAL) {
            gloss = 0.85;
        } else if (blockId == SOLACE_GLOSS_POLISHED) {
            gloss = 0.45;
        } else if (blockId == SOLACE_GLOSS_FABRIC) {
            gloss = 0.16;
        } else if (blockId == SOLACE_GLOSS_SAND) {
            /* Sand and gravel: a sheen, not a highlight. The fourth gloss class,
               and the last one this pack was missing. */
            gloss = 0.08;
        }

        if (gloss > 0.0) {
            vec3 halfway = normalize(astroDir + normalize(-viewSpacePos));
            float highlight = pow(sat(dot(viewNormal, halfway)), 44.0);
            /* Rain kills the highlight: wet metal should not specular like dry. */
            colour += astroColour * highlight * gloss * GLOSS_STRENGTH * facing * skyLight
                    * (1.0 - rainStrength);
        }
    #endif

    #if EMISSIVE_GLOW == 1
        if (blockId == SOLACE_EMISSIVE) {
            colour = max(colour, albedo.rgb * (0.90 + 0.35 * sat(rawBlock)));
        }
    #endif

    /* A lightning bolt and the fire an entity wears while burning are light, not lit
       surfaces. Both ids come from entity.properties, and entity.properties is read
       through `entityId`: `mc_Entity` is a terrain attribute, so testing blockId here
       could never match in an entity program. In a terrain program entityId is 0,
       which is not one of these two ids. */
    if (entityId == 10101 || entityId == 10201) {
        colour = max(colour, albedo.rgb);
    }

    if (blockId == SOLACE_PORTAL) {
        /* The End portal as a stack of layers, each a finer grid than the one behind
           it, with the layers that are left nearly transparent drawn first. A flat
           swirl of noise was the first attempt here, and it had neither the colour
           nor the depth of a portal.
           Six layers, not ten, with the fade stopping the loop early: past the
           fourth layer the remaining contribution is under one 8-bit step. */
        float t = frameTimeCounter;

        vec3 violet = vec3(0.500, 0.235, 0.500);
        vec3 blue = vec3(0.176, 0.286, 0.726);
        vec3 teal = vec3(0.161, 0.396, 0.494);

        float cycle = t * 0.67;
        vec3 layerColour = mix(violet, blue, sin(cycle) * 0.5 + 0.5);
        layerColour = mix(layerColour, teal, cos(cycle * 0.7) * 0.5 + 0.5);

        vec2 flow = vec2(0.618034) * (t * 0.20);
        vec2 base = worldSpacePos.xz + worldSpacePos.y * 1.96 + flow;

        vec3 portal = vec3(0.0);
        for (int i = 0; i < 6; i++) {
            float layer = float(i) / 6.0;
            float inverse = 1.0 - layer;

            vec2 grid = base * (5.0 * (1.0 + layer * 20.0));
            grid -= cameraPosition.xz * (layer * 50.0);
            grid += flow * (inverse * 10.0);

            float n = solHash(floor(grid));
            float n5 = n * n;
            n5 = n5 * n5 * n;
            float intensity = smoothstep(0.75, 1.0, n5);

            float fade = inverse * inverse;
            fade *= fade;

            portal += layerColour * intensity * fade * 3.0;
            if (fade < 0.01) break;
        }

        colour = portal;
    }

    #if EYE_LIGHT == 1
        colour = mix(colour, colour * vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B),
                     nightVision * 0.60);
    #endif

    /* Blindness and the Warden's darkness, applied to the final colour. A uniform a
       running version lacks reads 0. */
    float darkness = max(blindness, darknessFactor * darknessLightFactor);
    if (darkness > 0.01) {
        colour = mix(colour, vec3(0.0), sat(darkness * length(viewSpacePos) * 0.24));
    }

    /* Fog: the amount came from the vertex stage, only the colour is per pixel. */
    vec3 fogTint = fogColour(day, dusk);
    #if UNDERWATER_FOG == 1
        if (isEyeInWater == 1) {
            fogTint = underwaterFogColour(day);
        }
    #endif
    if (isEyeInWater == 2) {
        fogTint = vec3(0.55, 0.12, 0.02);      // lava
    } else if (isEyeInWater == 3) {
        fogTint = vec3(0.80, 0.86, 0.92);      // powder snow
    }

    colour = mix(colour, fogTint, isEyeInWater > 0 ? sat(fogFactor * 1.6) : fogFactor);

    #if BLACK_ENTITY_FIX == 1
        /* A workaround, not an effect. Some old drivers hand entity programs a black
           albedo, and a black albedo times any light is still black. Lifting the
           result off zero makes the mob visible again, at the price of lifting every
           other surface off zero too - which is why it ships off and is described as
           a compatibility switch rather than a setting. */
        colour = max(colour, albedo.rgb * 0.10 + vec3(0.005));
    #endif

    /* Every geometry write is clamped to 50, which is what keeps a stray highlight
       out of the bloom and the AA history. */
    gl_FragData[0] = vec4(clamp(colour, vec3(0.0), vec3(50.0)), albedo.a);
}


/* The DRAWBUFFERS directive for this pass is in each gbuffers_* and dh_terrain program
   file, not here: it belongs to the program. */
