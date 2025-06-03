# Shaders 101

A shader is a program running on GPU, usually with the goal of calculating the look of an object. This is done in two different moments:

- per-vertex: [Vertex Shader](#vertex-shader)
- per-pixel: [Fragment Shader](#fragment-shader)

In Unity, shaders are defined using a language called [`ShaderLab`](https://docs.unity3d.com/Manual/SL-Reference.html).

## Vertex Shader

A function which runs once per vertex for each geometry which needs to be displayed on screen.

## Fragment Shader

A function which runs once per pixel for each geometry which needs to be displayed on screen.

# Anatomy of a Shader

```bash
Shader
├── Properties
├── SubShader
│   ├── LOD
│   ├── Tags
│   ├── OPTIONAL Commands
│   ├── Pass
│   │   ├── OPTIONAL Tags
│   │   └── OPTIONAL Commands
│   └── OPTIONAL Additional Passes
├── OPTIONAL Additional SubShaders
├── OPTIONAL Custom Inspector Class
└── OPTIONAL Fallback Shader
```

> [!TIP]
> Most of the titles in this file are clickable and link to relevant resources such as the Unity's documentation page.  
> My suggestion is to take an in-depth view of all those resources to gain a solid comprehension of how shaders and render works in Unity.

## [Shader](https://docs.unity3d.com/Manual/SL-Shader.html)

`Shader` is the top-most block, enclosing all others.

Unlike the other blocks, this one is followed by a string, delimited by quotes, before opening the curly brace. This string contains the **shader's name**.

This name will be used by unity to add it to the shader seleciton dropdown in the material inspector as well as by the programmer to programamtically load a shader.

Shader names support pathing, so more shaders can be grouped together. The forward slash (`/`) is used as group separator. The last group *(or the only one)* will be what Unity will display as the shader's name. Nonetheless, the shader name for lookup from code will be the complete string.

For example, if we define a shader as

```
Shader "My Shaders/FX/Standard Rim" { }
```

Unity will group it under `My Shaders` and again under `FX` and will display `Standard Rim` as the shader's name.

```bash
My Shaders
└── FX
    └── Standard Rim
```

However, we can load that shader via code, as follows, using the full string:

```csharp
Shader myShader = Shader.Find("My Shaders/FX/Standard Rim");
Material myMaterial = new Material(myShader);
renderer.material = myMaterial;
```

A shader block usually contains a [`Properties`](#properties) block and a [`SubShader`](#subshaders) or a [`Pass`](#pass) block.

Optionally, a custom inspector class can be specified with a line `CustomEditor = "CSharpClassName"`. If specified, the material inspector will use our own custom class to draw the material editor.

Optionally, a fallback shader can be specified with a line `Fallback = "Fallback Shader Full Name"`. When specified, if none of the `SubShader` blocks in this `Shader` block can be ran on the current hardware, the fallback shader is used, instead of drawing a magenta mesh showing a shader error.  
This is particularily useful when writing a shader that uses specific hardware features (e.g. ray tracing) but the game is meant to run over lots of different platforms and we can't know that all our players' machines can support that specific render feature.  
While `SubShader`s are meant for optimization *(LODs, render pipeline, use more or less hardware features)* with the goal of a consistent look, a fallback shader is meant for compatibility purposes, making the material render on all hardwares, even if it will look different on unsupported hardware.

## [Properties](https://docs.unity3d.com/Manual/SL-Properties.html)

*Theoretically optional*, this block contains the fields that we can assign via inspector to a material so we will likely always specify this block with at least one parameter.

Properties are defined inline as follows:

```
[optional: attribute] Name("Display name", Type) = default value
```

- The starting attribute is optional. See the [dedicated section](#material-property-attributes) for more details.
- Follows the internal name of the property, used in ShaderLab, CG/HLSL and C# code to reference the specific property. This name is conventionally in **PascalCase** and preceded by an underscore (`_`) (e.g. `_MyCoolProperty`).
- The name is followed by a parentheses block, containing two items (order is relevant):
	- A string definig what this property will look like in the Unity's inspector.
	- The type of the property (is it a color, a texture...?).
- Finally, an euqals (`=`) symbol followed by the default value (format changes based on the type).

### Property Types

Unity supports a wide variety of property types. For the full range, please refer to the [docs](https://docs.unity3d.com/Manual/SL-Properties.html).

| **Type** | **Description** | **Default Value Format** |
| --- | --- | --- |
| `Integer` | Whole numbers | `1` |
| `Float` | Fractional numbers | `5.2` |
| `Color` | A color | `(r, g, b, a)` |
| `Vector` | A vector | `(x, y, z, w)` |
| `Texture2D` | Image + Sampler | `"map_name" {}` (see [details](#texture-2d-properties-initialization)) |

> [!NOTE]  
> Other types usually initialize as `"" {}`.

#### Texture 2D Properties Initialization

| **Map** | **Pixel Content** |
| --- | --- |
| `white` | `(1, 1, 1, 1)` |
| `black` | `(0, 0, 0, 0)` |
| `gray` | `(0.5, 0.5, 0.5, 0.5)` |
| `bump` | `(0.5, 0.5, 1, 1)` |
| `red` | `(1, 0, 0, 0)` |

> [!WARNING]  
> Pixel content values listed above **differ from Unity's documentation**. They have been collected experimentally.  
> I didn't find any official or unofficial topic about this discrepancy so do not consider them 100% accurate.

### Accessing Properties via Code

Properties are accessible both from the material inspector and from code, both in read and write.

```csharp
Material myMaterial = new Material(Shader.Find("My Shaders/My Shader"));

myMaterial.SetInteger("_MyInteger", 5);
int i = myMaterial.GetInteger("_MyInteger");

myMaterial.SetFloat("_MyFloat", 0.5f);
float f = myMaterial.GetFloat("_MyFloat");

myMaterial.SetVector("_MyVector", Vector4.one);
Vector4 v = myMaterial.GetVector("_MyVector");

myMaterial.SetColor("_MyColor", Color.green);
Color col = myMaterial.GetColor("_MyColor");

myMaterial.SetTexture("_MyTexture", myFantasticTexture);
Texture t = myMaterial.GetTexture("_MyTexture");
```

When we're not sure whether the shader assigned to the current material has a property or not, we can query the material for it:

```csharp
if(renderer.material.HasTexture("_MyTextureProperty"))
	renderer.material.SetTexture("_MyTextureProperty", myFantasticTexture);
```

Take a deep look at [material class' API](https://docs.unity3d.com/ScriptReference/Material.html) to learn a lot of useful utilites such as `Material.Lerp()` or more advanced functions such as `Material.SetPass()`.

### Special Property Names

There are a couple of property names which Unity knows. Using correct names for correct properties, makes coding easier and makes our shader more readable and integrated in Unity's pipelines.

Those names **must** be unique in a Shader.

- `_Color`: Used on a color poperty, represents the main color for materials
- `_MainTex`: Used on a texture property, represents the main texture for materials

From C#, we can easily access them via:

```csharp
Material myMaterial = new Material(Shader.Find("My Shaders/My Shader"));
myMaterial.color = Color.red;	//	Shortcut for myMaterial.SetColor("_Color", Color.red);
myMaterial.mainTexure = myFantasticTexture;	//	Shortcut for myMaterial.SetTexture("_MainTex", myFantasticTexture);
```

> [!IMPORTANT]
> Some names are reserved by Unity.

### [Material Property Attributes](https://docs.unity3d.com/Manual/SL-Properties.html#material-property-attributes)

Property attributes share the same syntax and work the same way as C#'s attributes: they add info to the property so that Unity can check the presence of specific a attribute and respond to it.

Here's a list of most common attributes (refer to the [doc](https://docs.unity3d.com/Manual/SL-Properties.html#material-property-attributes) for the full list):
- `[Gamma]`: Placed before float or vector properties, treats the value as [sRGB](https://it.wikipedia.org/wiki/Spazio_colore_sRGB) (~1/2.2 exponent) values.
- `[HDR]`: Placed before color or texture properties, treats the value as High Dynamic Range.
- `[HideInInspector]`: The property is not shown in the material editor. Can still be accessed via code.
- `[NoScaleOffset]`: Placed before texture properties, hides the tiling and offset parameters.
- `[Normal]`:  Placed before texture properties, informs Unity that the property represents a normal map, enabling the warning if we don't assign a valid normal map, along with the "Fix" button.
- `[ToggleUI]`:  Placed before float properties, displays the property as a toggle, setting the property value to 1.0 when checked and 0.0 when unchecked.
- `[PowerSlider(n)]`:  Placed before range properties, applies an exponent (`n`) to the slider UI and assigns the result to the value.

## [SubShader(s)](https://docs.unity3d.com/Manual/SL-SubShader.html)

> [!TIP]
> This block can be omitted if only one `SubShader` is defined in a `Shader`.  
> In that case proceed with the usual content of the `SubShader` block, instead.

Writing multiple `SubShader`s will allow Unity to choose which one to use. [`SubShader` selection process](https://docs.unity3d.com/Manual/shader-loading.html#selecting-subshaders) is based on different conditions, the main are:

- [LOD](#lod)
- Render Pipeline
- Hardware

> [!TIP]
> It is possible to programmatically force the selection of a `SubShader` for advanced effects.

The main reason for writing more `SubShader` blocks within the same `Shader` blocks is to support different platforms with the same shader.

Via code, we can set the maximum `LOD`, both globally and locally:

```csharp
//	Set maximum LOD level for a specific shader
Shader.Find("My Shaders/My Shader").maximumLOD = 200;

//	Set maximum LOD level for ALL shaders
Shader.globalMaximumLOD = 200;
```

## [Pass](https://docs.unity3d.com/Manual/SL-Pass.html)

This block is where the real magic happens. `Pass` blocks contain the instructions for the GPU to calculate the final image.

`Pass` blocks can contain [`Tags`](#tags) and [`Commands`](#commands) as [`SubShader`](#subshaders) blocks do. In that case they override the outer scope.

Pass blocks can contain [`Code Blocks`](#code-blocks) and/or ShaderLab commands.

> [!NOTE]  
> I mentioned the `ShaderLab commands`. This is an old way of writing simple shaders without writing code.  
> They're outside the scope of this overview and we won't treat them.

We'll dive deeper into writing a shader pass in a [dedicated overview](ShaderPrograms.md).

## [Tags](https://docs.unity3d.com/Manual/SL-SubShaderTags.html)

`Tag` blocks can be specified inside `SubShader` blocks or `Pass` blocks. A `Pass`' `Tags` block overrides the outer `SubShader`'s `Tags` block.

Tags are key-value pairs where both key and value are strings.

```
"TagName" = "TagValue"
```

When multiple tags need to be specified they are just written one per line or on the same line, with one or more whitespace characters as separator.

```
Tags { "Tag1" = "Value1" "Tag2" = "Value2" }
```
or (equivalent)
```
Tags
{
	"Tag1" = "Value1"
	"Tag2" = "Value2"
}
```

### Queue

`"Queue" = "[name]"`  
`"Queue" = "[name]+[offset]"`

Queue tag tells the GPU when to render this shader. Lower numbers get rendered earlier and so are potentially drawn behind other elements. Higher numbers are rendered later and so are potentially drawn above other elements.

Instead of numbers, a set of keywords can be used:

- `"Background"` [1000]
- `"Geometry"` [2000] *(default, when Queue tag is omitted)*
- `"AlphaTest"` [2450]
- `"Transparent"` [3000]
- `"Overlay"` [4000]

There is a huge gap between the different stages, and this is intentionally made to allow fine-tuning of the render.  
If most opaque objects render during the default stage `"Queue" = "Geometry"`, and we want to achieve an effect for other opaque objects which need to render after all the other opaque objects but "still in that stage", we can write a shader with `"Queue" = "Geometry+1"` *(so with an index of 2001)*, and we can go on like that until `"Queue" = "Geometry+449"`, still being sure to be rendering before the AlphaTest stage.  

> [!TIP]
> Subtractions are allowed too, such as `"Queue" = "Geometry-1"`. This will translate to 1999.  

Arbitrary numbers like `"Queue" = "1234"` cannot be specified via shader but it is possible via C# or via the material inspector, when the Queue is exposed or in debug mode.

Render queue can be queried at runtime with

```csharp
//	Active SubShader's render queue
int myShaderRenderQueue = Shader.Find("My Shaders/My Shader").renderQueue;
```

or can be changed at runtime via

```csharp
renderer.material.renderQueue = 1234;
```

### RenderType

`"RenderType" = "[name]"`

Often used along with Queue tag, the RenderType tag allows to define a string which can be used by scripts.

Common RenderType names are:

- "Opaque" *(default, when RenderType is omitted)*, used for fully opaque objects
- "Transparency", used for semi-transparent objects like glass *(alpha blend)*
- "TransparencyCutout", used for object with fully opaque parts and fully transparent (clipped) parts *(alpha test)*

Custom RenderType names can be specified and this is used in advanced techniques such as [Shader Replacement](https://docs.unity3d.com/Manual/SL-ShaderReplacement.html) to achieve certain effects or to extract data from the scene via a special render.

### IgnoreProjector

`"IgnoreProjector" = "False"` *(default, when IgnoreProjector tag is omitted)*  
`"IgnoreProjector" = "True"`

Makes this SubShader ignore [projectors](https://docs.unity3d.com/Manual/class-Projector.html).

### PreviewType

`"PreviewType" = "[shape]"`

This is a totally cosmetic tag, telling unity what kind of preview should be used when displaying this shader *in the inspector*.

Possible shapes are:

- "Sphere" *(default, when PreviewType tag is omitted)*
- "Plane"
- "Skybox"

### RenderPipeline

`"RenderPipeline" = "[name]"`

This tag allows to bind a `SubShader` to a specific render pipeline. Leveraging on this, we can write a single `Shader` which renders on every render pipeline by creating a `SubShader` for each render pipeline we want to support.

Built-in names are:

- "UniversalPipeline"
- "HDRenderPipeline"

> [!TIP]
> If the RenderPipeline tag is omitted, or if it has a value which doesn't match any existing scriptable render pipeline, it's assumed to not support any render pipeline and used with the core render pipeline.


## [Commands](https://docs.unity3d.com/Manual/shader-shaderlab-commands.html)

`Command`s are single lines of ShaderLab code that serve two main purposes:

- Setting parameters the GPU will use during render.
- Defining special `Pass`es.

### Render State Commands

Here is a set of the most common render `Command`s, refer to the [docs](https://docs.unity3d.com/Manual/SL-Commands.html) for the full set:

#### [Blend](https://docs.unity3d.com/Manual/SL-Blend.html)

Blend is a common `Command` since it determines how a pixel from current render step (current pixel of current geometry) blends with the underlying pixel.  
By default, blending is disabled (`Blend Off`), meaning that the new pixel replaces the underlying one.

It has many possible forms, but the most commons, by far, are:

- `Blend <source factor> <destination factor>`: Specifies the weight of the source (current rendered pixel) and the weight of the target (underlying pixel).
- `Blend <source RGB factor> <destination RGB factor>, <source alpha factor> <destination alpha factor>`:  As above, but allows to specify different factors for color and alpha channels.

Factors are used in a simple formula to calculate the final pixel:

```
finalValue = sourceFactor * sourceValue operation destinationFactor * destinationValue
```

> [!NOTE]
> The `operation` token in the above formula is [discussed right below](#blendop).

Supported blend factors are:

- `One`: Takes the current input entirely.
- `Zero`: Discards the current input.
- `SrcColor`: Represents the RGB components of the source input.
- `SrcAlpha`: Represents the Alpha component of the source input.
- `SrcAlphaSaturate`: Equals to the minimum alpha value of the source multiplied by (1 - destination alpha).
- `DstColor`: Represents the RGB components of the destination input.
- `DstAlpha`: Represents the Alpha component of the destination input.
- `OneMinusSrcColor`: (1 - source RGB).
- `OneMinusSrcAlpha`: (1 - source Alpha).
- `OneMinusDstColor`: (1 - destination RGB).
- `OneMinusDstAlpha`: (1 - destination Alpha).

A few examples:

> [!NOTE]
> The following example assume that the `operation` token is at its default value, which is `Add`.

- `Blend SrcAlpha OneMinusSrcAlpha`: *Alpha blend*, the new pixel will be multiplied by its alpha channel and the underlying pixel will be multiplied by the inverse (`1 - x`) of that alpha channel.
- `Blend One One`: *Additive*, both the channels will be full-weight, meaning the final pixel will be brighter as incorporates the two colors in full.
- `Blend DstColor Zero`: *Multiply*, the new pixel is multiplied by the underlying pixel and the underlying pixel is zeroed (taken out of the addition).

##### [BlendOp](https://docs.unity3d.com/Manual/SL-BlendOp.html)

The BlendOp `Command` defines what operation is used in the blend formula to calculate the final value: the `operation` token in the formula is defined here.

By default it is `Add`. `BlendOp`s have different support based on both graphics API and hardware.  
When it comes to unsupported operations:

- GL will skip
- Vulkan will fallback to Add
- Metal will fallback to Add

The operations Unity supports are (refer to the docs):

- `Add` *(default, when `BlendOp` is omitted)*
- `Sub`
- `RevSub`
- `Min`
- `Max`
- `LogicalClear`
- `LogicalSet`
- `LogicalCopy`
- `LogicalCopyInverted`
- `LogicalNoop`
- `LogicalInvert`
- `LogicalAnd`
- `LogicalNand`
- `LogicalOr`
- `LogicalNor`
- `LogicalXor`
- `LogicalEquiv`
- `LogicalAndReverse`
- `LogicalAndInverted`
- `LogicalOrReverse`
- `LogicalOrInverted`
- `Multiply`
- `Screen`
- `Overlay`
- `Darken`
- `Lighten`
- `ColorDodge`
- `ColorBurn`
- `HardLight`
- `SoftLight`
- `Difference`
- `Exclusion`
- `HSLHue`
- `HSLSaturation`
- `HSLColor`
- `HSLLuminosity`

#### [Cull](https://docs.unity3d.com/Manual/SL-Cull.html)

`Cull <side>`

The `Cull` command tells the GPU whether or not to skip the rendering of a specific side of a polygon.

Possible sides are:

- `Back`: meshes' back-faces are not rendered *(default, when `Cull` command is omitted)*
- `Front`: meshes' front-faces are not rendered
- `Off`: no face is discarded, both front and back faces are rendered

It may be useful to define different passes for front and back faces, each pass culling a different face, to give two different looks to meshes with no thickness but that can be seen from both sides (e.g. the hood of a hoodie).

> [!WARNING]  
> `Cull Off` or `Pass { Cull Back } Pass { Cull Front }` are heavier to render since the same polygon gets rendered twice.  
> Make sure to limit the usage of this technique. In the hoodie example, the hoodie mesh should have two different materials, one for the main part of the garment which culls back-faces and one only for the hood which doesn't cull.

> [!TIP]
> Render-performance-wise, having a thin mesh *(a mesh with only one sheet of polygons)* which draws both faces or having a thick mesh *(a mesh with two layers of polygons, one per side, and maybe a thickness loop of polygons)* are not much different scenarios.  
> Despite this, this topic is worth a couple of considerations:
> - Thick meshes allow to use the same material and the same shader on all faces of the mesh, favouring batching.
> - Thin meshes reduce the number of vertices, favouring simulations *(such as clothing)*.

#### [ZWrite](https://docs.unity3d.com/Manual/SL-ZWrite.html)

`ZWrite <mode>`

When a pixel renders, it can write to the depth buffer, a grayscale image used internally by the renderer to tell the distance of that pixel from the camera, other than the color buffer (the final rendered image).  
This information is used by pixels which render later to understand if they're in front of or behind the scene rendered up to now.

Possible modes are:

- `On` *(default, when `ZWrite` command is omitted)*
- `Off`

> [!TIP]
> Usually, opaque object write to the depth buffer while transparent ones don't.  
> Transparent objects must not occlude opaque objects, but need to be occluded by opaque object. Hence they need to `ZTest LEqual` to be occluded, `ZWrite Off` to not occlude and render later *(`Tags { "Queue" = "Transparent"}`)*, to be sure that the depth buffer is (theoretically) in its final state.

#### [ZTest](https://docs.unity3d.com/Manual/SL-ZTest.html)

`ZTest <mode>`

The `ZTest` command tells the GPU how to perform depth test before considering to render one fragment (pixel).

The GPU makes a comparison between the current geometry's depth on the current pixel and the depth for that pixel on the depth buffer; the comparison function is specified in this `ZTest` command.

If the evaluation fails, the new pixel is simply skipped, being behind something which covers it, and therefore the previous color is kept.

The `ZTest` command can manipulate the comparison mode to achieve custom effects.

Possible comparison modes are:

- `Disabled`
- `Never`
- `Less`
- `Equal`
- `LEqual` *(default, when ZTest is omitted)*
- `Greater`
- `NotEqual`
- `GEqual`
- `Always`

For instance, we can use `ZTest Always` to make sure an object is visible even when behind other objects, or we can use `ZTest Greater` to force the object to be visible when behind other objects but not when it's in front of them.

> [!TIP]
> Often, when messing with `ZTest` command, it's also useful to mess with the "Queue" tag, to make the depth test in a moment when the full scene depth has been computed.  
> For instance `Tags { "Queue" = "Geometry+1" }` makes the current object render one step after all other geometry, when the scene's depth has been (theoretically) fully computed and it's safe to make comparisons.

#### [ColorMask](https://docs.unity3d.com/Manual/SL-ColorMask.html)

`ColorMask <mask>`  
`ColorMask <mask> <render target>`

The `ColorMask` command is pretty simple but quite powerful. It has two possible signatures but let's just consider the simplest one; the second optional parameter is used to specify the render target and defaults to `0` which is the final render. Dealing with multiple render target requires knowledge of the current rendering path and the usage that the rendering path makes of the different render targets.

As the name says, this command acts as a bit-mask during the copy of the color computed in the fragment shader to the render target. Using this command, we can decide what channels we can let pass and reach the render target. Omitted channels are discarded and do not affect the render target.

Possible mask values are:

- `0`: all channels get completely discarded
- `R`: red channel (x component) is blended onto the render target
- `G`: green channel (y component) is blended onto the render target
- `B`: blue channel (z component) is blended onto the render target
- `A`: alpha channel (W component) is blended onto the render target

`R`, `G`, `B` and `A` can be combined at will, for instance:

- `RB`: only red channel (x component) and blue channel (z component) are blended into the render target
- `GA`: only green channel (y component) and alpha channel (w component) are blended into the render target
- `RGB`: only red channel (x component), the green channel (y component) and blue channel (z component) are blended into the render target
- `RBA`: only red channel (x component), the blue channel (z component) are blended into the render target and alpha channel (w component) are blended into the render target

The default value, when `ColorMask` is omitted, is `RGBA`, meaning that all channels are blended by default.

A trivial example may be depth masking:

```
Shader "Depth Mask"
{
	SubShader
	{
		ColorMask 0
		ZWrite On
		Tags { "Queue" = "Geometry-1" }
	}
}
```

An object with this shader doesn't affect the final render's color but it renders before the other objects so it will cause objects behind it to fail their depth test.

#### [Offset](https://docs.unity3d.com/Manual/SL-Offset.html)

`Offset <factor>, <units>`

The `Offset` command is another simple but quite powerful command. It allows to tell the GPU to apply an offset to the depth of the current pixel. This helps resolving z-fighting issues when two geometries occupy the same exact depth, by explicitly telling the GPU which one draws on front.

##### Factor

The first parameter, the factor, is a float number ranging between -1 and 1.  
It represents the Z slope of a polygon. By "Z slope" we mean the incline between the polygon and the camera's near/far clip planes.

Change this value to fine tune the visual result, based on the scenario.

##### Units

The second parameter, the units, is a float number ranging between -1 and 1.  
It represents the actual depth offset to apply to the pixel.

Negative numbers pull the pixel towards the camera, positive numbers push the pixel away from the camera.

### Pass Commands

#### [UsePass](https://docs.unity3d.com/Manual/SL-UsePass.html)

`UsePass "Shader object name/PASS NAME IN UPPERCASE"`

The `UsePass` command allows to use a pass that has been defined in another shader.

```
Shader "Examples/ContainsNamedPass"
{
    SubShader
    {
        Pass
        {    
              Name "ExampleNamedPass"
            
              // The rest of the Pass contents go here.
        }
    }
}
```

```
Shader "Examples/UsesNamedPass"
{
    SubShader
    {
        UsePass "Examples/ContainsNamedPass/EXAMPLENAMEDPASS"
    }
}
```

## [LOD](https://docs.unity3d.com/Manual/SL-ShaderLOD.html)

While `SubShader`s are used to select an implementation over another based on hardware features or other parameters, `LOD` is used to create lighter versions of a `SubShader` for the same hardware type.  
The same feature set can be shared by low-end and high-end hardware, using `LOD` we can write shaders for different hardwares tier.

`LOD` are defined inline as a single integer number: `LOD 300`. Higher numbers are used for more demanding shaders, lower numbers for lighter shaders. As a reference, Unity's unlit shaders have a `LOD` value of 100, while Unity's Standard shader has a `LOD` value of 300.

## [Shader Variants](https://docs.unity3d.com/Manual/shader-variants.html)

When we write a shader, rarely we're actually writing a single shader. When it gets compiled, it gets split into variants. How many variants are created depends on different factors, which in turn depend on what kind of shader we're writing (code or ShaderGraph). Refer to docs for more details.

## [Stencil Buffer](https://docs.unity3d.com/Manual/SL-Stencil.html)

Think of the `Stencil Buffer` as a single-channel 8-bit integer render target with the same size of the active render target.  
On this buffer we don't write colors but simple numbers. The default value on all "pixels" in this buffer is `0`.

> [!CAUTION]
> 8 bits is an optimistic evaluation of the depth of the `Stencil Buffer`. Based on the rendering path, some limitations can occur:  
> **Forward Rendering Path** leaves all the *8 bits* from the `Stencil Buffer` available to the programmer.  
> **Deferred Rendering Path**, instead, uses the *3 highest* bits of this buffer for the main light and *up to 4 more higher bits* for additional lights, leaving potentially just 1 available to the programmer. In this case we have two options:
> 1. Setting [`Camera.clearStencilAfterLightingPass`](https://docs.unity3d.com/ScriptReference/Camera-clearStencilAfterLightingPass.html) to `true` frees up all the bits after lighting is computed.
> 2. Using `ReadMask`and `WriteMask` to safely operate on the free bit(s).

> [!TIP]
> Clearing stencil after lighting pass is useful for UI too, since UI masks use `Stencil Buffer` for hard masking

> [!TIP]
> Cameras can override render path. It is good practice to have one or more cameras dedicated to UI and set to Forward Rendering Path to bypass the stencil issue from 3D rendering.

### What's the Stencil Buffer For?

The stencil buffer is mainly used for special effects or [constructive solid geometry](https://en.wikipedia.org/wiki/Constructive_solid_geometry).

### Usage

```
Stencil
{
	<settings here>
}
```

The `Stencil` block can ble placed inside a `Pass` block, to affect a single pass, or inside a `SubShader` block, to affect all passes in that `SubShader`.

The Stencil block has a lot of settings, we're going to outline the most common ones.

#### Ref

```
Stencil
{
	Ref <0-255>
}
```

Sets the stencil value to write to or read from the pixels when this `Stencil` block passes (see [`Comp`](#comp)), based on this `Ref` value.

#### Comp

```
Stencil
{
	Comp <comparison function>
}
```

This is the conditional statement. In conjunction with [`Ref`](#ref), adds a condition for this `Stencil` block to pass.

Possible comparison functions are:

- `Never`
- `Less`
- `Equal`
- `LEqual`
- `Greater`
- `NotEqual`
- `GEqual`
- `Always`

#### Pass and Fail

```
Stencil
{
	Pass <operation>
	Fail <operation>
}
```

Determines what operation to perform in case this Stencil block passes or fails *(mainly based on [`Ref`](#ref) and [`Comp`](#comp) settings)*.

Possible operations are:

- `Keep`
- `Zero`
- `Replace`
- `IncrSat`
- `DecrSat`
- `Invert`
- `IncrWrap`
- `DecrWrap`

#### Examples

The following `Stencil` block *always* *writes* the value *5* to the stencil buffer, whenever the Z-Test passes (object's pixel is in front of other objects).

```
Stencil
{
	Ref 5
	Comp Always
	Pass Replace
}
```

The following `Stencil` block allows the Pass *(or SubShader, depending on where it is placed)* to render only if the stencil buffer for that pixel already *contains* a value of *5*. If the stencil [`Comp`](#comp) fails, the pixel is discarded.

```
Stencil
{
	Ref 5
	Comp Equal
}
```

## [Code Blocks](https://docs.unity3d.com/Manual/shader-shaderlab-code-blocks.html)

Actual shader program is written inside code blocks.

Code blocks are defined inside `Pass` blocks as follows:

```
Shader
{
	SubShader
	{
		Pass
		{
			<language>PROGRAM
			//...
			END<language>
		}
	}
}
```

Shader code is written between the `<language>PROGRAM` directive and the `END<language>` directive.

The `<language>` token must be replaced with `CG` or `HLSL` depending on the shader language we need to use.

### CG vs HLSL

`CG` and `HLSL` are the two languages we use to write shaders in Unity.

Unity originally worked with `CG` language.  
Today, `CG` is supported only by the built-in render pipeline, since `CGPROGRAM`s automatically include code that is not compatible with URP and HDRP (or any pipeline, even custom ones, based on SRP Core).

As opposite, `HLSL` supports the full range of Unity's render pipeline, from built-in to URP and HDRP to custom render pipelines, being them based on SRP Core or not.

### INCLUDE vs PROGRAM

So far we learnt that `Pass` blocks can have shader code, as well as a `SubShader` block can have more than one `Pass` block and a `Shader` block can have more than one `SubShader` block. We also learnt that shader code is written inside a shader program, identified by the keyword `<language>PROGRAM`.

We may need to share some code (e.g. a conversion function) between all the programs in this shader.  
Here we have two options, based on our needs:

1. `#include`: in case the code we want to share is relevant to more than one shader file, we can extract that code into a different file, with `.cginc` (for CG) or `.hlsl` (for HLSL) extension, and include it in every `<language>PROGRAM` that needs to use it.
2. `<language>INCLUDE`: in case the code we want to share is relevant to multiple programs in this shader but not relevant to other shaders, we can declare a `<language>INCLUDE ... END<language>` block in a `SubShader` block to share it with all the `Pass` blocks inside that `SubShader` block, or in a `Shader` block to share it with all the `Pass` blocks in all the `SubShader` blocks in the `Shader` block.

### Structure of a Code Block

> [!NOTE]  
> This is just a brief introduction to the structure of a code block, we'll dive deeper into details in [Shader Programs](ShaderPrograms.md) overview.

> [!NOTE]  
> In this paragraph, when we talk about **code blocks** we mean `<language>PROGRAM` blocks and not `<language>INCLUDE` code blocks.  
> Some *(or almost all)* of the main parts of `<language>PROGRAM` code blocks can be moved to a `<language>INCLUDE` block, but it's just an implementation detail. Let's consider only `<language>PROGRAM` blocks in this paragraph.

Code blocks have a set of important elements that need to be defined in order for the GPU to process the code the right way.

```c
Shader "Custom/Shader Name"
{
	SubShader
	{
		Pass
		{
			HLSLPROGRAM
			//	Pragma directives
			#pragma vertex vertex_shader_function_name
			#pragma fragment fragment_shader_function_name

			//	Possible includes

			//	Data exchange structures declarations
			struct MeshData { /* Mesh to vertex shader data */ };
			struct V2F { /* Vertex shader to Fragment shader data */ };

			//	Shader program definition
			V2F vertex_shader_function_name(MeshData meshData) { /*	Prepare mesh data for fragment shader	*/ }
			float4 fragment_shader_function_name(V2F IN) : SV_Target { /* Calculate final render color for current pixel (aka fragment) */ }
			ENDHLSL
		}
	}
}
```

#### Pragma Directives

`#pragma` directives are used to inform the compiler. In this case, we're telling the compiler the name of the functions acting as vertex and fragment shaders.

Function names can be arbitrary, that's why we need to inform the compiler. Of course the function names must comply the `C` language syntax.

To inform the compiler about the vertex function, we write `#pragma vertex <vertex_func_name>`, while to inform the compiler about the pixel function we write `#pragma fragment <fragment_func_name>`.

> [!TIP]
> Fragment and Vertex functions can be included from a `<language>INCLUDE` block or via a `#include "path/to/file.hlsl"` directive.  
> There's no need to define those functions in the same shader file, the only important thing is that the functions are defined somewhere (and included, of course) at the moment of compilation.  
> Unity does so in most of its shader code. They do so both to address the high complexity of some shaders *(so we don't have to read all the code in the same page to understand what a shader does at high level)*, and to allow for the same code to be used in different shaders.

##### Pragma Surface Directive

A special `#pragma` directive is the `#pragma surface <surface_func_name>`, which allows for quicker shader programming, under certain circumstances.  
This is matter for the [Shader Programs](ShaderPrograms.md#unity-surface-shaders) overview.

#### Data Exchange Structures and Program Definition

When a geometry needs to be rendered, a shader is evaluated in two *(main)* different steps:

1. First, the vertex shader is called once per vertex.
	1. Information about the geometry is passed to the vertex shader using a dedicated structure.
	2. The vertex shader has the responsibility to take mesh data and the object's transformation and to transform all that data to clip space (in the render target coordinates, usually screen).
	3. Once calculated, this information is passed to the fragment shader, using a dedicated data structure.
2. Then, the fragment shader is called once per pixel.
	1. Information about what to render are taken from the vertex shader's calculation on the three vertices for the current triangle.
	2. The three data structures are interpolated based on the fragment position on the triangle.
	3. The interpolated information is passed to the fragment shader.
	4. The fragment shader has the responsibility to calculate the final color for each pixel, taking into account the surface color, micro-surface, material type, lighting and so on.
	5. The final color is then copied by the GPU to the active render target.

> [!WARNING]  
> The information about the three vertices composing the triangle on which the current fragment lies, are linearly interpolated.  
> This means that vector values do not preserve their magnitude. Take this into account when writing shader code.

We'll dive deeper in the shader program definition in the [Shader Programs](ShaderPrograms.md) overview.

Especially, the same way we need to inform the compiler about names of vertex and fragment functions, we'll see how to format data structures to tell the GPU what the information we pass to it stand for, and we'll do this using [semantics](ShaderPrograms.md#semantics).
