/* Convert RTL to assembler code and output it, for GNU compiler.
   Copyright (C) 1987, 1988 Free Software Foundation, Inc.

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


/* This is the final pass of the compiler.
   It looks at the rtl code for a function and outputs assembler code.

   Call `final_start_function' to output the assembler code for function entry,
   `final' to output assembler code for some RTL code,
   `final_end_function' to output assembler code for function exit.
   If a function is compiled in several pieces, each piece is
   output separately with `final'.

   Some optimizations are also done at this level.
   Move instructions that were made unnecessary by good register allocation
   are detected and omitted from the output.  (Though most of these
   are removed by the last jump pass.)

   Instructions to set the condition codes are omitted when it can be
   seen that the condition codes already had the desired values.

   In some cases it is sufficient if the inherited condition codes
   have related values, but this may require the following insn
   (the one that tests the condition codes) to be modified.

   The code for the function prologue and epilogue are generated
   directly as assembler code by the macros FUNCTION_PROLOGUE and
   FUNCTION_EPILOGUE.  Those instructions never exist as rtl.  */

#include <stdio.h>
#include "config.h"
#include "rtl.h"
#include "regs.h"
#include "insn-config.h"
#include "recog.h"
#include "conditions.h"
#include "gdbfiles.h"
#include "flags.h"

/* Get N_SLINE and N_SOL from stab.h if we can expect the file to exist.  */
#ifdef DBX_DEBUGGING_INFO
#include <stab.h>
#endif

/* .stabd code for line number.  */
#ifndef N_SLINE
#define	N_SLINE	0x44
#endif

/* .stabs code for included file name.  */
#ifndef N_SOL
#define	N_SOL 0x84
#endif

#define min(A,B) ((A) < (B) ? (A) : (B))

void output_asm_insn ();
rtx alter_subreg ();
static int alter_cond ();
void output_asm_label ();
static void output_operand ();
void output_address ();
void output_addr_const ();
static void output_source_line ();

/* the sdb debugger needs the line given as an offset from the beginning
   of the current function -wfs*/

extern int sdb_begin_function_line;

/* Line number of last NOTE.  */
static int last_linenum;

/* Nonzero while outputting an `asm' with operands.
   This means that inconsistencies are the user's fault, so don't abort.
   The precise value is the insn being output, to pass to error_for_asm.  */
static rtx this_is_asm_operands;

/* Number of operands of this insn, for an `asm' with operands.  */
static int insn_noperands;

/* Indexed by hard register, the name of the register for assembler code.  */

static char *reg_name[] = REGISTER_NAMES;

/* File in which assembler code is being written.  */

extern FILE *asm_out_file;

/* All the symbol-blocks (levels of scoping) in the compilation
   are assigned sequence numbers in order of appearance of the
   beginnings of the symbol-blocks.  Both final and dbxout do this,
   and assume that they will both give the same number to each block.
   Final uses these sequence numbers to generate assembler label names
   LBBnnn and LBEnnn for the beginning and end of the symbol-block.
   Dbxout uses the sequence nunbers to generate references to the same labels
   from the dbx debugging information.

   Sdb records this level at the beginning
   of each function, so that when it recurses down the declarations, it may
   find the current level, since it outputs the block beginning and endings
   at the point in the asm file, where the blocks would begin and end.  */

int next_block_index;

/* Chain of all `struct gdbfile's.  */

struct gdbfile *gdbfiles;

/* `struct gdbfile' for the last file we wrote a line number for.  */

static struct gdbfile *current_gdbfile;

/* Filenum to assign to the next distinct source file encountered.  */

static int next_gdb_filenum;

/* This variable contains machine-dependent flags (defined in tm-...h)
   set and examined by output routines
   that describe how to interpret the condition codes properly.  */

CC_STATUS cc_status;

/* During output of an insn, this contains a copy of cc_status
   from before the insn.  */

CC_STATUS cc_prev_status;

/* Last source file name mentioned in a NOTE insn.  */

static char *lastfile;

/* Indexed by hardware reg number, is 1 if that register is ever
   used in the current function.

   In life_analysis, or in stupid_life_analysis, this is set
   up to record the hard regs used explicitly.  Reload adds
   in the hard regs used for holding pseudo regs.  Final uses
   it to generate the code in the function prologue and epilogue
   to save and restore registers as needed.  */

char regs_ever_live[FIRST_PSEUDO_REGISTER];

/* Nonzero means current function must be given a frame pointer.
   Set in stmt.c if anything is allocated on the stack there.
   Set in reload1.c if anything is allocated on the stack there.  */

int frame_pointer_needed;

/* Assign unique numbers to labels generated for profiling.  */

int profile_label_no;

/* Length so far allocated in PENDING_BLOCKS.  */

static int max_block_depth;

/* Stack of sequence numbers of symbol-blocks of which we have seen the
   beginning but not yet the end.  Sequence numbers are assigned at
   the beginning; this stack allows us to find the sequence number
   of a block that is ending.  */

static int *pending_blocks;

/* Number of elements currently in use in PENDING_BLOCKS.  */

static int block_depth;

/* Nonzero if have enabled APP processing of our assembler output.  */

static int app_on;

