/* Subroutines for insn-output.c for Convex.
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

/*
 *  set_cmp (left_rtx, right_rtx, [bhwlsd])
 *  gen_cmp (label_rtx, cmpop, [tf])
 *
 *  set_cmp saves the operands of a "cmp" insn,
 *    along with the type character to be used in the compare instruction.
 *
 *  gen_cmp finds out what comparison is to be performed and
 *    outputs the necessary instructions, eg,
 *    "eq.w a1,a2 ! jbra.t L5"
 *    for (cmpsi a1 a2) (beq L5)
 *  if necessary, it reverses the order of the operands to put a constant first
 *  the operands of eq can be swapped without changing the sense
 *    of the test; swapping the operands of lt changes it to le with
 *    the branch sense reversed, and similarly for le.
 */
 
static rtx xop0, xop1;
static char typech, regch;

char *
set_cmp (op0, op1, typechr)
     rtx op0, op1;
     char typechr;
{
  xop0 = op0;
  xop1 = op1;
  typech = typechr;
  if (GET_CODE (op0) == REG)
    regch = REGNO_OK_FOR_BASE_P (REGNO (op0)) ? 'a' : 's';
  else if (GET_CODE (op1) == REG)
    regch = REGNO_OK_FOR_BASE_P (REGNO (op1)) ? 'a' : 's';
  else abort ();
  return "";
}

char *
gen_cmp (label, cmpop, tf)
     rtx label;
     char *cmpop;
     char tf;
{
  char buf[80];
  char revop[4];
  rtx ops[3];

  ops[2] = label;

  /* constant must be first; swap operands if necessary
     if lt, le, ltu, leu are swapped, change to le, lt, leu, ltu
     and reverse the sense of the jump */

  if (CONSTANT_P (xop1) || GET_CODE (xop1) == CONST_DOUBLE)
    {
      ops[0] = xop1;
      ops[1] = xop0;
      if (cmpop[0] == 'l')
	{
	  bcopy (cmpop, revop, 4);
	  revop[1] ^= 'e' ^ 't';
	  tf ^= 't' ^ 'f';
	  cmpop = revop;
	}
    }
  else
    {
      ops[0] = xop0;
      ops[1] = xop1;
    }

  sprintf (buf, "%s.%c %%0,%%1! jbr%c.%c %%l2", cmpop, typech, regch, tf);
  output_asm_insn (buf, ops);
  return "";
}

/*
 *  set_section -- arg is a section name, like ".text".  
 *	Remembers it and returns it
 *
 *  align_section -- returns a string to align current section,
 *	something like ".text 2" or ".align 8".  Arg is log2 of boundary.
 */

static char *prevsect = "";
static char *cursect = "";

char *
set_section (p)
     char *p;
{
  if (p == 0)
    p = prevsect;
  prevsect = cursect;
  cursect = p;
  return p;
}

char *
align_section (n)
     int n;
{
  static char buf[20];

  if (n < 0)
    {
      /* -n is a size; align to that size */
      if ((n & 7) == 0) n = 3;
      else if ((n & 3) == 0) n = 2;
      else if ((n & 1) == 0) n = 1;
      else n = 0;
    }

  if (!strcmp (cursect, ".text"))
    {
      if (n > 1)
	sprintf (buf, "%s %d\n", cursect, n);
      else
	sprintf (buf, "%s\n.align %d\n", cursect, 1 << n);
      return buf;
    }
  else
    {
      if (n == 0) return "";
      sprintf (buf, ".align %d\n", 1 << n);
      return buf;
    }
}

/*
 *  calls like  (*f)()  generate  calls @n(ap)  -- invalid, since ap 
 *  has been changed for the call.  Detect this case so the instruction
 *   pattern can deal with it.
 */

call_ap_check (addr)
     rtx addr;
{
  if (GET_CODE (addr) != MEM)
    return 0;
  addr = XEXP (addr, 0);
  if (GET_CODE (addr) != MEM)
    return 0;
  addr = XEXP (addr, 0);
  if (REG_P (addr) && REGNO (addr) == ARG_POINTER_REGNUM)
    return 1;
  if (GET_CODE (addr) != PLUS)
    return 0;
  addr = XEXP (addr, 0);
  if (REG_P (addr) && REGNO (addr) == ARG_POINTER_REGNUM)
    return 1;
  return 0;
}

/*
 *  pick target machine if not specified, the same as the host
 */

extern int target_flags;

override_options ()
{
#ifdef convex
#include <sys/sysinfo.h>    
  if (! (TARGET_C1 || TARGET_C2))
    {
      struct system_information sysinfo;
      getsysinfo (sizeof sysinfo, &sysinfo);
      if (sysinfo.cpu_type >= SI_CPUTYPE_C2MP)
	target_flags |= 2;
      else
	target_flags |= 1;
    }
#endif
}

