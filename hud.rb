#!/usr/bin/env ruby

require_relative 'lib/raylib-rb'
require_relative 'lib/task'

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

class ImageCache
  def initialize
    @cache = {}
  end

  def image(path)
    return @cache[path] if @cache.include?(path)

    @cache[path] = Raylib.LoadTexture("resources/#{path}")
  end
end

# A non-rendering component that runs a specified [TASK] at a requested
# interval, making the retrieved data available along with indication of any
# errors.
class AutoRefreshingData
  def initialize(refresh_interval, &fetcher)
    @data = nil
    @state = :loading

    @refresh_interval = refresh_interval
    @last_refresh_time = Time.at(0)
    @fetcher = fetcher
    @task = nil
  end

  def on_tick(now)
    if @task.nil?
      @task = Task.new(&@fetcher) \
        if now - @last_refresh_time > @refresh_interval

      # If not enough time has passed, wait for the next tick to check again.
    elsif @task.is_finished?
      @data = @task.result
      @task = nil
      @last_refresh_time = now
      @state = :loaded
    elsif @task.has_errored?
      # Keep the existing data
      @task = nil
      @last_refresh_time = now
      @state = :error
    end

    # If the task has not finished, successfully or unsuccesfully, then wait
    # for the next tick to check again.
  end

  attr_reader :data, :last_refresh_time, :state
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

# A component that displays the current weather. Manages retrieving the weather
# data in order to display it.
class WeatherDisplay
  Weather = Struct.new(:icon, :temp, :description)

  def initialize
    # TODO:
    #   - Retrieve real weather data
    #   - Set the refresh interval accordingly
    @current_weather = AutoRefreshingData.new(REFRESH_INTERVAL_SECONDS) do
      sleep 1

      if rand < 0.3
        raise 'failed'
      else
        Weather.new(
          Dir
            .glob('resources/icons/*.png')
            .map { |png| File.basename(png)[0..2] }
            .sample,
          rand(0..25),
          ['Sunny', 'Mist', 'Rain', 'Cloudy'].sample
        )
      end
    end

    @icon_cache = ImageCache.new
  end

  def on_tick(now)
    @current_weather.on_tick(now)
  end

  def draw(window, fonts, now)
    if @current_weather.data.nil?
      show_loading(window, fonts)
    else
      show_weather(window, fonts, @current_weather.data)
    end

    case @current_weather.state
    when :loaded
      show_last_refreshed_time(
        window,
        fonts,
        @current_weather.last_refresh_time
      )
    when :error
      show_error(window, fonts)
    end
  end

  private

  REFRESH_INTERVAL_SECONDS = 2
  private_constant :REFRESH_INTERVAL_SECONDS

  def show_loading(window, fonts)
    text = Raylib::CenterAnchoredText.new(
      'Loading weather...',
      font: fonts.main(48),
      size: 48,
      color: Raylib::RAYWHITE
    )

    text.draw_at(window.w / 2, window.h / 2)
  end

  def show_weather(window, fonts, current_weather)
    icon = icon_for_current_weather(current_weather)
    Raylib.DrawTexture(
      icon,
      window.w * 5 / 24,
      window.h / 2 - 72,
      Raylib::WHITE
    )

    temp = Raylib::CenterAnchoredText.new(
      current_weather.temp.to_s,
      font: fonts.bold(96),
      size: 96,
      color: Raylib::RAYWHITE
    )

    unit = Raylib::CenterAnchoredText.new(
      '°C',
      font: fonts.main(64),
      size: 64,
      color: Raylib::RAYWHITE
    )

    desc = Raylib::CenterAnchoredText.new(
      current_weather.description,
      font: fonts.light(48),
      size: 48,
      color: Raylib::RAYWHITE
    )

    temp_padding = 8

    temp_w = temp.box_size.x
    temp_x = (window.w * 5 / 8).floor
    temp_y = window.h / 2 - 48

    unit_w = unit.box_size.x
    unit_x = temp_x + temp_w / 2 + temp_padding + unit_w / 2
    unit_y = temp_y - 8

    desc_x = temp_x - temp_w / 2 + (temp_w + temp_padding + unit_w) / 2
    desc_y = temp_y + 64

    temp.draw_at(temp_x, temp_y)
    unit.draw_at(unit_x, unit_y)
    desc.draw_at(desc_x, desc_y)
  end

  def icon_for_current_weather(current_weather)
    path = "icons/#{current_weather.icon}.png"
    @icon_cache.image(path)
  end

  def show_last_refreshed_time(window, fonts, time)
    Raylib::CenterAnchoredText.new(
      "Last refreshed at #{time.strftime('%-I:%M')}",
      font: fonts.light(24),
      size: 24,
      color: Raylib::LIGHTGRAY
    ).draw_at(window.w / 2, window.h - 48)
  end

  def show_error(window, fonts)
    Raylib::CenterAnchoredText.new(
      'Last refresh failed',
      font: fonts.light(24),
      size: 24,
      color: Raylib::RED
    ).draw_at(window.w / 2, window.h - 48)
  end
end

## RENDERING PARAMETERS #######################################################

Window = Struct.new(:w, :h)
WINDOW = Window.new(480, 320)

## MAIN LOOP ##################################################################

Raylib.InitWindow(WINDOW.w, WINDOW.h, 'Pi HUD')

font_cache = FontCache.new
datetime_display = DateTimeDisplay.new
weather_display = WeatherDisplay.new

Raylib.main_loop(fps: 10) do
  now = Time.now
  weather_display.on_tick(now)

  Raylib.draw_with_background(Raylib::BLACK) do
    # TODO: switch between pages instead of showing only one
    # datetime_display.draw(WINDOW, font_cache, now)
    weather_display.draw(WINDOW, font_cache, now)
  end
end
