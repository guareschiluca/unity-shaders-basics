Shader "LG/07 Transparent (Fade)"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)
	}
	SubShader
	{
		/*
		 * This time we're moving even later in the render queue as transparent
		 * object, by definition, need to blend with the opaque objects when
		 * they are all ready.
		 * 
		 * Setting the render type to transparent configures the render pipeline
		 * to render this kind of objects.
		 */
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }

		/*
		 * Transparent objects don't usually write on the Z-buffer as they're not
		 * supposed to cover other objects.
		 */
		ZWrite Off

		/*
		 * The Blend command is a powerful command that allows for specific effects
		 * by controlling how much of the current pixel is taken and how it's "stacked"
		 * with the existing one.
		 * 
		 * In this scenario we're taking as much of the current pixel as its alpha
		 * channel requests and we're taking a complementary amount of the existing
		 * pixel.
		 * 
		 */
		Blend SrcAlpha OneMinusSrcAlpha

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
			};

			struct V2F
			{
				float4 position : SV_Position;
				float2 uv0 : TEXCOORD0;
			};

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _MainTex_ST;

			float4 _Color;

			V2F vert(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);

				return OUT;
			}

			float4 frag(V2F IN) : SV_Target
			{
				float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

				return texColor * _Color;
			}
			ENDHLSL
		}
	}
}
