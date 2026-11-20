/* Solace - final.fsh

The last pass, and the one that knows where the picture currently lives:

  the geometry wrote colortex0. If the godray/exposure pass ran the scene moved to
  colortex1. If the antialiasing/motion-blur pass ran it moved back to colortex0.
  SCENE below is whichever is current, chosen by the same options that switched
  those passes on, so nothing is read from a buffer another pass is writing.

Then: depth of field, chromatic aberration, FXAA-only mode, unsharp mask, ambient
occlusion, bloom, exposure (fixed, or the value the exposure pass left in
colortex6), tone curve, colour-blindness aid, saturation, contrast, dither.

FXAA lives here and not in composite2 because it needs no history: a whole pass for
it would be wasted. AA_TYPE 3 is FXAA on its own; AA_TYPE 2 runs it after the
temporal pass, which has already put its result back in colortex0.
*/

#version 120

/* Needed for texture2DLod in a fragment shader, which is how the bloom gathers from
   a mip level instead of taking forty taps at full resolution. */
#extension GL_ARB_shader_texture_lod : enable

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/ssao.glsl"
#include "/lib/buffers.glsl"

#if (AA_TYPE == 1 || AA_TYPE == 2) || MOTION_BLUR == 1
    #define SCENE colortex0
#elif VOL_LIGHT == 1 || AUTO_EXPOSURE == 1
    #define SCENE colortex1
#else
    #define SCENE colortex0
#endif

uniform sampler2D SCENE;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

varying vec2 texcoord;

/* My own tone curve. Monotonic, 1.0 in gives about 0.73 out and 2.0 gives about
   0.93, so highlights roll off instead of clipping. */
vec3 toneCurve(vec3 x) {
    x = max(x, vec3(0.0));
    return (x * (2.0 + x)) / (x * (x + 1.5) + 1.6);
}

/* Colour-blindness aid, in the shape of the algorithm daltonize.org published: work
   in the long/medium/short cone responses, replace the response the eye is missing
   with what the other two can reconstruct, see how far that leaves the picture from
   the original, and push the difference into the channels that still work. What came
   before this only washed the colour towards grey, which dims the picture without
   making anything easier to tell apart.

   Mode 1 is red-weak, 2 green-weak, 3 blue-weak, the same numbering the options file
   uses. */
vec3 colourBlindAid(vec3 c) {
    float L = 17.8824 * c.r + 43.5161 * c.g + 4.11935 * c.b;
    float M = 3.45565 * c.r + 27.1554 * c.g + 3.86714 * c.b;
    float S = 0.0299566 * c.r + 0.184309 * c.g + 1.46709 * c.b;

    float l = L;
    float m = M;
    float s = S;

    #if COLOR_BLIND_MODE == 1
        l = 2.02344 * M - 2.52581 * S;
    #elif COLOR_BLIND_MODE == 2
        m = 0.494207 * L + 1.24827 * S;
    #elif COLOR_BLIND_MODE == 3
        s = -0.395913 * L + 0.801109 * M;
    #endif

    /* What that weakness would see, and the part of the picture it loses. */
    vec3 seen;
    seen.r = 0.0809444479 * l - 0.130504409 * m + 0.116721066 * s;
    seen.g = -0.0102485335 * l + 0.0540193266 * m - 0.113614708 * s;
    seen.b = -0.000365296938 * l - 0.00412161469 * m + 0.693511405 * s;

    vec3 lost = c - seen;
    vec3 aided = c;

    #if COLOR_BLIND_MODE == 1
        aided.g += lost.r * 0.70;
        aided.b += lost.r * 0.70;
    #elif COLOR_BLIND_MODE == 2
        aided.r += lost.g * 0.70;
        aided.b += lost.g * 0.70;
    #elif COLOR_BLIND_MODE == 3
        aided.r += lost.b * 0.70;
        aided.g += lost.b * 0.70;
    #endif

    return sat(aided);
}

