const vec2 aoOffsets[4] = vec2[4](
	vec2( 1.0,  0.0),
	vec2( 0.0,  1.0),
	vec2(-1.0,  0.0),
	vec2( 0.0, -1.0)
);

float getLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

float getAmbientOcclusion(float linearDepth0){
	float ao = 0.0;
	float totalWeight = 0.0;
	
	for (int i = 0; i < 4; i++){
		vec2 pixelOffset = aoOffsets[i] / vec2(viewWidth, viewHeight);
		float sampleDepth = getLinearDepth(texture2D(depthtex0, texCoord + pixelOffset).r);
		float weight = max(1.0 - 2.0 * far * abs(linearDepth0 - sampleDepth), 0.0001);

		ao += texture2D(colortex4, texCoord + pixelOffset).r * weight;
		totalWeight += weight;
	}

	ao /= totalWeight;
	
	if (totalWeight < 0.0001) ao = texture2D(colortex4, texCoord).r;

	return pow(ao, AO_STRENGTH);
}