const float warpAmount = 0.08;
const float bloomStrength = 0.6;
const float bloomRadius = 3.0;
const float scanlineThickness = 0.47; // Lower = thicker scanlines (0.3-1.0 recommended)
const float scanlineSpeed = 0.03; // Speed of scanline movement
const float scanlineBrightness = 0.92; // Brightness of dark scanlines (0.0-1.0, lower = darker)
const float scanlineOffset = 0.00022;
const float greenTintStrength = 0.15; // Green tint on dark areas (0.0-0.3 recommended)
const float greenTintThreshold = 0.3; // Brightness threshold for green tint (0.0-1.0)

vec2 barrelDistortion(vec2 uv, float strength) {
    vec2 centered_uv = uv - 0.5;
    float aspect = iResolution.x / iResolution.y;
    centered_uv.x *= aspect;
    float dist_sq = dot(centered_uv, centered_uv);
    vec2 distorted_uv = centered_uv * (1.0 + strength * dist_sq);
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
    float glitchStrength = 0.0;
    
    // Random glitch trigger (happens occasionally)
    float glitchTime = floor(time * 2.0);
    float glitchRandom = hash(vec2(glitchTime, 0.0));
    
    if(glitchRandom > 0.98) {
        glitchStrength = 1.0;
    }
    
    // Horizontal displacement glitch
    float glitchLine = hash(vec2(floor(uv.y * 100.0), glitchTime));
    if(glitchLine > 0.98 && glitchStrength > 0.0) {
        uv.x += (hash(vec2(uv.y, time)) - 0.5) * 0.03 * glitchStrength;
    }
    
    // RGB shift glitch
    float rgbShift = glitchStrength * 0.002;
    
    // Apply barrel distortion
    vec2 warped_uv = barrelDistortion(uv, warpAmount);
    
    // Calculate scanline pattern once for consistency
    float scanlineY = (warped_uv.y - time * scanlineSpeed) * iResolution.y * scanlineThickness;
    float scanlinePattern = sin(scanlineY);
    
    // Scanline displacement (shifts content slightly right on dark lines) - AFTER warp
    warped_uv.x += scanlinePattern * scanlineOffset;
    
    // Get base image with RGB shift during glitches
    vec4 color;
    if(rgbShift > 0.0) {
        color.r = safeTexture(iChannel0, warped_uv + vec2(rgbShift, 0.0)).r;
        color.g = safeTexture(iChannel0, warped_uv).g;
        color.b = safeTexture(iChannel0, warped_uv - vec2(rgbShift, 0.0)).b;
        color.a = 1.0;
    } else {
        color = safeTexture(iChannel0, warped_uv);
    }
    
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
    
    // Add slight warm tint (amber/yellow CRT look)
    final.r *= 1.05;
    final.g *= 1.02;
    final.b *= 0.95;
    
    // Crush blacks slightly for that vintage look
    final.rgb = pow(final.rgb, vec3(1.1));
    final.rgb = max(final.rgb - 0.02, 0.0);
    
    // Add green tint to dark areas (phosphor glow effect)
    float darkness = 1.0 - length(final.rgb) / sqrt(3.0);
    final.g += darkness * 0.05;
    
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
        float jitter = hash(vec2(floor(uv.y * 200.0), time)) * 0.05 * glitchStrength;
        final.rgb += vec3(jitter);
    }
    
    fragColor = final;
}