#if AA_TYPE == 2 || AA_TYPE == 3
/* Edge antialiasing, in the shape of the published FXAA 3.11: find whether the
   edge through this pixel runs horizontally or vertically, walk both ways along
   it until the luma stops changing, blend a little towards the nearer end, and add
   a sub-pixel term for the edges that are thinner than a pixel.

   What came before this detected an edge and then blurred along an eight-tap
   direction, which is cheaper but visibly softer and leaves steep diagonals
   stepped. */
vec3 sceneFxaa(vec2 uv) {
    vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    vec3 centre = texture2D(SCENE, uv).rgb;
    float lumaCentre = luma(centre);

    float lumaDown = luma(texture2D(SCENE, uv + vec2(0.0, -texel.y)).rgb);
    float lumaUp = luma(texture2D(SCENE, uv + vec2(0.0, texel.y)).rgb);
    float lumaLeft = luma(texture2D(SCENE, uv + vec2(-texel.x, 0.0)).rgb);
    float lumaRight = luma(texture2D(SCENE, uv + vec2(texel.x, 0.0)).rgb);

    float lumaLow = min(lumaCentre, min(min(lumaDown, lumaUp), min(lumaLeft, lumaRight)));
    float lumaHigh = max(lumaCentre, max(max(lumaDown, lumaUp), max(lumaLeft, lumaRight)));
    float lumaRange = lumaHigh - lumaLow;

    /* FXAA_EDGE is the relative threshold; the fixed floor keeps noise in very
       dark areas from being treated as an edge. */
    if (lumaRange <= max(0.03125, lumaHigh * FXAA_EDGE)) return centre;

    float lumaDownLeft = luma(texture2D(SCENE, uv + vec2(-texel.x, -texel.y)).rgb);
    float lumaDownRight = luma(texture2D(SCENE, uv + vec2(texel.x, -texel.y)).rgb);
    float lumaUpLeft = luma(texture2D(SCENE, uv + vec2(-texel.x, texel.y)).rgb);
    float lumaUpRight = luma(texture2D(SCENE, uv + vec2(texel.x, texel.y)).rgb);

    float downUp = lumaDown + lumaUp;
    float leftRight = lumaLeft + lumaRight;
    float leftCorners = lumaDownLeft + lumaUpLeft;
    float rightCorners = lumaDownRight + lumaUpRight;
    float downCorners = lumaDownLeft + lumaDownRight;
    float upCorners = lumaUpLeft + lumaUpRight;

    float edgeHorizontal = abs(-2.0 * lumaLeft + leftCorners)
                         + abs(-2.0 * lumaCentre + downUp) * 2.0
                         + abs(-2.0 * lumaRight + rightCorners);
    float edgeVertical = abs(-2.0 * lumaUp + upCorners)
                       + abs(-2.0 * lumaCentre + leftRight) * 2.0
                       + abs(-2.0 * lumaDown + downCorners);

    bool horizontal = (edgeHorizontal >= edgeVertical);

    float lumaNear = horizontal ? lumaDown : lumaLeft;
    float lumaFar = horizontal ? lumaUp : lumaRight;
    float gradientNear = lumaNear - lumaCentre;
    float gradientFar = lumaFar - lumaCentre;
    bool nearSteepest = abs(gradientNear) >= abs(gradientFar);

    float gradientScale = 0.25 * max(abs(gradientNear), abs(gradientFar));
    float localAverage = 0.5 * ((nearSteepest ? lumaNear : lumaFar) + lumaCentre);

    /* Half a pixel towards the steepest side, then walk along the edge. */
    float stepLength = horizontal ? texel.y : texel.x;
    if (nearSteepest) stepLength = -stepLength;

    vec2 walk = uv;
    if (horizontal) walk.y += stepLength * 0.5;
    else walk.x += stepLength * 0.5;

    vec2 along = horizontal ? vec2(texel.x, 0.0) : vec2(0.0, texel.y);
    vec2 end1 = walk - along;
    vec2 end2 = walk + along;

    float lumaEnd1 = luma(texture2D(SCENE, end1).rgb) - localAverage;
    float lumaEnd2 = luma(texture2D(SCENE, end2).rgb) - localAverage;
    bool reached1 = abs(lumaEnd1) >= gradientScale;
    bool reached2 = abs(lumaEnd2) >= gradientScale;

    if (!reached1) end1 -= along;
    if (!reached2) end2 += along;

    /* Eight steps, each twice as long as the one before, so a long straight edge
       costs the same as a short one. */
    for (int i = 1; i < 8; i++) {
        if (reached1 && reached2) break;

        float reach = exp2(float(i));

        if (!reached1) {
            end1 -= along * reach;
            lumaEnd1 = luma(texture2D(SCENE, end1).rgb) - localAverage;
            reached1 = abs(lumaEnd1) >= gradientScale;
        }
        if (!reached2) {
            end2 += along * reach;
            lumaEnd2 = luma(texture2D(SCENE, end2).rgb) - localAverage;
            reached2 = abs(lumaEnd2) >= gradientScale;
        }
    }

    float distance1 = horizontal ? (uv.x - end1.x) : (uv.y - end1.y);
    float distance2 = horizontal ? (end2.x - uv.x) : (end2.y - uv.y);
    bool towardsFirst = distance1 < distance2;
    float distanceFinal = min(distance1, distance2);
    float edgeThickness = distance1 + distance2;

    float pixelOffset = -distanceFinal / max(edgeThickness, 1e-6) + 0.5;
    bool centreSmaller = lumaCentre < localAverage;
    bool correctVariation = ((towardsFirst ? lumaEnd1 : lumaEnd2) < 0.0) != centreSmaller;

    float finalOffset = correctVariation ? pixelOffset : 0.0;

    /* Sub-pixel term: how far the centre is from the average of its neighbours,
       relative to the range, shaped so that it peaks for edges about a pixel wide. */
    float lumaAverage = (1.0 / 12.0)
                      * (2.0 * (downUp + leftRight) + leftCorners + rightCorners);
    float subPixel = sat(abs(lumaAverage - lumaCentre) / max(lumaRange, 1e-6));
    subPixel = (-2.0 * subPixel + 3.0) * subPixel * subPixel;
    subPixel = subPixel * subPixel * 0.75;

    finalOffset = max(finalOffset, subPixel);

    vec2 finalUV = uv;
    if (horizontal) finalUV.y += finalOffset * stepLength;
    else finalUV.x += finalOffset * stepLength;

    return texture2D(SCENE, clamp(finalUV, vec2(0.0), vec2(1.0))).rgb;
}
#endif

