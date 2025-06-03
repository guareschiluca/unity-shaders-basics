using UnityEngine;
using UnityEngine.UI;
#if UNITY_EDITOR
using UnityEditor;
using UnityEditorInternal;
#endif

using S = System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace LegacyPost
{
	[DisallowMultipleComponent]
	[ExecuteAlways]
	public class LegacyPost : MonoBehaviour
	{
		#region Private variables
		[SerializeField]
		private Material mat;
		#endregion
		#region Lifecycle
		void OnRenderImage(RenderTexture source, RenderTexture destination)
		{
			if (mat != null)
				Graphics.Blit(source, destination, mat);
			else
				Graphics.Blit(source, destination);
		}
		#endregion
	}
}
