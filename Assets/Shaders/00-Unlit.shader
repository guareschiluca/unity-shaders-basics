Shader "LG/00 Unlit"
{
	/*
	 * The Properties block exposes both to materials and to c# code
	 * all the parameters we want to be able to change, per-material
	 * or at runtime.
	 */
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1, 1, 1, 1)
	}
	/*
	 * A SubShader is a variant of the current shader. You can have
	 * only one, like in this case, or multiple SubShaders, where
	 * usually each targets a different hardware tier.
	 */
	SubShader
	{
		/*
		 * HLSLINCLUDE blocks are code blocks which are shared among
		 * all the HLSLPROGRAM blocks in the same scope, meaning that
		 * creating an HLSLINCLUDE in a SubShader block, its contents
		 * will be shared by all HLSLPROGRAM blocks in the same
		 * SubShader.
		 */
		HLSLINCLUDE
		#include "UnityCG.cginc"
		ENDHLSL
		/*
		 * Pass blocks are where the real execution happens. They can
		 * be many, each with a different purpose, but it's important
		 * to remember that multi-pass is not allowed on every render
		 * pipeline: URP, for instance, supports only one "regular"
		 * pass.
		 * 
		 * I said "regular" referring to the passes that produce a
		 * pixel color, so the actual render, but passes may have spacial
		 * purposes and special passes are ignored during rendering,
		 * instead they're explicitly executed by the render pipeline
		 * itself or by effects.
		 * 
		 * In this trivial example we have the first pass which renders
		 * the depth to the depth buffer for the URP. Its tags make so
		 * that the renrer pipelines that don't explicitly look for it
		 * will ignore it (like the built-in RP), but adds full support
		 * for URP.
		 * 
		 * The second pass, instead, is the render pass, which computes
		 * the final color for each pixel. This pass is shared between
		 * the different render pipelines, being a render pass.
		 */
		Pass
		{
			/*
			 * This is the depth-compatibility pass for URP.
			 * Most of the opaque shaders will need this simple pass.
			 * 
			 * I'm not commenting this pass as it will become clear
			 * automatically as we proceed with exploring shaders and
			 * their features.
			 */
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
			/*
			 * Shaders in Unity can be written via the ShaderLab language,
			 * which is the same that we're using to define the building
			 * blocks such as Shader, Properties, SubShader, Pass...
			 * It also includes commands to trigger a full render, but
			 * they're pretty much limiting and a very old way to write
			 * shaders.
			 * 
			 * The "correct" way to write shaders are code blocks.
			 * Code blocks can be written in two languages, the legacy CG,				//	C for Graphics
			 * which is not supported by the scriptable render pipelines such
			 * as URP or HDRP because it automatically includes incompatible
			 * code made for the old built-in RP, and the more modern HLSL				//	High Level Shader Language
			 * which is 100% compatible with scriptable render pipelines as
			 * it allows us to decide what to import, preventing compile
			 * errors.
			 * 
			 * To be 100% compatible and future-proof, we don't even deal
			 * with CG, even if it's so much similar that you couldn't tell
			 * which one is if you read them out of the context.
			 */
			HLSLPROGRAM
			/*
			 * A shader is made of two main programs, one to process vertices
			 * and one to process pixels (fragments).
			 * The first thing we need to do is to tell the GPU the names of
			 * these two programs, the vertex program and the fragment program.
			 */
			#pragma vertex vert
			#pragma fragment frag

			/*
			 * Here we can include any support library we need. We're no doing
			 * so now because we already included Unity's main library in the
			 * HLSLINCLUDE block above that, as we know, is shared with all the
			 * HLSLPROGRAM blocks in the same scope, including this.
			 */
			//#include "..."

			/*
			 * Here we need to define exchagne data structures. We'll use them
			 * to read data from the geometry from the vertex program and then
			 * pass parsed and processed data from the vertex program to the
			 * fragment program.
			 * 
			 * Of course fragments and vertices do not have a 1:1 ratio. The
			 * vertex program is called once per vertex, then the fragment is
			 * called once per pixel. Each pixel belongs to a triangle of the
			 * geometry, each triangle lies on 3 vertices and the pixel on the
			 * triangle's surface has a certain distance from the vertices.
			 * These distances are used to interpolate the data passed by the
			 * vertex program for the 3 vertices of the current triangle and
			 * pass to the fragment shader an interpolated information that
			 * represents that exact position in 3D space, allowing for a
			 * higher density than the mere vertices.
			 * 
			 * This interpolation is linear, and we need to keep this in mind
			 * when we pass vectors from vertex to fragment, as their magnitude
			 * will likely change!
			 * 
			 * The names of the fields we declare are arbitrary, the GPU knows
			 * how to fill them thanks to semantics, specified aside each field
			 * we want to expose. Semantics are fixed and have a direct meaning
			 * for the input of the vertex program, while for the input of the
			 * fragment program the only real mandatory and explicit-purpose
			 * semantic is SV_Position that must contain the clip (screen) space
			 * position of a vertex. Other semantics for the fragment program's
			 * input are general purpose.
			 * You can see semantics as a set of named hardware containers for
			 * data, which are used by the GPU when passing data from the mesh
			 * to the vertex program, but we can use at our own will when we
			 * prepare data for the fragment program.
			 */
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

			
			/*
			 * Here we're declaring shader variables. They can be general purpose
			 * variables, or they can represents the properties we declared in the
			 * Properties block. We need to declare variables of a compatible type
			 * for each declared property we need to use within our code block.
			 * Types are mostly straightforward with one exception which are
			 * textures: they are handled differently based on the graphics API.
			 * DirectX 9 and older did use a combined texture+sampler type, while
			 * DirectX 10 and later use separate texture object and sampler object.
			 * To write fully compatible and also easier to write shader code, we
			 * leverage two macros: UNITY_DECLARE_TEX2D for texture declaration and
			 * UNITY_SAMPLE_TEX2D for texture sampling, which already take care of
			 * API differences.
			 * 
			 * Down here we have one variable which doesn't correspond to any
			 * property we declared: _MainTex_ST. This is an example of variable set
			 * via code, in this case by Uinty itself. Variables named after a texture's
			 * name followed by _ST (stands for Scale/Translate) are filled by unity
			 * with the tiling and offset information from the material editor for
			 * that specific texture.
			 */
			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _MainTex_ST;

			float4 _Color;

			/*
			 * Finally, we have our vertex and fragment programs, which names we
			 * communicated to the GPU with the initial #pragma directives.
			 * 
			 * The main thing to note here is about the fragment shader. It is the
			 * one responsible for calculating the final color of a pixel, hence
			 * the float4 return value (R, G, B, A). For more advanced purposes,
			 * an example is the depth pass above, the fragment can return things
			 * different from a mere color. The fragment must inform the GPU where
			 * to write its return value: SV_Target represents the main render
			 * target, so the screen or the current render texture.
			 */
			V2F vert(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);	//	This is actually a matrix multiplicaiton of the object-space vertex position to transform it to screen-space
				OUT.uv0 = TRANSFORM_TEX(meshData.uv0, _MainTex);	//	Expands to (meshData.uv0 * _MainTex_ST.xy + _MainTex_ST.zw)

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
