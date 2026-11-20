/* Solace - lib/sky_model.glsl

The pack's colour model, in one place so the sky, the fog on every surface and the
water reflection cannot disagree: sun height from worldTime, a palette, a dome
gradient, light colours and the fog colour.

The palette is picked in two steps: themePalette() reads COLOR_SCHEME (eight
presets plus the custom slot), and palette() lets a dimension override it. The
dimension folders set SOLACE_DIM_NETHER or SOLACE_DIM_END before including a
program, which is how the Nether and the End get their own sky without a separate
copy of any shader body.
*/

#ifndef SOLACE_SKY_MODEL
#define SOLACE_SKY_MODEL

#include "/lib/math.glsl"
#include "/lib/config.glsl"
#include "/lib/uniforms.glsl"

/* worldTime: 0 sunrise, 6000 noon, 12000 sunset, 18000 midnight. */
float sunHeight() {
    return sin(float(worldTime) * (TAU_SOLACE / 24000.0));
}

/* The Nether and the End have no day, so their light does not swing with sunrise. */
float dayFactor() {
    #if SOLACE_DIM_NETHER == 1 || SOLACE_DIM_END == 1
        return 1.0;
    #else
        return sat(sunHeight() * 1.7 + 0.30);
    #endif
}

float duskFactor() {
    #if SOLACE_DIM_NETHER == 1 || SOLACE_DIM_END == 1
        return 0.0;
    #else
        return sat(1.0 - abs(sunHeight()) * 3.2);
    #endif
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

/* The dimension has the last word over the theme. */
void palette(out vec3 zenith, out vec3 horizon) {
    #if SOLACE_DIM_NETHER == 1
        zenith = vec3(0.230, 0.055, 0.030);
        horizon = vec3(0.520, 0.160, 0.065);
    #elif SOLACE_DIM_END == 1
        zenith = vec3(0.070, 0.035, 0.130);
        horizon = vec3(0.230, 0.150, 0.330);
    #else
        themePalette(zenith, horizon);
    #endif
}

vec3 sunColour() {
    float h = sat(sunHeight());
    vec3 low = vec3(1.00, 0.55, 0.26);
    vec3 high = vec3(1.00, 0.94, 0.84);
    return mix(low, high, smoothstep(0.0, 0.55, h)) * (0.30 + 0.80 * h);
}

vec3 moonColour() {
    return vec3(0.40, 0.50, 0.78) * 0.30;
}

vec3 zenithColour() {
    vec3 dayZenith;
    vec3 dayHorizon;
    palette(dayZenith, dayHorizon);

    vec3 night = vec3(0.006, 0.010, 0.026);
    vec3 dusk = dayZenith * 0.55 + vec3(0.030, 0.010, 0.040);
    vec3 c = mix(night, dayZenith, dayFactor());
    return mix(c, dusk, duskFactor() * 0.65);
}

vec3 horizonColour() {
    vec3 dayZenith;
    vec3 dayHorizon;
    palette(dayZenith, dayHorizon);

    vec3 night = vec3(0.020, 0.028, 0.055);
    vec3 dusk = mix(dayHorizon, vec3(0.980, 0.560, 0.330), 0.65);
    vec3 c = mix(night, dayHorizon, dayFactor());
    return mix(c, dusk, duskFactor() * 0.85);
}

/* Ambient skylight: the colour that reaches a surface facing up. */
vec3 ambientColour() {
    vec3 dayZenith;
    vec3 dayHorizon;
    palette(dayZenith, dayHorizon);

    vec3 night = vec3(0.020, 0.026, 0.050) * (0.6 + NIGHT_AMBIENT * 8.0);
    vec3 day = mix(dayZenith, dayHorizon, 0.55) * 1.35 + vec3(0.10);
    return mix(night, day, dayFactor());
}

vec3 blockLightColour() {
    return vec3(1.00, 0.70, 0.40);
}

vec3 fogColour() {
    vec3 c = mix(horizonColour(), zenithColour(), 0.35);
    return c * (1.0 - rainStrength * 0.30);
}

/* directionWorld is normalised and in world space. */
vec3 skyColour(vec3 directionWorld) {
    vec3 d = normalize(directionWorld);
    float band = pow(1.0 - sat(d.y), 4.0);
    vec3 col = mix(zenithColour(), horizonColour(), band);

    #if SKY_SUN_GLOW == 1
        vec3 sunDir = mat3(gbufferModelViewInverse) * normalize(sunPosition);
        vec3 moonDir = mat3(gbufferModelViewInverse) * normalize(moonPosition);
        float sun = sat(dot(d, sunDir));
        float moon = sat(dot(d, moonDir));
        col += sunColour() * pow(sun, 110.0) * 0.80;
        col += sunColour() * pow(sun, 9.0) * 0.075;
        col += moonColour() * pow(moon, 70.0) * 0.60;
    #endif

    if (d.y < 0.0) {
        col = mix(col, fogColour() * 0.75, sat(-d.y * 2.5));
    }

    #if SKY_STARS == 1
        float night = sat(1.0 - dayFactor() * 1.4);
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
