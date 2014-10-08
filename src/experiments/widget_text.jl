using ModernGL, GLAbstraction, GLWindow, GLFW, Reactive, ImmutableArrays, Images, GLText, Quaternions, Color, FixedPointNumbers, ApproxFun
using GLPlot


immutable GLGlyph{T} <: TextureCompatible
  glyph::T
  line::T
  row::T
  style_index::T

end
function GLGlyph(glyph::Char, line::Integer, row::Integer, style_index::Integer)
  if !isascii(glyph)
    glyph = char('1')
  end
  GLGlyph{Uint16}(uint16(glyph), uint16(line), uint16(row), uint16(style_index))
end
GLGlyph() = GLGlyph(' ', typemax(Uint16), typemax(Uint16), 0)

immutable Style{StyleValue}
end

window  = createdisplay(w=1920, h=1080, windowhints=[
  (GLFW.SAMPLES, 0), 
  (GLFW.DEPTH_BITS, 0), 
  (GLFW.ALPHA_BITS, 0), 
  (GLFW.STENCIL_BITS, 0),
  (GLFW.AUX_BUFFERS, 0)
])

mousepos = window.inputs[:mouseposition]

pcamera   = OrthographicPixelCamera(window.inputs)

sourcedir = Pkg.dir("GLPlot", "src", "experiments")
shaderdir = sourcedir

parameters = [
        (GL_TEXTURE_WRAP_S,  GL_CLAMP_TO_EDGE),
        (GL_TEXTURE_WRAP_T,  GL_CLAMP_TO_EDGE ),

        (GL_TEXTURE_MIN_FILTER, GL_NEAREST),
        (GL_TEXTURE_MAG_FILTER, GL_NEAREST) 
]

fb = glGenFramebuffers()
glBindFramebuffer(GL_FRAMEBUFFER, fb)

framebuffsize = [window.inputs[:framebuffer_size].value]

color     = Texture(RGBA{Ufixed8},     framebuffsize, parameters=parameters)
stencil   = Texture(Vector2{GLushort}, framebuffsize, parameters=parameters)

glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, color.id, 0)
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, stencil.id, 0)

rboDepthStencil = GLuint[0]

glGenRenderbuffers(1, rboDepthStencil)
glBindRenderbuffer(GL_RENDERBUFFER, rboDepthStencil[1])
glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, framebuffsize...)
glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, rboDepthStencil[1])

lift(window.inputs[:framebuffer_size]) do window_size
  resize!(color, window_size)
  resize!(stencil, window_size)
  glBindRenderbuffer(GL_RENDERBUFFER, rboDepthStencil[1])
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, window_size...)
end


selectiondata = Input(Vector2(0))



RGBAU8 = AlphaColorValue{RGB{Ufixed8}, Ufixed8}
rgba(r::Real, g::Real, b::Real, a::Real) = AlphaColorValue(RGB{Float32}(r,g,b), float32(a))
rgbaU8(r::Real, g::Real, b::Real, a::Real) = AlphaColorValue(RGB{Ufixed8}(r,g,b), ufixed8(a))

#GLPlot.toopengl{T <: AbstractRGB}(colorinput::Input{T}) = toopengl(lift(x->AlphaColorValue(x, one(T)), RGBA{T}, colorinput))
tohsv(rgba)     = AlphaColorValue(convert(HSV, rgba.c), rgba.alpha)
torgb(hsva)     = AlphaColorValue(convert(RGB, hsva.c), hsva.alpha)
tohsv(h,s,v,a)  = AlphaColorValue(HSV(float32(h), float32(s), float32(v)), float32(a))

Base.length{T}(::GLGlyph{T})                   = 4
Base.length{T}(::Type{GLGlyph{T}})             = 4
Base.eltype{T}(::GLGlyph{T})                   = T
Base.eltype{T}(::Type{GLGlyph{T}})             = T
Base.size{T}(::GLGlyph{T})                     = (4,)

GLGlyph(x::GLGlyph; glyph=x.glyph, line=x.line, row=x.row, style_index=x.style_index) = GLGlyph(glyph, line, row, style_index)