/* Initialize data in final at the beginning of a compilation.  */

void
init_final (filename)
     char *filename;
{
  next_block_index = 2;
  lastfile = filename;
  app_on = 0;
  max_block_depth = 20;
  pending_blocks = (int *) xmalloc (20 * sizeof *pending_blocks);
  gdbfiles = 0;
  next_gdb_filenum = 0;
}

/* Enable APP processing of subsequent output.
   Used before the output from an `asm' statement.  */

void
app_enable ()
{
  if (! app_on)
    {
      fprintf (asm_out_file, ASM_APP_ON);
      app_on = 1;
    }
}

/* Enable APP processing of subsequent output.
   Called from varasm.c before most kinds of output.  */

void
app_disable ()
{
  if (app_on)
    {
      fprintf (asm_out_file, ASM_APP_OFF);
      app_on = 0;
    }
}

/* Output assembler code for the start of a function,
   and initialize some of the variables in this file
   for the new function.  The label for the function and associated
   assembler pseudo-ops have already been output in `assemble_function'.

   FIRST is the first insn of the rtl for the function being compiled.
   FILE is the file to write assembler code to.
   WRITE_SYMBOLS says which kind of debugging info to write (or none).
   OPTIMIZE is nonzero if we should eliminate redundant
     test and compare insns.  */

void
final_start_function (first, file, write_symbols, optimize)
     rtx first;
     FILE *file;
     enum debugger write_symbols;
     int optimize;
{
  block_depth = 0;

  this_is_asm_operands = 0;

  /* Record beginning of the symbol-block that's the entire function.  */

  if (write_symbols == GDB_DEBUG)
    {
      pending_blocks[block_depth++] = next_block_index;
      fprintf (file, "\t.gdbbeg %d\n", next_block_index++);
    }

  /* Initial line number is supposed to be output
     before the function's prologue and label
     so that the function's address will not appear to be
     in the last statement of the preceding function.  */
  if (NOTE_LINE_NUMBER (first) != NOTE_INSN_DELETED)
    output_source_line (file, first, write_symbols);

#ifdef FUNCTION_PROLOGUE
  /* First output the function prologue: code to set up the stack frame.  */
  FUNCTION_PROLOGUE (file, get_frame_size ());
#endif

#ifdef SDB_DEBUGGING_INFO
  next_block_index = 1;
  if (write_symbols == SDB_DEBUG)
    sdbout_begin_function (last_linenum);
#endif

  if (profile_flag)
    {
      int align = min (BIGGEST_ALIGNMENT, BITS_PER_WORD);
      extern int current_function_returns_struct;
      extern int current_function_needs_context;
      int sval = current_function_returns_struct;
      int cxt = current_function_needs_context;
      data_section ();
      ASM_OUTPUT_ALIGN (file, floor_log2 (align / BITS_PER_UNIT));
      ASM_OUTPUT_INTERNAL_LABEL (file, "LP", profile_label_no);
      assemble_integer_zero ();
      text_section ();

#ifdef STRUCT_VALUE_INCOMING_REGNUM
      if (sval)
	ASM_OUTPUT_REG_PUSH (file, STRUCT_VALUE_INCOMING_REGNUM);
#else
#ifdef STRUCT_VALUE_REGNUM
      if (sval)
	ASM_OUTPUT_REG_PUSH (file, STRUCT_VALUE_REGNUM);
#endif
#endif

#if 0
#ifdef STATIC_CHAIN_INCOMING_REGNUM
      if (cxt)
	ASM_OUTPUT_REG_PUSH (file, STATIC_CHAIN_INCOMING_REGNUM);
#else
#ifdef STATIC_CHAIN_REGNUM
      if (cxt)
	ASM_OUTPUT_REG_PUSH (file, STATIC_CHAIN_REGNUM);
#endif
#endif
#endif /* 0 */

      FUNCTION_PROFILER (file, profile_label_no);
      profile_label_no++;

#if 0
#ifdef STATIC_CHAIN_INCOMING_REGNUM
      if (cxt)
	ASM_OUTPUT_REG_POP (file, STATIC_CHAIN_INCOMING_REGNUM);
#else
#ifdef STATIC_CHAIN_REGNUM
      if (cxt)
	ASM_OUTPUT_REG_POP (file, STATIC_CHAIN_REGNUM);
#endif
#endif
#endif /* 0 */

#ifdef STRUCT_VALUE_INCOMING_REGNUM
      if (sval)
	ASM_OUTPUT_REG_POP (file, STRUCT_VALUE_INCOMING_REGNUM);
#else
#ifdef STRUCT_VALUE_REGNUM
      if (sval)
	ASM_OUTPUT_REG_POP (file, STRUCT_VALUE_REGNUM);
#endif
#endif
    }
}

/* Output assembler code for the end of a function.
   For clarity, args are same as those of `final_start_function'
   even though not all of them are needed.  */

