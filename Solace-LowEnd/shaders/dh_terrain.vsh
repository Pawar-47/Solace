/* Solace - dh_terrain.vsh

Distant Horizons draws the terrain past the vanilla render distance. Iris hands it
the same vertex stage as ordinary terrain, minus the per-block attributes, so the
shared library runs with SOLACE_DH_GEOMETRY set and skips exactly what it cannot
have: the block id and the waving that reads it.
*/

#version 120

#define SOLACE_DH_GEOMETRY 1

#include "/lib/vertex_geometry.glsl"
