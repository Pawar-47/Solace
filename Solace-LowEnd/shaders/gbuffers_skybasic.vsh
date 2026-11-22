/* Solace - gbuffers_skybasic.vsh
The sky dome. The texture coordinates are all the fragment stage needs, and the
sub-pixel jitter belongs here too: if the sky does not move with the temporal
antialiasing, every edge against it smears. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if AA_TYPE == 1 || AA_TYPE == 2
        float phase = float(frameCounter - 4 * (frameCounter / 4));
        vec2 subPixel = vec2(
            phase == 0.0 || phase == 3.0 ? -0.25 : 0.25,
            phase < 2.0 ? -0.25 : 0.25);
        gl_Position.xy += subPixel * vec2(2.0 / viewWidth, 2.0 / viewHeight) * gl_Position.w;
    #endif
}