void
final_end_function (first, file, write_symbols, optimize)
     rtx first;
     FILE *file;
     enum debugger write_symbols;
     int optimize;
{
  if (app_on)
    {
      fprintf (file, ASM_APP_OFF);
      app_on = 0;
    }

  if (write_symbols == GDB_DEBUG)
    fprintf (file, "\t.gdbend %d\n", pending_blocks[0]);

#ifdef SDB_DEBUGGING_INFO
  if (write_symbols == SDB_DEBUG)
    sdbout_end_function (last_linenum);
#endif

#ifdef FUNCTION_EPILOGUE
  /* Finally, output the function epilogue:
     code to restore the stack frame and return to the caller.  */
  FUNCTION_EPILOGUE (file, get_frame_size ());
#endif

#ifdef SDB_DEBUGGING_INFO
  if (write_symbols == SDB_DEBUG)
    sdbout_end_epilogue ();
#endif

  /* If FUNCTION_EPILOGUE is not defined, then the function body
     itself contains return instructions wherever needed.  */
}

/* Output assembler code for some insns: all or part of a function.
   For description of args, see `final_start_function', above.

   PRESCAN is 1 if we are not really outputting,
     just scanning as if we were outputting.
   Prescanning deletes and rearranges insns just like ordinary output.
   PRESCAN is -2 if we are outputting after having prescanned.
   In this case, don't try to delete or rearrange insns
   because that has already been done.
   Prescanning is done only on certain machines.  */

