/* Solace - dh_water.fsh

Far water: waves, the sky reflection, the sun glint and the fog, all from the same
library the near water uses. The scene copy it would refract is a near-scene buffer,
so the far water leaves refraction to the near one and simply keeps its own colour.
*/

#version 120

#include "/lib/fragment_water.glsl"
