#ifdef VC
int day = worldDay % 72 / 8 / 21;

float amount = mix(VC_AMOUNT * (1.0 + day), 2.0, rainStrength);

#ifndef BLOCKY_CLOUDS
float get3DNoise(vec3 pos) {
	pos *= 0.5 + clamp(float(day), 0.0, 0.5);
	pos.xz *= 0.5;

	vec3 floorPos = floor(pos);
	vec3 fractPos = fract(pos);

	vec2 noiseCoord = (floorPos.xz + fractPos.xz + floorPos.y * 16.0) * 0.015625;

	float planeA = texture2D(noisetex, noiseCoord).r;
	float planeB = texture2D(noisetex, noiseCoord + 0.25).r;

	return mix(planeA, planeB, fractPos.y);
}
#else
float get3DNoise(vec3 pos) {
	pos *= 0.5;
	pos.xz *= 0.5;

	vec3 floorPos = floor(pos);
	vec3 fractPos = fract(pos);

	vec2 noiseCoord = (floorPos.xz + fractPos.xz + floorPos.y * 16.0) * 0.015625;

	float planeA = texture2D(shadowcolor1, noiseCoord).a;
	float planeB = texture2D(shadowcolor1, noiseCoord + 0.25).a;

	return mix(planeA, planeB, fractPos.y);
}
#endif

void computeVolumetricClouds(in float dither, in float ug, inout vec4 vc) {
	//Depts
	float z0 = texture2D(depthtex0, texCoord).r;

	float visibility = ug * float(z0 > 0.56);

	#if MC_VERSION >= 11900
	visibility *= 1.0 - darknessFactor;
	#endif

	visibility *= 1.0 - blindFactor;

	if (visibility > 0.0) {
		//Positions
		vec4 screenPos = vec4(texCoord, z0, 1.0);
		vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;
		vec3 nWorldPos = normalize(mat3(gbufferModelViewInverse) * viewPos.xyz);

		float lViewPos = length(viewPos);
		float VoS = clamp(abs(dot(normalize(viewPos.xyz), sunVec)), 0.0, 1.0);
		lightCol.rgb *= 1.0 + pow4(VoS);

		//We want to march between two planes which we set here
		float lowerPlane = (VC_HEIGHT + VC_STRETCHING - cameraPosition.y) / nWorldPos.y;
		float upperPlane = (VC_HEIGHT - VC_STRETCHING - cameraPosition.y) / nWorldPos.y;
		float minDist = max(min(lowerPlane, upperPlane), 0.0);
		float maxDist = min(max(lowerPlane, upperPlane), VC_DISTANCE);
		float rayLength = maxDist - minDist;

		int sampleCount = clamp(int(rayLength), 1, VC_SAMPLES);

		//Precompute the ray position
		vec3 rayPos = cameraPosition + nWorldPos * minDist;
		vec3 rayDir = nWorldPos * (rayLength / sampleCount);
		rayPos += rayDir * dither;
		rayPos.y -= rayDir.y;

		//Ray marching and main calculations
		for (int i = 0; i < sampleCount; i++, rayPos += rayDir) {
			vec3 worldPos = rayPos - cameraPosition;
			float lWorldPos = length(worldPos);

			if (lWorldPos > VC_DISTANCE || lWorldPos > lViewPos) break;

			float cloudLayer = abs(VC_HEIGHT - rayPos.y) / VC_STRETCHING;

			if (cloudLayer > 2.0) break;

			float cloudVisibility = float(cloudLayer < 2.0);

			//Indoor leak prevention
			if (eyeBrightnessSmooth.y <= 150.0) {
				vec3 shadowPos = calculateShadowPos(worldPos);
				float shadow1 = shadow2D(shadowtex1, shadowPos).z;

				cloudVisibility *= 1.0 - float(shadow1 != 1.0);
			}

			//Shaping & Lighting
			if (cloudVisibility > 0.0) {
				//Cloud Noise
				#ifndef BLOCKY_CLOUDS
				float noise = get3DNoise(rayPos * 0.500 + frameTimeCounter * 0.20) * 1.0;
					  noise+= get3DNoise(rayPos * 0.250 + frameTimeCounter * 0.15) * 1.5;
					  noise+= get3DNoise(rayPos * 0.125 + frameTimeCounter * 0.10) * 3.0;
					  noise+= get3DNoise(rayPos * 0.025 + frameTimeCounter * 0.05) * 9.0;
				#else
				float noise = get3DNoise(rayPos * 0.045) * 350.0;
				#endif

				noise = clamp(noise * amount - (10.0 + cloudLayer * 5.0), 0.0, 1.0);

				//Color Calculations
				float cloudLighting = clamp(smoothstep(VC_HEIGHT + VC_STRETCHING * noise, VC_HEIGHT - VC_STRETCHING * noise, rayPos.y) * 0.5 + noise * 0.5, 0.0, 1.0);
				float cloudDistantFade = clamp((VC_DISTANCE - lWorldPos) / VC_DISTANCE, 0.125, 1.0);

				vec4 cloudColor = vec4(mix(lightCol, ambientCol, cloudLighting), noise * cloudDistantFade);
					 cloudColor.rgb *= cloudColor.a;

				vc += cloudColor * (1.0 - vc.a);
			}
		}

		//Why not tint out clouds with the sky color?
		vc.rgb = mix(vc.rgb, vc.rgb * 0.65, (1.0 - rainStrength) * (1.0 - timeBrightness));
		vc.rgb = mix(vc.rgb, vc.rgb * skyColor * skyColor * 2.0, timeBrightness * (1.0 - rainStrength));
		vc *= ug;
	}
}
#endif