void
final (first, file, write_symbols, optimize, prescan)
     rtx first;
     FILE *file;
     enum debugger write_symbols;
     int optimize;
     int prescan;
{
  register rtx insn;
  register int i;

  init_recog ();

  CC_STATUS_INIT;

  for (insn = NEXT_INSN (first); insn; insn = NEXT_INSN (insn))
    {
      switch (GET_CODE (insn))
	{
	case NOTE:
	  if (prescan > 0)
	    break;
	  if (write_symbols == NO_DEBUG)
	    break;
	  if (NOTE_LINE_NUMBER (insn) == NOTE_INSN_FUNCTION_BEG)
	    abort ();		/* Obsolete; shouldn't appear */
	  if (NOTE_LINE_NUMBER (insn) == NOTE_INSN_LOOP_BEG
	      || NOTE_LINE_NUMBER (insn) == NOTE_INSN_LOOP_END)
	    break;
	  if (NOTE_LINE_NUMBER (insn) == NOTE_INSN_DELETED)
	    break;		/* An insn that was "deleted" */
	  if (app_on)
	    {
	      fprintf (file, ASM_APP_OFF);
	      app_on = 0;
	    }
	  if (NOTE_LINE_NUMBER (insn) == NOTE_INSN_BLOCK_BEG)
	    {
	      /* Beginning of a symbol-block.  Assign it a sequence number
		 and push the number onto the stack PENDING_BLOCKS.  */

	      if (block_depth == max_block_depth)
		{
		  /* PENDING_BLOCKS is full; make it longer.  */
		  max_block_depth *= 2;
		  pending_blocks
		    = (int *) xrealloc (pending_blocks,
					max_block_depth * sizeof (int));
		}
	      pending_blocks[block_depth++] = next_block_index;

	      /* Output debugging info about the symbol-block beginning.  */

#ifdef SDB_DEBUGGING_INFO
	      if (write_symbols == SDB_DEBUG)
		sdbout_begin_block (file, last_linenum, next_block_index);
#endif
#ifdef DBX_DEBUGGING_INFO
	      if (write_symbols == DBX_DEBUG)
		ASM_OUTPUT_INTERNAL_LABEL (file, "LBB", next_block_index);
#endif
	      if (write_symbols == GDB_DEBUG)
		fprintf (file, "\t.gdbbeg %d\n", next_block_index);

	      next_block_index++;
	    }
	  else if (NOTE_LINE_NUMBER (insn) == NOTE_INSN_BLOCK_END)
	    {
	      /* End of a symbol-block.  Pop its sequence number off
		 PENDING_BLOCKS and output debugging info based on that.  */

	      --block_depth;

#ifdef DBX_DEBUGGING_INFO
	      if (write_symbols == DBX_DEBUG && block_depth >= 0)
		ASM_OUTPUT_INTERNAL_LABEL (file, "LBE",
					   pending_blocks[block_depth]);
#endif

#ifdef SDB_DEBUGGING_INFO
	      if (write_symbols == SDB_DEBUG && block_depth >= 0)
		sdbout_end_block (file, last_linenum);
#endif

	      if (write_symbols == GDB_DEBUG)
		fprintf (file, "\t.gdbend %d\n", pending_blocks[block_depth]);
	    }
	  else if (NOTE_LINE_NUMBER (insn) > 0)
	    /* This note is a line-number.  */
	    output_source_line (file, insn, write_symbols);
	  break;

	case BARRIER:
#ifdef ASM_OUTPUT_ALIGN_CODE
	  ASM_OUTPUT_ALIGN_CODE (file);
#endif
	  break;

	case CODE_LABEL:
	  CC_STATUS_INIT;
	  if (prescan > 0)
	    break;
	  if (app_on)
	    {
	      fprintf (file, ASM_APP_OFF);
	      app_on = 0;
	    }
#ifdef ASM_OUTPUT_CASE_LABEL
	  if (NEXT_INSN (insn) != 0
	      && GET_CODE (NEXT_INSN (insn)) == JUMP_INSN)
	    {
	      rtx nextbody = PATTERN (NEXT_INSN (insn));

	      /* If this label is followed by a jump-table,
		 output the two of them together in a special way.  */

	      if (GET_CODE (nextbody) == ADDR_VEC
		  || GET_CODE (nextbody) == ADDR_DIFF_VEC)
		{
		  ASM_OUTPUT_CASE_LABEL (file, "L", CODE_LABEL_NUMBER (insn),
					 NEXT_INSN (insn));
		  break;
		}
	    }
#endif

	  ASM_OUTPUT_INTERNAL_LABEL (file, "L", CODE_LABEL_NUMBER (insn));
	  break;

	default:
	  {
	    register rtx body = PATTERN (insn);
	    int insn_code_number;
	    char *template;

	    /* An INSN, JUMP_INSN or CALL_INSN.
	       First check for special kinds that recog doesn't recognize.  */

	    if (GET_CODE (body) == USE /* These are just declarations */
		|| GET_CODE (body) == CLOBBER)
	      break;
	    if (GET_CODE (body) == ASM_INPUT)
	      {
		/* There's no telling what that did to the condition codes.  */
		CC_STATUS_INIT;
		if (prescan > 0)
		  break;
		if (! app_on)
		  {
		    fprintf (file, ASM_APP_ON);
		    app_on = 1;
		  }
		fprintf (asm_out_file, "\t%s\n", XSTR (body, 0));
		break;
	      }

	    /* Detect `asm' construct with operands.  */
	    if (asm_noperands (body) >= 0)
	      {
		int noperands = asm_noperands (body);
		rtx *ops;
		char *string;

		/* There's no telling what that did to the condition codes.  */
		CC_STATUS_INIT;
		if (prescan > 0)
		  break;

		/* alloca won't do here, since only return from `final'
		   would free it.  */
		if (noperands > 0)
		  ops = (rtx *) xmalloc (noperands * sizeof (rtx));

		if (! app_on)
		  {
		    fprintf (file, ASM_APP_ON);
		    app_on = 1;
		  }

		/* Get out the operand values.  */
		string = decode_asm_operands (body, ops, 0, 0, 0);
		/* Inhibit aborts on what would otherwise be compiler bugs.  */
		insn_noperands = noperands;
		this_is_asm_operands = insn;
		/* Output the insn using them.  */
		output_asm_insn (string, ops);
		this_is_asm_operands = 0;
		if (noperands > 0)
		  free (ops);
		break;
	      }

	    if (prescan <= 0 && app_on)
	      {
		fprintf (file, ASM_APP_OFF);
		app_on = 0;
	      }

	    /* Detect insns that are really jump-tables
	       and output them as such.  */

	    if (GET_CODE (body) == ADDR_VEC)
	      {
		register int vlen, idx;

		if (prescan > 0)
		  break;

		vlen = XVECLEN (body, 0);
		for (idx = 0; idx < vlen; idx++)
		  ASM_OUTPUT_ADDR_VEC_ELT (file,
			   CODE_LABEL_NUMBER (XEXP (XVECEXP (body, 0, idx), 0)));
#ifdef ASM_OUTPUT_CASE_END
		ASM_OUTPUT_CASE_END (file,
				     CODE_LABEL_NUMBER (PREV_INSN (insn)),
				     insn);
#endif
		break;
	      }
	    if (GET_CODE (body) == ADDR_DIFF_VEC)
	      {
		register int vlen, idx;

		if (prescan > 0)
		  break;

		vlen = XVECLEN (body, 1);
		for (idx = 0; idx < vlen; idx++)
		  ASM_OUTPUT_ADDR_DIFF_ELT (file,
			   CODE_LABEL_NUMBER (XEXP (XVECEXP (body, 1, idx), 0)),
			   CODE_LABEL_NUMBER (XEXP (XEXP (body, 0), 0)));
#ifdef ASM_OUTPUT_CASE_END
		ASM_OUTPUT_CASE_END (file,
				     CODE_LABEL_NUMBER (PREV_INSN (insn)),
				     insn);
#endif
		break;
	      }

	    /* We have a real machine instruction as rtl.  */

	    body = PATTERN (insn);

	    /* Check for redundant test and compare instructions
	       (when the condition codes are already set up as desired).
	       This is done only when optimizing; if not optimizing,
	       it should be possible for the user to alter a variable
	       with the debugger in between statements
	       and the next statement should reexamine the variable
	       to compute the condition codes.  */

	    if (optimize
		&& GET_CODE (body) == SET
		&& GET_CODE (SET_DEST (body)) == CC0)
	      {
		if (GET_CODE (SET_SRC (body)) == SUBREG)
		  SET_SRC (body) = alter_subreg (SET_SRC (body));
		if ((cc_status.value1 != 0
		     && rtx_equal_p (SET_SRC (body), cc_status.value1))
		    || (cc_status.value2 != 0
			&& rtx_equal_p (SET_SRC (body), cc_status.value2)))
		  {
		    /* Don't delete insn if has an addressing side-effect */
		    if (! find_reg_note (insn, REG_INC, 0)
			/* or if anything in it is volatile.  */
			&& ! volatile_refs_p (PATTERN (insn)))
		      /* We don't really delete the insn; just ignore it.  */
		      break;
		  }
	      }

	    /* If this is a conditional branch, maybe modify it
	       if the cc's are in a nonstandard state
	       so that it accomplishes the same thing that it would
	       do straightforwardly if the cc's were set up normally.  */

	    if (cc_status.flags != 0
		&& GET_CODE (insn) == JUMP_INSN
		&& GET_CODE (body) == SET
		&& SET_DEST (body) == pc_rtx
		&& GET_CODE (SET_SRC (body)) == IF_THEN_ELSE
		/* This is done during prescan; it is not done again
		   in final scan when prescan has been done.  */
		&& prescan >= 0)
	      {
		/* This function may alter the contents of its argument
		   and clear some of the cc_status.flags bits.
		   It may also return 1 meaning condition now always true
		   or -1 meaning condition now always false
		   or 2 meaning condition nontrivial but altered.  */
		register int result = alter_cond (XEXP (SET_SRC (body), 0));
		/* If condition now has fixed value, replace the IF_THEN_ELSE
		   with its then-operand or its else-operand.  */
		if (result == 1)
		  SET_SRC (body) = XEXP (SET_SRC (body), 1);
		if (result == -1)
		  SET_SRC (body) = XEXP (SET_SRC (body), 2);
		/* The jump is now either unconditional or a no-op.
		   If it has become a no-op, don't try to output it.
		   (It would not be recognized.)  */
		if (SET_SRC (body) == pc_rtx)
		  {
		    PUT_CODE (insn, NOTE);
		    NOTE_LINE_NUMBER (insn) = NOTE_INSN_DELETED;
		    NOTE_SOURCE_FILE (insn) = 0;
		    break;
		  }
		/* Rerecognize the instruction if it has changed.  */
		if (result != 0)
		  INSN_CODE (insn) = -1;
	      }

#ifdef STORE_FLAG_VALUE
	    /* Make same adjustments to instructions that examine the
	       condition codes without jumping (if this machine has them).  */

	    if (cc_status.flags != 0
		&& GET_CODE (body) == SET)
	      switch (GET_CODE (SET_SRC (body)))
		{
		case GTU:
		case GT:
		case LTU:
		case LT:
		case GEU:
		case GE:
		case LEU:
		case LE:
		case EQ:
		case NE:
		  {
		    register int result;
		    if (GET_CODE (XEXP (SET_SRC (body), 0)) != CC0)
		      break;
		    result = alter_cond (SET_SRC (body));
		    if (result == 1)
		      SET_SRC (body) = gen_rtx (CONST_INT, VOIDmode,
						STORE_FLAG_VALUE);
		    if (result == -1)
		      SET_SRC (body) = const0_rtx;
		    if (result != 0)
		      INSN_CODE (insn) = -1;
		  }
		}
#endif /* STORE_FLAG_VALUE */

	    /* Try to recognize the instruction.
	       If successful, verify that the operands satisfy the
	       constraints for the instruction.  Crash if they don't,
	       since `reload' should have changed them so that they do.  */

	    insn_code_number = recog_memoized (insn);
	    insn_extract (insn);
	    for (i = 0; i < insn_n_operands[insn_code_number]; i++)
	      {
		if (GET_CODE (recog_operand[i]) == SUBREG)
		  recog_operand[i] = alter_subreg (recog_operand[i]);
	      }

#ifdef REGISTER_CONSTRAINTS
	    if (! constrain_operands (insn_code_number))
	      abort ();
#endif

	    /* Some target machines need to prescan each insn before
	       it is output.  */

#ifdef FINAL_PRESCAN_INSN
	    FINAL_PRESCAN_INSN (insn, recog_operand,
				insn_n_operands[insn_code_number]);
#endif

	    cc_prev_status = cc_status;

	    /* Update `cc_status' for this instruction.
	       The instruction's output routine may change it further.
	       If the output routine for a jump insn needs to depend
	       on the cc status, it should look at cc_prev_status.  */

	    NOTICE_UPDATE_CC (body, insn);

	    /* If the proper template needs to be chosen by some C code,
	       run that code and get the real template.  */

	    template = insn_template[insn_code_number];
	    if (template == 0)
	      template = (*insn_outfun[insn_code_number]) (recog_operand, insn);

	    if (prescan > 0)
	      break;

	    /* Output assembler code from the template.  */

	    output_asm_insn (template, recog_operand);
	  }
	}
    }
}

