//Settings//
#include "/lib/common.glsl"

#define GBUFFERS_WEATHER

#ifdef FSH

//Varyings//
in vec2 texCoord, lightMapCoord;

//Uniforms//
uniform float rainStrength;

uniform sampler2D texture;

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * rainStrength;

	if (albedo.a > 0.001) {
		albedo.a *= 0.15;
		albedo.rgb *= vec3(1.0) + lightMapCoord.x * blockLightCol;
	}

    /* DRAWBUFFERS:01 */
    gl_FragData[0] = albedo * 0.75;
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
}

#endif

/////////////////////////////////////////////////////////////////////////////////////

#ifdef VSH

//Varyings//
out vec2 texCoord, lightMapCoord;

//Program//
void main() {
	//Coords
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lightMapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lightMapCoord = clamp(lightMapCoord, vec2(0.0), vec2(0.9333, 1.0));

	//Position
	gl_Position = ftransform();
}

#endif