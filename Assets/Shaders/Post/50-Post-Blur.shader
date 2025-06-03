Shader "Hidden/LG/Post/Blur"
{
	/*
	 * This POST effect is designed for URP Full Screen Render Pass
	 * render feature.
	 * 
	 * This is not going to work on the built-in RP or other SRPs.
	 */
	Properties
	{
		_Blur("Blur Amount (Values outside [0; 1] will cause artifacts)", Float) = 1
	}
	SubShader
	{
		/*
		 * Tags here are not strictly required as the Full Screen Render Pass
		 * directly uses the material in a custom way, bypassing Unity's filters.
		 * Still specifying them to preserve maximum compatibility with possible
		 * custom effects.
		 */
		Tags
		{
			"RenderType" = "Opaque"
			"LightMode" = "FullScreen"
		}

		ZTest Always	//	Overlay effect, ignore scene depth
		ZWrite Off		//	Overlay effect, do not interfere with scene depth
		Cull Off		//	Just ensures the effect is rendered, regardless the vertex order

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct MeshData
			{
				uint vertexID : SV_VertexID;	//	Uncommon input, useful in this case (read comments in the vertex shader)
			};

			struct V2F
			{
				float4 position : POSITION;
				float2 uv0 : TEXCOORD0;
			};

			V2F vert(MeshData meshData)
			{
				V2F OUT;

				/*
				 * This is a tricky but fascinating one.
				 * Full screen effects render as a full-screen triangle.
				 * TRIANGLE, not quad: 3 vertices, 1 triangle, that cover
				 * the entire viewport. How?
					----------------
					|      |....../
					| VIEW |..../
					| PORT |../
					|      |/
					--------
					|...../
					|.../
					|./
					|/
				 * Each vertex is assigned with an ID by the GPU so
				 * we just take the vertex id and assign a clip-space
				 * position to it, so that one vertex is at a corner
				 * while the other two are as far as twice the viewport
				 * size.
				 * Binary operators are just an optimized way to make
				 * the calculation.
				 */
				float2 position = float2(
					(meshData.vertexID << 1) & 2,
					meshData.vertexID & 2
				);

				OUT.position = float4(position * 2 - 1, 0.0, 1.0);	//	The w component stores either 0 (direction vector) or 1 (point vector)
				OUT.uv0 = float2(position.x, 1 - position.y);		//	Screen space and UV space have reversed Y coordinate

				return OUT;
			}

			/*
			 * Sampling color and depth from the current
			 * rendered frame.
			 */
			UNITY_DECLARE_TEX2D(_BlitTexture);

			float _Blur;

			// 7x7 Gaussian blur kernel weights (normalized, center-weighted)
			static const int BLUR_KERNEL_SIZE = 7;
			static const int BLUR_KERNEL_SHIFT = BLUR_KERNEL_SIZE / 2;	//	Integer division on odd number is rounded down
			static const float BLUR_KERNEL[BLUR_KERNEL_SIZE * BLUR_KERNEL_SIZE] = {
				0.0166297,		0.0183786,		0.0195151,		0.0199093,		0.0195151,		0.0183786,	0.0166297,
				0.0183786,		0.0203115,		0.0215675,		0.0220032,		0.0215675,		0.0203115,	0.0183786,
				0.0195151,		0.0215675,		0.0229012,		0.0233638,		0.0229012,		0.0215675,	0.0195151,
				0.0199093,		0.0220032,		0.0233638,		0.0238358,		0.0233638,		0.0220032,	0.0199093,
				0.0195151,		0.0215675,		0.0229012,		0.0233638,		0.0229012,		0.0215675,	0.0195151,
				0.0183786,		0.0203115,		0.0215675,		0.0220032,		0.0215675,		0.0203115,	0.0183786,
				0.0166297,		0.0183786,		0.0195151,		0.0199093,		0.0195151,		0.0183786,	0.0166297
			};

			float4 frag(V2F IN) : SV_Target
			{
				//	Take current rendered screen color
				float4 screenColor = UNITY_SAMPLE_TEX2D(_BlitTexture, IN.uv0);

				//	Calculate the texel size from screen resolution
				float2 texelSize = 1.0 / _ScreenParams.xy;

				//	Calculate the blur color by stacking contributes from neighbouring pixels
				float4 blurColor = 0;
				for(int u = 0; u < BLUR_KERNEL_SIZE; ++u)
					for(int v = 0; v < BLUR_KERNEL_SIZE; ++v)
					{
						float2 kernelCoord = float2(
							u - BLUR_KERNEL_SHIFT,
							v - BLUR_KERNEL_SHIFT
						);
						float4 neighbourColor = UNITY_SAMPLE_TEX2D(
							_BlitTexture,
							IN.uv0 + kernelCoord * texelSize * _Blur
						);
						blurColor += neighbourColor * BLUR_KERNEL[u * BLUR_KERNEL_SIZE + v];
					}

				//	Return the blur color
				return blurColor;
			}
			ENDHLSL
		}
	}
}
