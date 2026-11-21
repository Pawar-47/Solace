/* Solace - lib/buffers.glsl

The buffer contract, in one place. Three things here are easy to get wrong and all
three break silently:

  * the history buffers must NOT be cleared, or the temporal antialiasing and the
    exposure average restart from nothing every frame and can never converge;
  * mipmaps must be enabled on the scene buffers the bloom reads, or the glow has no
    wide level to gather from;
  * the formats must be wide enough for a history, or the values crawl.

None of the declarations at the end of this file are GLSL. They are directives: Iris and
OptiFine read them out of the shader source and apply them to their own buffers, and the
format names - RGBA16F, R11F_G11F_B10F, R16F - belong to the mods, not to the language.
That is why they are inside a block comment. Written as code they reach the GLSL compiler,
which has never heard of those identifiers and refuses the whole program:

    composite.fsh: 0:141(29): error: 'R11F_G11F_B10F' undeclared

which is exactly the error this file caused once. Keep them commented.
*/

#ifndef SOLACE_BUFFERS
#define SOLACE_BUFFERS

/* Scene copy for refraction and reflections (gaux1, colortex4).

   It must not be cleared: gbuffers_water runs before `deferred`, the pass that fills it,
   so at the moment water is drawn this buffer holds the previous frame's copy. Clearing
   it would leave the water refracting black. The cost of not clearing is that refraction
   and reflections lag one frame behind the camera, which temporal antialiasing hides when
   it is on.

   The scene buffers (colortex0, colortex1): bloom gathers from a mip level of whichever
   one is current, which is what the mipmap flags below are for.

   Temporal antialiasing history (colortex3), and the auto-exposure value carried between
   frames (colortex6, gaux3).

   Coloured shadows: the shadow pass writes the colour of whatever it draws into
   shadowcolor0, so a stained-glass pane or a sheet of water tints the shadow under it.
   The map is not cleared for two reasons - a shadow lock has to be able to skip a frame
   without losing the previous map, and a stale colour is no worse than a stale depth that
   comes with it. Declared unconditionally: a format the pass never writes costs nothing.
*/

/*
const int colortex4Format = R11F_G11F_B10F;
const bool colortex4Clear = false;

const bool colortex0MipmapEnabled = true;
const bool colortex1MipmapEnabled = true;

const int colortex3Format = RGBA16F;
const bool colortex3Clear = false;

const int colortex6Format = R16F;
const bool colortex6Clear = false;

const int shadowcolor0Format = RGBA16;
const bool shadowtex0Clear = false;
const bool shadowcolor0Clear = false;
*/

#endif
