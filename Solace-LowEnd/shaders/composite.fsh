/* Solace - composite.fsh
Light shafts and the exposure average, from the shared library. */

#version 120

/* The options have to be known before the DRAWBUFFERS test below, because an
   identifier the preprocessor has not met yet reads as 0. Testing AUTO_EXPOSURE
   first always took the else branch, so the exposure attachment was never declared
   and the value the pass computed was written to a target that did not exist. */
#include "/lib/config.glsl"

/* DRAWBUFFERS for this pass: the scene copy, plus the exposure attachment when that
   option is on. Written here, in the program file, rather than in the library it
   includes: the directive belongs to the program, and a pass that reads colortex0 must
   not be handed colortex0 as one of eight attachments it does not write. */
#if AUTO_EXPOSURE == 1
    /* DRAWBUFFERS:16 */
#else
    /* DRAWBUFFERS:1 */
#endif

#include "/lib/composite_body.glsl"