/* Set up FILENAME as the current file for GDB line-number output.  */

void
set_current_gdbfile (filename)
     char *filename;
{
  register struct gdbfile *f;
  for (f = gdbfiles; f; f = f->next)
    if (!strcmp (f->name, filename))
      break;

  if (!f)
    {
      f = (struct gdbfile *) permalloc (sizeof (struct gdbfile));
      f->next = gdbfiles;
      gdbfiles = f;
      f->name = filename;
      f->filenum = next_gdb_filenum++;
      f->nlines = 0;
    }
  current_gdbfile = f;
  lastfile = filename;
}

/* Output debugging info to the assembler file FILE
   based on the NOTE-insn INSN, assumed to be a line number.  */

static void
output_source_line (file, insn, write_symbols)
     FILE *file;
     rtx insn;
     enum debugger write_symbols;
{
  register char *filename = NOTE_SOURCE_FILE (insn);

  last_linenum = NOTE_LINE_NUMBER (insn);

  if (write_symbols == GDB_DEBUG)
    {
      /* Output GDB-format line number info.  */

      /* If this is not the same source file as last time,
	 find or assign a GDB-file-number to this file.  */
      if (filename && (lastfile == 0 || strcmp (filename, lastfile)
		       || current_gdbfile == 0))
	set_current_gdbfile (filename);

      ++current_gdbfile->nlines;
      fprintf (file, "\t.gdbline %d,%d\n",
	       current_gdbfile->filenum, NOTE_LINE_NUMBER (insn));
    }

