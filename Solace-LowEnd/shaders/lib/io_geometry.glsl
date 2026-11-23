/* Solace - lib/io_geometry.glsl

What the geometry vertex stage hands to its fragment stage, plus the block ids the
pack reads. Both stages include this file, so the names, the types and the ids
cannot drift apart.

fogFactor is computed per vertex and only mixed per pixel, which turns what would be
one exp() per pixel into one per vertex.

blockId is mc_Entity.x. The ids are the ones this pack writes into
block.properties, not raw block numbers, so nothing outside those lists can be
mistaken for a plant, a metal or a portal.
*/

#ifndef SOLACE_IO_GEOMETRY
#define SOLACE_IO_GEOMETRY

#include "/lib/blockids.glsl"

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 tint;
varying vec3 normalView;
varying vec3 viewSpacePos;
varying vec3 worldSpacePos;
varying float blockId;
varying float fogFactor;

#endif
