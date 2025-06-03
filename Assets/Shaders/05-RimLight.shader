Shader "LG/05 Rim Light"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)

		[Normal] [NoScaleOffset] _Bump("Normal Map", 2D) = "bump" {}

		_Ambient("Ambient Light", Color) = (0.3, 0.3, 0.3)

		_SpecularColor("Specular Color", Color) = (1, 1, 1, 0.5)
		[Gamma] _SpecularPower("Specular Sharpness", Range(0.1, 10)) = 5

		_RimColor("Rim Color", Color) = (1, 1, 1, 0.5)
		[Gamma] _RimPower("Rim Sharpness", Range(0.1, 10)) = 2
		[Toggle(PIVOT_VIEW_DIR)] _PivotViewDir("Use Pivot for View Direction", Float) = 0
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

			/*
			 * When we declare properties with the [Toggle(CONSTANT)] attribute, we can compile
			 * the shader in multiple variants and then use precompiler directives to execute
			 * different code based on the variant.
			 * 
			 * Variants are lighter than runtime checks as they're totally different shaders
			 * with only the strict necessary code for their purpose, but they come at a cost.
			 * 
			 * First, a shader cannot have infinite variants. Secondly, shader variants affect
			 * shaders compile time and shaders loading time.
			 */
			#pragma multi_compile _ PIVOT_VIEW_DIR

			#include "Includes/LightFunc.hlsl"

			struct MeshData
			{
				float4 position : POSITION;
				float3 normal : NORMAL;
				float4 tangent : tangent;
				float2 uv0 : TEXCOORD0;
			};

			struct V2F
			{
				float4 position : SV_Position;
				float3 normalWS : NORMAL;
				float3 tangentWS : COLOR0;
				float3 binormalWS : COLOR1;
				float2 uv0 : TEXCOORD0;
				float3 viewDirWS : TEXCOORD1;
			};

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _MainTex_ST;

			float4 _Color;

			UNITY_DECLARE_TEX2D(_Bump);

			float4 _Ambient;

			float4 _SpecularColor;
			float _SpecularPower;

			float4 _RimColor;
			float _RimPower;

			V2F vert(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.normalWS = UnityObjectToWorldNormal(meshData.normal);
				OUT.tangentWS = UnityObjectToWorldDir(meshData.tangent);
				OUT.binormalWS = cross(OUT.tangentWS, OUT.normalWS) * meshData.tangent.w;

				OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);	//	Expands to (meshData.uv0 * _MainTex_ST.xy + _MainTex_ST.zw)

				/*
				 * Rim light can look better or worse if calculated based on the pixel's position or
				 * based on the pivot's position depending on the distance and angle we're looking at
				 * the object as well as how the object was made.
				 * 
				 * Here we support both the alternatives.
				 */
				#ifdef PIVOT_VIEW_DIR
				OUT.viewDirWS = WorldSpaceViewDir(float4(0, 0, 0, 1));
				#else
				OUT.viewDirWS = WorldSpaceViewDir(meshData.position);
				#endif

				return OUT;
			}

			float4 frag(V2F IN) : SV_Target
			{
				float3x3 TBN = transpose(
					float3x3(
						normalize(IN.tangentWS),
						normalize(IN.binormalWS),
						normalize(IN.normalWS)
					)
				);
				float3 normalMap = UnpackNormal(UNITY_SAMPLE_TEX2D(_Bump, IN.uv0));
				float3 normal = mul(TBN, normalMap);

				float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

				float4 color = texColor * _Color;

				float diffuse = Diffuse(normalize(normal));

				color.rgb *= diffuse.rrr + _Ambient.rgb;

				float specularIntensity = Specular(
					normalize(normal),
					normalize(IN.viewDirWS),
					_SpecularPower
				);
				specularIntensity *= diffuse;

				color.rgb += _SpecularColor.rgb * _SpecularColor.a * specularIntensity;

				/*
				 * Rim light is a simple but useful effect. It basically calculates the incidence
				 * between the interpolated vertex normal and the view direction, creating a sort
				 * of smooth outline, like a back light, to the edges of a rounded geometry.
				 * 
				 * It's often used to detach object from the background in dark environments or to
				 * create stylized effects.
				 */
				float rimIntensity = pow(
					1 -
					saturate(
						dot(
							normal,
							IN.viewDirWS
						)
					),
					_RimPower
				);
				color.rgb += _RimColor.rgb * _RimColor.a * rimIntensity;

				return color;
			}
			ENDHLSL
		}
	}
}