  if (write_symbols == SDB_DEBUG || write_symbols == DBX_DEBUG)
    {
#ifdef SDB_DEBUGGING_INFO
      if (write_symbols == SDB_DEBUG
	  /* COFF can't handle multiple source files--lose, lose.  */
	  && !strcmp (filename, main_input_filename)
	  /* COFF can't handle line #s before start-line of this function.  */
	  && last_linenum >= sdb_begin_function_line)
	{
#ifdef ASM_OUTPUT_SOURCE_LINE
	  ASM_OUTPUT_SOURCE_LINE (file, last_linenum);
#else
	  fprintf (file, "\t.ln\t%d\n",
		   (sdb_begin_function_line
		    ? last_linenum - sdb_begin_function_line : 1));
#endif
	}
#endif

#ifdef DBX_DEBUGGING_INFO
      if (write_symbols == DBX_DEBUG)
	{
	  /* Write DBX line number data.  */

	  if (filename && (lastfile == 0 || strcmp (filename, lastfile)))
	    {
#ifdef ASM_OUTPUT_SOURCE_FILENAME
	      ASM_OUTPUT_SOURCE_FILENAME (file, filename);
#else
	      fprintf (file, "\t.stabs \"%s\",%d,0,0,Ltext\n",
		       filename, N_SOL);
#endif
	      lastfile = filename;
	    }
	}

#ifdef ASM_OUTPUT_SOURCE_LINE
      ASM_OUTPUT_SOURCE_LINE (file, NOTE_LINE_NUMBER (insn));
#else
      fprintf (file, "\t.stabd %d,0,%d\n",
	       N_SLINE, NOTE_LINE_NUMBER (insn));
#endif
#endif /* DBX_DEBUGGING_INFO */
    }
}

/* If X is a SUBREG, replace it with a REG or a MEM,
   based on the thing it is a subreg of.  */

rtx
alter_subreg (x)
     register rtx x;
{
  register rtx y = SUBREG_REG (x);
  if (GET_CODE (y) == SUBREG)
    y = alter_subreg (y);

  if (GET_CODE (y) == REG)
    {
      /* If the containing reg really gets a hard reg, so do we.  */
      PUT_CODE (x, REG);
      REGNO (x) = REGNO (y) + SUBREG_WORD (x);
    }
  else if (GET_CODE (y) == MEM)
    {
      register int offset = SUBREG_WORD (x) * UNITS_PER_WORD;
#ifdef BYTES_BIG_ENDIAN
      offset -= (min (UNITS_PER_WORD, GET_MODE_SIZE (GET_MODE (x)))
		 - min (UNITS_PER_WORD, GET_MODE_SIZE (GET_MODE (y))));
#endif
      PUT_CODE (x, MEM);
      XEXP (x, 0) = plus_constant (XEXP (y, 0), offset);
    }
  else if (GET_CODE (y) == CONST_DOUBLE)
    return y;

  return x;
}

/* Do alter_subreg on all the SUBREGs contained in X.  */

static rtx
walk_alter_subreg (x)
     rtx x;
{
  switch (GET_CODE (x))
    {
    case PLUS:
    case MULT:
      XEXP (x, 0) = walk_alter_subreg (XEXP (x, 0));
      XEXP (x, 1) = walk_alter_subreg (XEXP (x, 1));
      break;

    case MEM:
      XEXP (x, 0) = walk_alter_subreg (XEXP (x, 0));
      break;

    case SUBREG:
      return alter_subreg (x);
    }

  return x;
}

/* Given BODY, the body of a jump instruction, alter the jump condition
   as required by the bits that are set in cc_status.flags.
   Not all of the bits there can be handled at this level in all cases.

   The value is normally 0.
   1 means that the condition has become always true.
   -1 means that the condition has become always false.
   2 means that COND has been altered.  */

