# Configures a Makefile that will build the extension. The assumption is that
# SWIG has already been used to generate a C or C++ wrapper file, and this
# Makefile will simply compile and link that wrapper into a shared library.

require 'mkmf'

# Specifies that the location of the Raylib header and library files can be
# configured externally by the user. The name of this configuration does not
# need to match the name of the library, but with this directive, the user can
# specify the following options:
#
#   --with-raylib-dir=prefix
#   --with-raylib-include=directory-with-header
#   --with-raylib-lib=directory-with-library
#
# And the corresponding directories will be added to the include and library
# paths in the generated Makefile.
dir_config('raylib')

# Structure:
#   name
#   [name, description]
#
# The name is used as part of the `-l` directive passed to the compiler. The
# description is a human-readable representation used for error messages. If
# both the name name and the description are the same, the shorter form can be
# used.
#
# TODO: these are the libraries needed on desktop Linux. This will need to be
# updated for other platforms.
REQUIRED_LIBRARIES = [
  'raylib',
  ['m', 'math'],
  'pthread',
  'dl',
  'rt',
  'X11'
]

# Make sure the libraries are included in the linking step.
REQUIRED_LIBRARIES.reverse.each do |lib|
  name, desc = lib.is_a?(Array) ? lib : [lib, lib]
  raise "#{desc} is missing" unless have_library(name)
end

# Generate the actual Makefile, outputting a shared library with the given
# name. In particular, this name should match the `%module` name specified in
# the SWIG interface file.
#
# SWIG will create a wrapper function named `Init_module_name`, and the
# Makefile below will assume the presence of that initialization function.
create_makefile('raylib')
