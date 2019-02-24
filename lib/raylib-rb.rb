require_relative 'raylib'

# The module containing all the wrapped Raylib functions and data types. Any
# Raylib method that would normally be accessed in the global scope in C is
# available within this module.
#
# Additionally, this module contains some useful, but generally thin,
# abstractions on top of the C functions. These abstractions make use of
# higher-level Ruby idioms, such as blocks and named parameters. Instead of
# attempting to rename individual functions, the goal of these abstractions is
# to codify common patterns that are otherwise verbose in C.
#
# Load the `raylib-rb` file instead of `raylib` to access these abstractions.
#
# Note that the choice of abstractions is driven by the needs of this project.
# A lack of a convenience method doesn't mean the method is not useful, just
# that the corresponding functionality/usage pattern is not present in this
# project.
module Raylib # top-level structure
  # Run the standard Raylib main loop, running the specified code until the
  # window is ready to close, then closing the window.
  #
  # It's crucial that [.draw_with_background] be called as part of the given
  # block. This method is what ends a frame, causing Raylib to wait until
  # enough time has passed for the next frame to begin. If nothing is drawn,
  # the loop will execute without any pause, causing the CPU to reach 100%
  # utilization.
  #
  # A simple example of a main loop would be:
  #
  # ```rb
  # Raylib.main_loop do
  #   x = compute_x
  #   y = compute_y
  #
  #   Raylib.draw_with_background(Raylib::RAYWHITE) do
  #     Raylib.DrawCircle(x, y, 10, Raylib::BLACK)
  #   end
  # end
  # ```
  #
  # @param fps the target frames per second at which to run
  # @see .draw_with_background
  def self.main_loop(fps: 30)
    Raylib.SetTargetFPS(fps)

    yield until Raylib.WindowShouldClose
    Raylib.CloseWindow
  end

  # Run the specified drawing code, making sure to set up the frame and end it.
  # Typical operations during the setup would include resetting the OpenGL
  # matrices, whereas teardown would include waiting for enough time for the
  # next frame to begin.
  #
  # Typically called inside of a [.main_loop] block.
  #
  # @see .main_loop
  def self.draw_with_background(background_color)
    Raylib.BeginDrawing

    Raylib.ClearBackground(background_color)
    yield

    Raylib.EndDrawing
  end
end

module Raylib # colors
  class Color
    # Re-define the auto-generated constructor so parameters can be passed
    # during initialization.

    alias_method :swig_initialize, :initialize
    def initialize(r, g, b, a = 255)
      swig_initialize
      self.r = r
      self.g = g
      self.b = b
      self.a = a
    end
  end

  # Colors defined by Raylib. Because these colors are defined in the C header
  # file as struct initializers, SWIG is unable to translate them to Ruby
  # constants. Duplicate them here for convenience.

  LIGHTGRAY  = Color.new(200, 200, 200, 255)
  GRAY       = Color.new(130, 130, 130, 255)
  DARKGRAY   = Color.new( 80,  80,  80, 255)
  YELLOW     = Color.new(253, 249,   0, 255)
  GOLD       = Color.new(255, 203,   0, 255)
  ORANGE     = Color.new(255, 161,   0, 255)
  PINK       = Color.new(255, 109, 194, 255)
  RED        = Color.new(230,  41,  55, 255)
  MAROON     = Color.new(190,  33,  55, 255)
  GREEN      = Color.new(  0, 228,  48, 255)
  LIME       = Color.new(  0, 158,  47, 255)
  DARKGREEN  = Color.new(  0, 117,  44, 255)
  SKYBLUE    = Color.new(102, 191, 255, 255)
  BLUE       = Color.new(  0, 121, 241, 255)
  DARKBLUE   = Color.new(  0,  82, 172, 255)
  PURPLE     = Color.new(200, 122, 255, 255)
  VIOLET     = Color.new(135,  60, 190, 255)
  DARKPURPLE = Color.new(112,  31, 126, 255)
  BEIGE      = Color.new(211, 176, 131, 255)
  BROWN      = Color.new(127, 106,  79, 255)
  DARKBROWN  = Color.new( 76,  63,  47, 255)

  WHITE      = Color.new(255, 255, 255, 255)
  BLACK      = Color.new(  0,   0,   0, 255)
  BLANK      = Color.new(  0,   0,   0,   0)
  MAGENTA    = Color.new(255,   0, 255, 255)
  RAYWHITE   = Color.new(245, 245, 245, 255)
end

module Raylib # geometry
  class Vector2
    # Re-define the auto-generated constructor so parameters can be passed
    # during initialization.

    alias_method :swig_initialize, :initialize
    def initialize(x, y)
      swig_initialize
      self.x = x
      self.y = y
    end
  end
end

module Raylib # center anchored text
  class CenterAnchoredText
    include Raylib

    def initialize(text, **opts)
      @text = text

      opts = DEFAULT_OPTIONS.merge(opts)
      @font = opts[:font] || GetFontDefault()
      @font_size = opts[:size]
      @color = opts[:color]
      @spacing = @font_size / 10
    end

    def draw_at(cx, cy)
      size = box_size
      top_left_position = Vector2.new(
        (cx - size.x / 2).floor,
        (cy - size.y / 2).floor
      )

      DrawTextEx(@font, @text, top_left_position, @font_size, @spacing, @color)
    end

    def box_size
      MeasureTextEx(@font, @text, @font_size, @spacing)
    end

    private

    DEFAULT_OPTIONS = {
      font: nil,
      size: 16,
      color: BLACK
    }

    private_constant :DEFAULT_OPTIONS
  end
end
