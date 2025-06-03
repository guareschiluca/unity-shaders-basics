Shader "LG/11 Vertex Manipulation"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)

		_Ambient("Abient Color", Color) = (0.1, 0.1, 0.1, 1)

		_SpecCol("Specular Color", Color) = (1, 1, 1, 0.5)
		[Gamma] _SpecSharpness("Specular Sharpness", Range(0.1, 10)) = 5

		[Normal] [NoScaleOffset] _Normal("Normal Map", 2D) = "bump" {}

		_RimCol("Rim Color", Color) = (1, 1, 1, 0.5)
		[Gamma] _RimSharpness("Rim Sharpness", Range(0.1, 10)) = 2

		[Toggle(DO_RIM)] _DoRim("Do Rim", Float) = 1

		_Waves("Waves: Main Length (X), Main Height (Y), Secondary Length (Z), Secondary Height (W)", Vector) = (5, 0.2, 0.5, 0.1)

		_TexturePanSpeed("Pan Speed", Vector) = (0.05, 0.005, 0, 0)

		_NormalReconstructOffset("Normal Reconstruction Offset", Float) = 0.5
		[Toggle(ENF_ORTHO)] _EnforceOrthonormality("Safeguard Normal Recalc", Float) = 1
	}
	HLSLINCLUDE
	#include "UnityCG.cginc"

	#include "Includes/WaterMass.hlsl"

	struct MeshData
	{
		float4 position : POSITION;
		float2 uv0 : TEXCOORD0;
		float3 normal : NORMAL;
	};
	struct V2F
	{
		float4 position : POSITION;
		float2 uv0 : TEXCOORD0;
		float3 viewDirWS : TEXCOORD1;
		float3 normalWS : NORMAL;
		float3 tangentWS : COLOR0;
		float3 binormalWS : COLOR1;
	};
	
	UNITY_DECLARE_TEX2D(_MainTex);
	float4 _MainTex_ST;

	float _NormalReconstructOffset;

	float4 _TexturePanSpeed;

	float4 _Waves;

	V2F vert(MeshData meshData)
	{
		V2F OUT;

		//	Displace the vertex according
		float4 positionWS = mul(unity_ObjectToWorld, meshData.position);
		positionWS.y += GetWaveDisplacementAtPointFromPacked(positionWS, _Waves, _Time);

		//	Recompute normal
		GetWaveSpaceAtPointFromPacked(
			positionWS,
			_Waves, _Time,
			_NormalReconstructOffset,
			OUT.tangentWS, OUT.binormalWS, OUT.normalWS
		);
		#ifdef ENF_ORTHO
		//...	Enforce the resulting TBN space as orthonormal
		OUT.binormalWS = normalize(cross(OUT.tangentWS, OUT.normalWS));
		#endif

		//	Calculate world space UV coordinates
		OUT.uv0 = positionWS.xz / _MainTex_ST.xy + _MainTex_ST.zw;
		//...	Apply panning
		OUT.uv0 += _Time.ww * _TexturePanSpeed.xy;

		//	Convert world space position to object space
		float4 positionOS = mul(unity_WorldToObject, positionWS);

		//	Convert object space position to clip space
		OUT.position = UnityObjectToClipPos(positionOS);

		//	Calculate the view direction
		OUT.viewDirWS = WorldSpaceViewDir(positionOS);

		return OUT;
	}
	ENDHLSL
	SubShader
	{
		Pass
		{
			Name "DepthOnly"
			Tags { "LightMode"="DepthOnly" }

			ZWrite On
			ColorMask 0

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment depthFrag

			float depthFrag(V2F IN) : SV_Depth
			{
				return IN.position.z;
			}
			ENDHLSL
		}
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile _ DO_RIM
			#pragma multi_compile __ ENF_ORTHO

			#include "Includes/LightFunc.hlsl"

			float4 _Color;
			float4 _Ambient;
			UNITY_DECLARE_TEX2D(_Normal);

			float4 _SpecCol;
			float _SpecSharpness;

			float4 _RimCol;
			float _RimSharpness;

			float4 frag(V2F IN) : SV_Target
			{
				//	Build the tangent space to world space transformation matrix
				float3x3 TBN = 
					transpose(
						float3x3(
						normalize(IN.tangentWS),
						normalize(IN.binormalWS),
						normalize(IN.normalWS)
					)
				);

				//	Read and unpack the normal map
				float3 normalMap = UnpackNormal(UNITY_SAMPLE_TEX2D(_Normal, IN.uv0));

				//	Convert normal map from tangent space to world space
				float3 normal = normalize(mul(TBN, normalMap));

				//	Read texture color
				float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

				float4 color = texColor;

				//	Apply tint
				color *= _Color;

				//	Apply diffuse lighting
				float diffuse = Diffuse(normal);
				color.rgb *= _Ambient.rgb + diffuse.rrr;

				//	Apply specular highlight
				float specularIntensity = Specular(
					normal,
					normalize(IN.viewDirWS),
					_SpecSharpness
				);
				specularIntensity *= diffuse;
				float3 specularColor = _SpecCol.rgb * specularIntensity * _SpecCol.a;
				color.rgb += specularColor;

				#ifdef DO_RIM
				//	Apply rim light
				float rimIntensity = 1 - saturate(dot(IN.viewDirWS, normal));
				rimIntensity = pow(rimIntensity, _RimSharpness);

				color.rgb += _RimCol.rgb * _RimCol.a * rimIntensity;
				#endif

				//	Return final color
				return color;
			}
			ENDHLSL
		}
	}
}
