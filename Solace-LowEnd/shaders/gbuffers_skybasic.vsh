/* Solace - gbuffers_skybasic.vsh
The sky dome. The texture coordinates are all the fragment stage needs, and the
sub-pixel jitter belongs here too: if the sky does not move with the temporal
antialiasing, every edge against it smears. */

#version 120

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

varying vec2 texcoord;
/* The ray, worked out once per vertex. It is affine in screen space, so interpolation
   reproduces it exactly, and the sky covers a third of the screen. */
varying vec3 skyRay;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if AA_TYPE == 1 || AA_TYPE == 2
        float phase = float(frameCounter - 4 * (frameCounter / 4));
        vec2 subPixel = vec2(
            phase == 0.0 || phase == 3.0 ? -0.25 : 0.25,
            phase < 2.0 ? -0.25 : 0.25);
        gl_Position.xy += subPixel * vec2(2.0 / viewWidth, 2.0 / viewHeight) * gl_Position.w;
    #endif

    /* After the jitter, so the ray moves with it: the sky has to follow the same
       sub-pixel offset as the geometry or every edge against it smears. */
    vec4 ray = gbufferProjectionInverse
             * vec4(gl_Position.xy / gl_Position.w, 1.0, 1.0);
    skyRay = ray.xyz / ray.w;
}
