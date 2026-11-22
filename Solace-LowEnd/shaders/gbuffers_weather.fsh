/* Solace - gbuffers_weather.fsh
Rain and snow: the solid lighting path, with the alpha halved so the streaks stay
translucent against the sky. */

#version 120

#define SOLACE_WEATHER 1

/* DRAWBUFFERS:0 */

#include "/lib/fragment_geometry.glsl"
