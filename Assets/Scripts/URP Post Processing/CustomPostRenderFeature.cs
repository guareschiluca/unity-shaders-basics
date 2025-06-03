using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

namespace URPPost
{
	public partial class CustomPostRenderFeature : ScriptableRendererFeature
	{
		#region Private variables
		[SerializeField]
		private Material passMaterial;
		[SerializeField]
		private ScriptableRenderPassInput requirements = ScriptableRenderPassInput.Color;
		[SerializeField]
		private RenderPassEvent injectionPoint = RenderPassEvent.BeforeRenderingPostProcessing;
		private EffectPass customPass = null;
		#endregion
		#region Lifecycle
		public override void Create()
		{
			/*
			 * To begin, we create an instance of the class that will take care of
			 * rendering the renfer feature pass.
			 * Here we're declaring one pass, which is actually potentially made of
			 * multiple raster passes, but we can create many that contribute to the
			 * final effect.
			 */
			customPass = new EffectPass(name, passMaterial, injectionPoint);
		}
		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			/*
			 * As the first step we check if any effect (material) is passed.
			 * If not, there's no need to weight on the render pipeline, we'd also
			 * generate errors due to null references.
			 */
			if(
				customPass == null ||
				passMaterial == null
			)
				return;

			/*
			 * We update the pass with up-to-date data.
			 */
			customPass.passMaterial = passMaterial;
			customPass.requirements = requirements;

			/*
			 * We enqueue the render pass to the renderer.
			 */
			renderer.EnqueuePass(customPass);
		}
		#endregion
	}
}
