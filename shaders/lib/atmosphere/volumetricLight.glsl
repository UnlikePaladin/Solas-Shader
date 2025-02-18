void computeVolumetricLight(inout vec3 vl, in vec3 translucent, in float dither) {
	//Depths
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;

	//Positions
	vec4 screenPos = vec4(texCoord, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec3 nViewPos = normalize(viewPos.xyz);

	float VoU = max(dot(nViewPos, upVec), 0.0);
	float nVoU = pow2(1.0 - VoU);

	vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
	float VoL = clamp(dot(nViewPos, lightVec), 0.0, 1.0);
	float sun = clamp(VoL * 0.5 + 0.5, 0.0, 1.0);
		  sun = (0.01 / (1.0 - 0.99 * sun) - 0.01) * 2.0;
		  sun = sqrt(sun);
	float nVoL = mix(0.5 + sun * 2.5, sun * (2.0 - eBS), timeBrightness);

	float visibility = float(z0 > 0.56) * mix(nVoU * nVoL, 2.0 + nVoL * 2.0, float(sign(isEyeInWater))) * 0.02 * VL_OPACITY;

	#if MC_VERSION >= 11900
	visibility *= 1.0 - darknessFactor;
	#endif

	visibility *= 1.0 - blindFactor;

	if (visibility > 0.0) {
		vec3 shadowCol = vec3(0.0);

		float lViewPos = length(viewPos);
		float linearDepth0 = getLinearDepth(z0);
		float linearDepth1 = getLinearDepth(z1);

		float distanceFactor = mix(8.0, 3.0, float(sign(isEyeInWater)));

		//Ray marching and main calculations
		for (int i = 0; i < VL_SAMPLES; i++) {
			float currentDepth = pow(i + dither + 0.25, 1.5) * distanceFactor;

			if (linearDepth1 < currentDepth || (linearDepth0 < currentDepth && translucent.rgb == vec3(0.0))) {
				break;
			}

			vec3 worldPos = calculateWorldPos(getLogarithmicDepth(currentDepth), texCoord);

			float lWorldPos = length(worldPos);

			if (nVoU == 0.0 || lWorldPos > far) break;

			vec3 shadowPos = calculateShadowPos(worldPos);
			shadowPos.z += 0.0512 / shadowMapResolution;

			if (length(shadowPos.xy * 2.0 - 1.0) < 1.0) {
				float shadow0 = shadow2D(shadowtex0, shadowPos).z;

				//Colored Shadows
				#ifdef SHADOW_COLOR
				if (shadow0 < 1.0) {
					float shadow1 = shadow2D(shadowtex1, shadowPos.xyz).z;
					if (shadow1 > 0.0) {
						shadowCol = texture2D(shadowcolor0, shadowPos.xy).rgb;
						shadowCol *= shadowCol * shadow1;
					}
				}
				#endif
				vec3 shadow = clamp(shadowCol * 8.0 * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(1.0));

				//Translucency Blending
				if (linearDepth0 < currentDepth) {
					shadow *= translucent.rgb;
				}

				vl += shadow;
			}
		}

		vl *= visibility;
		vl *= lightCol;
	}
}