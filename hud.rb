#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'net/http'
require 'ostruct'

require_relative 'lib/raylib-rb'
require_relative 'lib/task'

LOGGER = Logger.new(STDOUT)
LOGGER.level = Logger::INFO
at_exit do LOGGER.close end

## NETWORK REQUESTS ###########################################################

# A set of methods to allow fetching weather data from the OpenWeatherMap API.
# The methods that fetch data should be run in a separate thread to avoid
# blocking the UI. The suggested use is to run the methods inside of a [Task].
module WeatherNetworkRetriever
  OPEN_WEATHER_APP_ID_KEY = 'OPEN_WEATHER_APPID'

  WeatherDataPoint = Struct.new(:timestamp, :icon, :temp, :description)
  Forecast = Struct.new(:predictions)

  # Call this method to check if the App ID needed to access the OpenWeatherMap
  # API is present. Perform this check early in order to exit early if the App
  # ID has not been specified by the user.
  def self.open_weather_app_id_present?
    ENV.include?(OPEN_WEATHER_APP_ID_KEY)
  end

  def self.fetch_current_weather
    app_id = ENV[OPEN_WEATHER_APP_ID_KEY]
    res = Net::HTTP.get_response(
      'api.openweathermap.org',
      "/data/2.5/weather?id=5400075&units=metric&APPID=#{app_id}"
    )

    raise "Current weather API returned #{res.code}" unless res.code == '200'
    begin
      data = JSON.parse(res.body, object_class: OpenStruct)
      validate_weather_data_point(data)

      current_weather = WeatherDataPoint.new(
        Time.at(data.dt),
        data.weather[0].icon,
        data.main.temp.floor,
        data.weather[0].main
      )

      LOGGER.info { 'Fetched current weather' }

      current_weather
    rescue
      LOGGER.error { "Could not parse current weather response: #{res.body}" }
      raise
    end
  end

  def self.fetch_forecast
    app_id = ENV[OPEN_WEATHER_APP_ID_KEY]
    res = Net::HTTP.get_response(
      'api.openweathermap.org',
      "/data/2.5/forecast?id=5400075&units=metric&APPID=#{app_id}"
    )

    raise "Forecast weather API returned #{res.code}" unless res.code == '200'
    begin
      data = JSON.parse(res.body, object_class: OpenStruct)
      data.list.each do |prediction|
        validate_weather_data_point(prediction)
      end

      predictions = data
        .list
        .map { |prediction|
          WeatherDataPoint.new(
            Time.at(prediction.dt),
            prediction.weather[0].icon,
            prediction.main.temp.floor,
            prediction.weather[0].main
          )
        }
        .sort_by(&:timestamp)
      raise 'No forecast data found' if predictions.empty?

      forecast = Forecast.new(predictions)

      LOGGER.info { 'Fetched weather forecast' }

      forecast
    rescue
      LOGGER.error { "Could not parse weather forecast response: #{res.body}" }
      raise
    end
  end

  private

  def self.validate_weather_data_point(data_point)
      raise 'Weather data_point has no timestamp' unless data_point.dt

      raise 'No temperature found' \
        unless data_point.main and data_point.main.temp

      raise 'No weather condition found' \
        unless data_point.weather and
          data_point.weather.kind_of?(Array) and
          data_point.weather[0] and
          data_point.weather[0].main and
          data_point.weather[0].icon
  end
end

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

