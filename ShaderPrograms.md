# Shader Programs

`CG` and `HLSL` are the two languages used to write shaders in Unity.

Originally, Unity worked with the `CG` language.  
Today, `CG` is supported only by the built-in render pipeline since `CGPROGRAM`s automatically include code that is not compatible with URP, HDRP, or any custom pipeline based on SRP Core.

Conversely, `HLSL` supports the full range of Unity's render pipelines, from built-in to URP and HDRP, as well as custom render pipelines—whether based on SRP Core or not.

For compatibility and future-proofing, we will write our shaders in `HLSL`.

## HLSL

`HLSL` isn't a language created for Unity. The name stands for `High Level Shader Language`, and it's Microsoft's creation.

For the full documentation, refer to Microsoft's website:

- [Learn website](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl)
- [Programming guide](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-pguide)
- [Reference](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-reference)

### Numeric Data Types

Scalar data types:

- `bool`
- `int` (32-bit, signed)
- `uint` (32-bit, unsigned)
- `dword` (32-bit, unsigned)
- `half` (16-bit, floating point) *(language compatibility type)*
- `float` (32-bit, floating point)
- `double` (64-bit, floating point) *(limited support)*

Vector data types are obtained adding a trailing number to the type:

- `int2`
- `int3`
- `int4`
- `float2`
- `float3`
- `float4`
- ...

Vector are used to store both mathematical values and color values.  
Components can be accessed using both mathematical components or color components, in any combination:

```c
float4 vector = float4(0.1f, 0.2f, 0.3f, 0.4f);

vector.x	//	value is 0.1f
vector.y	//	value is 0.2f
vector.z	//	value is 0.3f
vector.w	//	value is 0.4f
vector.r	//	value is 0.1f
vector.g	//	value is 0.2f
vector.b	//	value is 0.3f
vector.a	//	value is 0.4f
vector.xyz	//	value is { 0.1f, 0.2f, 0.3f }
vector.rgb	//	value is { 0.1f, 0.2f, 0.3f }
vector.xz	//	value is { 0.1f, 0.3f }
vector.rb	//	value is { 0.1f, 0.3f }
vector.yy	//	value is { 0.2f, 0.2f }
vector.gg	//	value is { 0.2f, 0.2f }
vector.yg	//	NOT ALLOWED, cannot mix color component with math components
```

Matrix data types are obtained by adding the matrix size as a trailing `ROWSxCOLS` to the type:

- `int2x3`
- `int4x4`
- `float3x3`
- `float4x4`
- ...

### Texture Data Types

When it comes to textures, things get slightly more complicated. `HLSL` has different syntax (and to be true a different approach) between `DirectX9` and `DirectX10`.  
In `DX9`, `HLSL` kept the concept of 2D sampler and 2D texture as a unique object, matching the previous `CG` approach.  
In `DX10`, `HLSL` separated the concept of 2D texture and sampler into two different object, changing therefore the way to sample a texture.

> [!TIP]
> By **sampling** a texture, we mean retrieving the color from a texture at given normalized coordinates.  
> This involves mapping the normalized coordinates to pixel coordinates and applying filtering to extract the correct color in non 1:1 contexts.

#### Texture Data - The Unity Way

For a matter of compatibility, as well as for ease of writing, Unity implements two macros which help quickly declaring and sampling textures.

To declare a texture property in a "cross-syntax" way, we use the macro `UNITY_DECLARE_TEX2D(_TexturePropertyName)`.  
Then we sample the color from the texture by `float4 color = UNITY_SAMPLE_TEX2D(_TexturePropertyName, IN.uv)`.

### Variables in a Unity Shader

In a Unity shader, variables can be (and are) defined in different placed, by different parties.

#### Local Scoped Variables

The most basic usage of the aforementioned data types is inside functions. When we need to work with data, we declare a variable of a given type and we assign to and read from it as we would in any other programming language.

