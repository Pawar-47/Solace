/* Solace - world1/composite.fsh
End light shafts and exposure, with the End palette. */

#version 120

#define SOLACE_DIM_END 1

/* DRAWBUFFERS: the scene copy, plus the exposure attachment when that option is on. */
#if AUTO_EXPOSURE == 1
    /* DRAWBUFFERS:16 */
#else
    /* DRAWBUFFERS:1 */
#endif

#include "/lib/composite_body.glsl"