static int
alter_cond (cond)
     register rtx cond;
{
  int value = 0;

  if (cc_status.flags & CC_REVERSED)
    {
      value = 2;
      switch (GET_CODE (cond))
	{
	case LE:
	  PUT_CODE (cond, GE);
	  break;
	case GE:
	  PUT_CODE (cond, LE);
	  break;
	case LT:
	  PUT_CODE (cond, GT);
	  break;
	case GT:
	  PUT_CODE (cond, LT);
	  break;
	case LEU:
	  PUT_CODE (cond, GEU);
	  break;
	case GEU:
	  PUT_CODE (cond, LEU);
	  break;
	case LTU:
	  PUT_CODE (cond, GTU);
	  break;
	case GTU:
	  PUT_CODE (cond, LTU);
	  break;
	}
    }

  if (cc_status.flags & CC_NOT_POSITIVE)
    switch (GET_CODE (cond))
      {
      case LE:
      case LEU:
      case GEU:
	/* Jump becomes unconditional.  */
	return 1;

      case GT:
      case GTU:
      case LTU:
	/* Jump becomes no-op.  */
	return -1;

      case GE:
	PUT_CODE (cond, EQ);
	value = 2;
	break;

      case LT:
	PUT_CODE (cond, NE);
	value = 2;
	break;
      }

  if (cc_status.flags & CC_NOT_NEGATIVE)
    switch (GET_CODE (cond))
      {
      case GE:
      case GEU:
	/* Jump becomes unconditional.  */
	return 1;

      case LT:
      case LTU:
	/* Jump becomes no-op.  */
	return -1;

      case LE:
      case LEU:
	PUT_CODE (cond, EQ);
	value = 2;
	break;

      case GT:
      case GTU:
	PUT_CODE (cond, NE);
	value = 2;
	break;
      }

  if (cc_status.flags & CC_NO_OVERFLOW)
    switch (GET_CODE (cond))
      {
      case GEU:
	/* Jump becomes unconditional.  */
	return 1;

      case LEU:
	PUT_CODE (cond, EQ);
	value = 2;
	break;

      case GTU:
	PUT_CODE (cond, NE);
	value = 2;
	break;

      case LTU:
	/* Jump becomes no-op.  */
	return -1;
      }

  if (cc_status.flags & (CC_Z_IN_NOT_N | CC_Z_IN_N))
    switch (GET_CODE (cond))
      {
      case LE:
      case LEU:
      case GE:
      case GEU:
      case LT:
      case LTU:
      case GT:
      case GTU:
	abort ();

      case NE:
	PUT_CODE (cond, cc_status.flags & CC_Z_IN_N ? GE : LT);
	value = 2;
	break;

      case EQ:
	PUT_CODE (cond, cc_status.flags & CC_Z_IN_N ? LT : GE);
	value = 2;
	break;
      }
  
  return value;
}

/* Report inconsistency between the assembler template and the operands.
   In an `asm', it's the user's fault; otherwise, the compiler's fault.  */

static void
output_operand_lossage (str)
     char *str;
{
  if (this_is_asm_operands)
    error_for_asm (this_is_asm_operands, "invalid `asm': %s", str);
  else
    abort ();
}

/* Output of assembler code from a template, and its subroutines.  */

/* Output text from TEMPLATE to the assembler output file,
   obeying %-directions to substitute operands taken from
   the vector OPERANDS.

   %N (for N a digit) means print operand N in usual manner.
   %lN means require operand N to be a CODE_LABEL or LABEL_REF
      and print the label name with no punctuation.
   %cN means require operand N to be a constant
      and print the constant expression with no punctuation.
   %aN means expect operand N to be a memory address
      (not a memory reference!) and print a reference
      to that address.
   %nN means expect operand N to be a constant
      and print a constant expression for minus the value
      of the operand, with no other punctuation.  */

void
output_asm_insn (template, operands)
     char *template;
     rtx *operands;
{
  register char *p;
  register int c;

  /* An insn may return a null string template
     in a case where no assembler code is needed.  */
  if (*template == 0)
    return;

  p = template;
  putc ('\t', asm_out_file);

#ifdef ASM_OUTPUT_OPCODE
  ASM_OUTPUT_OPCODE (asm_out_file, p);
#endif

  while (c = *p++)
    {
#ifdef ASM_OUTPUT_OPCODE
      if (c == '\n')
	{
	  putc (c, asm_out_file);
	  while ((c = *p) == '\t')
	    {
	      putc (c, asm_out_file);
	      p++;
	    }
	  ASM_OUTPUT_OPCODE (asm_out_file, p);
	}
      else
#endif
      if (c != '%')
	putc (c, asm_out_file);
      else
	{
	  /* %% outputs a single %.  */
	  if (*p == '%')
	    {
	      p++;
	      putc (c, asm_out_file);
	    }
	  /* % followed by a letter and some digits
	     outputs an operand in a special way depending on the letter.
	     Letters `acln' are implemented here.
	     Other letters are passed to `output_operand' so that
	     the PRINT_OPERAND macro can define them.  */
	  else if ((*p >= 'a' && *p <= 'z')
		   || (*p >= 'A' && *p <= 'Z'))
	    {
	      int letter = *p++;
	      c = atoi (p);

	      if (this_is_asm_operands
		  && c >= (unsigned) insn_noperands && *p >= '0' && *p <= '9')
		output_operand_lossage ("operand number out of range");
	      else if (letter == 'l')
		output_asm_label (operands[c]);
	      else if (letter == 'a')
		output_address (operands[c]);
	      else if (letter == 'c')
		{
		  if (CONSTANT_ADDRESS_P (operands[c]))
		    output_addr_const (asm_out_file, operands[c]);
		  else
		    output_operand (operands[c], 'c');
		}
	      else if (letter == 'n')
		{
		  if (GET_CODE (operands[c]) == CONST_INT)
		    fprintf (asm_out_file, "%d", - INTVAL (operands[c]));
		  else
		    {
		      putc ('-', asm_out_file);
		      output_addr_const (asm_out_file, operands[c]);
		    }
		}
	      else if (*p >= '0' && *p <= '9')
		output_operand (operands[c], letter);
	      else
		/* No operand-number follows the letter.  */
		output_operand (0, letter);

	      while ((c = *p) >= '0' && c <= '9') p++;
	    }
	  /* % followed by a digit outputs an operand the default way.  */
	  else if (*p >= '0' && *p <= '9')
	    {
	      c = atoi (p);
	      if (this_is_asm_operands && c >= (unsigned) insn_noperands)
		output_operand_lossage ("operand number out of range");
	      else
		output_operand (operands[c], 0);
	      while ((c = *p) >= '0' && c <= '9') p++;
	    }
	  /* % followed by punctuation: output something for that
	     punctuation character alone, with no operand.
	     The PRINT_OPERAND macro decides what is actually done.  */
	  else
	    output_operand (0, *p++);
	}
    }

  putc ('\n', asm_out_file);
}

