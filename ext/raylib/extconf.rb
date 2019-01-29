# Configures a Makefile that will build the extension. The assumption is that
# SWIG has already been used to generate a C or C++ wrapper file, and this
# Makefile will simply compile and link that wrapper into a shared library.

require 'mkmf'

# These platform values are the same ones used by Raylib. This way, the user
# has familiarity with the possible platforms.
#
# This wrapper only supports a subset of all the platforms supported by Raylib.
platform = ENV['PLATFORM'] || 'PLATFORM_DESKTOP'

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

# A library that will be linked into the final extension. By default, only the
# name is specified, in which case the library will be linked as `-lname`.
#
# However, additional options can be specified, such as where to search for the
# library on the system.
class Library
  # - Required: `name`
  # - Optional: `readable_name` - used to display information to the user, such
  #     as error messages
  # - Optional: `paths`: directories where to look for the library
  def initialize(name, opts = {})
    @name = name
    @readable_name = opts[:readable_name] || name
    @paths = opts[:paths] || []
  end

  attr_reader :name, :readable_name, :paths
end

# Notes on the libraries:
#
# - Order matters. When linking, a library that's specified earlier will expose
#   symbols to libraries specified later.
#
#   Furthermore, when actually attempting to find libraries in order to create
#   the Makefile, it seems that some libraries can't be found until other ones
#   have already been found. No idea why...
#
# - Sometimes, multiple libraries are found in the same path. In that case,
#   only the first library that is searched for (which is the last one in the
#   list, see below) needs to specify the `path` option. Once a library is
#   found in a path, `find_library` will automatically search that path for
#   subsequent libraries.
#
#   However, it's good to specify the path in all cases as documentation.
REQUIRED_LIBRARIES =
  case platform
  when 'PLATFORM_DESKTOP'
    [
      Library.new('raylib'),
      Library.new('m', readable_name: 'math'),
      Library.new('pthread'),
      Library.new('dl'),
      Library.new('rt'),
      Library.new('X11')
    ]
  when 'PLATFORM_RPI'
    [
      Library.new('raylib'),
      Library.new('brcmEGL', paths: ['/opt/vc/lib']),
      Library.new('brcmGLESv2', paths: ['/opt/vc/lib']),
      Library.new('pthread'),
      Library.new('rt'),
      Library.new('m', readable_name: 'math'),
      Library.new('bcm_host', paths: ['/opt/vc/lib']),
      Library.new('dl')
    ]
  else raise "Unrecognized platform #{platform}"
  end

# Make sure the libraries are included in the linking step. The libraries will
# be linked in the reverse order of the calls to `find_library`, so search for
# the libraries in reverse order.
REQUIRED_LIBRARIES.reverse.each do |lib|
  raise "#{lib.readable_name} is missing" \
    unless find_library(lib.name, nil, *lib.paths)
end

# Generate the actual Makefile, outputting a shared library with the given
# name. In particular, this name should match the `%module` name specified in
# the SWIG interface file.
#
# SWIG will create a wrapper function named `Init_module_name`, and the
# Makefile below will assume the presence of that initialization function.
create_makefile('raylib')
