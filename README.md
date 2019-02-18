Raspberry Pi Heads-Up Display (HUD)
===================================

Quick Start
-----------

1. Install [Raylib](https://www.raylib.com/). Build a shared library, instead of the default static library:

    ```sh
    cd /path/to/raylib
    cd src

    make RAYLIB_LIBTYPE=SHARED
    ```

1. Install development dependencies. On Debian-based systems:

    ```sh
    sudo apt install build-essential swig
    ```

1. Ensure you have a suitably new version of Ruby, along with its development headers needed to build native extensions. If you're using the system-wide Ruby installation on Debian-based systems:

    ```sh
    sudo apt install ruby ruby-dev
    ```

    I prefer using [rbenv](https://github.com/rbenv/rbenv) and [ruby-build](https://github.com/rbenv/ruby-build) to manage my Ruby installations. This allows me to have multiple installations on the same system.

1. Build the Ruby extension:

    ```sh
    # Install rake
    gem install bundler
    bundle

    # If Raylib is installed to standard location (with include + lib
    # subdirectories). Defaults to `/usr/local` if installed system-wide.
    bundle exec rake raylib RAYLIB_INSTALL_PATH=/path/to/raylib

    # If Raylib is installed to non-standard locations
    bundle exec rake raylib \
        RAYLIB_HEADER_INSTALL_PATH=/path/to/raylib/header \
        RAYLIB_LIB_INSTALL_PATH=/path/to/raylib/lib

    # If compiling on the Raspberry Pi, pass the `PLATFORM` flag. This flag
    # can be combined with the other flags from above.
    bundle exec rake raylib PLATFORM=PLATFORM_RPI
    ```

1. **TODO**: need to run a Ruby application that uses Raylib

Clean up
--------

The intermediate files generated during the building of the extension can be cleaned up:

```sh
# To clean up all intermediate files, but leave the final extension library:
#
#   rake clean
#
# To clean up all build artifacts, including the final extension library:
#
#   rake clobber
```

Notes on using the Raylib bindings
----------------------------------

In addition to automatically generate wrappers around the Raylib functions and data types, this project provides some higher-level Ruby abstractions. To use them, simply load `lib/raylib-rb`. This gives you access to both the original Raylib functions, as well as the Ruby abstractions.

Below is a complete example of a Raylib application built with the bindings:

```rb
require_relative 'lib/raylib-rb'

Raylib.InitWindow(480, 320, "Ruby Raylib test")

Raylib.main_loop(fps: 30) do
  now = Time.now.to_f * 3
  x = (Math.cos(now) * 150 + 240).floor

  Raylib.draw_with_background(Raylib::RAYWHITE) do
    Raylib.DrawCircle(x, 160, 50, Raylib::MAROON)
  end
end
```

Packaged Dependencies
---------------------

### Roboto Condensed Font

- [Homepage](https://fonts.google.com/specimen/Roboto+Condensed?selection.family=Roboto+Condensed)
- Licensed under the [Apache License, version 2.0](http://www.apache.org/licenses/LICENSE-2.0)
