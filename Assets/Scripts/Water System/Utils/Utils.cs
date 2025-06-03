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

namespace WaterSystem
{
	public static class Utils
	{
		#region Public methods
		public static Vector3 ProjectOntoSurface(Vector3 worldPosition, Transform transform) =>
			ProjectOntoSurface(worldPosition, transform.position, transform.up);
		public static Vector3 ProjectOntoSurface(Vector3 worldPosition, Vector3 planePoint, Vector3 planeNormal) =>
			ProjectOntoSurface(worldPosition, new Plane(planeNormal, planePoint));
		public static Vector3 ProjectOntoSurface(Vector3 worldPosition, Plane plane)
		{
			Vector3 normal = plane.normal;

			// If normal.y is too small, the plane is nearly vertical, making Y projection unreliable
			if(Mathf.Abs(normal.y) < 0.0001f)
				return worldPosition; // Avoid division issues

			// Solve for y using the plane equation
			float projectedY = (-normal.x * worldPosition.x - normal.z * worldPosition.z - plane.distance) / normal.y;

			// Return the corrected position
			return new Vector3(worldPosition.x, projectedY, worldPosition.z);
		}
		#endregion
		#region Private methods
		#endregion
	}
}
