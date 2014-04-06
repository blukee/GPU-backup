void main()
{
    // TODO: Calculate normal and light direction per-vertex.
    // Set them in varyings to interpolate them for the frag shader.
    gl_Position = ftransform();
}
