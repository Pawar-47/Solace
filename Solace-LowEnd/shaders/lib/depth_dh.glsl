/* Solace - lib/depth_dh.glsl

Depth helpers for Distant Horizons, which draws the terrain past the vanilla render
distance with its own projection and therefore its own near and far planes. A value
from `dhDepthTex1` means nothing until it has been pushed through that projection.

Everything here returns a distance in blocks, so it can be compared with the near
depth and with the distance of a water surface. */

#ifndef SOLACE_DEPTH_DH
#define SOLACE_DEPTH_DH

#include "/lib/config.glsl"
#include "/lib/math.glsl"
#include "/lib/uniforms.glsl"

#ifdef DISTANT_HORIZONS

/* Distance in blocks of a value from one of the DH depth buffers. */
float solDhLinearDepth(float depth) {
    return (2.0 * dhNearPlane * dhFarPlane)
         / (dhFarPlane + dhNearPlane
            - (2.0 * depth - 1.0) * (dhFarPlane - dhNearPlane));
}

#endif

#endif
