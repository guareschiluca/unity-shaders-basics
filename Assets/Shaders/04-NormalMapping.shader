Shader "LG/04 Normal Mapped"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)

		[Normal] [NoScaleOffset] _Bump("Normal Map", 2D) = "bump" {}

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

			V2F vert(MeshData meshData)
			{
				V2F OUT;

				/*
				 * This one is tricky but pretty easy once understood.
				 * 
				 * First, we need to understand what a normal map is: a texture where pixels
				 * do not represent colors but direction vectors in tangent space.
				 * The strength of the normal map, against the vertex normals, is that pixels
				 * are much more dense than vertices, allowing for more detail in lighting.
				 * 
				 * Up to now we only calculated the light as a function of the light direction
				 * and the interpolated world-space vertex normal. What we want to do now is
				 * to use a new world space vector with higher density than vertices.
				 * 
				 * To do so we need to transform the information from the normal map from its
				 * tangent space to world space, and this is done by defining the tangent space,
				 * using it later to transform tangent-space vectors to world space.
				 * 
				 * To do so we need to create an orthonormal space, a space made of 3 normal
				 * (1-sized) vectors that are orthogonal to each other.
				 * The mesh gives us two of them: the normal and the tangent. We need to get
				 * the binormal as the cross product between the tangent and the normal vectors.
				 * The tangent passed by the geometry stores in the w component a correction
				 * value that determines the sign or direction of the cross product.
				 */
				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.normalWS = UnityObjectToWorldNormal(meshData.normal);
				OUT.tangentWS = UnityObjectToWorldDir(meshData.tangent);
				OUT.binormalWS = cross(OUT.tangentWS, OUT.normalWS) * meshData.tangent.w;

				OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);
				OUT.viewDirWS = WorldSpaceViewDir(meshData.position);

				return OUT;
			}

			float4 frag(V2F IN) : SV_Target
			{
				/*
				 * Now that we have the interpolated tangent space we can create the transformation
				 * matrix as a matrix where columns are the orthonormal space' vectors.
				 * 
				 * Since we need to transform a direction, not a position, we'll use a 3x3 matrix.
				 * Since the flaot3x3 constructor lays out the 3 input vectors as rows, not columns,
				 * we need to get the transposed matrix (rows become columns).
				 * 
				 * As an alternative, we can use the explicit constructor and place all the components
				 * at the right place from the beginning, skipping the transpose oeration, but this
				 * would become really verbose and wouldn't aid comprehension in this scenario.
				 * 
				 * This TBN matrix will allow us soon to transform tangent-space direction vectors
				 * to world-space direction vectors that light functions can use.
				 */
				float3x3 TBN = transpose(
					float3x3(
						normalize(IN.tangentWS),
						normalize(IN.binormalWS),
						normalize(IN.normalWS)
					)
				);
				/*
				 * Normal map is packed, meaning that in a texure R, G and B channels have values in the
				 * 0 to 1 range, but as vectors we expect valuee in the -1 to 1 range.
				 * 
				 * The UnpackNormal function does exactly this: transforms the packed-into-color vector
				 * into a real vector.
				 * 
				 * The unpacked vector is in tangent space so we multiply it by the transformation matrix
				 * to obtain the world-space vector representing the facing of this specific pixel.
				 * 
				 * We'll pass this, instead of the vertex' normal to every lighting calculation.
				 */
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

				return color;
			}
			ENDHLSL
		}
	}
}