# A carousel consisting of multiple "pages". Features:
#
# - Each page displays for a set amount of time, then the display switches to
#   the next page in the rotation.
#
# - The user can click to force a page switch. After doing so, the user cannot
#   force a page flip for some amount of time (typically less than the amount
#   of time required for the next page to display automatically).
class Carousel
  def initialize(now)
    @pages = [
      DateTimeDisplay.new,
      WeatherDisplay.new,
      WeatherForecastDisplay.new
    ]

    @last_click_time = Time.at(0)

    @current_page_index = 0
    @page_start_time = now
    @page_switch_time_left = -1
  end

  def on_tick(now)
    advance_page(now) if now - @page_start_time > PAGE_SWITCH_SECONDS

    @page_switch_time_left = @page_start_time + PAGE_SWITCH_SECONDS - now

    # Allow all the pages, even the ones that are not currently rendering, to
    # update their internal state as necessary.
    @pages.each { |page| page.on_tick(now) }
  end

  def on_mouse_click(now)
    if now - @last_click_time >= CLICK_THROTTLE_SECONDS
      @last_click_time = now
      advance_page(now)
    end
  end

  def draw(window, fonts, now)
    current_page.draw(window, fonts, now)
  end

  private

  CLICK_THROTTLE_SECONDS = 0.5
  PAGE_SWITCH_SECONDS = 15
  private_constant \
    :CLICK_THROTTLE_SECONDS,
    :PAGE_SWITCH_SECONDS

  def current_page; @pages[@current_page_index]; end

  def advance_page(now)
    @page_start_time = now
    @current_page_index = (@current_page_index + 1) % @pages.size
  end
end

