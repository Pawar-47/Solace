/* Solace - gbuffers_entities_glowing.vsh
The glowing outline. The one difference from the shared vertex library is that it is
drawn just in front of the entity, as the reference does, so it cannot z-fight with
the model it outlines. */

#version 120

#define SOLACE_ENTITY_GLOW 1

#include "/lib/vertex_geometry.glsl"