/* Output a LABEL_REF, or a bare CODE_LABEL, as an assembler symbol.  */

void
output_asm_label (x)
     rtx x;
{
  char buf[20];

  if (GET_CODE (x) == LABEL_REF)
    ASM_GENERATE_INTERNAL_LABEL (buf, "L", CODE_LABEL_NUMBER (XEXP (x, 0)));
  else if (GET_CODE (x) == CODE_LABEL)
    ASM_GENERATE_INTERNAL_LABEL (buf, "L", CODE_LABEL_NUMBER (x));
  else
    output_operand_lossage ("`%l' operand isn't a label");

  assemble_name (asm_out_file, buf);
}

/* Print operand X using machine-dependent assembler syntax.
   The macro PRINT_OPERAND is defined just to control this function.
   CODE is a non-digit that preceded the operand-number in the % spec,
   such as 'z' if the spec was `%z3'.  CODE is 0 if there was no char
   between the % and the digits.
   When CODE is a non-letter, X is 0.

   The meanings of the letters are machine-dependent and controlled
   by PRINT_OPERAND.  */

static void
output_operand (x, code)
     rtx x;
     int code;
{
  if (x && GET_CODE (x) == SUBREG)
    x = alter_subreg (x);
  PRINT_OPERAND (asm_out_file, x, code);
}

/* Print a memory reference operand for address X
   using machine-dependent assembler syntax.
   The macro PRINT_OPERAND_ADDRESS exists just to control this function.  */

void
output_address (x)
     rtx x;
{
  walk_alter_subreg (x);
  PRINT_OPERAND_ADDRESS (asm_out_file, x);
}

/* Print an integer constant expression in assembler syntax.
   Addition and subtraction are the only arithmetic
   that may appear in these expressions.  */

void
output_addr_const (file, x)
     FILE *file;
     rtx x;
{
  char buf[20];

 restart:
  switch (GET_CODE (x))
    {
    case SYMBOL_REF:
      assemble_name (file, XSTR (x, 0));
      break;

    case LABEL_REF:
      ASM_GENERATE_INTERNAL_LABEL (buf, "L", CODE_LABEL_NUMBER (XEXP (x, 0)));
      assemble_name (asm_out_file, buf);
      break;

    case CODE_LABEL:
      ASM_GENERATE_INTERNAL_LABEL (buf, "L", CODE_LABEL_NUMBER (x));
      assemble_name (asm_out_file, buf);
      break;

    case CONST_INT:
      fprintf (file, "%d", INTVAL (x));
      break;

    case CONST:
      x = XEXP (x, 0);
      goto restart;

    case CONST_DOUBLE:
      if (GET_MODE (x) == DImode)
	{
	  /* We can use %d if the number is <32 bits and positive.  */
	  if (XINT (x, 1) || XINT (x, 0) < 0)
	    fprintf (file, "0x%x%08x", XINT (x, 1), XINT (x, 0));
	  else
	    fprintf (file, "%d", XINT (x, 0));
	}
      else
	/* We can't handle floating point constants;
	   PRINT_OPERAND must handle them.  */
	output_operand_lossage ("floating constant misused");
      break;

    case PLUS:
      /* Some assemblers need integer constants to appear last (eg masm).  */
      if (GET_CODE (XEXP (x, 0)) == CONST_INT)
	{
	  output_addr_const (file, XEXP (x, 1));
	  if (INTVAL (XEXP (x, 0)) >= 0)
	    fprintf (file, "+");
	  output_addr_const (file, XEXP (x, 0));
	}
      else
	{
	  output_addr_const (file, XEXP (x, 0));
	  if (INTVAL (XEXP (x, 1)) >= 0)
	    fprintf (file, "+");
	  output_addr_const (file, XEXP (x, 1));
	}
      break;

    case MINUS:
      output_addr_const (file, XEXP (x, 0));
      fprintf (file, "-");
      output_addr_const (file, XEXP (x, 1));
      break;

    default:
      output_operand_lossage ("invalid expression as operand");
    }
}