# A component that displays the specified date and time.
class DateTimeDisplay
  def on_tick(now)
    # Do nothing
  end

  def draw(window, fonts, now)
    date = Raylib::AnchoredText.new(
      now.strftime('%a %-m/%d'),
      :center,
      font: fonts.main(72),
      size: 72,
      color: Raylib::RAYWHITE
    )

    time = Raylib::AnchoredText.new(
      now.strftime('%-I:%M'),
      :center,
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
  def initialize
    @current_weather = AutoRefreshingData.new(REFRESH_INTERVAL_SECONDS) do
      WeatherNetworkRetriever.fetch_current_weather
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

  REFRESH_INTERVAL_SECONDS = 60
  private_constant :REFRESH_INTERVAL_SECONDS

  def show_loading(window, fonts)
    text = Raylib::AnchoredText.new(
      'Loading weather...',
      :center,
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

    temp = Raylib::AnchoredText.new(
      current_weather.temp.to_s,
      :center,
      font: fonts.bold(96),
      size: 96,
      color: Raylib::RAYWHITE
    )

    unit = Raylib::AnchoredText.new(
      '°C',
      :top_left,
      font: fonts.main(64),
      size: 64,
      color: Raylib::RAYWHITE
    )

    desc = Raylib::AnchoredText.new(
      current_weather.description,
      :center,
      font: fonts.light(48),
      size: 48,
      color: Raylib::RAYWHITE
    )

    temp_padding = 8

    temp_w = temp.box_size.x
    temp_h = temp.box_size.y
    temp_x = (window.w * 5 / 8).floor
    temp_y = window.h / 2 - 48

    unit_w = unit.box_size.x
    unit_x = temp_x + temp_w / 2 + temp_padding
    unit_y = temp_y - temp_h / 2 + 6

    desc_x = temp_x - temp_w / 2 + (temp_w + temp_padding + unit_w) / 2
    desc_y = temp_y + 72

    temp.draw_at(temp_x, temp_y)
    unit.draw_at(unit_x, unit_y)
    desc.draw_at(desc_x, desc_y)
  end

  def icon_for_current_weather(current_weather)
    path = "icons/#{current_weather.icon}.png"
    @icon_cache.image(path)
  end

  def show_last_refreshed_time(window, fonts, time)
    Raylib::AnchoredText.new(
      "Last refreshed at #{time.strftime('%-I:%M')}",
      :center,
      font: fonts.light(24),
      size: 24,
      color: Raylib::LIGHTGRAY
    ).draw_at(window.w / 2, window.h - 48)
  end

  def show_error(window, fonts)
    Raylib::AnchoredText.new(
      'Last refresh failed',
      :center,
      font: fonts.light(24),
      size: 24,
      color: Raylib::RED
    ).draw_at(window.w / 2, window.h - 48)
  end
end

# A component that displays the weather forecast for the current data. Manages
# retrieving the weather data in order to display it.
class WeatherForecastDisplay
  def initialize
    @forecast = AutoRefreshingData.new(REFRESH_INTERVAL_SECONDS) do
      WeatherNetworkRetriever.fetch_forecast
    end

    @icon_cache = ImageCache.new
  end

  def on_tick(now)
    @forecast.on_tick(now)
  end

  def draw(window, fonts, now)
    if @forecast.data.nil?
      show_loading(window, fonts)
    else
      show_forecast(window, fonts, @forecast.data)
    end

    case @forecast.state
    when :loaded
      show_last_refreshed_time(
        window,
        fonts,
        @forecast.last_refresh_time
      )
    when :error
      show_error(window, fonts)
    end
  end

  private

  MAX_PREDICTIONS_TO_SHOW = 4
  SIDE_PADDING = 32
  REFRESH_INTERVAL_SECONDS = 60

  private_constant \
    :MAX_PREDICTIONS_TO_SHOW,
    :REFRESH_INTERVAL_SECONDS

  def show_loading(window, fonts)
    text = Raylib::AnchoredText.new(
      'Loading forecast...',
      :center,
      font: fonts.main(48),
      size: 48,
      color: Raylib::RAYWHITE
    )

    text.draw_at(window.w / 2, window.h / 2)
  end

  def show_forecast(window, fonts, forecast)
    predictions = forecast.predictions.take(MAX_PREDICTIONS_TO_SHOW)
    return if predictions.empty?

    max_temp = predictions.max_by(&:temp).temp
    min_temp = predictions.min_by(&:temp).temp

    if (max_temp - min_temp) < 1
      temp_ys = predictions.map { |_| 202 }
    else
      temp_ys = predictions
        .map(&:temp)
        .map { |temp|
          (224 - (temp - min_temp).to_f / (max_temp - min_temp) * 44).floor
        }
    end

    column_w = (window.w - SIDE_PADDING * 2) / predictions.size
    column_xs = (0...predictions.size)
      .map { |i| SIDE_PADDING + column_w * i + column_w / 2 }

    predictions
      .take(predictions.size - 1)
      .each_with_index do |prediction, i|
        Raylib.DrawLineEx(
          Raylib::Vector2.new(column_xs[i], temp_ys[i]),
          Raylib::Vector2.new(column_xs[i + 1], temp_ys[i + 1]),
          2,
          Raylib::DARKGRAY
        )
      end

    predictions.each_with_index do |prediction, i|
      column_x = column_xs[i]

      Raylib::AnchoredText.new(
        prediction.timestamp.strftime('%-I %p'),
        :center,
        font: fonts.light(32),
        size: 32,
        color: Raylib::RAYWHITE
      ).draw_at(column_x, 72)

      icon = icon_for_prediction(prediction)
      Raylib.DrawTextureEx(
        icon,
        Raylib::Vector2.new(
          column_x - 20,
          104
        ),
        0,   # rotation
        0.4, # scale
        Raylib::WHITE
      )

      Raylib.DrawCircle(column_x, temp_ys[i], 36, Raylib::BLACK)

      Raylib::AnchoredText.new(
        "#{prediction.temp}°",
        :center,
        font: fonts.main(32),
        size: 32,
        color: Raylib::RAYWHITE
      ).draw_at(column_x, temp_ys[i])
    end
  end

  def icon_for_prediction(prediction)
    path = "icons/#{prediction.icon}.png"
    @icon_cache.image(path)
  end

  def show_last_refreshed_time(window, fonts, time)
    Raylib::AnchoredText.new(
      "Last refreshed at #{time.strftime('%-I:%M')}",
      :center,
      font: fonts.light(24),
      size: 24,
      color: Raylib::LIGHTGRAY
    ).draw_at(window.w / 2, window.h - 48)
  end

  def show_error(window, fonts)
    Raylib::AnchoredText.new(
      'Last refresh failed',
      :center,
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

unless WeatherNetworkRetriever.open_weather_app_id_present?
  message = "ERR: '#{WeatherNetworkRetriever::OPEN_WEATHER_APP_ID_KEY}' " +
    'environment variable not present'
  puts message
  exit 1
end

Raylib.InitWindow(WINDOW.w, WINDOW.h, 'Pi HUD')

font_cache = FontCache.new
app = Carousel.new(Time.now)

Raylib.main_loop(fps: 10) do
  now = Time.now
  app.on_tick(now)
  app.on_mouse_click(now) \
    if Raylib.IsMouseButtonPressed(Raylib::MOUSE_LEFT_BUTTON)

  Raylib.draw_with_background(Raylib::BLACK) do
    app.draw(WINDOW, font_cache, now)
  end
end
