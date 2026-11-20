/* Solace - gbuffers_terrain_cutout.fsh

The same lighting, with the alpha test on: leaves, panes, plants and the rest of the
cutout layer need their discard, and they are drawn here so that solid terrain can go
through gbuffers_terrain_solid with early-Z intact.
*/

#version 120

#define SOLACE_ALPHA_TEST 1

#include "/lib/fragment_geometry.glsl"
