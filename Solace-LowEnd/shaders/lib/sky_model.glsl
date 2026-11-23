/* Solace - lib/sky_model.glsl

The pack's colour model, in one place so the sky, the fog on every surface and the
water reflection cannot disagree.

The day and dusk factors are **parameters**, not functions called from inside every
colour function: `sunHeight()` costs a sin(), and paying it inside each colour
function means eight of them on one sky pixel. Each program computes them once and
passes them down instead, so the pixel pays one sin() in total.

The palette is picked in two steps: themePalette() reads COLOR_SCHEME (eight presets
plus the custom slot), and palette() lets the dimension override it. The dimension is
read at run time from biome_category (see lib/uniforms.glsl), so a program is the same
file in every dimension and there are no per-dimension copies to drift apart.
*/

#ifndef SOLACE_SKY_MODEL
#define SOLACE_SKY_MODEL

#include "/lib/math.glsl"
#include "/lib/config.glsl"
#include "/lib/uniforms.glsl"

/* worldTime: 0 sunrise, 6000 noon, 12000 sunset, 18000 midnight.
   One sin() is the whole cost of the sun's height, so it is computed once per pixel
   and everything else takes the result: the day and dusk mixers and the sun colour
   are pure functions of it. */
float sunHeight() {
    return sin(float(worldTime) * (TAU_SOLACE / 24000.0));
}

float dayFrom(float height) {
    if (solaceNoSky()) return 1.0;
    return sat(height * 1.7 + 0.30);
}

float duskFrom(float height) {
    if (solaceNoSky()) return 0.0;
    return sat(1.0 - abs(height) * 3.2);
}

/* For the places that need the mixers and nothing else. A program that also wants
   the sun colour should compute sunHeight() itself and use the *From forms. */
float dayFactor() {
    return dayFrom(sunHeight());
}

float duskFactor() {
    return duskFrom(sunHeight());
}

/* The two colours a palette is built from.

   The presets are named for what they look like, not for anything else: a player
   should be able to pick one without knowing what the others are. They differ in hue
   and in how far apart the overhead and horizon colours sit, which is what decides
   whether a sky looks flat or deep. */
void themePalette(out vec3 zenith, out vec3 horizon) {
    #if COLOR_SCHEME == 0        // Natural: what a clear sky does, no stylising.
        zenith = vec3(0.110, 0.230, 0.520);
        horizon = vec3(0.560, 0.680, 0.880);
    #elif COLOR_SCHEME == 1      // Vivid: same hue, pushed until it is unmistakable.
        zenith = vec3(0.060, 0.230, 0.780);
        horizon = vec3(0.470, 0.750, 1.000);
    #elif COLOR_SCHEME == 2      // Game: the bright blue a block game should have.
        zenith = vec3(0.100, 0.180, 0.670);
        horizon = vec3(0.560, 0.750, 0.980);
    #elif COLOR_SCHEME == 3      // Soft: low contrast, pale, easy to look at for hours.
        zenith = vec3(0.290, 0.380, 0.610);
        horizon = vec3(0.770, 0.810, 0.900);
    #elif COLOR_SCHEME == 4      // Cinematic: deep blue above, amber on the horizon.
        zenith = vec3(0.060, 0.150, 0.310);
        horizon = vec3(0.880, 0.640, 0.440);
    #elif COLOR_SCHEME == 5      // Neon: violet and magenta, for screenshots.
        zenith = vec3(0.250, 0.060, 0.520);
        horizon = vec3(0.980, 0.420, 0.770);
    #elif COLOR_SCHEME == 6      // Warm: golden light, as at the end of an afternoon.
        zenith = vec3(0.180, 0.200, 0.390);
        horizon = vec3(0.960, 0.780, 0.570);
    #elif COLOR_SCHEME == 7      // Bright: high key, almost white on the horizon.
        zenith = vec3(0.200, 0.300, 0.570);
        horizon = vec3(0.880, 0.900, 0.950);
    #else                        // Custom: the six channels of the palette screen.
        zenith = vec3(CUSTOM_ZENITH_R, CUSTOM_ZENITH_G, CUSTOM_ZENITH_B);
        horizon = vec3(CUSTOM_HORIZON_R, CUSTOM_HORIZON_G, CUSTOM_HORIZON_B);
    #endif
}

