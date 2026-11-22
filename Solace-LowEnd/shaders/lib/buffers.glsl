/* Solace - lib/buffers.glsl

The buffer contract, in one place: which buffers may not be cleared, and how wide the
ones carrying a history have to be.

Two forms, and both matter:

  * the FORMATS are not GLSL at all - RGBA16F, R11F_G11F_B10F, R16F are names the mods
    understand and the compiler has never heard of. They go inside a block comment.
    Written as code they reach the GLSL compiler and the whole program is refused:
    `composite.fsh: error: 'R11F_G11F_B10F' undeclared`.
  * the CLEAR flags are ordinary bool constants, so they are written as code and the
    mods read them from there. This is the arrangement the reference pack uses too, and
    it is the one that is known to work.

What is deliberately NOT here: mipmap flags. Nothing in this pack samples a mip level -
the bloom gathers at full resolution and scales its radius with BLOOM_LOD instead - so
asking the mod to build a mip chain for the scene buffer every frame was work that
nothing consumed. The reference declares no mipmap flags either.
*/

#ifndef SOLACE_BUFFERS
#define SOLACE_BUFFERS

/* Formats. Directives, not code. */

/*
const int colortex4Format = R11F_G11F_B10F;
const int colortex3Format = R11F_G11F_B10F;
const int colortex6Format = R16F;
*/

/* Clears.

   colortex0 and colortex1 are the scene, rewritten edge to edge every frame, so their
   old contents can never show through.

   colortex3 is the temporal-antialiasing history: clearing it would restart the history
   from nothing every frame and it could never converge. It is also the one buffer this
   pack reads and writes inside one draw, so `flip.composite2.colortex3` is set in
   shaders.properties; without the flip the pass samples the texture it is writing.

   colortex4 is the copy of the scene that water refraction and reflections read. It does
   not have to be cleared: deferred fills it edge to edge and runs before gbuffers_water
   reads it. It is left un-cleared anyway, so that a frame with the pass absent reads as
   the previous frame rather than as black.

   colortex6 is the auto-exposure value carried between frames. It is the other buffer
   read and written in one draw (`flip.composite.colortex6`), for the same reason as
   colortex3. */

const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex3Clear = false;
const bool colortex4Clear = false;
const bool colortex6Clear = false;

#endif
