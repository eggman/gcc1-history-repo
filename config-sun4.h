/* Config file for running GCC on Sunos version 4.
   This file is good for either a Sun 3 or a Sun 4 machine.  */

#include "config-m68k.h"

/* Provide required defaults for linker -e and -d switches.  */

#define LINK_SPEC "%{!e*:-e start} -dc -dp"

#ifdef sparc
#ifndef __GNUC__
#include <alloca.h>
#endif
#endif