/* The dimension has the last word over the theme.

   Both other dimensions are nearly neutral: the End sky is (0.0465, 0.0375, 0.0465)
   and the Nether's is (0.0480, 0.0434, 0.0425) - almost grey, with the colour coming
   from the light and the fog rather than from the palette. A bright orange Nether and
   a violet End, as earlier versions of this pack had, make the fog in both far too
   strong. The Nether takes most of its colour from vanilla's fog now. */
void palette(out vec3 zenith, out vec3 horizon) {
    if (solaceIsNether()) {
        vec3 neutral = vec3(0.0480, 0.0434, 0.0425);
        zenith = mix(neutral, fogColor, 0.35);
        horizon = mix(neutral, fogColor, 0.85);
    } else if (solaceIsEnd()) {
        zenith = vec3(0.0465, 0.0375, 0.0465);
        horizon = vec3(0.0465, 0.0375, 0.0465);
    } else {
        themePalette(zenith, horizon);
    }
}

/* h is sat(sunHeight()). Kept separate so a program that already has the height does
   not pay for the sin() a second time. */
vec3 sunColourAt(float h) {
    vec3 low = vec3(1.00, 0.55, 0.26);
    vec3 high = vec3(1.00, 0.94, 0.84);
    vec3 base = mix(low, high, smoothstep(0.0, 0.55, h)) * (0.30 + 0.80 * h);

    /* Channel gains, in percent. Three sliders rather than one hue control: this is
       what corrects a sun that reads too green on a cheap panel without touching the
       rest of the picture, and the sky palette and the output gains stay separate. */
    return base * vec3(float(SUN_R), float(SUN_G), float(SUN_B)) * 0.01;
}

vec3 sunColour() {
    return sunColourAt(sat(sunHeight()));
}

vec3 moonColour() {
    return vec3(0.40, 0.50, 0.78) * 0.30;
}

/* The sun and the moon are drawn here, not by the game.

   shaders.properties switches the game's own discs off (`sun = false`, `moon =
   false`) because they are textured quads: whatever happens to the alpha - a resource
   pack with an opaque sun texture, a driver that samples the wrong one, a blend state
   the mod did not expect - leaves a rectangle in the sky. That is exactly what the
   first build showed: a box where the sun should be, and no setting that could shrink
   it, because the size was the game's quad and not this pack's. A disc built from a
   dot product cannot become a rectangle, and SUN_SIZE scales the disc and its glow
   together.

   The angles are angular radii, so the disc stays the same size on screen whatever
   the field of view. 1.10 degrees at SUN_SIZE 1 is a little larger than the real sun,
   which is what reads as a sun at this resolution. */
vec3 sunDiscColour(vec3 d, vec3 sunDir, vec3 sunCol) {
    float cosAngle = dot(d, sunDir);
    float radius = cos(radians(1.10 * SUN_SIZE));
    float disc = smoothstep(radius - 0.0009, radius + 0.0009, cosAngle);
    return sunCol * disc * 2.40;
}

vec3 moonDiscColour(vec3 d, vec3 moonDir) {
    float cosAngle = dot(d, moonDir);
    float radius = cos(radians(1.05 * SUN_SIZE));
    float disc = smoothstep(radius - 0.0009, radius + 0.0009, cosAngle);
    return moonColour() * disc * 4.20;
}

/* The colour of the water you are inside.

   One definition, used by the fog on solid geometry, by the water surface and by the
   sky seen from below it. Those three were three separate constants a few thousandths
   apart, which is why the surface of a lake and the water under it disagreed. */
vec3 underwaterFogColour(float day) {
    return vec3(0.050, 0.185, 0.245) * (0.35 + 0.65 * day);
}

/* How much skylight a theme gives. Every theme has its own level, from a dim 0.32 for
   Cinematic to a bright 0.62 for Bright; without it the eight presets differ only in
   hue and all sit at the same brightness. (This comment used to quote two numbers that
   were not the ones below, and named two other packs while doing it.) */