import Base: (+)

function (+){T}(a::Array{GLGlyph{T}, 1}, b::GLGlyph{T})
  for i=1:length(a)
    a[i] = a[i] + b
  end
end
function (+){T}(a::GLGlyph{T}, b::GLGlyph{T})
  GLGlyph{T}(a.glyph + b.glyph, a.line + b.line, a.row + b.row, a.style_index + b.style_index)
end

Style(x::Symbol) = Style{x}()
mergedefault!{S}(style::Style{S}, styles, customdata) = merge!(Dict{Symbol, Any}(customdata), styles[S])

#################################################################################################################################
#Text Rendering:
TEXT_DEFAULTS = [
:Default => [
  :start            => Vec3(0),
  :offset           => Vec2(1, 1.5), #Multiplicator for advance, newline
  :color            => rgbaU8(248.0/255.0, 248.0/255.0,242.0/255.0, 1.0),
  :backgroundcolor  => rgba(0,0,0,0),
  :model            => eye(Mat4),
  :newline          => -Vec3(0, getfont().props[1][2], 0),
  :advance          => Vec3(getfont().props[1][1], 0, 0),
  :camera           => pcamera
]
]
# High Level text rendering for one line or multi line text, which is decided by searching for the occurence of '\n' in text
GLPlot.toopengl(text::String,                 style=Style(:Default); customization...) = toopengl(style, text, mergedefault!(style, TEXT_DEFAULTS, customization))
# Low level text rendering for one line text
GLPlot.toopengl(text::Texture{GLGlyph, 1, 1}, style=Style(:Default); customization...) = toopengl(style, text, mergedefault!(style, TEXT_DEFAULTS, customization))
# Low level text rendering for multiple line text
GLPlot.toopengl(text::Texture{GLGlyph, 1, 2}, style=Style(:Default); customization...) = toopengl(style, text, mergedefault!(style, TEXT_DEFAULTS, customization))

# END Text Rendering
#################################################################################################################################



function makecompatible(glyph::Char, typ)
  if int(glyph) >= 0 && int(glyph) <= 255
    return convert(typ, glyph)
  else
    return convert(typ, 0)
  end
end
operators = [":", ";","=", "+", "-", "!", "¬", "~", "<", ">","=", "/", "&", "|", "\$", "*"]
brackets  = ["(", ")", "[", "]", "{", "}"]
keywords  = ["for", "end", "while", "if", "elseif", "using", "return", "in", "function", "local", "global", "let", "quote", "begin", "const", "do", "false", "true"]

regex_literals = ['|', '[', ']', '*', '.', '?', '\\', '(', ')', '{', '}', '+', '-', '$']

function escape_regex(x::String)
    result = ""
    for elem in x
        if elem in regex_literals
            result *= string('\\')
        end
        result *= string(elem)
    end
    result
end
regreduce(arr, prefix="(", suffix=")") = Regex(reduce((v0, x) -> v0*"|"*prefix*escape_regex(x)*suffix, prefix*escape_regex(arr[1])*suffix, arr[2:end]))
operators         = regreduce(operators)
brackets          = regreduce(brackets)
keywords          = regreduce(keywords, "((?<![[:alpha:]])", "(?![[:alpha:]]))")
comments          = r"(#=.*=#)|(#.*[\n\r])"
stringalike_regex = r"(\".*\")|('.*')|((?<!:):[[:alpha:]][[:alpha:]_]*)"
function_regex    = r"(?<![[:alpha:]])[[:graph:]]*\("

function colorize(color, substrings, colortexture)
    for elem in substrings
        startorigin = elem.offset+1
        stoporigin  = elem.offset+elem.endof

        colortexture[startorigin:stoporigin] = [GLGlyph(elem.glyph, elem.line, elem.row, color) for elem in colortexture[startorigin:stoporigin]]
    end
end


