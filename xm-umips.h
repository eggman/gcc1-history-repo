/* Configuration for GNU C-compiler for UMIPS operating system
   Copyright (C) 1987 Free Software Foundation, Inc.

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

/*
 *  Notes for compiling gcc on umips (v3.0)
 *	- change the -g in the CFLAGS to a -g3 or take it out all together.
 *	- do not define DBX_DEBUGGING_INFO in tm.h, it doesn't exist (unless
 *	you get one from a bsd system)
 */
#include "xm-mips.h"

/* Arguments to use with `exit'.  */
#define SUCCESS_EXIT_CODE 0
#define FATAL_EXIT_CODE 33

/* If compiled with GNU C, use the built-in alloca */
#ifdef __GNUC__
#define alloca __builtin_alloca
#endif

#define USG

/* for the emacs version of alloca */
#define STACK_DIRECTION	-1

#define bcopy(a,b,c)	memcpy((b),(a),(c))
#define bzero(a,b)	memset((a),0,(b))
#define bcmp(a,b,c)	memcmp((a),(b),(c))
