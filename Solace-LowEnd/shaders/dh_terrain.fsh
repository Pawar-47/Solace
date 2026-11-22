/* Solace - dh_terrain.fsh

Far terrain, shaded by the same library as near terrain: the same lightmap, the same
candle curve, the same palette, the same fog. Two things the library has to know: this
geometry is untextured, so its colour is the vertex tint, and it has to cull itself
where the near world is already drawing.
*/

#version 120

#define SOLACE_DH_GEOMETRY 1

/* DRAWBUFFERS:0 */

#include "/lib/fragment_geometry.glsl"
