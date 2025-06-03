Shader "LG/99 DissolveShader"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		[NoScaleOffset] _DissolveRamp("Dissolve Ramp", 2D) = "white" {}

		[Gamma] _Threshold("Dissolve Threshold", Range(0, 1)) = 0
		_Transition("Transition Area", Range(0, 0.5)) = 0.1

		_TransitionColor("Transition Color", Color) = (1, 1, 0, 1)

		[Toggle(AUTO)] _AutoTransition("Auto Transition", Float) = 0.0
	}
	SubShader
	{
		HLSLINCLUDE
		#pragma multi_compile _ AUTO

		/*
		 * Multiple passes (depth and color) will use the exact same vertex
		 * logic as well as a lot of shared code for the fragment logic.
		 * 
		 * We're moving as much as possible in the shared program to optimize
		 * maintenance.
		 */

		#include "UnityCG.cginc"

		struct MeshData
		{
			float3 position : POSITION;
			float2 uv0 : TEXCOORD0;
		};
		struct V2F
		{
			float4 position : POSITION;
			float2 uv0 : TEXCOORD0;
		};
		
		UNITY_DECLARE_TEX2D(_MainTex);
		float4 _MainTex_ST;
		UNITY_DECLARE_TEX2D(_DissolveRamp);
		float _Threshold;
		float _Transition;

		V2F vert(MeshData meshData)
		{
			V2F OUT;

			OUT.position = UnityObjectToClipPos(meshData.position);
			OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);

			return OUT;
		}

		/*
		 * This is the core of the dissolve shader, the most simple and
		 * broadly used shader in game development by both indie and
		 * AAA studios for its simplicity and its usefulness.
		 * 
		 * Basically, we're using a gradient texture (black to white,
		 * any shape) to progressively mask the mesh' pixels. The masking
		 * process is simple: we move a trehsold between black and white
		 * and we discard every pixel where the mask is below the threshold.
		 * 
		 * We'll leverage the clip() function, which takes a float argument
		 * and discards the pixel if the argument is less than 0.
		 *		https://developer.download.nvidia.com/cg/clip.html
		 * Knowing this, the operation is simple: we subtract the theshold
		 * from the gradient texture sample and pass the result to the
		 * clip() function: if the threshold is higher than the gradient,
		 * then the argument will be negative and the pixel gets discarded.
		 */
		float DissolveTransitionValue(float2 uv)
		{
			float dissolve = UNITY_SAMPLE_TEX2D(_DissolveRamp, uv).r;

			/*
			 * Here we just animate the effect for showcase purposes.
			 * 
			 * The real effect uses the _Threshold property to animate the
			 * effect based on game logic.
			 * 
			 * The lerp operation expands the threshold value beyond the
			 * [0; 1] range to include the _Transition space and allow
			 * for fully visible (with no transition pixels) and fully
			 * hidden (with no transition pixels) mesh.
			 */
			#ifdef AUTO
			float th = _SinTime.w * 0.5 + 0.5;
			th = pow(th, 2.2);
			float threshold = lerp(-_Transition, 1 + _Transition, th);
			#else
			float threshold = lerp(-_Transition, 1 + _Transition, _Threshold);
			#endif

			/*
			 * The subtraction will wither be used to decide whether to
			 * discard the pixel or not or to calculate the transition
			 * area.
			 */
			float remaining = dissolve - threshold;

			return remaining;
		}
		ENDHLSL
		Pass
		{
			Name "DepthOnly"
			Tags { "LightMode" = "DepthOnly" }

			ZWrite On
			ColorMask 0

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			float frag(V2F IN) : SV_Depth
			{
				//	Discard masked pixels
				float remaining = DissolveTransitionValue(IN.uv0);
				clip(remaining);

				//	Return the pixel's depth.
				return IN.position.z;
			}
			ENDHLSL
		}
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			float4 _TransitionColor;

			float4 frag(V2F IN) : SV_Target
			{
				//	Discard masked pixels
				float remaining = DissolveTransitionValue(IN.uv0);
				clip(remaining);

				//	Caculate the transition area
				float transition = saturate(remaining / _Transition);

				//	Read the main texture color
				float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

				//	Blend the transition color onto the main texture color based on the transition area
				return lerp(_TransitionColor, texColor, transition);
			}
			ENDHLSL
		}
	}
}
