#!/usr/bin/env ruby

require_relative 'lib/raylib-rb'

## COMPONENTS #################################################################

# A cache that allows loading a controlled set of fonts at arbitrary sizes. The
# set of loadable fonts is restricted to discourage mixing too many fonts
# throughout the application. In theory, the sizes should be restricted too,
# but it's easiest, during development, to play around with the sizes to see
# what sizes are needed.
#
# This cache only loads each font once at each size. The cache does not unload
# any fonts throughout the lifetime of the application.
class FontCache
  def initialize
    @cache = {}
  end

  def main(size)
    load('RobotoCondensed-Regular.ttf', size)
  end

  def light(size)
    load('RobotoCondensed-Light.ttf', size)
  end

  def bold(size)
    load('RobotoCondensed-Bold.ttf', size)
  end

  private

  def load(name, size)
    @cache[name] ||= {}
    return @cache[name][size] if @cache[name].include?(size)

    # Load fonts with the following parameters:
    #
    # - Load enough characters to cover the characters used in the GUI. In
    #   particular, we want the "degree sign" (U+00B0) in the Latin-1
    #   Supplement block.
    #
    # - Don't bother picking out individual characters from the full set of
    #   characters. Passing in `nil` for the character selection array will
    #   pick out N characters starting at U+0020 ("space"), where N is the
    #   number of characters we want to load.
    @cache[name][size] =
      Raylib.LoadFontEx("resources/fonts/#{name}", size, nil, 224)
  end
end

# A component that displays the specified date and time.
class DateTimeDisplay
  def draw(window, fonts, now)
    date = Raylib::CenterAnchoredText.new(
      now.strftime('%a %-m/%d'),
      font: fonts.main(72),
      size: 72,
      color: Raylib::RAYWHITE
    )

    time = Raylib::CenterAnchoredText.new(
      now.strftime('%-I:%M'),
      font: fonts.bold(96),
      size: 96,
      color: Raylib::RAYWHITE
    )

    date.draw_at(window.w / 2, window.h / 2 - 48)
    time.draw_at(window.w / 2, window.h / 2 + 40)
  end
end

## RENDERING PARAMETERS #######################################################

Window = Struct.new(:w, :h)
WINDOW = Window.new(480, 320)

## MAIN LOOP ##################################################################

Raylib.InitWindow(WINDOW.w, WINDOW.h, 'Pi HUD')

font_cache = FontCache.new
datetime_display = DateTimeDisplay.new

Raylib.main_loop(fps: 10) do
  now = Time.now

  Raylib.draw_with_background(Raylib::BLACK) do
    datetime_display.draw(WINDOW, font_cache, now)
  end
end
