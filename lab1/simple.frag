void main()
{
    vec4 color = gl_LightModel.ambient * gl_FrontMaterial.ambient;
    
    // TODO: ambient color is given above.
    // Complete the code by adding in diffuse and specular color.
	
    gl_FragColor = color;
}