void main() {
    vec2 uv = texcoord;
    vec2 pixel = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    vec3 colour;

    #if AA_TYPE == 2 || AA_TYPE == 3
        colour = sceneFxaa(uv);
    #else
        colour = texture2D(SCENE, uv).rgb;
    #endif

    #if CHROMA_ABER == 1
        /* One offset outwards from the centre: red shifted by all of it, green by
           half, blue by none. Shifting red and blue in opposite directions by the
           same amount, which is the obvious alternative, adds a blue fringe where
           there should be none.
           The 0.06 keeps this pack's slider range at a comparable strength.

           The taps read the scene rather than the antialiased result: the offset is
           many pixels wide, so folding FXAA into them would cost three edge traces
           for no visible gain - the base image keeps the antialiasing. */
        vec2 split = (uv - 0.5) * (0.06 * CHROMA_STRENGTH);
        colour.r = texture2D(SCENE, clamp(uv - split, vec2(0.0), vec2(1.0))).r;
        colour.g = texture2D(SCENE, clamp(uv - split * 0.5, vec2(0.0), vec2(1.0))).g;
        colour.b = texture2D(SCENE, uv).b;
    #endif

    #if DOF == 1
        float centreDepth = texture2D(depthtex0, vec2(0.5, 0.5)).r;
        /* Focus follows centerDepthSmooth, a value the engine smooths over frames;
           falling back to the raw centre pixel keeps it working without. */
        float focusDepth = centerDepthSmooth > 0.0 ? centerDepthSmooth : centreDepth;
        float hereDepth = texture2D(depthtex0, uv).r;
        float circle = sat(abs(hereDepth - focusDepth) * DOF_STRENGTH * 90.0);
        if (circle > 0.004 && hereDepth < 0.99999) {
            vec3 ring = colour;
            float seed = solDitherShifted(gl_FragCoord.xy,
                                          float(frameCounter % 64) * 0.015625);
            for (int i = 1; i <= DOF_SAMPLES; i++) {
                float turn = fract((float(i) + seed) * 1.6180339887) * 6.28318530718;
                vec2 offset = vec2(cos(turn), sin(turn)) * (circle * 0.014 * float(i) * 0.6);
                ring += texture2D(SCENE, clamp(uv + offset, vec2(0.0), vec2(1.0))).rgb;
            }
            colour = ring / float(DOF_SAMPLES + 1);
        }
    #endif

    #if IMAGE_SHARPENING == 1
        vec3 neighbours = texture2D(SCENE, uv + vec2(pixel.x, 0.0)).rgb
                        + texture2D(SCENE, uv - vec2(pixel.x, 0.0)).rgb
                        + texture2D(SCENE, uv + vec2(0.0, pixel.y)).rgb
                        + texture2D(SCENE, uv - vec2(0.0, pixel.y)).rgb;
        neighbours *= 0.25;
        colour += (colour - neighbours) * SHARPEN;
    #endif

    #if AO == 1
        /* The occlusion is measured from `depthtex0`, which holds the opaque scene
           only. On a water or glass pixel that depth belongs to whatever is *behind*
           the surface, so darkening by it would draw the shape of the river bed onto
           the water. `depthtex1` includes the translucent geometry: where the two
           differ, this pixel is in front of the opaque depth and is left alone. The
           alternative is to compute the occlusion in the deferred pass, before the
           water is drawn, which costs a pass this machine does not have. */
        float opaqueDepth = texture2D(depthtex0, uv).r;
        float surfaceDepth = texture2D(depthtex1, uv).r;
        if (opaqueDepth - surfaceDepth < 0.00005) {
            colour *= screenSpaceAO(uv);
        }
    #endif

    #if BLOOM == 1
        /* Gather from a mip level instead of a wide ring of full-resolution taps: one
           fetch at mip BLOOM_LOD already averages a block of pixels, so eight rotated
           taps give a wide, smooth glow. */
        float bloomSeed = solDitherShifted(gl_FragCoord.yx * 0.31,
                                           float(frameCounter % 64) * 0.015625);
        vec3 glow = vec3(0.0);
        for (int i = 0; i < 8; i++) {
            float turn = fract((float(i) + bloomSeed) * 1.6180339887) * 6.28318530718;
            vec2 offset = vec2(cos(turn), sin(turn))
                        * (BLOOM_RADIUS * float(i + 1) * 0.12) * pixel;
            vec3 tapped = texture2DLod(SCENE, clamp(uv + offset, vec2(0.0), vec2(1.0)),
                                       BLOOM_LOD).rgb;
            glow += max(tapped - vec3(0.62), vec3(0.0));
        }
        colour += glow * (BLOOM_STRENGTH * 0.125);
    #endif

    #if AUTO_EXPOSURE == 1
        colour *= texture2D(colortex6, vec2(0.5, 0.5)).r;
    #else
        colour *= EXPOSURE;
    #endif

    #if TONEMAP == 1
        colour = toneCurve(colour);
    #elif TONEMAP == 2
        colour = colour / (1.0 + colour);
    #else
        colour = sat(colour);
    #endif

    #if COLOR_BLINDNESS == 1
        colour = colourBlindAid(colour);
    #endif

    float grey = luma(colour);
    colour = mix(vec3(grey), colour, SATURATION);

    colour = (colour - 0.5) * CONTRAST + 0.5;
    colour = sat(colour);

    #if DITHER == 1
        /* The tile-flipped pattern, not a plain hash: at one 8-bit step of
           amplitude the shape of the noise is what decides whether the eye sees
           grain or a repeating grid. */
        colour += (solDitherBlue(gl_FragCoord.xy) - 0.5) * (1.0 / 255.0);
    #endif

    gl_FragData[0] = vec4(colour, 1.0);
}
