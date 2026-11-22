/* Solace - lib/sky_model.glsl

The pack's colour model, in one place so the sky, the fog on every surface and the
water reflection cannot disagree.

The day and dusk factors are **parameters**, not functions called from inside every
colour function: `sunHeight()` costs a sin(), and paying it inside each colour
function means eight of them on one sky pixel. Each program computes them once and
passes them down instead, so the pixel pays one sin() in total.

The palette is picked in two steps: themePalette() reads COLOR_SCHEME (eight presets
plus the custom slot), and palette() lets a dimension override it. The dimension
folders set SOLACE_DIM_NETHER or SOLACE_DIM_END before including a program.
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
    #if SOLACE_DIM_NETHER == 1 || SOLACE_DIM_END == 1
        return 1.0;
    #else
        return sat(height * 1.7 + 0.30);
    #endif
}

float duskFrom(float height) {
    #if SOLACE_DIM_NETHER == 1 || SOLACE_DIM_END == 1
        return 0.0;
    #else
        return sat(1.0 - abs(height) * 3.2);
    #endif
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
    #if SOLACE_DIM_NETHER == 1
        vec3 neutral = vec3(0.0480, 0.0434, 0.0425);
        zenith = mix(neutral, fogColor, 0.35);
        horizon = mix(neutral, fogColor, 0.85);
    #elif SOLACE_DIM_END == 1
        zenith = vec3(0.0465, 0.0375, 0.0465);
        horizon = vec3(0.0465, 0.0375, 0.0465);
    #else
        themePalette(zenith, horizon);
    #endif
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

/* How much skylight a theme gives. Every theme has its own level, from a dim 0.25 for
   Shoka to a bright 0.65 for Testigo; without it the eight presets differ only in
   hue and all sit at the same brightness. */
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
    #if SOLACE_DIM_NETHER == 1
        return vec3(1.00, 0.46, 0.20);
    #else
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

/* Ambient skylight: the colour that reaches a surface facing up. */
vec3 ambientColour(float day, float dusk) {
    vec3 dayZenith;
    vec3 dayHorizon;
    palette(dayZenith, dayHorizon);

    vec3 night = vec3(0.020, 0.026, 0.050) * (0.6 + NIGHT_AMBIENT * 8.0);
    /* The 2.1 keeps the pack's overall brightness where it was and lets the theme
       only spread it: the eight levels run 0.25 to 0.65, centred near 0.47. */
    vec3 dayColour = (mix(dayZenith, dayHorizon, 0.55) * 1.35 + vec3(0.10))
                   * (themeAmbient() * 2.1);
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

    #if SKY_SUN_GLOW == 1
        vec3 sunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
        vec3 moonDir = mat3(gbufferModelViewInverse) * normalize(moonPosition);
        float sun = sat(dot(d, sunDir));
        float moon = sat(dot(d, moonDir));

        /* Two exponents, not one: a tight core that reads as the disc and a broad
           wash of scattered light around it. The shape option moves both, so the sun
           can be a hard point, a soft glow or a wide haze. Three pow() calls are the
           most expensive thing on a sky pixel, and most sky pixels are nowhere near
           the sun or the moon, so they are skipped when the dot product cannot
           produce a visible halo. */
        #if SUN_HALO_SHAPE == 0
            float coreExp = 190.0;
            float washExp = 16.0;
        #elif SUN_HALO_SHAPE == 1
            float coreExp = 110.0;
            float washExp = 9.0;
        #else
            float coreExp = 70.0;
            float washExp = 4.5;
        #endif

        /* A bigger sun needs a tighter exponent, or raising the size would only make
           the sky brighter instead of the disc larger. */
        coreExp /= SUN_SIZE;
        washExp /= SUN_SIZE;

        if (sun > 0.02) {
            col += sunCol * pow(sun, coreExp) * 0.80;
            col += sunCol * pow(sun, washExp) * 0.075 * SUN_SIZE;
        }
        if (moon > 0.02) {
            col += moonColour() * pow(moon, coreExp * 0.64) * 0.60;
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
