# Shader Programming in Scriptable Render Pipelines

Scriptable Render Pipelines (`SRP`s) were introduced by Unity as alternatives to the built-in render pipeline, allowing graphics programmers to customize the rendering process.  
At the same time, Unity provided two implementations to start with:

- Lightweight Render Pipeline (`LWRP`, which evolved into the Universal Render Pipeline `URP`)
- High Definition Render Pipeline (`HDRP`)

## Full Code Shader Considerations

Being *custom* by design, every render pipeline requires a dedicated approach to shader writing. This makes coding shaders for `SRP`s more complex, especially when aiming for compatibility across multiple render pipelines.

The coding rules remain the same, but the absence of conveniences such as the [Surface Shader](ShaderPrograms.md#unity-surface-shaders) from the built-in render pipeline forces shader programmers to implement lighting functions manually for every new shader.  
In practice, a shader programmer would likely create a lighting library to include in each new shader, mimicking the Surface Shader paradigm.

The challenge lies in writing accurate, optimized, and stable lighting functions that support all rendering paths (forward, deferred). This process can be quite demanding and, of course, requires specific expertise.

## ShaderGraph

Unity's `URP` and `HDRP` both support ShaderGraph, a visual, node-based shader editor that simplifies shader creation for these render pipelines.

However, simplicity always comes with compromises. Using nodes can be less efficient, as placing and linking them may be more time-consuming and less focused than writing code. Additionally, when implementing advanced features, the visual editor lacks fine control.

## Typical Workflow for Writing Shaders in SRPs

As is often the case, the best approach lies in a hybrid solution that takes advantage of both methods.

The actual workflow in a real-world scenario depends on several factors: budget, project scope, target platform, team skills, and team size.  
One of the most commonly adopted workflows is to write shaders using ShaderGraph’s visual tools while leveraging coding techniques such as:

- [`Custom Function Node`](https://docs.unity3d.com/Packages/com.unity.shadergraph@17.3/manual/Custom-Function-Node.html): allows programmers to write custom code within a node, taking inputs from and exposing outputs to other ShaderGraph nodes.
- [`Scriptable Render Features`](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/renderer-features/scriptable-renderer-features/intro-to-scriptable-renderer-features.html) and [`Scriptable Render Pass`](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/renderer-features/intro-to-scriptable-render-passes.html): allow programmers to hook into the render pipeline to control how rendering occurs.