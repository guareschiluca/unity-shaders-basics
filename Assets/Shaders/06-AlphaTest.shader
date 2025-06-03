Shader "LG/06 Transparent (Cutoff)"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)

		_Threshold("Alpha Threshold", Range(0, 1)) = 0.5
	}
	SubShader
	{
		/*
		 * The Tags block allows to change how and when a SubShader or a Pass
		 * gets rendered. In this case, we're moving this shader later in the
		 * render queue, somewhere in the middle between opaque and transparent
		 * objects.
		 * 
		 * We usually mess with the render queue when we need to calculate the
		 * current pixel based on a stable state, in this case after all opaque
		 * geometry rendered.
		 */
		Tags { "Queue" = "AlphaTest" }

		HLSLINCLUDE
		#include "UnityCG.cginc"

		struct MeshData
		{
			float4 position : POSITION;
			float2 uv0 : TEXCOORD0;
		};

		struct V2F
		{
			float4 position : SV_Position;
			float2 uv0 : TEXCOORD0;
		};

		UNITY_DECLARE_TEX2D(_MainTex);
		float4 _MainTex_ST;

		float4 _Color;

		float _Threshold;

		V2F vert(MeshData meshData)
		{
			V2F OUT;

			OUT.position = UnityObjectToClipPos(meshData.position);
			OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);

			return OUT;
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
			#pragma fragment depthFrag

			float depthFrag(V2F IN) : SV_Depth
			{
				float cutoff = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0).a * _Color.a;
				clip(cutoff - _Threshold);

				return IN.position.z;
			}
			ENDHLSL
		}
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			float4 frag(V2F IN) : SV_Target
			{
				/*
				 * Alpha tested shaders are particular shaders that render geometry
				 * either fully opaque or fully transparent.
				 * Fully transparent pixels are actually totally discarded.
				 * 
				 * The clip() function takes a numeric parameter and does nothing
				 * if that number is above 0 while discards the pixel if the number
				 * is 0 or below.
				 * 
				 * This avoids depth-related issues such as sorting or effects such
				 * as depth of field or simple triangles'' depth test.
				 */
				float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);
				clip(texColor.a - _Threshold);

				return texColor * _Color;
			}
			ENDHLSL
		}
	}
}
