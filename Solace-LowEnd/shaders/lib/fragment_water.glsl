/* Solace - lib/fragment_water.glsl

The water surface: waves from two moving noise layers tilting the geometry normal,
the surface lit with the same de-biased lightmap and candle curve the solid geometry
uses, the sky reflected by a fresnel curve, a sun or moon highlight, fog - and two
optional extras that both read the copy of the scene the deferred pass leaves in
gaux1:

  REFRACTION  the scene behind the surface is bent by the normal and darkened by the
              depth the light travels through water - the thickness of water behind
              the pixel, not the distance to the eye, which is what makes a shallow
              pool still show its floor.
  WATER_SSR   the reflected ray is marched through that same copy, so water reflects
              the world and not only the sky; the sky remains the fallback when the
              march finds nothing.

WATER_TEXTURE and VANILLA_WATER choose where the base colour comes from.

Glass is shaded as glass and not as flat water: no ripples, no absorption, a squarer
border fade on its reflection, its base colour already blended towards the reflection
by the fresnel curve, and an alpha that closes to opaque at grazing angles.
*/

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"
#include "/lib/sky_model.glsl"
#include "/lib/depth_dh.glsl"
#include "/lib/pack_textures.glsl"

/* DRAWBUFFERS:0 */

uniform sampler2D gcolor;
uniform sampler2D depthtex0;

#if REFRACTION == 1 || WATER_SSR == 1
uniform sampler2D gaux1;
#endif

/* View-space distance of a depth-buffer value, derived from the projection matrix so
   the near plane is never needed. */
float waterLinearDepth(float depth) {
    return gbufferProjection[3][2] / (gbufferProjection[2][2] + 2.0 * depth - 1.0);
}

