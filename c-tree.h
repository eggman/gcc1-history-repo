/* Definitions for C parsing and type checking.
   Copyright (C) 1987 Free Software Foundation, Inc.

This file is part of GNU CC.

GNU CC is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 1, or (at your option)
any later version.

GNU CC is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU CC; see the file COPYING.  If not, write to
the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.  */

/* Nonzero means reject anything that ANSI standard C forbids.  */
extern int pedantic;

/* In a RECORD_TYPE or UNION_TYPE, nonzero if any component is read-only.  */
#define C_TYPE_FIELDS_READONLY(type) TYPE_SEP_UNIT (type)

/* in c-typecheck.c */
extern tree build_component_ref(), build_conditional_expr(), build_compound_expr();
extern tree build_unary_op(), build_binary_op(), build_function_call();
extern tree build_binary_op_nodefault ();
extern tree build_indirect_ref(), build_array_ref(), build_c_cast();
extern tree build_modify_expr();
extern tree c_sizeof (), c_alignof ();
extern void store_init_value ();
extern tree digest_init ();
extern tree c_expand_start_case ();
extern tree default_conversion ();

/* Given two integer or real types, return the type for their sum.
   Given two compatible ANSI C types, returns the merged type.  */

extern tree commontype ();

/* in c-decl.c */
extern tree build_label ();

extern int start_function ();
extern void finish_function ();
extern void store_parm_decls ();
extern tree get_parm_info ();

extern void pushlevel(), poplevel();

extern tree groktypename(), lookup_name();

extern tree lookup_label(), define_label();

extern tree implicitly_declare(), getdecls(), gettags ();

extern tree start_decl();
extern void finish_decl();

extern tree start_struct(), finish_struct(), xref_tag();
extern tree grokfield();

extern tree start_enum(), finish_enum();
extern tree build_enumerator();

extern tree make_index_type ();

extern tree double_type_node, long_double_type_node, float_type_node;
extern tree char_type_node, unsigned_char_type_node, signed_char_type_node;

extern tree short_integer_type_node, short_unsigned_type_node;
extern tree long_integer_type_node, long_unsigned_type_node;
extern tree unsigned_type_node;
extern tree string_type_node, char_array_type_node, int_array_type_node;

extern int current_function_returns_value;
extern int current_function_returns_null;

extern void yyerror();
extern int lineno;

extern tree ridpointers[];

/* Points to the FUNCTION_DECL of the function whose body we are reading. */
extern tree current_function_decl;

/* Nonzero means `$' can be in an identifier.  */

extern int dollars_in_ident;

/* Nonzero means `char' should be signed.  */

extern int flag_signed_char;

/* Nonzero means allow type mismatches in conditional expressions;
   just make their values `void'.   */

extern int flag_cond_mismatch;

/* Nonzero means don't recognize the keyword `asm'.  */

extern int flag_no_asm;

/* Nonzero means warn about implicit declarations.  */

extern int warn_implicit;

/* Nonzero means warn about function definitions that default the return type
   or that use a null return and have a return-type other than void.  */

extern int warn_return_type;

/* Nonzero means give string constants the type `const char *'
   to get extra warnings from them.  These warnings will be too numerous
   to be useful, except in thoroughly ANSIfied programs.  */

extern int warn_write_strings;

/* Nonzero means warn about pointer casts that can drop a type qualifier
   from the pointer target type.  */

extern int warn_cast_qual;

/* Nonzero means do some things the same way PCC does.  */

extern int flag_traditional;
