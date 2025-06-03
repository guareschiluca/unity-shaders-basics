Shader "LG/10 Particles"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }

		ZWrite Off
		Blend One One

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct MeshData
			{
				float4 position : POSITION;
				float2 uv0 : TEXCOORD0;
				float4 color : COLOR;
			};

			struct V2F
			{
				float4 position : SV_Position;
				float2 uv0 : TEXCOORD0;
				float4 color : COLOR0;
			};

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _MainTex_ST;

			V2F vert(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);
				/*
				 * For a matter of performance and to aid instancing, particles do not
				 * pass their color as material property blocks or property overrides,
				 * instead they "burn" their color into the mesh' vertex color.
				 * 
				 * This shader reads the tint from vertex color instead of from a
				 * shader's property.
				 */
				OUT.color = meshData.color;

				return OUT;
			}

			float4 frag(V2F IN) : SV_Target
			{
				float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

				return float4(texColor.rgb * texColor.a * IN.color.rgb * IN.color.a, 1);
			}
			ENDHLSL
		}
	}
}