void main() {
    #if defined SOLACE_DH_WATER && defined DISTANT_HORIZONS
        /* Where the near world has already drawn something, the far water behind it
           must not appear - the far pass does not depth-test against the near one.
           And inside the near range the water is drawn there, in full detail. */
        if (texture2D(depthtex0, gl_FragCoord.xy
                      / vec2(viewWidth, viewHeight)).r < 0.9999) discard;
        if (length(viewSpacePos) < dhNearPlane + (far - dhNearPlane) * 0.90) discard;

        /* Untextured level-of-detail water: the colour arrives as the vertex tint, so a
           hash-based ripple stands in for the resource pack's texture and keeps the
           surface from being a flat sheet. */
        float synth = solHash(floor(worldSpacePos.xz * 8.0
                                    + vec2(frameTimeCounter * 0.05)));
        vec4 albedo = vec4(tint.rgb * (0.85 + 0.30 * synth), 0.86);
    #else
        vec4 albedo = texture2D(gcolor, texcoord) * tint;
        if (albedo.a < 0.05) discard;
    #endif

    vec3 normal = normalize(normalView);

    /* Water and glass are shaded separately: only water ripples. */
    bool glass = (blockId == SOLACE_GLASS);

    #if WATER_WAVES == 1
    if (!glass) {
        #if PACK_TEXTURES == 1
            /* Two texture fetches from textures/noise.png instead of the six noise
               evaluations below, which is the whole reason the file exists. */
            float t = frameTimeCounter * WAVE_SPEED;
            vec2 base = worldSpacePos.xz * (0.05 * WAVE_SCALE);
            vec2 waveA = texture2D(noise, base + vec2(t * 0.040, t * 0.030)).rg - 0.5;
            vec2 waveB = texture2D(noise, base * 2.0 - vec2(t * 0.050, t * 0.020)).rg - 0.5;
            vec2 slope = (waveA + waveB * 0.66) * (1.0 - rainStrength * 0.35);

            vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;
            worldNormal = normalize(worldNormal + vec3(slope.x, 0.0, slope.y) * 1.10);
            normal = normalize(mat3(gbufferModelView) * worldNormal);
        #else
            #if defined SOLACE_DH_WATER
                /* Far water fills a lot of screen at a distance where nobody can read
                   a second layer of chop: one layer, two thirds of the cost. */
                vec2 p1 = worldSpacePos.xz * (0.42 * WAVE_SCALE)
                        + vec2(frameTimeCounter * WAVE_SPEED * 0.85,
                               frameTimeCounter * WAVE_SPEED * 0.55);

                /* One evaluation, not three: the slope comes from the derivative of the
                   patch the height came from, so no finite difference is needed. The
                   0.08 is the step the difference used, which keeps the amplitude. */
                vec2 slope = solNoiseSlope(p1).yz * (4.0 * 0.08)
                           * (1.0 - rainStrength * 0.35);

                vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;
                worldNormal = normalize(worldNormal + vec3(slope.x, 0.0, slope.y) * 0.45);
                normal = normalize(mat3(gbufferModelView) * worldNormal);
            #else
            vec2 base = worldSpacePos.xz * (0.42 * WAVE_SCALE);
            float t = frameTimeCounter * WAVE_SPEED;
            vec2 p1 = base + vec2(t * 0.85, t * 0.55);
            vec2 p2 = base * 2.10 - vec2(t * 0.65, t * 0.95);

            /* Six noise evaluations became two. The slope comes from the derivative of
               the same patch the height did, so the four extra evaluations a finite
               difference needed - sixteen hashes per water pixel - are gone. The 0.08
               factor is the step the old difference used, which keeps the amplitude
               the pack shipped with. */
            vec3 layerA = solNoiseSlope(p1);
            vec3 layerB = solNoiseSlope(p2);

            vec2 slope = (layerA.yz * 4.0 + layerB.yz * 2.0) * 0.08;

            /* Rain flattens the chop: wet weather should not leave the surface
               looking windier than the dry. */
            slope *= 1.0 - rainStrength * 0.35;

            vec3 worldNormal = mat3(gbufferModelViewInverse) * normal;
            worldNormal = normalize(worldNormal + vec3(slope.x, 0.0, slope.y) * 0.45);
            normal = normalize(mat3(gbufferModelView) * worldNormal);
            #endif
        #endif
    }
    #endif

    vec3 waterBase;
    #if WATER_TEXTURE == 1
        /* The resource pack's texture decides the pattern; the theme decides how
           blue it is, through a factor that stays near 1 so the texture is not
           darkened by a theme whose water colour happens to be deep. */
        waterBase = albedo.rgb * tint.rgb * (0.80 + 1.60 * themeWater());
    #else
        waterBase = mix(themeWater(), tint.rgb, 0.45);
    #endif
    #if VANILLA_WATER == 1
        waterBase = tint.rgb;
    #endif

    vec3 toEye = normalize(-viewSpacePos);
    float viewDist = length(viewSpacePos);

    /* One sin() for the whole water pixel, for the same reason as the solid geometry:
       day, dusk, the astro direction and its colour all come from one height. */
    float sunUp = sunHeight();
    float day = dayFrom(sunUp);
    float dusk = duskFrom(sunUp);
    vec3 astroDir = normalize(mix(moonPosition, sunPosition, day));
    vec3 astroColour = mix(moonColour() * 2.5, sunColourAt(sat(sunUp)), day);

    /* The sky channel is still wanted per pixel: glass mixes by it and the glint is
       scaled by it. The palette mix and the candle curve are not, when the vertex stage
       has already done them - it hands water the same ambient-plus-block light it hands
       solid blocks, which takes a sqrt, a sixth power and the ambient palette out of
       every water pixel. */
    float skyLight = sat(max(lmcoord.y - 0.065, 0.0) * 1.06951871657754);

    #if VERTEX_LIGHTING == 1
        vec3 light = vertexLight;
    #else
        float blockCurve = lmcoord.x * sqrt(lmcoord.x) + solPow6(lmcoord.x * 1.17);
        vec3 light = ambientColour(day, dusk) * (0.045 + 0.955 * (skyLight * skyLight))
                   + blockLightColour() * blockCurve * BLOCK_LIGHT;
    #endif

    light += astroColour * sat(dot(normal, astroDir)) * 0.35;

    vec3 colour = waterBase * light;

    /* x^5 as four multiplies: the fresnel curve needs a fifth power, and pow() is two
       special functions for something a mul chain does. */
    float fresnel = solPow5(1.0 - sat(dot(normal, toEye)));
    float reflection = 0.0;

    bool skyReflectionOn = false;
    vec3 skyReflection = vec3(0.0);

    /* Computed even with reflections off: the march and the glint both need it, and
       one matrix multiply is cheaper than the branch that would guard it. */
    vec3 reflectedWorld = mat3(gbufferModelViewInverse) * reflect(-toEye, normal);

    #if WATER_REFLECTION == 1
        skyReflection = reflectionColour(reflectedWorld, day, dusk, astroColour);
        skyReflectionOn = true;
    #endif

    /* The mirror image, from the sky, and the world where WATER_SSR finds it. */
    vec3 reflectionColourOut = skyReflection * 0.85;
    float reflectionBorder = 0.0;
    /* How much of the mirror direction is still open sky: the highlight below may
       only appear where nothing in the world blocks it. */
    float reflectionSky = 1.0;

    #if defined SOLACE_DH_WATER && WATER_SSR == 1 && WATER_REFLECTION == 1
        /* Far water cannot march a ray: the depth buffer it would march holds the
           near world, not the far one, so every step would either miss or hit
           something that is not there. Project the mirror direction 768 blocks out
           instead, sample the scene copy at that point, and fold the image at the
           screen edge exactly as the march does. Where the near world covers that
           pixel the copy holds the near world, not the sky, so the sky is used. */
        vec3 mirrorPlayer = worldSpacePos - cameraPosition + reflectedWorld * 768.0;
        vec4 mirrorClip = gbufferProjection * (gbufferModelView * vec4(mirrorPlayer, 1.0));

        if (mirrorClip.w > 0.0001) {
            vec2 uv = mirrorClip.xy / mirrorClip.w * 0.5 + 0.5;

            float border = sat((1.0 - max(0.0, abs(uv.y - 0.5)) * 2.0) * 50.0);
            float edgeY = sat(uv.y);
            float edgeY5 = solPow5(edgeY);
            border = sat(border - edgeY5 * edgeY5);

            uv.x = abs(uv.x);
            if (uv.x > 1.0) uv.x = 2.0 - uv.x;

            vec2 sampledUV = clamp(uv, vec2(0.002), vec2(0.998));
            float nearDepth = texture2D(depthtex0, sampledUV).r;

            vec3 mirror = skyReflection;
            if (nearDepth >= 0.99999) {
                mirror = texture2D(gaux1, sampledUV).rgb;
            }

            reflectionColourOut = mix(skyReflection * 0.85, mirror, border);
            reflection = sat(0.08 + fresnel * 0.92) * border;
            reflectionSky = 1.0 - border;
        }
    #endif

    #if WATER_SSR == 1 && !defined SOLACE_DH_WATER
        vec3 reflectedView = mat3(gbufferModelView) * reflectedWorld;
        bool found = false;
        vec2 hitUV = vec2(0.0);
        float hitDistance = 0.0;

        /* The ray marches in exponentially growing steps and then bisects to refine
           the hit: far fewer fetches than a fixed step, for the same accuracy up
           close. Two blocks out to the last step's reach. */
        float dither = solDitherShifted(gl_FragCoord.xy,
                                        float(frameCounter % 64) * 0.015625);
        float previousT = 0.0;
        float currentT = 0.0;

        for (int i = 1; i <= SSR_STEPS; i++) {
            previousT = currentT;
            currentT = 2.0 * exp2(float(i) - 1.0 + dither * 0.4);

            vec3 probe = viewSpacePos + reflectedView * currentT;
            vec4 clip = gbufferProjection * vec4(probe, 1.0);
            if (clip.w <= 0.0001) break;

            vec2 probeUV = clip.xy / clip.w * 0.5 + 0.5;
            if (probeUV.x < 0.0 || probeUV.x > 1.0 || probeUV.y < 0.0 || probeUV.y > 1.0) break;

            float sceneDepth = texture2D(depthtex0, probeUV).r;
            if (sceneDepth >= 0.99999) continue;

            vec4 sceneView = gbufferProjectionInverse
                           * vec4(probeUV * 2.0 - 1.0, sceneDepth * 2.0 - 1.0, 1.0);
            float sceneZ = sceneView.z / sceneView.w;

            if (probe.z < sceneZ) {
                found = true;
                hitUV = probeUV;
                hitDistance = currentT;
                break;
            }
        }

        /* Three bisections between the last miss and the hit, which turns the
           exponential steps into a usable surface point. */
        if (found) {
            float lo = previousT;
            float hi = currentT;
            for (int r = 0; r < 3; r++) {
                float mid = 0.5 * (lo + hi);
                vec3 probe = viewSpacePos + reflectedView * mid;
                vec4 clip = gbufferProjection * vec4(probe, 1.0);
                if (clip.w <= 0.0001) break;

                vec2 probeUV = clip.xy / clip.w * 0.5 + 0.5;
                if (probeUV.x < 0.0 || probeUV.x > 1.0 || probeUV.y < 0.0 || probeUV.y > 1.0) break;

                float sceneDepth = texture2D(depthtex0, probeUV).r;
                if (sceneDepth >= 0.99999) { lo = mid; continue; }

                vec4 sceneView = gbufferProjectionInverse
                               * vec4(probeUV * 2.0 - 1.0, sceneDepth * 2.0 - 1.0, 1.0);
                float sceneZ = sceneView.z / sceneView.w;

                if (probe.z < sceneZ) { hi = mid; hitUV = probeUV; }
                else { lo = mid; }
            }
            hitDistance = hi;
        }

        if (found) {
            /* Off-screen reflection rays have nowhere to sample, so the image is
               folded back at the screen edge and faded out towards it rather than
               smeared along the border. Glass gets a squarer falloff than water. */
            vec2 uv = hitUV;
            if (glass) {
                float fx = abs(2.0 * uv.x - 1.0);
                float fy = abs(2.0 * uv.y - 1.0);
                fx *= fx; fx *= fx;
                fy *= fy; fy *= fy;
                reflectionBorder = sat(min(1.0 - fx, 1.0 - fy));
            } else {
                uv.x = abs(uv.x);
                if (uv.x > 1.0) uv.x = 2.0 - uv.x;
                reflectionBorder = sat((1.0 - max(0.0, abs(uv.y - 0.5)) * 2.0) * 50.0);
                float edgeY = sat(uv.y);
                float edgeY5 = solPow5(edgeY);
                reflectionBorder = sat(reflectionBorder - edgeY5 * edgeY5);
            }

            vec3 sampled = texture2D(gaux1, clamp(uv, vec2(0.002), vec2(0.998))).rgb;
            vec3 fallback = skyReflectionOn ? skyReflection : sampled;

            /* The march can land on something further away than the water itself
               only by mistake; a hit that close to the eye is dropped. */
            float trust = sat((hitDistance - 0.35) * 4.0);
            reflectionColourOut = mix(sampled, fallback, 1.0 - trust);
            reflectionColourOut = mix(fallback, reflectionColourOut, reflectionBorder);
            reflection = sat(0.08 + fresnel * 0.92) * reflectionBorder * trust;
            reflectionSky = 1.0 - reflectionBorder * trust;
        }
    #endif

    if (reflection <= 0.0 && skyReflectionOn) {
        reflection = sat(0.08 + fresnel * 0.92);
        reflectionColourOut = skyReflection * 0.85;
    }

    /* Glass blends its own colour towards the sky and then towards the mirror
       image, both by fresnel; water mixes once, by the reflection strength. */
    if (glass) {
        vec3 glassSky = mix(colour, skyReflection, skyLight * skyLight);
        colour = mix(colour, glassSky, fresnel);
        colour = mix(colour, reflectionColourOut, fresnel);
    } else {
        colour = mix(colour, reflectionColourOut, reflection);
    }

    #if WATER_GLINT == 1
        #if WATER_REFLECTION == 1
            /* The highlight lies on the reflected ray, not on the surface normal,
               and only where that ray reaches the sky: a surface under a roof gets
               none of it, which the sky lightmap also enforces.
               reflectedWorld is a rotation of a unit vector, so it is already unit
               length - normalising it again was a sqrt for nothing. */
            float alignment = sat(dot(reflectedWorld, astroDir));
            float glint = smoothstep(0.995, 1.0, alignment);
            colour += astroColour * glint * skyLight * reflectionSky
                    * (1.0 - rainStrength) * 3.0;
        #else
            float alignment = pow(sat(dot(normal, astroDir)), 300.0);
            colour += astroColour * alignment * skyLight * 2.2;
        #endif
    #endif

    float alpha = sat(WATER_OPACITY * 0.80 + fresnel * 0.55 + reflection * 0.25);
    if (glass) alpha = mix(alpha, 1.0, fresnel * 0.9);

    #if REFRACTION == 1
        /* Glass does not bend what is behind it: it is drawn as opaque geometry with
           its own alpha. */
        if (!glass && isEyeInWater == 0) {
            vec2 bent = clamp(texcoord + normal.xy
                              * (0.09 / (1.0 + viewDist * 0.25)),
                              vec2(0.002), vec2(0.998));
            vec3 behind = texture2D(gaux1, bent).rgb;

            /* How much water the light crosses behind this pixel. A rational curve
               of the squared thickness is the obvious choice, but it turns negative
               for thick water, so this uses an exponential: monotone, and it cannot
               overshoot. */
            float surfaceDistance;
            float sceneDistance;

            #if defined SOLACE_DH_WATER && defined DISTANT_HORIZONS
                /* Far water lives entirely in Distant Horizons' projection: both
                   depths are linearised with its planes, and the scene behind it is
                   only ever in its own depth buffer. */
                surfaceDistance = solDhLinearDepth(gl_FragCoord.z);
                sceneDistance = solDhLinearDepth(texture2D(dhDepthTex1, bent).r);
            #else
                surfaceDistance = waterLinearDepth(gl_FragCoord.z);
                sceneDistance = waterLinearDepth(texture2D(depthtex0, bent).r);

                /* Near water can have far land behind it: that terrain is not in
                   depthtex0 at all, so it is linearised separately and the nearer of
                   the two decides how much water the light crossed. */
                #ifdef DISTANT_HORIZONS
                    float dhDistance = solDhLinearDepth(texture2D(dhDepthTex1, bent).r);
                    sceneDistance = min(sceneDistance, dhDistance);
                #endif
            #endif

            float thickness = max(sceneDistance - surfaceDistance, 0.0);

            /* Nothing behind the surface but sky: treated as fully absorbed, which
               stops the sky showing through the water. */
            float absorbed = 1.0 - exp(-thickness * thickness
                                       * WATER_ABSORPTION * 0.5);

            colour = mix(behind, colour, absorbed);
        }
    #endif

    vec3 fogTint = fogColour(day, dusk);
    if (isEyeInWater == 1) {
        fogTint = vec3(0.050, 0.180, 0.240);
    } else if (isEyeInWater == 2) {
        fogTint = vec3(0.55, 0.12, 0.02);
    } else if (isEyeInWater == 3) {
        fogTint = vec3(0.80, 0.86, 0.92);
    }

    colour = mix(colour, fogTint, fogFactor);

    gl_FragData[0] = vec4(clamp(colour, vec3(0.0), vec3(50.0)), alpha);
}
