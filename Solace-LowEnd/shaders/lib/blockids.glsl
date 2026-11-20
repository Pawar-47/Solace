/* Solace - lib/blockids.glsl

The block ids this pack reads, in their own file so the shadow programs can see them
without pulling in the geometry varyings. They are the ids written into
block.properties, never raw block numbers.
*/

#ifndef SOLACE_BLOCKIDS
#define SOLACE_BLOCKIDS

#define SOLACE_WAVE_PLANT 1.0
#define SOLACE_WAVE_LEAVES 2.0
#define SOLACE_GLOSS_METAL 3.0
#define SOLACE_GLOSS_POLISHED 4.0
#define SOLACE_GLOSS_FABRIC 5.0
#define SOLACE_EMISSIVE 6.0
#define SOLACE_PORTAL 7.0
#define SOLACE_WATER 8.0
#define SOLACE_GLASS 9.0

#endif
