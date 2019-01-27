/**
 * The SWIG interface file for Raylib. This interface file is meant to be as
 * light as possible, in order to ensure minimal work is required to keep the
 * generated wrapper up-to-date with the source library.
 */

// Defines the name of the generated wrapper. For example, in Ruby, this
// results in a module named `Raylib` that will house the Ruby wrapper methods.
%module raylib

// Header section, to be inserted into the generated wrapper file. The main
// directive is to make the Raylib header available to the wrapper code, so
// that Raylib functions and data types can be referenced by the wrapper.
%{
  #include <raylib.h>
%}

// Declarations, which specify which functions and data types will be made
// available by the wrapper to the high-level language.
//
// Automatically use the Raylib header to generate these declarations, which
// allows the wrapper to always be up-to-date. The caveat is that SWIG uses its
// own parser to extract declarations from the header, so care must be taken to
// ensure all the declarations in the header are correctly picked up.
%include "raylib.h"