float themeAmbient() {
    #if COLOR_SCHEME == 0        // Natural
        return 0.45;
    #elif COLOR_SCHEME == 1      // Vivid
        return 0.52;
    #elif COLOR_SCHEME == 2      // Game
        return 0.50;
    #elif COLOR_SCHEME == 3      // Soft
        return 0.40;
    #elif COLOR_SCHEME == 4      // Cinematic
        return 0.32;
    #elif COLOR_SCHEME == 5      // Neon
        return 0.42;
    #elif COLOR_SCHEME == 6      // Warm
        return 0.46;
    #elif COLOR_SCHEME == 7      // Bright
        return 0.62;
    #else                        // Custom
        return CUSTOM_AMBIENT;
    #endif
}

/* The colour water takes on from a palette, so an ocean in Cinematic is not the same
   blue as an ocean in Natural. Without it the pack had one fixed colour whatever the
   palette. */
vec3 themeWater() {
    #if COLOR_SCHEME == 0        // Natural
        return vec3(0.040, 0.110, 0.150);
    #elif COLOR_SCHEME == 1      // Vivid
        return vec3(0.010, 0.150, 0.230);
    #elif COLOR_SCHEME == 2      // Game
        return vec3(0.020, 0.140, 0.230);
    #elif COLOR_SCHEME == 3      // Soft
        return vec3(0.070, 0.140, 0.170);
    #elif COLOR_SCHEME == 4      // Cinematic
        return vec3(0.020, 0.090, 0.130);
    #elif COLOR_SCHEME == 5      // Neon
        return vec3(0.050, 0.060, 0.200);
    #elif COLOR_SCHEME == 6      // Warm
        return vec3(0.030, 0.130, 0.170);
    #elif COLOR_SCHEME == 7      // Bright
        return vec3(0.030, 0.160, 0.220);
    #else                        // Custom
        return vec3(CUSTOM_WATER_R, CUSTOM_WATER_G, CUSTOM_WATER_B);
    #endif
}

/* Torch and lava light: warm orange, a little paler towards yellow at full
   strength, and redder in the Nether. It is called from the geometry, water and
   glowing stages, and it once was called from all three without being defined
   anywhere, which stopped the pack from compiling at all. BLOCKLIGHT_TEMP moves the
   light from orange through warm white to neutral. */
vec3 blockLightColour() {
    if (solaceIsNether()) {
        return vec3(1.00, 0.46, 0.20);
    }
    #if BLOCKLIGHT_TEMP == 0
        return vec3(1.00, 0.56, 0.28);
    #elif BLOCKLIGHT_TEMP == 1
        return vec3(1.00, 0.66, 0.40);
    #elif BLOCKLIGHT_TEMP == 2
        return vec3(1.00, 0.75, 0.52);
    #elif BLOCKLIGHT_TEMP == 3
        return vec3(1.00, 0.83, 0.68);
    #else
        return vec3(1.00, 0.92, 0.85);
    #endif
}

vec3 zenithColour(float day, float dusk) {
    vec3 dayZenith;
    vec3 dayHorizon;
    palette(dayZenith, dayHorizon);

    vec3 night = vec3(0.006, 0.010, 0.026);
    vec3 duskColour = dayZenith * 0.55 + vec3(0.030, 0.010, 0.040);
    vec3 c = mix(night, dayZenith, day);
    return mix(c, duskColour, dusk * 0.65);
}

vec3 horizonColour(float day, float dusk) {
    vec3 dayZenith;
    vec3 dayHorizon;
    palette(dayZenith, dayHorizon);

    vec3 night = vec3(0.020, 0.028, 0.055);
    vec3 duskColour = mix(dayHorizon, vec3(0.980, 0.560, 0.330), 0.65);
    vec3 c = mix(night, dayHorizon, day);
    return mix(c, duskColour, dusk * 0.85);
}

/* Ambient skylight: the colour that reaches a surface facing up.

   This is *light*, not the sky, and the two must not be the same colour. Taking the
   palette straight as the ambient term - which is what the first build did - painted
   every surface in the sky's blue and made the world look lit from under water; the
   sun then contributed less than the fill, so nothing had a sunny side. The palette is
   desaturated towards its own luma first, and the level is normalised afterwards, so a
   theme's brightness is what changes and not its hue.

   The night floor is a separate colour: skylight at midnight is not a dark blue day. */
