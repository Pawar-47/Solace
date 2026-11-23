/* Solace - dh_water.fsh

Far water: waves, a reflection, the sun glint and the fog, from the same library the
near water uses, with one difference the library has to know about - this fragment's
depth is in Distant Horizons' projection, so its own depth buffer is the only one that
means anything here.
*/

#version 120

#define SOLACE_DH_GEOMETRY 1
#define SOLACE_DH_WATER 1

/* DRAWBUFFERS:0 */

#include "/lib/fragment_water.glsl"
