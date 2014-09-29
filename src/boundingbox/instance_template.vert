{{GLSL_VERSION}}
{{GLSL_EXTENSIONS}}

{{vertex_type}} vertex;
{{normal_vector_type}} normal_vector; // normal might not be an uniform, whereas the other will be allways uniforms
{{offset_type}} offset; //offset for texture look up. Needed to get neighbouring vertexes, when rendering the surface

{{xrange_type}} xrange; 
{{yrange_type}} yrange;
{{z_type}} z;   

{{xscale_type}} xscale; 
{{yscale_type}} yscale; 
{{zscale_type}} zscale; 

{{color_type}} color;

uniform vec2 texdimension;
uniform mat3 normalmatrix;
uniform mat4 modelmatrix;
uniform mat4 projection, view;

{{out}} vec3 N;
{{out}} vec3 V;
{{out}} vec4 vert_color;

mat4 getmodelmatrix(vec3 xyz, vec3 scale)
{
   return mat4(
      vec4(scale.x, 0, 0, 0),
      vec4(0, scale.y, 0, 0),
      vec4(0, 0, scale.z, 0),
      vec4(xyz, 1));
}

vec2 getcoordinate(sampler2D xvalues, sampler2D yvalues, vec2 uv)
{
    return vec2(texture(xvalues, uv).x, texture(yvalues, uv).x);
}
vec2 getcoordinate(vec2 xrange, vec2 yrange, vec2 uv)
{
    vec2 from = vec2(xrange.x, yrange.x);
    vec2 to = vec2(xrange.y, yrange.y);
    return from + (uv * (to - from));
}
vec2 getuv(vec2 texdim, int index, vec2 offset)
{
    float u = float((index % int(texdim.x)));
    float v = float((index / int(texdim.x)));
    return (vec2(u,v) + offset) / (texdim+1);
}
void main(){
    vec3 xyz, scale, normal, vert;

    vec2 uv     = getuv(texdimension, gl_InstanceID, offset);
    xyz.xy      = getcoordinate(xrange, yrange, uv);
    xyz.z       = {{z_calculation}}
    scale.x     = {{xscale_calculation}}
    scale.y     = {{yscale_calculation}}
    scale.z     = {{zscale_calculation}}
    
    vert        = {{vertex_calculation}}
    V           = vec3(getmodelmatrix(xyz, scale) * vec4(vert.xyz, 1.0));

    gl_Position = Vec4(0);
}