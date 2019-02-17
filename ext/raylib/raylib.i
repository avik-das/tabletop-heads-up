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

// Some of the Raylib functions accept an array as a pointer to the beginning
// of the array, and a count. This is standard practice in C. The problem is,
// in the Ruby interface, we want to pass in a single Ruby array.
//
// The following input typemap converts the pointer + length inputs into a
// single Ruby array. The array is then unwrapped into a newly-created C array,
// which is then passed to the underlying Raylib functions along with the
// length.
%typemap(in, numinputs=1) (Vector2 *points, int numPoints) {
    if (!RB_TYPE_P($input, T_ARRAY)) {
        SWIG_exception_fail(
                SWIG_TypeError,
                Ruby_Format_TypeError(
                    "",
                    "array of struct Vector2 *",
                    "DrawPolyEx",
                    1,
                    $input));
    }

    $2 = RARRAY_LEN($input);
    $1 = malloc($2 * sizeof(Vector2));

    for (int i = 0; i < $2; i++) {
        VALUE entry = rb_ary_entry($input, i);

        void *vec2;
        int res = SWIG_ConvertPtr(entry, &vec2, SWIGTYPE_p_Vector2, 0);

        if (!SWIG_IsOK(res)) {
            SWIG_exception_fail(
                    SWIG_ArgError(res),
                    Ruby_Format_TypeError(
                        "wrong array element type: ",
                        "struct Vector2 *",
                        "DrawPolyEx",
                        i + 1,
                        entry));
        }

        $1[i] = *(Vector2 *)(vec2);
    }
};

// Be sure to clean up the corresponding array from the above typemap.
%typemap(freearg) (Vector2 *points, int numPoints) {
    free($1);
}

// Declarations, which specify which functions and data types will be made
// available by the wrapper to the high-level language.
//
// Automatically use the Raylib header to generate these declarations, which
// allows the wrapper to always be up-to-date. The caveat is that SWIG uses its
// own parser to extract declarations from the header, so care must be taken to
// ensure all the declarations in the header are correctly picked up.
%include "raylib.h"
