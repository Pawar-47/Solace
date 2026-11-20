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

/* The two colours a theme is built from. */
void themePalette(out vec3 zenith, out vec3 horizon) {
    #if COLOR_SCHEME == 0
        zenith = vec3(0.100, 0.200, 0.460);   // Ethereal
        horizon = vec3(0.740, 0.820, 0.940);
    #elif COLOR_SCHEME == 1
        zenith = vec3(0.110, 0.230, 0.520);   // Shoka
        horizon = vec3(0.560, 0.680, 0.880);
    #elif COLOR_SCHEME == 2
        zenith = vec3(0.080, 0.180, 0.440);   // Classic
        horizon = vec3(0.620, 0.740, 0.920);
    #elif COLOR_SCHEME == 3
        zenith = vec3(0.060, 0.140, 0.360);   // Legacy
        horizon = vec3(0.520, 0.640, 0.840);
    #elif COLOR_SCHEME == 4
        zenith = vec3(0.050, 0.120, 0.300);   // Captain
        horizon = vec3(0.420, 0.540, 0.720);
    #elif COLOR_SCHEME == 5
        zenith = vec3(0.240, 0.100, 0.440);   // Psychedelic
        horizon = vec3(0.960, 0.460, 0.780);
    #elif COLOR_SCHEME == 6
        zenith = vec3(0.160, 0.180, 0.340);   // Cocoa
        horizon = vec3(0.920, 0.720, 0.560);
    #elif COLOR_SCHEME == 7
        zenith = vec3(0.180, 0.140, 0.400);   // Testigo
        horizon = vec3(1.000, 0.700, 0.820);
    #else
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
    return mix(low, high, smoothstep(0.0, 0.55, h)) * (0.30 + 0.80 * h);
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
    #if COLOR_SCHEME == 0
        return 0.40;   // Ethereal
    #elif COLOR_SCHEME == 1
        return 0.25;   // Shoka
    #elif COLOR_SCHEME == 2
        return 0.50;   // Classic
    #elif COLOR_SCHEME == 3
        return 0.50;   // Legacy
    #elif COLOR_SCHEME == 4
        return 0.50;   // Captain
    #elif COLOR_SCHEME == 5
        return 0.45;   // Psychedelic
    #elif COLOR_SCHEME == 6
        return 0.40;   // Cocoa
    #elif COLOR_SCHEME == 7
        return 0.65;   // Testigo
    #else
        return CUSTOM_AMBIENT;
    #endif
}

/* The colour water takes on from a theme, so a Cocoa ocean is not the same blue as
   an Ethereal one. Without it the pack had one fixed colour whatever the theme. */
vec3 themeWater() {
    #if COLOR_SCHEME == 0
        return vec3(0.050, 0.100, 0.110);
    #elif COLOR_SCHEME == 1
        return vec3(0.050, 0.100, 0.110);
    #elif COLOR_SCHEME == 2
        return vec3(0.016, 0.139, 0.165);
    #elif COLOR_SCHEME == 3
        return vec3(0.016, 0.139, 0.165);
    #elif COLOR_SCHEME == 4
        return vec3(0.050, 0.100, 0.110);
    #elif COLOR_SCHEME == 5
        return vec3(0.018, 0.120, 0.180);
    #elif COLOR_SCHEME == 6
        return vec3(0.020, 0.180, 0.322);
    #elif COLOR_SCHEME == 7
        return vec3(0.012, 0.110, 0.192);
    #else
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

        /* Three pow() calls are the most expensive thing on a sky pixel, and most
           sky pixels are nowhere near the sun or the moon: skip them when the dot
           product cannot produce a visible halo. */
        if (sun > 0.02) {
            col += sunCol * pow(sun, 110.0) * 0.80;

            /* The 9th power as four multiplies. Up to about 16, a mul chain is cheaper
               than the two special functions pow() costs; the tight 110th stays a
               pow(), because its chain would be longer than that. */
            float sun2 = sun * sun;
            float sun4 = sun2 * sun2;
            float sun8 = sun4 * sun4;
            col += sunCol * (sun8 * sun) * 0.075;
        }
        if (moon > 0.02) {
            col += moonColour() * pow(moon, 70.0) * 0.60;
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
