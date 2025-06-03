using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace URPPost
{
	public partial class CustomPostRenderFeature
	{
		#region Private sub-classes
		private class EffectPass : ScriptableRenderPass
		{
			#region Private sub-classes
			/*
			 * This simplified and small class is used to pass to a
			 * blit-copy pass the source texture to copy onto the
			 * destination texture set as the blit target.
			 */
			private class CopyPassData
			{
				internal TextureHandle source;
			}
			/*
			 * This class contains the data required by the main pass
			 * to apply the effect. It contains the material used to
			 * blit and all the required input textures to pass to the
			 * material.
			 */
			private class BlitPassData
			{
				internal Material passMaterial;
				internal TextureHandle color;
				internal TextureHandle depth;
			}
			#endregion
			#region Public variables
			/*
			 * Exposing configurable fields as public so the render
			 * feature can easily update them at any time.
			 */
			public Material passMaterial;
			public ScriptableRenderPassInput requirements;
			#endregion
			#region Private variables
			private readonly string featureName;
			#endregion
			#region Private properties
			private string fullPassName => $"[{featureName}] {passName}";
			#endregion
			#region Constructors
			public EffectPass(string featureName, Material passMaterial = null, RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing)
			{
				this.featureName = featureName;
				this.passMaterial = passMaterial;
				this.renderPassEvent = renderPassEvent;
			}
			#endregion
			#region Lifecycle
			/*
			 * This is where we're hooking to the RenderGraph API.
			 */
			public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
			{
				//	Get handles to URP resources
				UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();

				/*
				 * What we're doing here may seem useless and redundant but it's necessary, based on
				 * how the RenderGraph API works.
				 * The same texture cannot be set both as input and as output to a pass operation,
				 * hence here we create a temporary texture for the scene color, the only texture we
				 * need both as input and output, and we're using an additional pass to copy the scene
				 * color to the temporary texture.
				 */
				//	Prepare temporary textures for requirements
				TextureDesc colorTexDesc = renderGraph.GetTextureDesc(resourceData.activeColorTexture);
				colorTexDesc.name = "Color Copy";
				TextureHandle colorCopy = renderGraph.CreateTexture(colorTexDesc);

				//	Prepare the first pass, the one that takes a copy of the source color
				if((requirements & ScriptableRenderPassInput.Color) != 0x0)
				{
					/*
					 * Since this is an additional pass, we only do it if the color texture is a requirement!
					 */
					using(IRasterRenderGraphBuilder colorBuilder = renderGraph.AddRasterRenderPass<CopyPassData>($"{fullPassName} - Color Copy Pass", out CopyPassData copyPassData))
					{
						/*
						 * Here we prepare the pass data by passing a handle to the color texture so that
						 * the execute function will be able to read it during rendering.
						 */
						copyPassData.source = resourceData.activeColorTexture;

						/*
						 * Here we're defining the inputs (UseTexture) and output (SetRenderAttachment).
						 * Inputs lock texture handles and are used to define dependencies and then to
						 * schedule the pass at the right time, while the output is what will receive
						 * the results of Blitter.Blit*().
						 */
						colorBuilder.UseTexture(copyPassData.source, AccessFlags.Read);
						colorBuilder.SetRenderAttachment(colorCopy, 0, AccessFlags.Write);

						/*
						 * Here we're just assigning a function to call to actually perform the render
						 * operation.
						 */
						colorBuilder.SetRenderFunc<CopyPassData>(ExecuteCopyPass);
					}
				}

				//	Prepare the last pass, the actual effect pass
				using(IRasterRenderGraphBuilder builder = renderGraph.AddRasterRenderPass<BlitPassData>($"{fullPassName} - Effect Pass", out BlitPassData passData))
				{
					/*
					 * This pass works exactly as the one above, just uses more data.
					 * One important thing to notice here is that we're passing as the source color
					 * the temporary texture we copied in the above pass, and we're setting the
					 * active color texture itself as the blit target, so the result will wire into
					 * the render queue.
					 */
					//	Setup pass data
					passData.passMaterial = passMaterial;
					passData.color = colorCopy;
					passData.depth = resourceData.activeDepthTexture;

					//	Setup pass inputs and outputs
					//		... Inputs
					if((requirements & ScriptableRenderPassInput.Color) != 0x0)
						builder.UseTexture(passData.color, AccessFlags.Read);
					if((requirements & ScriptableRenderPassInput.Depth) != 0x0)
						builder.UseTexture(passData.depth, AccessFlags.Read);
					//	FEATURE:	Add here normals and motion vectors to support those requirements!

					//		... Outputs
					builder.SetRenderAttachment(resourceData.activeColorTexture, 0, AccessFlags.Write);

					//	Assign a funciton for rendering
					builder.SetRenderFunc<BlitPassData>(ExecuteEffectPass);
				}
			}
			#endregion
			#region Private static methods
			static void ExecuteCopyPass(CopyPassData copyPassData, RasterGraphContext context)
			{
				/*
				 * Here all we need to do is to copy 1:1 the source texture to
				 * the destination texture.
				 * The source texture is passed in the copyPassData parameter,
				 * while the destination texture has already been configured
				 * as the blit target (we decided that above, in the pass
				 * builder).
				 */
				Blitter.BlitTexture(
					context.cmd,
					copyPassData.source,
					new Vector4(1, 1, 0, 0),
					0.0f,
					false
				);
			}
			static void ExecuteEffectPass(BlitPassData passData, RasterGraphContext context)
			{
				/*
				 * Here we're passing useful textures for the shader to make its
				 * calculations.
				 */
				passData.passMaterial.SetTexture("_BlitTexture", passData.color);
				passData.passMaterial.SetTexture("_CameraDepthTexture", passData.depth);
#if USE_FULL_SCREEN_RECT_DRAW
				/*
				 * Here we could blit directly onto the destination texture via a material.
				 * The material uses any of the above passed textures to calculate
				 * the final color for each pixel of the image.
				 * The destination texture has already been configured as the blit
				 * target (we decided that above, in the pass builder).
				 * We won't go for this approach as it would involve rendering two
				 * triangles in a full-screen quad, and this would introduce inefficiencies
				 * such as overdraw on the diagonal.
				 * Also, GPU processes pixels in batches like 2x2, 4x4 or 8x8 which
				 * causes many pixels across the diagonal to be rendered twice.
				 */
				Blitter.BlitTexture(
					context.cmd,
					new Vector4(1, 1, 0, 0),
					passData.passMaterial,
					0
				);
#endif

				/*
				 * Here we're requesting the draw of a full-screen triangle, like the
				 * old Full Screen Render Pass Render Feature did (a detailed description
				 * of how this work is in the shaders used for post processing effects
				 * in this project).
				 * This way we're drawing efficiently, avoiding overdraw and keeping a
				 * smaller vertex buffer.
				 */
				context.cmd.DrawProcedural(
					Matrix4x4.identity,
					passData.passMaterial,
					0,
					MeshTopology.Triangles,
					3,
					1
				);
			}
			#endregion
		}
		#endregion
	}
}