#=
The text needs to be uploaded into a 2D texture, with 1D alignement, as there is no way to vary the row length, which would be a big waste of memory.
This is why there is the need, to prepare offsets information about where exactly new lines reside.
If the string doesn't contain a new line, the text is restricted to one line, which is uploaded into one 1D texture.
This is important for differentiation between multi-line and single line text, which might need different treatment
=#
function GLPlot.toopengl(style::Style{:Default}, text::String, data::Dict{Symbol, Any})
  global operators, brackets, keywords, string_regex, function_regex, comments
  if contains(text, "\n")
    tab         = 3
    text        = map(x-> isascii(x) ? x : char(1), text)
    text        = utf8(replace(text, "\t", " "^tab)) # replace tabs

    #Allocate some more memory, to reduce growing the texture residing on VRAM
    texturesize = (div(length(text),     1024) + 1) * 2 # a texture size of 1024 should be supported on every GPU
    text_array  = Array(GLGlyph{Uint16}, 1024, texturesize)

    line        = 1
    advance     = 0
    for i=1:length(text_array)
      if i <= length(text)
        glyph = text[i]
        text_array[i] = GLGlyph(glyph, line, advance, 0)
        if glyph == '\n'
          advance = 0
          line += 1
        else
          advance += 1
        end
      else # Fill in default value
        text_array[i] = GLGlyph()
      end
    end

    operators_match         = matchall(operators,         text)
    brackets_match          = matchall(brackets,          text)
    keywords_match          = matchall(keywords,          text)
    stringalike_regex_match = matchall(stringalike_regex, text)
    function_regex_match    = matchall(function_regex,    text)
    comments_match          = matchall(comments,          text)

    color_lookup = Texture([
      data[:color],
      rgbaU8(48/256.0, 178/256.0, 223/256.0, 1.0), 
      rgbaU8(250/256.0, 30/256.0, 100/256.0, 1.0),
      rgbaU8(198/256.0, 180/256.0, 39/256.0, 1.0),      
      rgbaU8(75/256.0, 70/256.0, 65/256.0, 1.0),      
    ])
#    colorize(rgbaU8(0.6,0.6,0,1), string_regex_match, colorarray)
    colorize(uint16(2), operators_match,         text_array)
    colorize(uint16(1), brackets_match,          text_array)
    colorize(uint16(2), keywords_match,          text_array)
    colorize(uint16(1), function_regex_match,    text_array)
    colorize(uint16(3), stringalike_regex_match, text_array)
    colorize(uint16(4), comments_match,          text_array)
    # To make things simple for now, checks if the texture is too big for the GPU are done by 'Texture' and an error gets thrown there.
    data[:color_lookup] = color_lookup
    data[:textlength]   = length(text)
    data[:lines]        = line

    return toopengl(style, Texture(text_array), data)
  else
    #return toopengl(style, Texture(reinterpret(GLGlyph{Uint8}, convert(Array{Uint8}, text))), data)
  end
end


# This is the low-level text interface, which simply prepares the correct shader and cameras
function GLPlot.toopengl(::Style{:Default}, text::Texture{GLGlyph{Uint16}, 4, 2}, data::Dict{Symbol, Any})
  camera        = data[:camera]
  font          = getfont()
  renderdata    = merge(data, font.data) # merge font texture and uv informations -> details @ GLFont/src/types.jl
  linesize      = font.props[1][2] * data[:lines]

  renderdata[:model] = eye(Mat4) * translationmatrix(Vec3(20,1080-20,0))

  view = [
    "GLSL_EXTENSIONS" => "#extension GL_ARB_draw_instanced : enable"
  ] 

  renderdata[:text]           = text
  renderdata[:projectionview] = camera.projectionview
  shader = TemplateProgram(
    Pkg.dir("GLText", "src", "textShader.vert"), Pkg.dir("GLText", "src", "textShader.frag"), 
    view=view, attributes=renderdata, fragdatalocation=[(0, "fragment_color"),(1, "fragment_groupid")]
  )
  obj = instancedobject(renderdata, shader, data[:textlength])
  obj[:prerender, enabletransparency] = ()
  return obj
end

