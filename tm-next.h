/* Definitions for Next as target machine for GNU C compiler.  */

#include "tm-sun3.h"

#undef CPP_PREDEFINES
#define CPP_PREDEFINES "-Dmc68000 -DNeXT -Dunix -D__MACH__"

#define CPLUSPLUS
#define DOLLARS_IN_IDENTIFIERS
