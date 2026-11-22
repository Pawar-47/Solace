/* Solace - world0/composite.fsh
Overworld light shafts and exposure, with the overworld palette. */

#version 120

#define SOLACE_DIM_OVERWORLD 1

/* DRAWBUFFERS: the scene copy, plus the exposure attachment when that option is on. */
#if AUTO_EXPOSURE == 1
    /* DRAWBUFFERS:16 */
#else
    /* DRAWBUFFERS:1 */
#endif

#include "/lib/composite_body.glsl"
