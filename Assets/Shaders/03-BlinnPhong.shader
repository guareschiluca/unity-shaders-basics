Shader "LG/03 Phong"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)
		_Ambient("Ambient Light", Color) = (0.3, 0.3, 0.3)

		_SpecularColor("Specular Color", Color) = (1, 1, 1, 0.5)
		[Gamma] _SpecularPower("Specular Sharpness", Range(0.1, 10)) = 5
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
				float3 viewDirWS : TEXCOORD1;
			};

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _MainTex_ST;

			float4 _Color;

			float4 _Ambient;

			float4 _SpecularColor;
			float _SpecularPower;

			V2F vert(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.normalWS = UnityObjectToWorldNormal(meshData.normal);
				OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);

				/*
				 * To calculate the specular reflection later in the fragment program, we need to
				 * calculate the view direction for the vertex, which is basically the normalized
				 * difference between the vertex' position and the camera's position and this is
				 * what the WorldSpaceViewDir() function does.
				 */
				OUT.viewDirWS = WorldSpaceViewDir(meshData.position);

				return OUT;
			}

			float4 frag(V2F IN) : SV_Target
			{
				float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

				float4 color = texColor * _Color;

				float diffuse = Diffuse(normalize(IN.normalWS));

				color.rgb *= diffuse.rrr + _Ambient.rgb;

				//	The Specular() function comes from our own library
				float specularIntensity = Specular(
					normalize(IN.normalWS),
					normalize(IN.viewDirWS),
					_SpecularPower
				);
				specularIntensity *= diffuse;

				/*
				 * Specular is an highlight, additional light coming from the light source and
				 * reflected toward our eyes by the surface.
				 * As an additional light, we're going to add the specular color to the final
				 * pixel's color.
				 */
				color.rgb += _SpecularColor.rgb * _SpecularColor.a * specularIntensity;

				return color;
			}
			ENDHLSL
		}
	}
}