#ifdef VL
void computeVolumetricLight(in float dither, in float ug, inout vec4 vl) {
	//Depths
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;

	//Positions
	vec4 screenPos = vec4(texCoord, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;
	vec3 nViewPos = normalize(viewPos.xyz);

	float VoU = 1.0 - clamp(dot(nViewPos, upVec), 0.0, 1.0);
	float VoS = mix(clamp(dot(nViewPos, sunVec), 1.0 - pow2(timeBrightness), 1.0), 1.0, float(isEyeInWater == 1));
	float visibility = ug * float(z0 > 0.56) * 0.75 * VL_OPACITY * VoU * VoS;

	#if MC_VERSION >= 11900
	visibility *= 1.0 - darknessFactor;
	#endif

	visibility *= 1.0 - blindFactor;

	if (visibility > 0.0) {
		#ifdef SHADOW_COLOR
		vec3 shadowCol = vec3(0.0);
		#endif

		vec4 translucent = texture2D(colortex1, texCoord);

		float lViewPos = length(viewPos);
		float linearDepth0 = getLinearDepth2(z0);
		float linearDepth1 = getLinearDepth2(z1);

		//Ray marching and main calculations
		for (int i = 0; i < VL_SAMPLES; i++) {
			float currentDepth = (i + dither) * (10.0 - float(isEyeInWater == 1.0) * 7.0);

			if (linearDepth1 < currentDepth || (linearDepth0 < currentDepth && translucent.rgb == vec3(0.0))) {
				break;
			}

			vec3 worldPos = calculateWorldPos(getLogarithmicDepth(currentDepth), texCoord);

			float lWorldPos = length(worldPos);

			if (VoU == 0.0 || lWorldPos > far) break;

			vec3 shadowPos = calculateShadowPos(worldPos);
			float shadow1 = shadow2D(shadowtex1, shadowPos).z;
			float shadow0 = shadow2D(shadowtex0, shadowPos).z;

			//Distant Fade
			float fogFade = 1.0 - clamp(pow4(lViewPos * 0.000125) + pow8(lWorldPos / far), 0.0, 1.0);

			//Colored Shadows
			#ifdef SHADOW_COLOR
			if (shadow0 < 1.0) {
				if (shadow1 > 0.0) {
					shadowCol = texture2D(shadowcolor0, shadowPos.xy).rgb;
					shadowCol *= shadowCol * shadow1;
				}
			}

			vec3 shadow = clamp(shadowCol * (2.0 + timeBrightness * 8.0) * (1.0 - shadow0) + shadow0, 0.0, 10.0);
			#endif

			//Color Calculations
			visibility *= fogFade;

			vec4 vlColor = vec4(0.0);
			if (visibility > 0.0 && shadow1 != 0.0) {
				vlColor = vec4(mix(lightCol, waterColor, float(isEyeInWater == 1)), visibility);
				vlColor.rgb *= vlColor.a;

				#ifdef SHADOW_COLOR
				vlColor.rgb *= shadow;
				#endif
			}

			//Trabslucency Blending
			if (linearDepth0 < currentDepth) {
				vlColor.rgb *= translucent.rgb;
			}

			vl += vlColor * (1.0 - vl.a);
		}
	}
}
#endif