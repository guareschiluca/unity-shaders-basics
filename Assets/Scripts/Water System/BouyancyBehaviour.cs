using UnityEngine;
using UnityEngine.Assertions;
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
	[DisallowMultipleComponent]
	public class BouyancyBehaviour : MonoBehaviour
	{
		#region Private enums
		private enum BuoyType : byte
		{
			Point,
			Surface
		}
		#endregion
		#region Private variables
		[SerializeField]
		private WaterSampler ownerSampler;
		[SerializeField]
		private BuoyType buoyType = BuoyType.Point;
		[SerializeField]
		private float buoySinkingCorrection = 0.0f;
		[SerializeField]
		private Vector3 surfaceBuoyRelativePoint1 = Vector3.forward;
		[SerializeField]
		private Vector3 surfaceBuoyRelativePoint2 = Quaternion.Euler(0, -120, 0) * Vector3.forward;
		[SerializeField]
		private Vector3 surfaceBuoyRelativePoint3 = Quaternion.Euler(0, 120, 0) * Vector3.forward;
		[SerializeField]
		[Range(0.0f, 1.0f)]
		private float positionAdaptionHardness = 0.05f;
		[SerializeField]
		[Range(0.0f, 1.0f)]
		private float rotationAdaptionHardness = 0.1f;
		#endregion
		#region Lifecycle
#if UNITY_EDITOR
		void OnDrawGizmosSelected()
		{
			Gizmos.matrix = transform.localToWorldMatrix;
			switch(buoyType)
			{
				case BuoyType.Point:
					Gizmos.color = Color.green;
					Gizmos.DrawLine(
						Vector3.zero,
						Vector3.up
					);
					break;
				case BuoyType.Surface:
					Gizmos.color = Color.blue;
					Vector3[] buoySamplePoints = new Vector3[] {
						surfaceBuoyRelativePoint1,
						surfaceBuoyRelativePoint2,
						surfaceBuoyRelativePoint3
					};
					Gizmos.DrawLineStrip(
						buoySamplePoints,
						true
					);
					break;
				default:
					Assert.IsTrue(false, $"Unsupported buoy type {buoyType}");
					break;
			}
		}
#endif
		void LateUpdate()
		{
			ApplyBuoyancy();
		}
		#endregion
		#region Private methods
		private void ApplyBuoyancy()
		{
			switch(buoyType)
			{
				case BuoyType.Point:
					ApplyPointBuoyancy();
					break;
				case BuoyType.Surface:
					ApplySurfaceBuoyancy();
					break;
				default:
					Assert.IsTrue(false, $"Unsupported buoy type {buoyType}");
					break;
			}
		}
		private void ApplyPointBuoyancy()
		{
			/*
			 * For point buoyancy, just sample one point and
			 * smoothly adapt to its Y, rotation is untouched
			 */
			Vector3 position = transform.position;
			Vector3 sample = ownerSampler.SamplePosition(position);

			position.y = Mathf.Lerp(position.y, sample.y + buoySinkingCorrection, positionAdaptionHardness);

			transform.position = position;
		}
		private void ApplySurfaceBuoyancy()
		{
			/*
			 * For surface buoyancy, we sample three points
			 * roughly on the perimeter of the object.
			 * The average height of these 3 points will be
			 * used right as for the point buoyancy.
			 * The normal is then used to tilt the object.
			 */

			//	Transform local points into world points
			Vector3 point1 = transform.TransformPoint(surfaceBuoyRelativePoint1);
			Vector3 point2 = transform.TransformPoint(surfaceBuoyRelativePoint2);
			Vector3 point3 = transform.TransformPoint(surfaceBuoyRelativePoint3);

			//	Preparing containers for sample points
			Vector3 sample1, sample2, sample3, normal;

			//	Asking the owner water sampler to sample the height at that point
			ownerSampler.SamplePlanarContext(
				point1, point2, point3,
				out sample1, out sample2, out sample3,
				out normal
			);

			//	Calculate targets
			Vector3 targetPosition = transform.position;
			targetPosition.y = (sample1.y + sample2.y + sample3.y) / 3.0f;
			targetPosition.y += buoySinkingCorrection;
			Quaternion tiltRotation = Quaternion.FromToRotation(Vector3.up, normal);
			Quaternion buoyYawRotation = Quaternion.Euler(0, transform.eulerAngles.y, 0);
			Quaternion targetRotation = tiltRotation * buoyYawRotation;

			//	Apply buoyancy
			transform.position = Vector3.Lerp(transform.position, targetPosition, positionAdaptionHardness);
			transform.rotation = Quaternion.Slerp(transform.rotation, targetRotation, rotationAdaptionHardness);
		}
		#endregion
	}
}
