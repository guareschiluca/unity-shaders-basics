#ifndef LG_WATER_MASS
#define LG_WATER_MASS

/*
 * The Wave struct contains all the data needed
 * to calculate a wave's displacement.
 */
struct Wave
{
	float2 origin;
	float length;
	float amplitude;
	float time;
};

/*
 * Waves are packed in the shader as a single
 * float4, as follows:
 *	x: Main Wave's length
 *	y: Main Wave's amplitude
 *	z: Aux Wave's length
 *	w: Aux Wave's amplitude
 * 
 * The noise wave is a function of the aux wave.
 * 
 * The following functions help extrapolating the
 * individual waves from packed data, to be used
 * in the wave calculation functions.
 */
Wave GetMainWave(float4 packedWaves, float4 time)
{
	Wave wave;

	wave.origin = float2(0, 0);
	wave.length = packedWaves.x;
	wave.amplitude = packedWaves.y;
	wave.time = time.y;

	return wave;
}
Wave GetAuxWave(float4 packedWaves, float4 time)
{
	Wave wave;

	wave.origin = float2(100, 100);
	wave.length = packedWaves.z;
	wave.amplitude = packedWaves.w;
	wave.time = -time.w;

	return wave;
}
Wave GetNoiseWave(float4 packedWaves, float4 time)
{
	Wave wave;

	wave.origin = float2(300, -1000);
	wave.length = packedWaves.z;
	wave.amplitude = packedWaves.w * 0.5;
	wave.time = -time.z;

	return wave;
}

/*
 * The following functions calculate the vertical offset
 * for a point at a given position.
 * The second function automatically handles packed data.
 */
float GetWaveDisplacementAtPoint(float3 positionWS, Wave waveMain, Wave waveAux, Wave waveNoise)
{
	float phaseMain = length(positionWS.xz + waveMain.origin);
	float phaseAux = length(positionWS.xz + waveAux.origin);
	float phaseNoise = length(positionWS.xz + waveNoise.origin);

	float vOffset = 0;

	vOffset += (sin(waveMain.time + (phaseMain / waveMain.length)) * 0.5 + 0.5) * waveMain.amplitude;
	vOffset += (sin(waveAux.time + (phaseAux / waveAux.length)) * 0.5 + 0.5) * waveAux.amplitude;
	vOffset += (sin(waveNoise.time + (phaseNoise / waveNoise.length)) * 0.5 + 0.5) * waveNoise.amplitude;

	float totalOffset = waveMain.amplitude + waveAux.amplitude + waveNoise.amplitude;

	return (vOffset / max(0.001, totalOffset)) * waveMain.amplitude;
}

float GetWaveDisplacementAtPointFromPacked(float3 positionWS, float4 waves, float4 time)
{
	Wave waveMain = GetMainWave(waves, time);
	Wave waveAux = GetAuxWave(waves, time);
	Wave waveNoise = GetNoiseWave(waves, time);
	
	return GetWaveDisplacementAtPoint(positionWS, waveMain, waveAux, waveNoise);
}

/*
 * The following functions calculate the orthonormal space
 * at a given point on a water surface via estimating a
 * discrete derivative around the point, at an offset, and
 * building the normal, tangent and binormal vectors.
 * 
 * The second function automatically handles packed data.
 * 
 * WARNING!!!
 * Due to the nature of the calculation, the resulting TBN
 * space may not be perfectly orthonormal.
 * If orthonormality is required, you must recalculate the
 * binormal as the cross product between the tangent and
 * the normal.
 * 
 * NOTE:
 * Orthonormality is required when you use TBN to create
 * a transformation matrix (e.g. for normal mapping).
 */
void GetWaveSpaceAtPoint(
	float3 positionWS,
	Wave waveMain, Wave waveAux, Wave waveNoise,
	float normalReconstructOffset,
	out float3 tangentWS, out float3 binormalWS, out float3 normalWS
)
{
	//	Recompute normal
	//...	Take the point to the left and to the right of the current vertex at a given offset
	float3 xRef = positionWS + float3(normalReconstructOffset, 0, 0);
	xRef.y += GetWaveDisplacementAtPoint(xRef, waveMain, waveAux, waveNoise);

	float3 xRefN = positionWS - float3(normalReconstructOffset, 0, 0);
	xRefN.y += GetWaveDisplacementAtPoint(xRefN, waveMain, waveAux, waveNoise);

	//...	Take the point to in fron and to behind of the current vertex at a given offset
	float3 yRef = positionWS + float3(0, 0, normalReconstructOffset);
	yRef.y += GetWaveDisplacementAtPoint(yRef, waveMain, waveAux, waveNoise);

	float3 yRefN = positionWS - float3(0, 0, normalReconstructOffset);
	yRefN.y += GetWaveDisplacementAtPoint(yRefN, waveMain, waveAux, waveNoise);

	//...	Calculate tangent and binormal based on the normalized distance between the offsets, per axis
	tangentWS = normalize(xRef - xRefN);
	binormalWS = normalize(yRef - yRefN);
	//...	Calculate the normal based on the tangent and binormal
	normalWS = normalize(cross(binormalWS, tangentWS));
}

void GetWaveSpaceAtPointFromPacked(
	float3 positionWS,
	float4 waves, float4 time,
	float normalReconstructOffset,
	out float3 tangentWS, out float3 binormalWS, out float3 normalWS
)
{
	Wave waveMain = GetMainWave(waves, time);
	Wave waveAux = GetAuxWave(waves, time);
	Wave waveNoise = GetNoiseWave(waves, time);
	
	GetWaveSpaceAtPoint(
		positionWS,
		waveMain, waveAux, waveNoise,
		normalReconstructOffset,
		tangentWS, binormalWS, normalWS
	);

}
#endif
