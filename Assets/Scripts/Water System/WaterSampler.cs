using UnityEngine;
using UnityEngine.Assertions;
using UnityEngine.UI;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditorInternal;
#endif

using S = System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace WaterSystem
{
	[DisallowMultipleComponent]
	[RequireComponent(typeof(Renderer))]
	public sealed class WaterSampler : MonoBehaviour
	{
		#region Private constants
		private const string KERNEL_ID_SAMPLE_WAVE_POINTS = "SampleWavePoints";
		private const string SHADER_PROP_WAVES_PACKED = "wavesPacked";
		private const string SHADER_PROP_TIME = "time";
		private const string SHADER_PROP_SAMPLES = "samples";
		#endregion
		#region Private variables
		private Renderer wavesRenderer;
		[SerializeField]
		private ComputeShader waveSamplingShader;
		private int kernelID_SampleWavePoints = 0;
		private int shaderProp_wavesPacked = 0;
		private int shaderProp_time = 0;
		private int shaderProp_samples = 0;
		[SerializeField]
		private string packedWavesDataParamName = "_Waves";
		private int? _packedWavesDataParam = null;
		private ComputeBuffer samplesBuffer = null;

		/*
		 * Since this class needs to build data for sampling points or
		 * planes each frame, that would trigger a lot of GC.
		 * We can take advantage of the extremely fixed array sizes
		 * the functions of this class require and pre-allocate them as
		 * persistent pools that we just update in their values.
		 * 
		 * Array instancing and destruction is the major pitfall of this
		 * script, that would lead an otherwise performant code to generate
		 * tons of GC.
		 */
		private Vector3[] samplePointData = new Vector3[1];
		private Vector3[] samplePlanarContextData = new Vector3[3];
		#endregion
		#region Private properties
		private int packedWavesDataParam
		{
			get
			{
				if(
					_packedWavesDataParam == null ||
					!_packedWavesDataParam.HasValue
				)
					_packedWavesDataParam = Shader.PropertyToID(packedWavesDataParamName);

				return _packedWavesDataParam.Value;
			}
		}
		/*
		 * Replicating the _Time built-in shader variable,
		 * which is needed by the waves formula but not
		 * available when we need it as we're out of the
		 * render loop and Unity doesn't take care of it
		 * for us.
		 */
		private Vector4 shaderTime => new Vector4(
			Time.time / 20,
			Time.time,
			Time.time * 2,
			Time.time * 3
		);
		/*
		 * We're reading the waves' configuration directly
		 * from the material, to be 100% in sync with it.
		 */
		private Vector4 packedWavesData => wavesRenderer.sharedMaterial.GetVector(packedWavesDataParam);
		#endregion
		#region Lifecycle
		void Awake()
		{
			//	Store waves mesh
			wavesRenderer = GetComponent<Renderer>();
			Assert.IsNotNull(wavesRenderer, "Water sampler requires a renderer for the waves.");
			Assert.IsTrue(wavesRenderer.sharedMaterial.HasVector(packedWavesDataParam), $"Water sampler requires a main material, on the renderer, named \"{packedWavesDataParamName}\", but it wasn't found or it's not a vector.");

			//	Prepare kernel id
			Assert.IsNotNull(waveSamplingShader, "Cannot sample without a sampling compute shader.");
			kernelID_SampleWavePoints = waveSamplingShader.FindKernel(KERNEL_ID_SAMPLE_WAVE_POINTS);

			//	Prepare shader prop ids
			shaderProp_wavesPacked = Shader.PropertyToID(SHADER_PROP_WAVES_PACKED);
			shaderProp_time = Shader.PropertyToID(SHADER_PROP_TIME);
			shaderProp_samples = Shader.PropertyToID(SHADER_PROP_SAMPLES);
		}
		void OnDestroy()
		{
			if(
				samplesBuffer != null &&
				samplesBuffer.IsValid()
			)
				samplesBuffer.Release();
		}
		#endregion
		#region Public methods
		public Vector3 ProjectPoint(Vector3 worldPosition) => Utils.ProjectOntoSurface(worldPosition, transform);
		public Vector3 SamplePosition(Vector3 worldPosition)
		{
			samplePointData[0] = Utils.ProjectOntoSurface(worldPosition, transform);
			SampleWaveOffsets(samplePointData);
			return samplePointData[0];
		}
		public void SamplePlanarContext(
			Vector3 point1, Vector3 point2, Vector3 point3,
			out Vector3 sample1, out Vector3 sample2, out Vector3 sample3,
			out Vector3 planeNormal
		)
		{
			//	Project points onto the surface's plane
			/*
			 * Point will likely NOT lie on the water's surface plane,
			 * hence we need to project them down to have the correct
			 * starting point to apply the waves' displacement, the
			 * same way as the vertex shader does during rendering.
			 */
			samplePlanarContextData[0] = ProjectPoint(point1);
			samplePlanarContextData[1] = ProjectPoint(point2);
			samplePlanarContextData[2] = ProjectPoint(point3);

			//	Smaple the 3 points we need for the surface mapping
			SampleWaveOffsets(samplePlanarContextData);

			//	Pass the 3 sampled points out
			sample1 = samplePlanarContextData[0];
			sample2 = samplePlanarContextData[1];
			sample3 = samplePlanarContextData[2];

			//	Calculate the normal for the plane where these 3 sampled points lie
			planeNormal = new Plane(sample1, sample2, sample3).normal;
		}
		#endregion
		#region Private methods
		/*
		 * Arrays are reference types in C#, hence we don't need to
		 * return the updated array passed as a parameter, only the
		 * pointer to the first element is copied in and would be
		 * copied out.
		 */
		private void SampleWaveOffsets(Vector3[] samplePoints)
		{
			//	Count the points to sample
			int samplesCount = samplePoints.Length;

			//	Resize samples buffer only if needed, otherwise keep the old one
			if(
				samplesBuffer == null ||
				!samplesBuffer.IsValid() ||	//	Unity may invalidate the buffer between frames, always check!
				samplesBuffer.count != samplesCount
			)
			{
				if(samplesBuffer != null)
					samplesBuffer.Release();

				samplesBuffer = new ComputeBuffer(
					samplesCount,
					sizeof(float) * 3
				);
			}

			//	Fill the buffer with the requested data
			samplesBuffer.SetData(samplePoints);

			//	Set compute shader params
			waveSamplingShader.SetVector(shaderProp_wavesPacked, packedWavesData);
			waveSamplingShader.SetVector(shaderProp_time, shaderTime);
			waveSamplingShader.SetBuffer(kernelID_SampleWavePoints, shaderProp_samples, samplesBuffer);

			//	Dispatch the compute shader
			waveSamplingShader.Dispatch(
				kernelID_SampleWavePoints,
				samplesCount, 1, 1
			);

			//	Wait for GPU to finish and read back the samples buffer
			samplesBuffer.GetData(samplePoints);	//	This waits for the GPU to finish calculations, syncing the execution
		}
		#endregion
	}
}
