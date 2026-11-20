/* Solace - dh_terrain.fsh

Far terrain, shaded by the same library as near terrain: the same lightmap, the same
candle curve, the same palette, the same fog. It is the point of a deferred-style
pack that the distance should not change the colour.
*/

#version 120

#include "/lib/fragment_geometry.glsl"