```c
float4 myFunc()
{
	float4 col = float4(0.5, 0.5, 0.5, 1);

	col += float4(-0.25, 0.0, 0.5, -0.1);

	return col;
}
```

#### Shader Scoped Variables

Another very common use of variables is to define them outside our functions. In this case, in Unity, variables are used to capture information passed by other parties.

The most straightforward example are shader properties: when we declare a shader property, if we want to access it within a code block, we need to declare a variable with the same name and a matching data type inside the code block, before we access it for the first time.  
Variables declared this way are treated as read-only.  
Their value is set by Unity, taking it from the material properties.

Variables declared inside a code block, outside any function, are scoped for all the code block, hence they're accessible inside all the functions declared in that code block.

```c
Shader "My Shaders/My Shader"
{
	Properties
	{
		_Color("Tint", Color) = (1, 1, 1, 1)
	}
	SubShader
	{
		Pass
		{
			HLSLPROGRAM
			//...
			float4 _Color;

			float4 frag(V2F IN) : SV_Target
			{
				return _Color;
			}
			ENDHLSL
		}
	}
}
```

#### Global Scoped Variables

Similar to the [Shader Variables](#shader-scoped-variables), since they're declared within a code block and outside any function, their value doesn't come from material properties but they can be set via C# code, and their value is not bound to the material instance but it's shared between all shaders.

Here are two almost identical shaders, both reading from a declared but never initialized variable called `_AtmosphereColor`.

```c
Shader "My Shaders/My Shader Multiply"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
	}
	SubShader
	{
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct MeshData { float4 position : POSITION; float2 uv : TEXCOORD0; };
			struct V2F { float4 position : POSITION; float2 uv : TEXCOORD0; };

			V2F frag(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.uv = meshData.uv;

				return V2F;
			}

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _AtmosphereColor;

			float4 frag(V2F IN) : SV_Target
			{
				float4 col = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv);

				col *= _AtmosphereColor;	//	<--	Only difference here

				return col;
			}
			ENDHLSL
		}
	}
}
Shader "My Shaders/My Shader Add"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "white" {}
	}
	SubShader
	{
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			struct MeshData { float4 position : POSITION; float2 uv : TEXCOORD0; };
			struct V2F { float4 position : POSITION; float2 uv : TEXCOORD0; };

			V2F frag(MeshData meshData)
			{
				V2F OUT;

				OUT.position = UnityObjectToClipPos(meshData.position);
				OUT.uv = meshData.uv;

				return V2F;
			}

			UNITY_DECLARE_TEX2D(_MainTex);
			float4 _AtmosphereColor;

			float4 frag(V2F IN) : SV_Target
			{
				float4 col = UNITY_SAMPLE_TEX2D(_MainTex, IN.uv);

				col += _AtmosphereColor;	//	<--	Only difference here

				return col;
			}
			ENDHLSL
		}
	}
}
```

The `_AtmosphereColor` variable's value can be set using the [Shader API](https://docs.unity3d.com/ScriptReference/30_search.html?q=Shader.SetGlobal).

```csharp
using UnityEngine;

public class SetGlobalFloatExample : MonoBehaviour
{
    void Start()
    {
        Shader.SetGlobalFloat("_AtmosphereColor", Random.ColorHSV());
    }
}
```

#### Unity Defined Variables

Their definition is the same as [Shader Scoped Variables](#shader-scoped-variables) and [Global Scoped Variables](#global-scoped-variables), within a code block but outside of any function.  
Their value is set via code, as for [Global Scoped Variables](#global-scoped-variables), but this time this doesn't happen in user code, instead it's the engine itself which sets their value.

See [Built-In Shader Variables](#built-in-shader-variables) for more details.

### Useful Functions

`HLSL` offers a large set of built-in functions useful to make math operations in a shader. A [full list of those function](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-intrinsic-functions), along with documentation, can be found on Microsoft's website.

Follows a selection of **most common functions**.

Numeric operations:

- `lerp(x, y, s)`: interpolates from `x` to `y`, based on an `s` float value between 0 and 1 (not clamped)
- `abs(x)`: calculates the absolute value of `x`
- `min(x, y)`: return the minimum value between `x` and `y`
- `max(x, y)`: return the maximum value between `x` and `y`
- `pow(x, y)`: elevates `x` to the power of `y`
- `sqrt(x)`: finds the squared root of `x`
- `round(x)`: rounds `x` to the nearest integer value
- `floor(x)`: rounds `x` to the nearest integer value less than or equal to `x`
- `ceil(x)`: rounds `x` to the nearest integer value greater than or equal to `x`
- `fmod(x, y)`: calculates the floating point remainder of the division `x`/`y`

Trigonometric operations:

- `sin(x)`: calculates the sine of the angle `x` (in radians)
- `cos(x)`: calculates the cosine of the angle `x` (in radians)
- `tan(x)`: calculates the tangent of the angle `x` (in radians)
- `asin(x)`: calculates the arc-sine of the angle `x` (in radians)
- `acos(x)`: calculates the arc-cosine of the angle `x` (in radians)
- `atan(x)`: calculates the arc-tangent of the angle `x` (in radians)
- `sincos(x, out s, out c)`: calculates the sine and the cosine of the angle `x` (in radians) and puts the results respectively into `s` and `c`

Vector operations:

- `dot(x, y)`: calculates the scalar product between the two vectors `x` and `y`
- `cross(x, y)`: calculates the vector product between the two 3D vectors `x` and `y`
- `length(x)`: calculates the magnitude of the `x` vector
- `dst(x, y)`: calculates the distance vector between the two vectors `x` and `y`
- `normalize(x)`: returns the `x` vector normalized

Conversion operations:

- `radians(x)`: converts the `x` angle from degrees to radians
- `degrees(x)`: converts the `x` angle from radians to degrees

### Semantics

HLSL doesn't use reserved names to identify what a value is for. Instead, semantics are used to clarify the purpose of a value. This purpose is usually referred to as *"intent"*.

Vertex and fragment shaders use dedicated semantics.

#### Vertex Shader Input Semantics

Vertex shader take mesh data as input and manipulates that data to serve to the fragment shader.  
For this reason, all input variables for a vertex shader need to have semantics.

All mesh date fed as inputs to the vertex shader are to be considered in object space.

| **Semantic** | **Data Type** | **What represents** |
| --- | --- | --- |
| `POSITION` | `float3` or `float4` | the vertex position |
| `NORMAL` | `float3` | the vertex normal vector |
| `TANGENT` | `float4` | the vertex tangent vector. The `w` component represents the sign. |
| `TEXCOORD0` | `float2` | teh UV coordinate on the first UV channel |
| `TEXCOORD1` | `float2` | teh UV coordinate on the second UV channel |
| `TEXCOORD2` | `float2` | teh UV coordinate on the third UV channel |
| `TEXCOORD3` | `float2` | teh UV coordinate on the fourth UV channel |
| `TANGENT` | `float4` | tangent vector (used for normal mapping) |
| `COLOR` | `float4` | per-vertex |

#### Vertex Shader Output Semantics

As mentioned above, the vertex shader has the purpose to provide useful data to the fragment shader.  
This is done via a data structure containing the data produced by the vertex shader, that will be then used by the fragment shader.

Also these data need semantics.

| **Semantic** | **Data Type** | **What represents** |
| --- | --- | --- |
| `POSITION` | `float4` | **MANDATORY** Represents the clip space position, the position on screen |
| `NORMAL` | `float4` | General purpose |
| `TEXCOOORD0` | `float2` or `float3` or `float4` | General purpose |
| `TEXCOOORD1` | `float2` or `float3` or `float4` | General purpose |
| `TEXCOOORD2` | `float2` or `float3` or `float4` | General purpose |
| `TEXCOOORD3` | `float2` or `float3` or `float4` | General purpose |
| `COLOR0` | `float4` | General purpose |
| `COLOR1` | `float4` | General purpose |

#### Fragment Shader Output Semantics

The fragment shader itself returns a color value and that value needs a semantic too.

> [!TIP]
> Fragment shader can return 3 different data types:
> - `float4`, representing a color, usually the final render image.
> - `float`, representing a distance, the depth.
> - `struct`, containing variables of one of the above types, each with a specific semantic.

> [!CAUTION]
> Writing to depth buffer or other render targets requires a deep understanding of the render process and of the active render path.

| **Semantic** | **Data Type** | **What represents** |
| --- | --- | --- |
| `SV_Target` | `float4` | the fragment shader is writing to the main render target |
| `SV_TargetN` | `float4` | the fragment shader is writing to the Nth render target, where N is anything between `0` an `7`. `SV_Target0` is the exact same as `SV_Target` |
| `SV_Depth` | `float` | the fragment shader is writing to the depth buffer |

## Unity Helpers

Unity provides a lot of helpers that ease and quicken the writing of shaders.

Those utilities are enclosed in include files, as described in Unity's documentation for [built-in shader include files](https://docs.unity3d.com/Manual/SL-BuiltinIncludes.html).

Usually, our shader program will start with the following line, right after the `#pragma` directives:

```c
#include "UnityCG.cginc"
```

> [!TIP]
> Somebody may have noticed that both the file name and the extension refer to the `CG` language, even if we're writing our shader with `HLSL`.  
> This is just a legacy terminology coming from the former language, kept for compatibility, but it's still correct to include it into `HLSL` shaders.  
> When we make our own include files for `HLSL`, use the `.hlsl` file extension.

### [Built-In Shader Variables](https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html)

Unity provides a huge amount of shader variables, for the full list refer to the documentation.  
Here we'll go over a few common and useful variables.

#### Time Variables

| **Name** | **Data Type** | **What represents** |
| --- | --- | --- |
| `_Time` | `float4` | Time since level load (t/20, t, t*2, t*3) |
| `_SinTime` | `float4` | Sine of time: (t/8, t/4, t/2, t) |
| `_CosTime` | `float4` | Cosine of time: (t/8, t/4, t/2, t) |
| `unity_DeltaTime` | `float4` | Delta time: (dt, 1/dt, smoothDt, 1/smoothDt) |
| `_WorldSpaceLightPos0` | `float4` | World space position of a light. For directional lights, world space direction. |
| `_LightColor0` | `float4` | Light color |

> [!TIP]
> All the time variables are vectors which contain the value itself in one component and common functions of that value in the other components.  
> Using those values, instead of calculating them on our own, will produce an sensible performance gain since Unity already made those calculations for us once preventing the need to repeat the calculation, for each vertex or even fragment shader, for each object using that shader.

#### Camera and Screen Variables

| **Name** | **Data Type** | **What represents** |
| --- | --- | --- |
| `_ScreenParams` | `float4` | x is the width of the camera’s target texture in pixels, y is the height of the camera’s target texture in pixels, z is 1.0 + 1.0/width and w is 1.0 + 1.0/height |
| `_WorldSpaceCameraPos` | `float3` | World space position of the camera |
| `unity_OrthoParams` | `float4` | x is orthographic camera’s width, y is orthographic camera’s height, z is unused and w is 1.0 when camera is orthographic, 0.0 when perspective |
| `unity_ObjectToWorld` | `float4x4` | Current object's transformation matrix |
| `unity_WorldToObject` | `float4x4` | Current object's inverse transformation matrix |

### [Built-In Shader Functions](https://docs.unity3d.com/Manual/SL-BuiltinFunctions.html)

Unity provides a huge amount of shader functions, for the full list refer to the documentation.  
Here we'll go over a few common and useful functions.

#### Vertex Transformation Functions

| **Signature** | **What it does** |
| --- | --- |
| `float4 UnityObjectToClipPos(float3 pos)` | Transforms a point from object space to the camera’s clip space in homogeneous coordinates |
| `float3 UnityObjectToViewPos(float3 pos)` | Transforms a point from object space to view space |
| `float3 UnityObjectToWorldDir(float3 dir)` | Rotates a direction vector from object space to world space |
| `float3 UnityObjectToWorldNormal(float3 normal)` | Rotates a normal vector from object space to world space |

#### Screen Space Functions

| **Signature** | **What it does** |
| --- | --- |
| `float4 ComputeScreenPos (float4 clipPos)` | Computes texture coordinate for doing a screenspace-mapped texture sample |

#### Generic Functions

| **Name** | **What it does** |
| --- | --- |
| `float3 WorldSpaceViewDir (float4 v)` | Returns world space direction (not normalized) from given object space vertex position towards the camera |
| `float3 ObjSpaceViewDir (float4 v)` | Returns object space direction (not normalized) from given object space vertex position towards the camera |
| `float Luminance (float3 c)` | Converts color to luminance (grayscale) |
| `float4 EncodeFloatRGBA (float v)` | Encodes (0..1) range float into RGBA color vector |
| `float DecodeFloatRGBA (float4 enc)` | Decodes RGBA color vector into a (0..1) range float |

## [Unity Surface Shaders](https://docs.unity3d.com/Manual/SL-SurfaceShaders.html)

Unity offers a quick way of writing shaders that take into account all complex lighting and shading tasks, which would take long to write and fine-tune in a vertex/fragment shader.

> [!CAUTION]
> Surface Shaders address lighting/shading needs based on a set of libraries written in CG for the **built-in render pipeline**.  
> Those libraries are included by default byt surface shaders and are written inside `CGPROGRAM` code blocks, which we already learnt are not compatible with scriptable render pipelines. Hence, it is not possible to write surface shaders for *URP* or *HDRP*.

> [!IMPORTANT]  
> Surface shaders are not actual shaders, but templates for shader code generation.  
> For this reason, surface shaders code blocks are written inside a `SubShader` block and not in a `Pass` block, as the code generation already takes care of creating the needed passes, based on the shader code written in the surface function.

> [!WARNING]  
> Due to its bond with the legacy built-in pipeline, surface shaders automatically include and generate code that is not compatible with HLSL and other render pipelines.  
> For this reason, we'll write code blocks as `CGPROGRAM ... ENDCG` instead of the usual `HLSLPROGRAM ... ENDHLSL`.

### Surface Pragma Directive

```c
#pragma surface surface_function_name light_model_funciton_partial_name [optional: options]
```

Instead of the usual vertex/fragment programs, in a surface shader we can define just a surface function.  
The surface function's name is written right above the `surface` keyword.

Following the surface function name, we need to specify what kind of lighting model function we want to use for our shader. This function will take care of calculating all the lighting and shading for the shader.  
We say function_*partial*_name because the name we specify here is the name of the function we want to use, without the `Lighting` prefix *(for a `LightingStandard` function, the partial name is `Standard`)*.

The built-in lighting function partial names are:

- `Standard` (PBR, metalness)
- `StandardSpecular` (PBR, specular)
- `Lambert` (non-PBR, diffuse)
- `BlinnPhong` (non-PBR, specular)

We can define our [custom lighting function(s)](https://docs.unity3d.com/Manual/SL-SurfaceShaderLighting.html) for surface shaders, but it requires some coding and deep comprehension about how the different rendering path work.

Finally, we have teh possibility to add a number of options to drive how the final shader will behave. For a complete overview of all the possible options, refer to [Unity's documentation (Optional Parameters section)](https://docs.unity3d.com/Manual/SL-SurfaceShaders.html).  
Here's a list of the most common options:

- `alpha` or `alpha:auto` Automatically picks `alpha:fade` for non-PBR lighting functions or `alpha:premul` PBR lighting functions.
- `alpha:fade` Total transparency, with an alpha value of `0` the pixel won't be visible.
- `alpha:premul` Physically accurate transparency, reflections and highlights are preserved wit an alpha value of `0`.
- `alphatest:VariableName` Uses a variable to determine wether to discard a pixel or not. Usually used in pair with `addshadow` to generate proper shadow caster pass.
- `vertex:VertexFunction` Specify a custom vertex function name (as we would with `#pragma vertex` directive in a vertex/fragmetn shader). Usually used in pair with `addshadow` to generate proper shadow caster pass.
- `addshadow` Generate a shadow caster pass. Usually noy needed.
- `fullforwardshadows` By default, only one directional light is supported in forward rendering. Use this if we need point or Spot Light shadows in forward rendering.

### Surface Shader Semantics

Differently from vertex/fragment shaders, where variable names in data structures did not have a meaning, instead semantics were used to determine the purpose of a variable, surface shaders have special variable names to identify their purpose.

#### Surface Input Structure

An input structure for passing data to the surface shader. The structure can be defined as we already know but the variables inside of it must comply to the following table.

| **Variable Name** | **Data Type** | **Required Semantic** | **What represents** |
| --- | --- | --- | --- |
| *arbitrary* | `float4` | `COLOR` | Interpolated vertex color |
| `viewDir` | `float3` |  | View direction |
| `screenPos` | `float4` |  | Screen space position |
| `worldPos` | `float3` |  | Interpolated vertex world position |
| `worldRefl` | `float3` |  | Surface's reflection vector in world space |
| `worldNormal` | `float3` |  | Surface's normal vector, in world space |

> [!IMPORTANT]  
> If the surface shader writes to the output normal, `worldRefl` should be instead declared as `float3 worldRefl; INTERNAL_DATA` in the input structure.

> [!IMPORTANT]  
> If the surface shader writes to the output normal, `worldNormal` should be instead declared as `float3 worldNormal; INTERNAL_DATA` in the input structure.

#### Surface Output Structures

Unity gives us a couple of pre-made output structures to use with different lighting models. A structure compatible with the chose lighting model must be used.  
Unity detects what variables have been set inside the surface function and generates a vertex/fragment shader accordingly, stripping unused data, when possible.

##### Non-PBR

```c
struct SurfaceOutput
{
	fixed3 Albedo;	// diffuse color
	fixed3 Normal;	// tangent space normal, if written
	fixed3 Emission;
	half Specular;	// specular power in 0..1 range
	fixed Gloss;	// specular intensity
	fixed Alpha;	// alpha for transparencies
};
```

##### PBR Metallic

```c
struct SurfaceOutputStandard
{
    fixed3 Albedo;      // base (diffuse or specular) color
    fixed3 Normal;      // tangent space normal, if written
    half3 Emission;
    half Metallic;      // 0=non-metal, 1=metal
    half Smoothness;    // 0=rough, 1=smooth
    half Occlusion;     // occlusion (default 1)
    fixed Alpha;        // alpha for transparencies
};
```

##### PBR Specular

```c
struct SurfaceOutputStandardSpecular
{
	fixed3 Albedo;		// diffuse color
	fixed3 Specular;	// specular color
	fixed3 Normal;		// tangent space normal, if written
	half3 Emission;
	half Smoothness;	// 0=rough, 1=smooth
	half Occlusion;		// occlusion (default 1)
	fixed Alpha;		// alpha for transparencies
};
```

### Surface Shader Syntax

```c
Shader "Samples/Surface Shader"
{
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		
		CGPROGRAM
		#pragma surface surf Lambert

		struct Input
		{
			float4 color : COLOR;
		};

		void surf(Input IN, inout SurfaceOutput o)
		{
			o.Albedo = float4(1, 1, 1, 1);
		}
		ENDCG
	}

	Fallback "Diffuse"
}
```
