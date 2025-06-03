Shader "Hidden/LG/Post/Graphic"
{
	/*
	 * This POST effect is designed for teh built-in RP to be used
	 * with OnRenderImage().
	 * 
	 * This is not going to work on SRPs.
	 */
	Properties
	{
		[HideInInspector] _MainTex("Main Texture", 2D) = "white" {}
		_DarkColor("Dark Color", Color) = (0, 0, 0, 1)
		_BrightColor("Bright Color", Color) = (1, 1, 1, 1)
		_Mask("Mask", 2D) = "white" {}

		_RevealThreshold("Reveal", Range(0, 1)) = 1
		_RevealTransition("Reveal Transition", Range(0, 0.5)) = 0.2

		_PaperNoise("Paper Noise", 2D) = "white" {}

		_Patterns("Patterns", 2D) = "white" {}
		_DarkThreshold("Dark Threshold", Range(0, 1)) = 0.225
		_MidThreshold("Mid Threshold", Range(0, 1)) = 0.5
		_BrightThreshold("Bright Threshold", Range(0, 1)) = 0.85
		_PatternsTransition("Patterns Transition", Range(0, 0.5)) = 0.1
	}
	SubShader
	{
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

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
				float2 uvScreen : TEXCOORD1;
			};

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _MainTex_ST;
			float4 _DarkColor;
			float4 _BrightColor;
			UNITY_DECLARE_TEX2D(_Mask);
			
			float _RevealThreshold;
			float _RevealTransition;

			UNITY_DECLARE_TEX2D(_PaperNoise);
			float4 _PaperNoise_ST;

			UNITY_DECLARE_TEX2D(_Patterns);
			float4 _Patterns_ST;
			float _DarkThreshold;
			float _MidThreshold;
			float _BrightThreshold;
			float _PatternsTransition;

			V2F vert(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);
				float4 screenPos = ComputeScreenPos(OUT.position);
				OUT.uvScreen = screenPos.xy / screenPos.w;
				OUT.uvScreen.x *= _ScreenParams.x / _ScreenParams.y;

				return OUT;
			}
			float4 frag(V2F IN) : SV_Target
			{
				//	==== Get color from current render target ====
				float4 screenColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

				//	==== Get a perceived grayscale from current color ====
				float perceivedBrightness = dot(screenColor, float3(0.299, 0.587, 0.114));

				//	==== Sample mask texture (store only R and G) ====
				float2 mask = UNITY_SAMPLE_TEX2D(_Mask, IN.uv0).rg;

				//	==== Use R mask to darken borders ====
				perceivedBrightness *= 1 - mask.r;

				//	==== Sample pattenrs texture ====
				float3 patterns = UNITY_SAMPLE_TEX2D(_Patterns, TRANSFORM_TEX(IN.uvScreen, _Patterns)).rgb;

				//	==== Calculate components for each brightness level ====
				float darkComponent = 1 - smoothstep(
					_DarkThreshold - _PatternsTransition,
					_DarkThreshold + _PatternsTransition,
					perceivedBrightness
				);
				float midComponent = 1 - smoothstep(
					_MidThreshold - _PatternsTransition,
					_MidThreshold + _PatternsTransition,
					perceivedBrightness
				) - darkComponent;
				float brightComponent = 1 - smoothstep(
					_BrightThreshold - _PatternsTransition,
					_BrightThreshold + _PatternsTransition,
					perceivedBrightness
				) - darkComponent - midComponent;
				float whiteComponent = smoothstep(
					_BrightThreshold - _PatternsTransition,
					_BrightThreshold + _PatternsTransition,
					perceivedBrightness
				);

				//	==== Calculate final pattern by stacking the different brightness levels ====
				float patternShade =
					patterns.r * darkComponent +
					patterns.g * midComponent +
					patterns.b * brightComponent +
					whiteComponent;

				//	==== Apply composite pattern to the brightness ====
				perceivedBrightness *= patternShade;

				//	==== Sample and apply paper noise based on screen space UV ====
				float paperNoise = UNITY_SAMPLE_TEX2D(_PaperNoise, TRANSFORM_TEX(IN.uvScreen, _PaperNoise)).r;
				perceivedBrightness *= paperNoise;

				//	==== Remap from grayscale to a color gradient ====
				float4 graphicColor = lerp(_DarkColor, _BrightColor, perceivedBrightness);

				//	==== Calculate reveal pattern based on G mask ====
				float revealThreshold = lerp(-_RevealTransition, 1 + _RevealTransition, 1 - _RevealThreshold);

				float revealAlpha = smoothstep(0, 1, (mask.g - revealThreshold) / _RevealTransition);

				//	==== Blend effect on the original color based on the reveal mask ====
				return lerp(screenColor, graphicColor, revealAlpha);
			}
			ENDHLSL
		}
	}
}
