Shader "LG/02 Lambert"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)
		_Ambient("Ambient Light", Color) = (0.3, 0.3, 0.3)
	}
	SubShader
	{
		HLSLINCLUDE
		#include "UnityCG.cginc"
		ENDHLSL
		Pass
		{
			Name "DepthOnly"
			Tags { "LightMode" = "DepthOnly" }

			ZWrite On
			ColorMask 0

			HLSLPROGRAM
			#pragma vertex depthVert
			#pragma fragment depthFrag

			float4 depthVert(float4 position : POSITION) : SV_Position
			{
				return UnityObjectToClipPos(position);
			}

			float depthFrag(float4 position : SV_Position) : SV_Depth
			{
				return position.z;
			}
			ENDHLSL
		}
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Includes/LightFunc.hlsl"

			struct MeshData
			{
				float4 position : POSITION;
				float3 normal : NORMAL;
				float2 uv0 : TEXCOORD0;
			};

			struct V2F
			{
				float4 position : SV_Position;
				float3 normalWS : NORMAL;
				float2 uv0 : TEXCOORD0;
			};

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _MainTex_ST;

			float4 _Color;

			float4 _Ambient;

			V2F vert(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.normalWS = UnityObjectToWorldNormal(meshData.normal);
				OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);

				return OUT;
			}

			float4 frag(V2F IN) : SV_Target
			{
				float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

				float4 color = texColor * _Color;

				//	The Diffuse() function comes from our own library
				float diffuse = Diffuse(normalize(IN.normalWS));
				/*
				 * Diffues lighting multiplies the surface's color:
				 * 0 light means black, 1 light means full surface color.
				 * 
				 * Ambient is an additional light that adds to the diffuse
				 * to prevent full-black faces and simulate bounce lighting.
				 * 
				 * Adding the ambient in a different pass would make the
				 * final pixel of a brighter gray, but woldn't let the
				 * surface' color pop out.
				 */
				color.rgb *= diffuse.rrr + _Ambient.rgb;

				return color;
			}
			ENDHLSL
		}
	}
}