vec3 ambientColour(float day, float dusk) {
    vec3 dayZenith;
    vec3 dayHorizon;
    palette(dayZenith, dayHorizon);

    vec3 base = mix(dayZenith, dayHorizon, 0.60);
    vec3 tint = mix(vec3(luma(base)), base, 0.30);

    /* themeAmbient runs 0.32 for Cinematic to 0.62 for Bright. 1.22 puts the brightest
       theme at the level a lit surface has in vanilla and the darkest near two thirds
       of it, which leaves room for the sun to be the brightest thing in the picture. */
    float level = themeAmbient() * 1.22;
    vec3 dayColour = tint * (level / max(luma(tint), 0.02));

    vec3 night = vec3(0.020, 0.026, 0.050) * (0.60 + NIGHT_AMBIENT * 7.0);
    return mix(night, dayColour, day);
}

vec3 fogColour(float day, float dusk) {
    vec3 c = mix(horizonColour(day, dusk), zenithColour(day, dusk), 0.35);
    return c * (1.0 - rainStrength * 0.30);
}

/* A cheap reflection: the dome gradient plus one soft glow at the light source, with
   no stars and no tight halo. A reflected pixel must not pay for the whole sky, so
   everything only the sky itself needs is left out.

   day, dusk and the astro colour come in as arguments: a water pixel has already
   worked them out, and recomputing them here would cost it three more sin(). */
vec3 reflectionColour(vec3 directionWorld, float day, float dusk, vec3 astroColour) {
    vec3 d = normalize(directionWorld);
    float band = solPow4(1.0 - sat(d.y));
    vec3 col = mix(zenithColour(day, dusk), horizonColour(day, dusk), band);

    vec3 astroDir = mat3(gbufferModelViewInverse) * normalize(mix(moonPosition, sunPosition, day));
    float astro = sat(dot(d, astroDir));
    col += astroColour * astro * astro * astro * 0.12;

    col *= 1.0 - rainStrength * 0.40;
    return col;
}

/* directionWorld is normalised and in world space. day, dusk and the sun colour are
   arguments for the same reason as above. */
vec3 skyColour(vec3 directionWorld, float day, float dusk, vec3 sunCol) {
    vec3 d = normalize(directionWorld);
    float band = solPow4(1.0 - sat(d.y));
    vec3 col = mix(zenithColour(day, dusk), horizonColour(day, dusk), band);

    vec3 sunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
    vec3 moonDir = mat3(gbufferModelViewInverse) * normalize(moonPosition);

    /* The discs do not depend on the glow setting: turning the halo off should leave
       a hard clean sun, not remove the sun. */
    col += sunDiscColour(d, sunDir, sunCol);
    col += moonDiscColour(d, moonDir);

    #if SKY_SUN_GLOW == 1
        float sun = sat(dot(d, sunDir));
        float moon = sat(dot(d, moonDir));

        /* One exponent, because the disc is the core now and the halo is only the light
           scattered around it. The three shapes are the spread of that scatter, and
           dividing by SUN_SIZE widens the glow with the disc instead of brightening it:
           the old pair of exponents (110 and 16) was so tight that neither was visible
           a degree away from the sun, which is why the setting did nothing. */
        #if SUN_HALO_SHAPE == 0
            float haloExp = 46.0;
            float sunHalo = 0.20;
        #elif SUN_HALO_SHAPE == 1
            float haloExp = 13.0;
            float sunHalo = 0.28;
        #else
            float haloExp = 4.0;
            float sunHalo = 0.38;
        #endif
        haloExp /= SUN_SIZE;

        if (sun > 0.01) {
            col += sunCol * pow(sun, haloExp) * sunHalo;
        }
        if (moon > 0.01) {
            col += moonColour() * pow(moon, haloExp * 0.55) * 1.10;
        }
    #endif

    if (d.y < 0.0) {
        col = mix(col, fogColour(day, dusk) * 0.75, sat(-d.y * 2.5));
    }

    #if SKY_STARS == 1
        float night = sat(1.0 - day * 1.4);
        if (night > 0.01 && d.y > 0.0) {
            vec3 cell = floor(d * 260.0);
            float h = solHash(cell.xy + cell.z * 31.7);
            float star = smoothstep(0.9970, 0.99985, h);
            float twinkle = 0.75 + 0.25 * sin(frameTimeCounter * 2.3 + h * 90.0);
            col += vec3(0.80, 0.86, 1.00) * star * night * twinkle * sat(d.y * 4.0);
        }
    #endif

    col *= 1.0 - rainStrength * 0.40;
    return col;
}

#endif
