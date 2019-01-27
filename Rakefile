require 'rake/clean'

# The CLEAN files are intermediate files generated during the extension
# building process. These files don't include the final output library, so
# these files can be cleaned up after building, without affecting the use of
# the final library.
#
# The CLOBBER files include the final output library. Clobbering will put the
# project back into its original state.
CLEAN.include('ext/**/*{.c,.o,.log,.so}')
CLEAN.include('ext/**/Makefile')
CLOBBER.include('lib/*.so')

desc 'Build the raylib C extension'
task :raylib do
  # Define defaults for where Raylib may be installed, based on what the Raylib
  # Makefile defaults to. May be overridden by specifying either:
  #
  # - only RAYLIB_INSTALL_PATH
  # - both RAYLIB_HEADER_INSTALL_PATH and RAYLIB_LIB_INSTALL_PATH
  raylib_install_path = ENV['RAYLIB_INSTALL_PATH'] || '/usr/local'
  raylib_header_install_path =
    ENV['RAYLIB_HEADER_INSTALL_PATH'] || "#{raylib_install_path}/include"
  raylib_lib_install_path =
    ENV['RAYLIB_LIB_INSTALL_PATH'] || "#{raylib_install_path}/lib"

  extconf_raylib_path_args = [
    "--with-raylib-include=#{raylib_header_install_path}",
    "--with-raylib-lib=#{raylib_lib_install_path}"
  ].join(' ')

  puts "\033[32mRaylib header directory: #{raylib_header_install_path}\033[0m"
  puts "\033[32mRaylib lib directory: #{raylib_lib_install_path}\033[0m"
  puts

  # Overview of the pipeline:
  #
  # 1. Use SWIG to build a C wrapper.
  # 2. Use `mkmf` to generate a Makefile for the extension.
  # 3. Build the extension.
  # 4. Copy the extension to the `lib` directory.

  Dir.chdir('ext/raylib') do
    sh [
      'swig',
      "-I#{raylib_header_install_path}",
      '-D__STDC__',
      '-D__STDC_VERSION__=199901',
      '-ruby',
      'raylib.i'
    ].join(' ')
    ruby "extconf.rb #{extconf_raylib_path_args}"
    sh 'make'
  end
  cp 'ext/raylib/raylib.so', 'lib/'
end
