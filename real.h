/* Front-end tree definitions for GNU compiler.
   Copyright (C) 1989 Free Software Foundation, Inc.

This file is part of GNU CC.

GNU CC is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY.  No author or distributor
accepts responsibility to anyone for the consequences of using it
or for whether it serves any particular purpose or works at all,
unless he says so in writing.  Refer to the GNU CC General Public
License for full details.

Everyone is granted permission to copy, modify and redistribute
GNU CC, but only under the conditions described in the
GNU CC General Public License.   A copy of this license is
supposed to have been given to you along with GNU CC so you
can know your rights and responsibilities.  It should be in a
file named COPYING.  Among other things, the copyright notice
and this notice must be preserved on all copies.  */

/* If we are not cross-compiling, use a `double' to represent the
   floating-point value.  Otherwise, use some other type
   (probably a struct containing an array of longs).  */
#ifndef REAL_VALUE_TYPE
#define REAL_VALUE_TYPE double
#else
#define REAL_IS_NOT_DOUBLE
#endif

/* Compare two floating-point values for equality.  */
#ifndef REAL_VALUES_EQUAL
#define REAL_VALUES_EQUAL(x,y) ((x) == (y))
#endif

/* Compare two floating-point values for less than.  */
#ifndef REAL_VALUES_LESS
#define REAL_VALUES_LESS(x,y) ((x) < (y))
#endif

/* Scale X by Y powers of 2.  */
#ifndef REAL_VALUE_LDEXP
#define REAL_VALUE_LDEXP(x,y) ldexp (x, y)
extern double ldexp ();
#endif

/* Convert the string X to a floating-point value.  */
#ifndef REAL_VALUE_ATOF
#define REAL_VALUE_ATOF(x) atof (x)
extern double atof ();
#endif

/* Negate the floating-point value X.  */
#ifndef REAL_VALUE_NEGATE
#define REAL_VALUE_NEGATE(x) (- (x))
#endif

/* Truncate the floating-point value X to single-precision.  */
#ifndef REAL_VALUE_TRUNCATE
#define REAL_VALUE_TRUNCATE(x) ((float) (x))
#endif

/* Union type used for extracting real values from CONST_DOUBLEs
   or putting them in.  */

union real_extract 
{
  REAL_VALUE_TYPE d;
  int i[sizeof (REAL_VALUE_TYPE) / sizeof (int)];
};

/* For a CONST_DOUBLE:
   The usual two ints that hold the value.
   For a DImode, that is all there are.
   For a float, the number of ints varies,
   so use &CONST_DOUBLE_LOW(r) as the address of an array of them.  */
#define CONST_DOUBLE_LOW(r) XINT (r, 2)
#define CONST_DOUBLE_HIGH(r) XINT (r, 3)

/* Link for chain of all CONST_DOUBLEs in use in current function.  */
#define CONST_DOUBLE_CHAIN(r) XEXP (r, 1)
/* The MEM which represents this CONST_DOUBLE's value in memory,
   or const0_rtx if no MEM has been made for it yet,
   or cc0_rtx if it is not on the chain.  */
#define CONST_DOUBLE_MEM(r) XEXP (r, 0)
