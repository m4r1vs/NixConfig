const float warpAmount = 2;
const float bloomStrength = 0.4;
const float bloomRadius = 3.0;
const float scanlineThickness = 1.4; // Lower = thicker scanlines (0.3-1.0 recommended)
const float scanlineSpeed = 0.01; // Speed of scanline movement
const float scanlineBrightness = 0.9; // Brightness of dark scanlines (0.0-1.0, lower = darker)
const float scanlineOffset = 0.00022;

vec2 barrelDistortion(vec2 uv, float strength) {
    vec2 centered_uv = uv - 0.5;
    float aspect = iResolution.x / iResolution.y;
    centered_uv.x *= aspect;
    float dist_sq = dot(centered_uv, centered_uv);

    // Spherical Bulge (Magnify Center)
    // R = strength (warpAmount)
    // x = distance from center
    float R = strength;
    float z = sqrt(R*R - dist_sq);

    // Calculate 'z_edge' to normalize the scaling at the top/bottom edges (dist = 0.5)
    float r_edge = 0.5;
    float z_edge = sqrt(R*R - r_edge*r_edge);

    // Scale factor:
    // At edge (z = z_edge): scale = 1.0 (Normal)
    // At center (z = R): scale = z_edge / R (< 1.0, Magnified)
    // Formula: z = sqrt(R^2 - x^2) is used implicitly in the scaling.
    float scale = z_edge / z;

    vec2 distorted_uv = centered_uv * scale;
    distorted_uv.x /= aspect;
    return distorted_uv + 0.5;
}

vec4 safeTexture(sampler2D tex, vec2 uv) {
    return texture(tex, clamp(uv, 0.0, 1.0));
}

// Simple bloom using a 9-tap gaussian blur
vec4 bloom(sampler2D tex, vec2 uv, float radius) {
    vec2 pixelSize = radius / iResolution.xy;

    vec4 sum = vec4(0.0);

    // Gaussian weights for 9-tap blur
    float weights[9];
    weights[0] = 0.05; weights[1] = 0.09; weights[2] = 0.05;
    weights[3] = 0.09; weights[4] = 0.20; weights[5] = 0.09;
    weights[6] = 0.05; weights[7] = 0.09; weights[8] = 0.05;

    int idx = 0;
    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y)) * pixelSize;
            sum += safeTexture(tex, uv + offset) * weights[idx];
            idx++;
        }
    }

    return sum;
}

// Extract bright areas for bloom
vec4 brightPass(vec4 color, float threshold) {
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float soft = smoothstep(threshold - 0.1, threshold + 0.1, brightness);
    return color * soft;
}

// Random noise function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    float time = iTime;

    // Glitch effects
    float glitchStrength = 0.08;

    // Random glitch trigger (happens occasionally)
    float glitchTime = floor(time * 1.8);
    float glitchRandom = hash(vec2(glitchTime, 0.0));

    if(glitchRandom > 0.92) {
        glitchStrength = hash(vec2(glitchTime + 1, 0.0));
    }

    // Horizontal displacement glitch
    float glitchLine = hash(vec2(floor(uv.y * 100.0), glitchTime));
    if(glitchLine > 0.98 && glitchStrength > 0.0) {
        uv.x += (hash(vec2(uv.y, time)) - 0.5) * 0.03 * glitchStrength;
    }

    // RGB shift glitch
    float rgbShift = glitchStrength * 0.002;

    // Glitch direction (50% chance vertical)
    vec2 rgbShiftVec = vec2(rgbShift, 0.0);
    if (hash(vec2(glitchTime + 2.0, 0.0)) > 0.5) {
        rgbShiftVec = vec2(0.0, rgbShift);
    }

    // Apply barrel distortion
    vec2 warped_uv = barrelDistortion(uv, warpAmount);

    // Calculate scanline pattern once for consistency
    float scanlineY = (warped_uv.y - time * scanlineSpeed) * iResolution.y * scanlineThickness;
    float scanlinePattern = sin(scanlineY);

    // Scanline displacement (shifts content slightly right on dark lines) - AFTER warp
    warped_uv.x += scanlinePattern * scanlineOffset;

    // Get base image with RGB shift during glitches
    vec4 color;
    color.r = safeTexture(iChannel0, warped_uv + rgbShiftVec).r;
    color.g = safeTexture(iChannel0, warped_uv).g;
    color.b = safeTexture(iChannel0, warped_uv - rgbShiftVec).b;

    // Set opacity
    color.a = 0.80;

    // Extract bright areas
    vec4 bright = brightPass(color, 0.6);

    // Apply bloom blur
    vec4 bloomColor = bloom(iChannel0, warped_uv, bloomRadius);
    bloomColor = brightPass(bloomColor, 0.5);

    // Combine base color with bloom
    vec4 final = color + bloomColor * bloomStrength;

    // Slight glow enhancement for CRT effect
    final.rgb = pow(final.rgb, vec3(0.95));

    // Retro filter
    // Reduce saturation slightly
    float gray = dot(final.rgb, vec3(0.299, 0.587, 0.114));
    final.rgb = mix(final.rgb, vec3(gray), 0.15);

    // Crush blacks slightly for that vintage look
    final.rgb = pow(final.rgb, vec3(1.1));
    final.rgb = max(final.rgb - 0.02, 0.0);

    // Add slight warm tint (amber/yellow CRT look)
    final.r *= 1.04;
    final.g *= 1.05;
    final.b *= 0.96;

    // Add green tint to dark areas (phosphor glow effect)
    float darkness = 1.0 - length(final.rgb) / sqrt(3.0);
    final.g += darkness * 0.03;

    // Add subtle vignette
    vec2 vignetteUV = uv * (1.0 - uv);
    float vignette = vignetteUV.x * vignetteUV.y * 1.5;
    vignette = pow(vignette, 0.15);
    vignette = mix(1.0, vignette, 0.35);
    final.rgb *= vignette;

    // CRT scanlines (using the same scanlinePattern for consistency)
    float scanline = scanlinePattern * 0.5 + 0.5;
    scanline = mix(scanlineBrightness, 1.0, scanline);
    final.rgb *= scanline;

    // Add scanline jitter during glitches (less intense)
    if(glitchStrength > 0.0) {
        float jitter = hash(vec2(floor(uv.y * 200.0), time)) * 0.03 * glitchStrength;
        final.rgb += vec3(jitter);
    }

    fragColor = final;
}
