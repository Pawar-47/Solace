/* Solace - lib/vertex_geometry.glsl

The vertex stage of every program that draws a textured object: terrain, block
entities, entities, the hand, particles, weather, clouds. Position, texture
coordinates, lightmap coordinates, the tint Minecraft already baked into the
vertex colour, the view-space normal, both spaces of position, the block id for
waving and gloss, and the sub-pixel jitter the temporal antialiasing needs.

The jitter is multiplied by w so it stays a constant fraction of a pixel whatever
the depth.
*/

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/io_geometry.glsl"

attribute vec4 mc_Entity;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    blockId = mc_Entity.x;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
    vec3 worldPos = playerPos + cameraPosition;

    #if WAVING == 1
        float amount = 0.0;
        if (blockId == SOLACE_WAVE_PLANT) {
            amount = 1.0 - texcoord.y;
        } else if (blockId == SOLACE_WAVE_LEAVES) {
            amount = (1.0 - texcoord.y) * 0.45;
        }

        if (amount > 0.001) {
            float t = frameTimeCounter;
            float swayX = sin(t * 1.60 + worldPos.x * 0.55 + worldPos.z * 0.35);
            float swayZ = cos(t * 1.25 + worldPos.z * 0.50 + worldPos.x * 0.30);
            vec3 offset = vec3(swayX, 0.0, swayZ) * (0.055 * WAVE_STRENGTH * amount);
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

    lmcoord = sat((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy);
    tint = gl_Color;

    normalView = normalize(mat3(gl_ModelViewMatrix) * gl_Normal);
    viewSpacePos = viewPos.xyz;
    worldSpacePos = (gbufferModelViewInverse * viewPos).xyz + cameraPosition;
}
