/*
 * What follows is called "include guard". It's a mechanism used to
 * prevent redefinition of the content of this library in case of
 * multiple or recursive inclusion (a file includes this file AND
 * another file including this file as well).
 */
#ifndef LG_LIGHT_FUNC
#define LG_LIGHT_FUNC

/*
 * The fresnel function takes a world-space normal, assuming it's
 * a normalized vector, and calculates the incidence between the
 * normal vector and the main light's direction.
 * 
 * The output is in the -1 (face off) to +1 (face) range.
 */
float Fresnel(float3 normalWS)
{
	return dot(_WorldSpaceLightPos0, normalWS);
}

/*
 * The difuse function is a saturated version of the fresnel function,
 * preventing the negative values from the dot product that would
 * interfere in lighting calculations.
 * 
 * The output is in the 0 to 1 range.
 */
float Diffuse(float3 normalWS)
{
	return saturate(Fresnel(normalWS));
}

/*
 * The specular function calculates the highlight of a smooth surface.
 * The hightlight is at its highest value whent the light direction is
 * the reflection vector of the view direction compared to the sufrace'
 * normal.
 * 
 * The output is in the 0 to 1 range.
 */
float Specular(float3 normalWS, float3 viewDirWS, float power)
{
	float3 medianVector = normalize(_WorldSpaceLightPos0 + viewDirWS);

	return pow(saturate(dot(medianVector, normalWS)), power);
}

#endif