TEXT_EDIT_DEFAULTS = (Symbol => Any)[:Default => (Symbol => Any)[]]
edit(text::Texture{GLGlyph{Uint16}, 4, 2}, id, style=Style(:Default); customization...) = edit(style, text, id, mergedefault!(style, TEXT_EDIT_DEFAULTS, customization))

# Filters a signal. If any of the items is in the signal, the signal is returned.
# Otherwise default is returned
function filteritems{T}(a::Signal{T}, items, default::T)
  lift(a) do signal
    if any(item-> in(item, signal), items)
      signal
    else
      default 
    end
  end
end

function edit_text(v0, selection1, unicode_keys, special_keys)
  # selection0 tracks, where the carsor is after a new character addition, selection10 tracks the old selection
  id, textlength, textGPU, text0, selection0, selection10 = v0
  v1 = (id, textlength, textGPU, text0, selection0, selection1)
  changed = false 
  try
    # to compare it to the newly selected mouse position
    if selection10 != selection1
      v1 = (id, textlength, textGPU, text0, selection1, selection1)
    elseif !isempty(special_keys) && isempty(unicode_keys)
      if in(GLFW.KEY_BACKSPACE, special_keys)
        text0 = delete!(text0, selection0[2])
        textlength -= 1
        changed = true
        v1 = (id, textlength, textGPU, text0, selection0 - Vector2(0,1), selection1)
      elseif in(GLFW.KEY_ENTER, special_keys)
        text0 = addnewline!(text0, '\n', selection0[2])
        textlength += 1
        changed = true
        v1 = (id, textlength, textGPU, text0, selection0 + Vector2(0,1), selection1)
      end
    elseif !isempty(unicode_keys) && selection0[1] == id # else unicode input must have occured
      text0 = addchar(text0, first(unicode_keys), selection0[2])
      textlength += 1
      changed = true
      v1 = (id, textlength, textGPU, text0, selection0 + Vector2(0,1), selection1)
    end

    if changed
      if textlength > length(text0) || length(text0) % 1024 != 0
        newlength = 1024 - rem(length(text0)+1024, 1024)
        text0     = [text0, Array(GLGlyph{Uint16}, newlength)]
        resize!(textGPU, [1024, div(length(text0),1024)])
      end
      textGPU[1:0, 1:0] = reshape(text0, 1024, div(length(text0),1024))
    end
  catch err
    Base.show_backtrace(STDERR, catch_backtrace())
    println(err)
  end

  return v1
end

function edit(style::Style{:Default}, textGPU::Texture{GLGlyph{Uint16}, 4, 2}, id::GLushort, custumization::Dict{Symbol, Any})
  specialkeys = filteritems(window.inputs[:buttonspressed], [GLFW.KEY_ENTER, GLFW.KEY_BACKSPACE], IntSet())
  # Filter out the selected index, 
  leftclick_selection = foldl((Vector2(-1)), selectiondata, window.inputs[:mousebuttonspressed]) do v0, data, buttons
    if !isempty(buttons) && first(buttons) == 0  # if any button is pressed && its the left button
      data #return index
    else
      v0
    end
  end
  text      = vec(data(textGPU))

  v00       = (id, length(text), textGPU, text, leftclick_selection.value, leftclick_selection.value)
  testinput = foldl(edit_text, v00, leftclick_selection, window.inputs[:unicodeinput], specialkeys)
    # selection0 tracks, where the carsor is after a new character addition, selection10 tracks the old selection
end
function Base.delete!(s::Array{GLGlyph{Uint16}, 1}, Index::Integer)
  if Index == 0
    return s
  elseif Index == length(s)
    return s[1:end-1]
  end
  if s[Index].glyph == '\n'
    newline_occured = false
    for j=Index+1:length(s)
      if !newline_occured
        newline_occured = '\n' == s[j].glyph
      end
      s[j] = s[j] + GLGlyph{Uint16}(zero(Uint16), -one(Uint16), newline_occured ? zero(Uint16) : s[Index].row, zero(Uint16))
    end
  else
    for j=Index+1:length(s)

      s[j] = s[j] + GLGlyph{Uint16}(zero(Uint16),zero(Uint16), -one(Uint16),zero(Uint16))
      if s[j].glyph == '\n'
        break
      end
    end
  end
  return [s[1:Index-1], s[Index+1:end]]
