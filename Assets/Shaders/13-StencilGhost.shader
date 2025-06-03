Shader "LG/13 Stencil Ghost"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)

		_StencilRef("Stencil Reference", Integer) = 1
	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }

		/*
		 * The stencil buffer is an additional render target with 8-bits depth
		 * that can contain values from in the 0 to 255 range.
		 * This value doesn't directly affect render but can be read to create
		 * effects.
		 * 
		 * Here, for instance, we're checking if the current pixel on the stencil
		 * buffer has a specific value.
		 * 
		 * The Ref sets the reference value to read or write.
		 * The Comp sets the comparison fuction, in this case it passes if the
		 * value on the buffer is the exact same as the reference value.
		 * 
		 * When the Comp fails, the pixel is discarded.
		 */
		Stencil
		{
			Ref [_StencilRef]
			Comp Equal
		}
		
		/*
		 * This is not mandatory, here we're not writing to the Z-buffer since
		 * we plan to use this shader as an additional material hence we don't
		 * want it to interfere with depth.
		 */
		ZWrite Off

		/*
		 * Here we want to render this special pass only when the object is hidden
		 * behind other objects (if any of those write the correct value to the
		 * stencil buffer, as stated above).
		 */
		ZTest Greater
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
