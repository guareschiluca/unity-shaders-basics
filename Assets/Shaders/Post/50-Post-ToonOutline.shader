Shader "Hidden/LG/Post/Toon Outline"
{
	/*
	 * This POST effect is designed for URP Full Screen Render Pass
	 * render feature.
	 * 
	 * This is not going to work on the built-in RP or other SRPs.
	 */
	Properties
	{
		_OutlineColor("Edge Color", Color) = (0, 0, 0, 1)
		_OutlineThickness("Edge Thickness", Integer) = 2
		_DepthThreshold("Depth Threshold", Range(0.0001, 1)) = 0.075
		_DepthThresholdWidth("Depth Threshold Width", Range(0.0001, 0.25)) = 0.1
		_DepthPower("Depth Contrast", Range(0.001, 10)) = 1
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
			UNITY_DECLARE_TEX2D(_CameraDepthTexture);
			
			float4 _OutlineColor;
			float _OutlineThickness;
			float _DepthThreshold;
			float _DepthThresholdWidth;
			float _DepthPower;

			#define SAMPLE_DEPTH_AT_OFFSET(offsetX, offsetY) \
				LinearEyeDepth( \
					UNITY_SAMPLE_TEX2D( \
						_CameraDepthTexture, \
						IN.uv0 + float2( \
							offsetX, \
							offsetY \
						) \
					) \
				)

			float4 frag(V2F IN) : SV_Target
			{
				//	Take current rendered screen color
				float4 screenColor = UNITY_SAMPLE_TEX2D(_BlitTexture, IN.uv0);

				//	Decide how far from the current pixel to compare the depth, in texture space
				float2 offset = _OutlineThickness / 1000.0;
				offset.x *= _ScreenParams.y / _ScreenParams.x;	//	Aspect correction
				offset *= _ScreenParams.z;	//	Render-scale correction

				//	Sample depth from center and neighboring pixels
				float centerDepth		= SAMPLE_DEPTH_AT_OFFSET(0,			0);
				float topRightDepth		= SAMPLE_DEPTH_AT_OFFSET(offset.x,	offset.y);
				float rightDepth		= SAMPLE_DEPTH_AT_OFFSET(offset.x,	0);
				float bottomRightDepth	= SAMPLE_DEPTH_AT_OFFSET(offset.x,	-offset.y);
				float topLeftDepth		= SAMPLE_DEPTH_AT_OFFSET(-offset.x,	offset.y);
				float leftDepth			= SAMPLE_DEPTH_AT_OFFSET(offset.x,	0);
				float bottomLeftDepth	= SAMPLE_DEPTH_AT_OFFSET(-offset.x,	-offset.y);
				float upDepth			= SAMPLE_DEPTH_AT_OFFSET(0,			offset.y);
				float downDepth			= SAMPLE_DEPTH_AT_OFFSET(0,			offset.y);

				//	Compute the total difference
				float diff =
					abs(centerDepth - topRightDepth) +
					abs(centerDepth - rightDepth) +
					abs(centerDepth - bottomRightDepth) +
					abs(centerDepth - topLeftDepth) +
					abs(centerDepth - leftDepth) +
					abs(centerDepth - bottomLeftDepth) +
					abs(centerDepth - upDepth) +
					abs(centerDepth - downDepth);
				diff /= 8;
				diff = pow(diff, _DepthPower);

				//	Determine the edge influence (smoothstep is basically a cubic inverse lerp)
				float edgeFactor = smoothstep(_DepthThreshold, _DepthThreshold + _DepthThresholdWidth, diff);

				//	Blend the edge color onto the screen color
				return lerp(screenColor, _OutlineColor, edgeFactor);
			}
			ENDHLSL
		}
	}
}