end

function addchar(s::Array{GLGlyph{Uint16}, 1}, char::Char, Index::Integer)
  if Index == 0
    for j=Index+1:length(s)
      if s[j].glyph == '\n'
        break
      end
      s[j] = s[j] + GLGlyph{Uint16}(zero(Uint16),zero(Uint16),one(Uint16),zero(Uint16))
    end
    return [GLGlyph{Uint16}(char,1,1,1,0), s]
  elseif Index == length(s)
    return [s, GLGlyph{Uint16}(char, s[end].line, s[end].row+one(Uint16), s[end].style_index)]
  elseif Index > length(s) || Index < 0
    return s
  end
  for j=Index+1:length(s)
    if s[j].glyph == '\n'
      break
    end
    s[j] = s[j] + GLGlyph{Uint16}(zero(Uint16),zero(Uint16),one(Uint16),zero(Uint16))
  end
  return [s[1:Index], GLGlyph{Uint16}(char, s[Index].line, s[Index].row+one(Uint16), s[Index].style_index), s[Index+1:end]]
end

function addnewline!(s::Array{GLGlyph{Uint16}, 1}, char::Char, Index::Integer)
  newline_occured = false
  advance = 0
  for j=Index+1:length(s)
    if !newline_occured
      advance += 1
      newline_occured = '\n' == s[j].glyph
    end
    s[j] = GLGlyph{Uint16}(s[j].glyph, s[j].line + 1, newline_occured ? s[j].row : advance, s[j].style_index)
  end
  if Index == 0
    return [GLGlyph{Uint16}(char,1,0,0), s]
  elseif Index == length(s)
    return [s, GLGlyph{Uint16}(char, s[end].line, s[end].row+one(Uint16), s[end].style_index)]
  elseif Index > length(s) || Index < 0
    return s
  end
  addline = s[Index].line
  row     = s[Index].row+one(Uint16)
  if Index > 0 && s[Index].glyph == '\n'
    addline += 1
    row = 0
  end
  return [s[1:Index], GLGlyph{Uint16}(char, addline, row, s[Index].style_index), s[Index+1:end]]
end



obj = toopengl(readall(open(Pkg.dir("GLPlot", "src", "experiments", "widget_text.jl"))))



edit(obj[:text], obj.id)




lift(x-> glViewport(0,0,x...), window.inputs[:framebuffer_size])
glClearColor(39.0/255.0, 40.0/255.0, 34.0/255.0, 1.0)
function renderloop()
  render(obj)
end


const mousehover = Vector2{GLushort}[Vector2{GLushort}(0,0)]
runner = 0
while !GLFW.WindowShouldClose(window.glfwWindow)
  yield() # this is needed for react to work
  glBindFramebuffer(GL_FRAMEBUFFER, fb)
  glDrawBuffers(2, [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1])
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
  renderloop()

  if runner % 15 == 0
    mousex, mousey = int([window.inputs[:mouseposition].value])
    glReadBuffer(GL_COLOR_ATTACHMENT1) 
    glReadPixels(mousex, mousey, 1,1, stencil.format, stencil.pixeltype, mousehover)
    @async push!(selectiondata, convert(Vector2{Int}, mousehover[1]))
  end


  glReadBuffer(GL_COLOR_ATTACHMENT0)
  glBindFramebuffer(GL_READ_FRAMEBUFFER, fb)
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0)
  glClear(GL_COLOR_BUFFER_BIT)

  window_size = window.inputs[:framebuffer_size].value
  glBlitFramebuffer(0,0, window_size..., 0,0, window_size..., GL_COLOR_BUFFER_BIT, GL_NEAREST)
  yield()

  GLFW.SwapBuffers(window.glfwWindow)
  GLFW.PollEvents()
  
  runner += 1
end
GLFW.Terminate()