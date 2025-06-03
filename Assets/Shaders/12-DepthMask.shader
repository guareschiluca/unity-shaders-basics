Shader "LG/12 Depth Mask"
{
	SubShader
	{
		/*
		 * Unity allows for a lot of flexibility with the render queue. For
		 * instance, between Geometry and AlphaTest we have 450 different queue
		 * values to fine tune our custom shader effects' scheduling.
		 * 
		 * Here we're writing an additional depth to cover other objects, but
		 * we want only some objects to be covered hence we render after the
		 * usual opaque queue.
		 * 
		 * Object that we want masked will need to render later than this.
		 */
		Tags { "Queue" = "Geometry+10" }

		Pass
		{
			/*
			 * The ColorMask command allows to determine what bits from the
			 * current pixel are written to the current target.
			 * 
			 * ColorMask 0 implies no color copy, just depth.
			 */
			ColorMask 0
		}
	}
}
