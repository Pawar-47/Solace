/* Solace - lib/io_geometry.glsl

What the geometry vertex stage hands to its fragment stage. Both sides include
this file, so the names and types cannot drift apart, and so can the block id
constants - blockId is the value of mc_Entity.x, which this pack's block.properties
fills in for waving and for the gloss classes.
*/

#ifndef SOLACE_IO_GEOMETRY
#define SOLACE_IO_GEOMETRY

#define SOLACE_WAVE_PLANT 1.0
#define SOLACE_WAVE_LEAVES 2.0
#define SOLACE_GLOSS_METAL 3.0
#define SOLACE_GLOSS_POLISHED 4.0
#define SOLACE_GLOSS_FABRIC 5.0

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 tint;
varying vec3 normalView;
varying vec3 viewSpacePos;
varying vec3 worldSpacePos;
varying float blockId;

#endif
