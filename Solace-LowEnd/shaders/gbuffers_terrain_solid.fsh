/* Solace - gbuffers_terrain_solid.fsh

The same lighting as every other block, with the alpha test compiled out.

Iris draws solid terrain through this program and cutout terrain through the next one.
That is not cosmetic: a discard is what makes a driver turn early-Z off, and terrain
behind other terrain is the bulk of the overdraw in a Minecraft world. With no discard
in this shader those hidden fragments never reach it. OptiFine has no such split and
uses gbuffers_terrain, where lib/fragment_geometry.glsl keeps the test by default.
*/

#version 120

#define SOLACE_ALPHA_TEST 0

#include "/lib/fragment_geometry.glsl"
