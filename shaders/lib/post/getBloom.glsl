vec3 GetBloomTile(float lod, vec2 coord, vec2 offset) {
	float scale = exp2(lod);

	float resScale = 1.25 * min(360.0, viewHeight) / viewHeight;
	vec2 centerOffset = vec2(0.125 * pixelWidth, 0.125 * pixelHeight);
	vec3 bloom = getDiskBlur4(colortex1, ((coord / scale + offset) * resScale + centerOffset), 1.0).rgb;

	return bloom;
}

void getBloom(inout vec3 color, vec2 coord) {
	vec3 blur1 = GetBloomTile(1.0, coord, vec2(0.0   , 0.0 ));
	vec3 blur2 = GetBloomTile(2.0, coord, vec2(0.51  , 0.0 ));
	vec3 blur3 = GetBloomTile(3.0, coord, vec2(0.51  , 0.26));
	vec3 blur4 = GetBloomTile(4.0, coord, vec2(0.645 , 0.26));
	vec3 blur5 = GetBloomTile(5.0, coord, vec2(0.7175, 0.26));

	#if BLOOM_RADIUS == 1
	vec3 blur = blur1;
	#elif BLOOM_RADIUS == 2
	vec3 blur = (blur1 + blur2) * 0.5;
	#elif BLOOM_RADIUS == 3
	vec3 blur = (blur1 + blur2 + blur3) * 0.33;
	#elif BLOOM_RADIUS == 4
	vec3 blur = (blur1 + blur2 + blur3 + blur4) * 0.25;
	#elif BLOOM_RADIUS == 5
	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5) * 0.2;
	#endif

	#if BLOOM_CONTRAST == 0
	color = mix(color, blur, 0.2 * BLOOM_STRENGTH);
	#else
	vec3 bloomContrast = vec3(exp2(BLOOM_CONTRAST * 0.25));
	vec3 bloomStrength = pow(vec3(0.2 * BLOOM_STRENGTH), bloomContrast);

	color = pow(color, bloomContrast);
	blur = pow(blur, bloomContrast);
	color = mix(color, blur, bloomStrength);
	color = pow(color, 1.0 / bloomContrast);
	#endif
}