vec4 getWaterFog(vec3 viewPos) {
    float neBS = clamp(eBS + 0.125, 0.0, 1.0);
    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-3.0 * fog);

    vec3 waterFogColor = mix(waterColor * waterColor, weatherCol.rgb * 0.25, rainStrength * 0.5);
         #ifdef OVERWORLD
         waterFogColor *= (0.125 + timeBrightness * 0.875) * 0.5;

         if (isEyeInWater == 1) {
            vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

            float VoL = dot(normalize(viewPos), lightVec) * shadowFade;
            float glare = clamp(VoL * 0.5 + 0.5, 0.0, 1.0);
            glare = 0.01 / (1.0 - 0.99 * glare) - 0.01;
            waterFogColor *= 1.0 + glare * 16.0 * neBS;
            
         }
         #endif

         waterFogColor *= neBS;
         waterFogColor *= 1.0 - blindFactor;

		 #if MC_VERSION >= 11900
		 waterFogColor *= 1.0 - darknessFactor;
		 #endif

    return vec4(waterFogColor, fog);
}