Shader "LG/13 Stencil Mask"
{
	Properties
	{
		_StencilRef("Stencil Reference", Integer) = 1
	}
	SubShader
	{
		Tags { "Queue" = "Geometry-10" }

		/*
		 * This is not mandatory, here we're not writing to the Z-buffer since
		 * we plan to use this shader as an additional material hence we don't
		 * want it to interfere with depth.
		 */
		ZWrite Off

		/*
		 * The stencil buffer is an additional render target with 8-bits depth
		 * that can contain values from in the 0 to 255 range.
		 * This value doesn't directly affect render but can be read to create
		 * effects.
		 * 
		 * Here, for instance, we're just writing a value to the depth buffer,
		 * unconditionally.
		 * 
		 * The Ref sets the reference value to read or write.
		 * The Comp sets the comparison fuction, in this case always passes.
		 * The Pass sets the operation to do on the depth buffer in case the
		 * Comp succeeds, and in this case we are writing the ref value by
		 * replacing any existing value for that pixel.
		 */
		Stencil
		{
			Ref [_StencilRef]
			Comp Always
			Pass Replace
		}

		Pass
		{
			ColorMask 0
		}
	}
}
