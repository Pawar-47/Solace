/* Solace - gbuffers_clouds.vsh
Vanilla cloud geometry. SOLACE_CLOUDS makes the shared vertex library measure fog
on the horizontal plane, because a cloud deck is a flat layer. */

#version 120

#define SOLACE_CLOUDS 1

#include "/lib/vertex_geometry.glsl"
