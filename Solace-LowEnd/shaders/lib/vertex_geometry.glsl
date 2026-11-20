/* Solace - lib/vertex_geometry.glsl

The vertex stage of every program that draws a textured object: terrain, block
entities, entities, the hand, particles, weather, clouds.

Carried over from the reference because a fragment stage cannot do it as well:

  * the fog amount is computed here, once per vertex. Clouds measure it on the
    horizontal plane, as the reference does, because a cloud deck is a flat layer;
  * plant waving grows from mc_midTexCoord upwards, is scaled by skylight squared
    (a plant in the dark does not wave) and gains a little in rain;
  * the temporal-antialiasing offset is multiplied by w, so it stays a constant
    fraction of a pixel at any depth.

Two programs are this same code with one difference, so the difference is a define
the program sets before including the file:
  SOLACE_ENTITY_GLOW  draws the glowing outline just in front of the entity
  SOLACE_CLOUDS       measures fog distance on the horizontal plane
*/

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"

attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    blockId = mc_Entity.x;
    lmcoord = sat((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
    vec3 worldPos = playerPos + cameraPosition;

    #if WAVING == 1
        float fromMiddle = clamp((mc_midTexCoord.y - texcoord.y) * 6.0, 0.0, 1.0);

        float amount = 0.0;
        if (blockId == SOLACE_WAVE_PLANT) {
            amount = fromMiddle;
        } else if (blockId == SOLACE_WAVE_LEAVES) {
            amount = 0.30;
        }

        /* Sky exposure squared: no wind in a cave, and rain bends plants further. */
        amount *= lmcoord.y * lmcoord.y;

        if (amount > 0.001) {
            float t = frameTimeCounter;
            float swayX = sin(t * 1.60 + worldPos.x * 0.55 + worldPos.z * 0.35);
            float swayZ = cos(t * 1.25 + worldPos.z * 0.50 + worldPos.x * 0.30);
            float strength = (0.030 + rainStrength * 0.050) * WAVE_STRENGTH;
            vec3 offset = vec3(swayX, 0.0, swayZ) * (strength * amount);
            viewPos.xyz += mat3(gbufferModelView) * offset;
        }
    #endif

    gl_Position = gl_ProjectionMatrix * viewPos;

    #if AA_TYPE == 1 || AA_TYPE == 2
        float phase = float(frameCounter - 4 * (frameCounter / 4));
        vec2 subPixel = vec2(
            phase == 0.0 || phase == 3.0 ? -0.25 : 0.25,
            phase < 2.0 ? -0.25 : 0.25);
        gl_Position.xy += subPixel * vec2(2.0 / viewWidth, 2.0 / viewHeight) * gl_Position.w;
    #endif

    #if defined SOLACE_ENTITY_GLOW
        gl_Position.z *= 0.01;
    #endif

    /* Fog amount, once per vertex, shaped the way the reference shapes it: a power
       curve on the distance normalised by far, scaled by how much sky this vertex
       can see (so a cave has almost none) and heavier while it rains. */
    #if defined SOLACE_CLOUDS
        float fogDist = length(viewPos.xz);
    #else
        float fogDist = length(viewPos.xyz);
    #endif

    float skyExposure = max(float(eyeBrightnessSmooth.y) * 0.004166666666666667,
                            sat(max(lmcoord.y - 0.065, 0.0) * 1.06951871657754));

    /* The reference gives the Nether and the End a fixed fog density of 1.0 and lets
       the overworld's setting do what it likes; in an enclosed dimension heavy fog
       just fills the screen. */
    #if SOLACE_DIM_NETHER == 1 || SOLACE_DIM_END == 1
        float fogDensity = 1.0;
    #else
        float fogDensity = FOG_DENSITY;
    #endif

    /* The Nether has no horizon to look at: the reference caps its sight at half the
       render distance, up to 96 blocks (NETHER_FOG_DISTANCE), so the fog closes in
       instead of ending at the build limit. */
    #if SOLACE_DIM_NETHER == 1
        float sight = min(far * 0.5, 96.0);
    #else
        float sight = far;
    #endif

    float fogExponent = mix(fogDensity * 2.0, 1.0, rainStrength);
    float fogAmount = pow(sat(fogDist / max(sight, 32.0)) * skyExposure, fogExponent);

    #if UNDERWATER_FOG == 1
        if (isEyeInWater == 1) {
            fogAmount = 1.0 - exp(-fogDist * 0.085);
        }
    #endif
    fogFactor = sat(fogAmount);

    tint = gl_Color;

    normalView = normalize(mat3(gl_ModelViewMatrix) * gl_Normal);
    viewSpacePos = viewPos.xyz;
    worldSpacePos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
}
