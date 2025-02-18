/*
const uint k = 1103515245U;

vec2 getHashNoise(uvec3 x){
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    
    return x.xy * (1.0 / float(0xffffffffU));
}

bool raytrace(vec3 viewPos, vec3 rayDir, float dither, inout vec3 hitPos) {
    const int rayCount = 10;
    const float rayLength = 1.0 / rayCount;

    vec3 screenPos = ToScreen(viewPos);
    vec3 screenDir = normalize(ToScreen(viewPos + rayDir) - screenPos) * rayLength;

    hitPos = screenPos + screenDir * dither;

    for (int i = 0; i < rayCount; i++, hitPos += screenDir) {
        if (clamp(hitPos.xy, 0.0, 1.0) != hitPos.xy) return false;

        float z1Hit = texture2D(depthtex1, hitPos.xy).r;

        if (abs(0.01 - (hitPos.z - z1Hit)) < 0.01 && z1Hit > 0.56) return true;
    }

    return false;
}

vec3 generateCosineVector(vec3 normal, vec2 noise) {
    noise.x *= TAU;
    noise.y = noise.y * 2.0 - 1.0;

    vec3 randomDir = vec3(vec2(sin(noise.x), cos(noise.x)) * sqrt(1.0 - noise.y * noise.y), noise.y);

    return normalize(normal + randomDir);
}

vec3 computeSSPT(vec3 screenPos, vec3 normal) {
    vec3 illumination = vec3(0.0);
    vec3 weight = vec3(1.0);

	float speed = 0.6180339887498967 * (frameCounter & 127);

    float dither = getBlueNoise(gl_FragCoord.xy);
          dither = fract(dither + speed);

    vec2 noise = getHashNoise(uvec3(gl_FragCoord.xy, speed));

    vec3 hitNormal = normalize(DecodeNormal(texture2D(colortex2, screenPos.xy).xy));
    vec3 hitPos = ToView(screenPos) + hitNormal * 0.001;
    vec3 rayDir = generateCosineVector(hitNormal, noise);

    bool hit = raytrace(hitPos, rayDir, dither, hitPos);

    if (hit) {
        vec3 hitAlbedo = texture2D(colortex0, hitPos.xy).rgb;
        float isEmissive = texture2D(colortex2, hitPos.xy).b * 1000.0;

        weight *= hitAlbedo;
        illumination += weight * isEmissive;
    }

    return illumination;
}
*/