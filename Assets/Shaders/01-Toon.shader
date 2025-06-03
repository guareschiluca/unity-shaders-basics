Shader "LG/01 Toon"
{
	Properties
	{
		[NoScaleOffset] _MainTex("Main Texture", 2D) = "white" {}

		[NoScaleOffset] _ShadeRampTex("Shade Ramp Texture", 2D) = "white" {}

		_OutlineSize("Outline Size", Float) = 0.001
		_OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
	}
	SubShader
	{
		/*
		 * For this toon shader we're taking a "smart" approach when it comes
		 * to the outline effect: we just render the geometry backwards and
		 * with an offset along the vertex normal. The problem here is that
		 * this requires two different passes to render the geometry and URP
		 * doesn't support multiple render passes so we need to find a way
		 * to write passes for both render pipelines without duplicating
		 * code.
		 * We'll need:
		 * - URP depth pass
		 * - URP render pass (same as built-in RP render pass but in a different place)
		 * - Built-in RP outline pass
		 * - Built-in RP render pass
		 * 
		 * The first two will be ignored by the built-in RP, which will render
		 * the last two. URP will render the depth pass explicitly and then will
		 * render only the first compatible render pass, which is the URP render
		 * pass.
		 * 
		 * The URP version won't have the fake outline. To achieve this we'd
		 * either need a second material or a post processing effect.
		 * 
		 * We'll write most of our shader within the HLSLINCLUDE block so the
		 * passes just need to inform the GPU which program names to run via the
		 * #pragma directives.
		 */
		HLSLINCLUDE
		#include "UnityCG.cginc"

		/*
		 * Here we're including our own library containing code we plan to use
		 * in different scenarios. That's a good chance to make re-usable and
		 * maintained-only-once code that we can even share between different
		 * projects.
		 */
		#include "Includes/LightFunc.hlsl"

		struct MeshData
		{
			float4 position : POSITION;
			float2 uv0 : TEXCOORD0;
			float3 normal : NORMAL;
		};

		struct V2F
		{
			float4 position : SV_Position;
			float2 uv0 : TEXCOORD0;
			float3 normalWS : NORMAL;
		};

		UNITY_DECLARE_TEX2D(_MainTex);

		UNITY_DECLARE_TEX2D(_ShadeRampTex);

		/*
		 * The toonVert() and toonFrag() programs will contribute in rendering the
		 * final pixel for the geometry's color. Here we're taking the directional
		 * light source to calculate the incidence relative to the surface' normal
		 * and use the incidence as the horizontal UV of a shade ramp texture.
		 */
		V2F toonVert(MeshData meshData)
		{
			V2F OUT;

			OUT.position = UnityObjectToClipPos(meshData.position);
			OUT.uv0 = meshData.uv0;
			OUT.normalWS = UnityObjectToWorldNormal(meshData.normal);

			return OUT;
		}

		float4 toonFrag(V2F IN) : SV_Target
		{
			float4 texColor = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv0);

			/*
			 * The Fresnel() function comes from our library and returns a number
			 * between -1 and 1. -1 represents a pixel fafcing off of the main light,
			 * 1 represents a pixel directly facing the main light, 0 represents a
			 * pixel exactly 90° away from the main light.
			 */
			float lightIncidence = Fresnel(
				normalize(IN.normalWS) // Inter-vertex interpolation may significanlty change normal's magnitude
			);

			float shade = UNITY_SAMPLE_TEX2D(_ShadeRampTex, float2(lightIncidence * 0.5 + 0.5, 0.25)).r;

			texColor.rgb *= shade;

			return texColor;
		}
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
			Tags { "RenderPipeline" = "UniversalPipeline" }

			HLSLPROGRAM
			#pragma vertex toonVert
			#pragma fragment toonFrag
			ENDHLSL
		}
		Pass
		{
			/*
			 * The Cull command tells the GPU which side of a triangle to discard.
			 * The default Cull Back discards the triangle's back face, Cull Off
			 * renders both the front and the back face of a triangle. Here we use
			 * Cull Front to only render back faces. This will render the geometry
			 * from the inside; this plus the vertex displacement create a fake
			 * outline effect.
			 */
			Cull Front

			HLSLPROGRAM
			#pragma vertex outlineVert
			#pragma fragment outlineFrag

			float _OutlineSize;
			float4 _OutlineColor;

			/*
			 * The outlineVert() and outlineFrag() programs are really simple.
			 * The vertex program moves the vertices out along the vertex normal to
			 * make the geometry pop out of the main geometry.
			 * 
			 * The fragment program just draws a solid color.
			 */
			float4 outlineVert(float4 position : POSITION, float3 normal : NORMAL) : SV_Position
			{
				return UnityObjectToClipPos(position + normal * _OutlineSize);
			}

			float4 outlineFrag(float4 position : SV_Position) : SV_Target
			{
				return _OutlineColor;
			}
			ENDHLSL
		}
		Pass
		{
			HLSLPROGRAM
			#pragma vertex toonVert
			#pragma fragment toonFrag
			ENDHLSL
		}
	}
}
