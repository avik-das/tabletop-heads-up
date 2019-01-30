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
module Raylib
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

  # Helper method to construct a [Color] object.
  def self.color(r, g, b, a = 255)
    col = Color.new
    col.r = r
    col.g = g
    col.b = b
    col.a = a

    col
  end

  # Colors defined by Raylib. Because these colors are defined in the C header
  # file as struct initializers, SWIG is unable to translate them to Ruby
  # constants. Duplicate them here for convenience.

  LIGHTGRAY  = color(200, 200, 200, 255)
  GRAY       = color(130, 130, 130, 255)
  DARKGRAY   = color( 80,  80,  80, 255)
  YELLOW     = color(253, 249,   0, 255)
  GOLD       = color(255, 203,   0, 255)
  ORANGE     = color(255, 161,   0, 255)
  PINK       = color(255, 109, 194, 255)
  RED        = color(230,  41,  55, 255)
  MAROON     = color(190,  33,  55, 255)
  GREEN      = color(  0, 228,  48, 255)
  LIME       = color(  0, 158,  47, 255)
  DARKGREEN  = color(  0, 117,  44, 255)
  SKYBLUE    = color(102, 191, 255, 255)
  BLUE       = color(  0, 121, 241, 255)
  DARKBLUE   = color(  0,  82, 172, 255)
  PURPLE     = color(200, 122, 255, 255)
  VIOLET     = color(135,  60, 190, 255)
  DARKPURPLE = color(112,  31, 126, 255)
  BEIGE      = color(211, 176, 131, 255)
  BROWN      = color(127, 106,  79, 255)
  DARKBROWN  = color( 76,  63,  47, 255)

  WHITE      = color(255, 255, 255, 255)
  BLACK      = color(  0,   0,   0, 255)
  BLANK      = color(  0,   0,   0,   0)
  MAGENTA    = color(255,   0, 255, 255)
  RAYWHITE   = color(245, 245, 245, 255)
end
