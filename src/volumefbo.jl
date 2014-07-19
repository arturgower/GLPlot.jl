using GLWindow, GLUtil, ModernGL, ImmutableArrays, GLFW, React, Images

framebuffdims = [1500, 1500]
window  = createwindow("Mesh Display", framebuffdims..., debugging = false)
cam     = Cam(window.inputs, Vector3(1.5f0, 1.5f0, 1.0f0))

shaderdir = Pkg.dir()*"/GLPlot/src/shader/"


shader              = GLProgram(shaderdir*"simple.vert", shaderdir*"iso.frag")
uvwshader           = GLProgram(shaderdir*"uvwposition")



file = shaderdir*"iso.frag"
function trackfilesource(file::ASCIIString)
  filetracker = lift(delta -> mtime(file), Float64, Timing.every(0.1))
  filediff = foldl((v0, v1) -> begin
    (v1, v1 - v0[1])
  end, (mtime(file), 1.0), filetracker)

  filechanged = filter(x -> x[2] != 0.0, (1.0, 1.0), filediff)

  lift(x -> readall(open(file)) , ASCIIString, filechanged)
end

vertsource = trackfilesource(shaderdir*"simple.vert")
fragsource = trackfilesource(shaderdir*"iso.frag")

lift((vsource,fsource) -> begin 
  update(vsource, fsource, file, shader.id)
end, vertsource, fragsource)


fb = glGenFramebuffers()

immutable Pivot
  position
  rotation
end
v, uvw, indexes = gencube(1f0, 1f0, 1f0)
cubedata = [
    :vertex         => GLBuffer(v, 3),
    :uvw            => GLBuffer(uvw, 3),
    :indexes        => GLBuffer(indexes, 1, buffertype = GL_ELEMENT_ARRAY_BUFFER),
    :projectionview => cam.projectionview
]


function genuvwcube(x,y,z)
  v, uvw, indexes = gencube(x,y,z)
  cubeobj = RenderObject([
    :vertex         => GLBuffer(v, 3),
    :uvw            => GLBuffer(uvw, 3),
    :indexes        => indexbuffer(indexes),
    :projectionview => cam.projectionview
  ], uvwshader)

  frontface = Texture(GLfloat, 4, framebuffdims)
  backface = Texture(GLfloat, 4, framebuffdims)

  lift(windowsize -> begin
    glBindTexture(texturetype(frontface), frontface.id)
    glTexImage(0, frontface.internalformat, windowsize..., 0, frontface.format, frontface.pixeltype, C_NULL)
    glBindTexture(texturetype(backface), backface.id)
    glTexImage(0, backface.internalformat, windowsize..., 0, backface.format, backface.pixeltype, C_NULL)
  end, window.inputs[:window_size])

  rendersetup = () -> begin
      glBindFramebuffer(GL_FRAMEBUFFER, fb)
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, backface.id, 0)
      glClearColor(1,1,1,0)
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

      glDisable(GL_DEPTH_TEST)
      glEnable(GL_CULL_FACE)
      glCullFace(GL_FRONT)
      render(cubeobj.vertexarray)

      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, frontface.id, 0)
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

      glDisable(GL_DEPTH_TEST)
      glEnable(GL_CULL_FACE)
      glCullFace(GL_BACK)
      render(cubeobj.vertexarray)

      glBindFramebuffer(GL_FRAMEBUFFER, 0)
  end

  postrender!(cubeobj, rendersetup)

  cubeobj, frontface, backface

end

cube1,frontf1, backf1 = genuvwcube(1f0, 1f0, 1f0 )
cube2,frontf2, backf2 = genuvwcube(0.1f0, 1f0, 1f0)


N = 56
volume = Float32[sin(x / 4f0)+sin(y / 4f0)+sin(z / 4f0) for x=1:N, y=1:N, z=1:N]
max = maximum(volume)
min = minimum(volume)
volume = (volume .- min) ./ (max .- min)
texparams = [
   (GL_TEXTURE_MIN_FILTER, GL_LINEAR),
  (GL_TEXTURE_MAG_FILTER, GL_LINEAR),
  (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
  (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE),
  (GL_TEXTURE_WRAP_R,  GL_CLAMP_TO_EDGE)

]

keypressed = keepwhen(lift(x-> x==1 ,Bool, window.inputs[:keypressedstate]) , 0, window.inputs[:keypressed])
isovalue 	= foldl((a,b) -> begin
				if b == GLFW.KEY_O
					return a-0.01f0
				elseif b == GLFW.KEY_P
					return a+0.01f0
				end
				a
			end, 0.5f0,keypressed)

algorithm  = lift(x -> begin
        if x == GLFW.KEY_M
          return 1f0
        elseif x == GLFW.KEY_I
          return 2f0
        end 
      end, filter(x-> x == GLFW.KEY_M || x == GLFW.KEY_I, GLFW.KEY_I, keypressed))

delete!(cubedata, :uvw)

cubedata[:frontface1]    = frontf1
cubedata[:backface1]     = backf1
cubedata[:backface2]     = backf2
cubedata[:frontface2]    = frontf2

cubedata[:volume_tex]    = Texture(volume, 1, parameters=texparams)
cubedata[:stepsize]      = 0.001f0
cubedata[:isovalue]      = isovalue
cubedata[:algorithm]     = algorithm

cubedata[:light_position] = Vec3(2, 2, -2)

cube = RenderObject(cubedata, shader)

prerender!(cube, glEnable, GL_DEPTH_TEST, glEnable, GL_CULL_FACE, glCullFace, GL_BACK, enabletransparency)
postrender!(cube, render, cube.vertexarray)

glClearColor(0,0,0,1)
glClearDepth(1)

include("grid.jl")
while !GLFW.WindowShouldClose(window.glfwWindow)

  render(cube1)
  render(cube2)

  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
  render(axis)
  render(cube)

  GLFW.SwapBuffers(window.glfwWindow)
  GLFW.PollEvents()
  sleep(0.1)
end
GLFW.Terminate()
