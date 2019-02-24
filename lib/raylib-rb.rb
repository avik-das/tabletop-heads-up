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

module Raylib # anchored text
  # An anchored text box, where the properties of the text box, like the text
  # itself as well as the font size, are specified once and the text box
  # rendered multiple times.
  #
  # There are two main differences from the native text-rendering functionality
  # in Raylib:
  #
  # - The abiltiy to specify a different anchor than the top-left. This allows
  #   specifying cooordinates in terms, say, the center of the text.
  #
  # - An object-oriented interface to text-related functionality in Raylib. For
  #   example, with Raylib functions, you would use `MeasureTextEx` to
  #   determine the size of some rendered text. This approach uses a function
  #   that's independent of the `DrawTextEx` function used to render the text.
  #
  #   With [AnchoredText], you can call [#box_size] directly on the text box
  #   object, keeping the rendering and measuring functionality close by.
  class AnchoredText
    include Raylib

    # @param text [String] the text to render
    # @param anchor [Symbol]
    #   Where to anchor the text when rendering. Options:
    #
    #   - `:center` - coordinates reference the horizontal and vertical center
    #     of the rendered text
    #
    #   - `:top_left` - coordinates reference the top-left corner of the
    #     rendered text. This is the same anchoring used by the native
    #     `DrawTextEx` function in Raylib.
    #
    # @param opts [Hash] all options have default values
    def initialize(text, anchor, **opts)
      @text = text
      @anchor = anchor

      opts = DEFAULT_OPTIONS.merge(opts)
      @font = opts[:font] || GetFontDefault()
      @font_size = opts[:size]
      @color = opts[:color]
      @spacing = @font_size / 10

      @box_size = calculate_box_size
    end

    # Render this text box at the given coordinates. The coordinates reference
    # the anchor configured for this text box.
    def draw_at(ax, ay)
      DrawTextEx(
        @font,
        @text,
        top_left_position_from_anchor_position(ax, ay),
        @font_size,
        @spacing,
        @color
      )
    end

    attr_reader :box_size

    private

    DEFAULT_OPTIONS = {
      # Note: the default font can't be assigned at the time the class is
      # loaded. This is because no default font is available until Raylib is
      # initialized.
      #
      # Thus, defer retrieving the default font until an instance of this class
      # is instantiated.

      size: 16,
      color: BLACK
    }

    private_constant :DEFAULT_OPTIONS

    def calculate_box_size
      MeasureTextEx(@font, @text, @font_size, @spacing)
    end

    def top_left_position_from_anchor_position(ax, ay)
      case @anchor
      when :center
        Vector2.new(
          (ax - @box_size.x / 2).floor,
          (ay - @box_size.y / 2).floor
        )
      when :top_left then Vector2.new(ax, ay)
      else raise "Invalid anchor: #{@anchor}"
      end
    end
  end
end
