/* Solace - lib/buffers.glsl

The buffer contract, in one place. Three things here are easy to get wrong and all
three break silently:

  * the history buffers must NOT be cleared, or the temporal antialiasing and the
    exposure average restart from nothing every frame and can never converge;
  * mipmaps must be enabled on the scene buffers the bloom reads, or the glow has no
    wide level to gather from;
  * the formats must be wide enough for a history, or the values crawl.

The reference declares the same set in its final program. Declaring them is what
makes them take effect, so this file is included by every program that touches
those buffers.
*/

#ifndef SOLACE_BUFFERS
#define SOLACE_BUFFERS

/* Scene copy for refraction and reflections (gaux1).
   It must not be cleared: gbuffers_water runs before `deferred`, the pass that fills
   it, so at the moment water is drawn this buffer holds the previous frame's copy.
   Clearing it would leave the water refracting black. The cost of not clearing is
   that refraction and reflections lag one frame behind the camera, which is the same
   trade the reference makes and is hidden by temporal antialiasing when it is on. */
const int colortex4Format = R11F_G11F_B10F;
const bool colortex4Clear = false;

/* The scene buffers: bloom gathers from a mip level of whichever one is current. */
const bool colortex0MipmapEnabled = true;
const bool colortex1MipmapEnabled = true;

/* Temporal antialiasing history. */
const int colortex3Format = RGBA16F;
const bool colortex3Clear = false;

/* Auto-exposure value carried between frames (gaux3). */
const int colortex6Format = R16F;
const bool colortex6Clear = false;

#endif
