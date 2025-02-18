//Settings//
#include "/lib/common.glsl"

#define GBUFFERS_TERRAIN

#ifdef FSH

//Varyings//
in float mat, isPlant;
in vec2 texCoord, lightMapCoord;
in vec3 sunVec, upVec, eastVec;
in vec3 normal;
in vec4 color;

//Uniforms//
#ifdef DYNAMIC_HANDLIGHT
uniform int heldItemId, heldItemId2;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
#endif

uniform float viewWidth, viewHeight;
uniform float nightVision;
uniform float frameTimeCounter;

#ifdef OVERWORLD
uniform float rainStrength;
#endif

#if defined OVERWORLD || defined END
uniform float timeBrightness, timeAngle;
#endif

#ifdef RAIN_PUDDLES
uniform float wetness;
#endif

#if defined RAIN_PUDDLES || defined EMISSIVE_FLOWERS
uniform sampler2D noisetex;
#endif

uniform vec3 cameraPosition;

#if defined BLOOM_COLORED_LIGHTING || defined GLOBAL_ILLUMINATION
uniform sampler2D gaux4;
#endif

uniform sampler2D texture;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

#if defined OVERWORLD || defined END
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
#endif

//Common Variables//
#if defined BLOOM_COLORED_LIGHTING || defined GLOBAL_ILLUMINATION
float getLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}
#endif

#ifdef OVERWORLD
float sunVisibility = clamp(dot(sunVec, upVec) + 0.025, 0.0, 0.1) * 10.0;
#endif

//Includes//
#include "/lib/util/ToNDC.glsl"
#include "/lib/util/ToWorld.glsl"
#include "/lib/util/bayerDithering.glsl"

#if defined OVERWORLD || defined END
#include "/lib/util/ToShadow.glsl"
#include "/lib/lighting/shadows.glsl"
#endif

#ifdef SHIMMER_MOD_SUPPORT
#include "/lib/lighting/shimmerModSupport.glsl"
#endif

#include "/lib/color/dimensionColor.glsl"
#include "/lib/lighting/sceneLighting.glsl"

#ifdef INTEGRATED_EMISSION
#include "/lib/ipbr/integratedEmissionTerrain.glsl"
#endif

#ifdef INTEGRATED_SPECULAR
#include "/lib/ipbr/integratedSpecular.glsl"
#endif

#if defined BLOOM || defined INTEGRATED_SPECULAR
#include "/lib/util/encode.glsl"
#endif

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord) * vec4(color.rgb, 1.0);
	vec3 newNormal = normal;

	float emission = 0.0;
	float specular = 0.0;

	if (albedo.a > 0.001) {
		float foliage = float(mat > 0.99 && mat < 1.01) + float(mat > 107.9 && mat < 108.1);
		float leaves = float(mat > 1.99 && mat < 2.01);

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		vec3 viewPos = ToNDC(screenPos);
		vec3 worldPos = ToWorld(viewPos);
		vec2 lightmap = clamp(lightMapCoord, 0.0, 1.0);

		#ifdef INTEGRATED_EMISSION
		getIntegratedEmission(albedo, viewPos, worldPos, lightmap, emission);
		#endif

		#ifdef INTEGRATED_SPECULAR
		getIntegratedSpecular(albedo, newNormal, worldPos.xz, lightmap, specular);
		#endif

		getSceneLighting(albedo.rgb, screenPos, viewPos, worldPos, newNormal, lightmap, emission, leaves, foliage, specular);
	}

	emission *= 4.0;

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;

	#ifndef INTEGRATED_SPECULAR
		#ifdef BLOOM
		/* DRAWBUFFERS:02 */
		gl_FragData[1].ba = vec2(emission * 0.1, emission);
		#endif
	#else
		/* DRAWBUFFERS:02 */
		gl_FragData[1] = vec4(EncodeNormal(newNormal), emission * 0.1, specular);
	#endif
}

#endif

/////////////////////////////////////////////////////////////////////////////////////

#ifdef VSH

//Varyings//
out float mat, isPlant;
out vec2 texCoord, lightMapCoord;
out vec3 sunVec, upVec, eastVec;
out vec3 normal;
out vec4 color;

//Uniforms//
#ifdef TAA
uniform int framemod8;

uniform float viewWidth, viewHeight;
#endif

#if defined OVERWORLD || defined END
uniform float timeAngle;
#endif

#ifdef WAVING_BLOCKS
uniform float frameTimeCounter;

uniform vec3 cameraPosition;
#endif

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

//Attributes//
attribute vec4 mc_Entity;

#ifdef WAVING_BLOCKS
attribute vec4 mc_midTexCoord;
#endif

//Includes//
#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef WAVING_BLOCKS
#include "/lib/util/waving.glsl"
#endif

//Program//
void main() {
	//Coord
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	lightMapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lightMapCoord = clamp(lightMapCoord, vec2(0.0), vec2(0.9333, 1.0));

	//Normal
	normal = normalize(gl_NormalMatrix * gl_Normal);

	//Sun & Other vectors
	sunVec = vec3(0.0);

    #if defined OVERWORLD
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * TAU;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
    #elif defined END
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
    sunVec = normalize((gbufferModelView * vec4(vec3(0.0, sunRotationData * 2000.0), 1.0)).xyz);
    #endif
	
	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

	//Materials
	mat = 0.0;
	isPlant = 0.0;

	if (mc_Entity.x >= 4 && mc_Entity.x <= 11 && mc_Entity.x != 9 && mc_Entity.x != 10 || (mc_Entity.x >= 14 && mc_Entity.x <= 15)) {
		mat = 1.0;
	} else if (mc_Entity.x == 9 || mc_Entity.x == 10){
		mat = 2.0;
	} else {
		mat = float(mc_Entity.x);
	}

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;

	#ifdef WAVING_BLOCKS
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz = getWavingBlocks(position.xyz, istopv, lightMapCoord.y);
	#endif

	#ifdef INTEGRATED_EMISSION
	#if defined EMISSIVE_FLOWERS && defined OVERWORLD
	if (mc_Entity.x >= 5 && mc_Entity.x <= 7) isPlant = 1.0;
	#endif
	#endif

	//Color & Position
    color = gl_Color;
	if (color.a < 0.1) color.a = 1.0;

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;

	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif