/* YACC parser for C syntax.
   Copyright (C) 1987, 1988, 1989 Free Software Foundation, Inc.

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


/* To whomever it may concern: I have heard that such a thing was once
written by AT&T, but I have never seen it.  */

%expect 23

/* These are the 23 conflicts you should get in parse.output;
   the state numbers may vary if minor changes in the grammar are made.

State 41 contains 1 shift/reduce conflict.  (Two ways to recover from error.)
State 90 contains 1 shift/reduce conflict.  (Two ways to recover from error.)
State 97 contains 1 shift/reduce conflict.  (Two ways to recover from error.)
State 101 contains 1 shift/reduce conflict.  (Two ways to recover from error.)
State 117 contains 1 shift/reduce conflict.  (See comment at component_decl.)
State 169 contains 2 shift/reduce conflicts.  (make notype_declarator longer.)
State 181 contains 1 shift/reduce conflict.  (Two ways to recover from error.)
State 191 contains 1 shift/reduce conflict.  (Two ways to recover from error.)
State 197 contains 1 shift/reduce conflict.  (Two ways to recover from error.)
State 239 contains 2 shift/reduce conflicts.  (make absdcl1 longer if poss.)
State 269 contains 2 shift/reduce conflicts.  (same for after_type_declarator).
State 299 contains 2 shift/reduce conflicts.  (similar for absdcl1 again.)
State 362 contains 1 shift/reduce conflict.  (dangling else.)
State 370 contains 2 shift/reduce conflicts.  (like 241, other context.)
State 373 contains 2 shift/reduce conflicts.  (like 241, other context.)
State 411 contains 2 shift/reduce conflicts.  (like 166 for parm_declarator)?
*/

%{
#include "config.h"
#include "tree.h"
#include "c-parse.h"
#include "c-tree.h"

#include <stdio.h>
#include <errno.h>

#ifndef errno
extern int errno;
#endif

/* Cause the `yydebug' variable to be defined.  */
#define YYDEBUG 1
%}

%start program

%union {long itype; tree ttype; enum tree_code code; }

/* All identifiers that are not reserved words
   and are not declared typedefs in the current block */
%token IDENTIFIER

/* All identifiers that are declared typedefs in the current block.
   In some contexts, they are treated just like IDENTIFIER,
   but they can also serve as typespecs in declarations.  */
%token TYPENAME

/* Reserved words that specify storage class.
   yylval contains an IDENTIFIER_NODE which indicates which one.  */
%token SCSPEC

/* Reserved words that specify type.
   yylval contains an IDENTIFIER_NODE which indicates which one.  */
%token TYPESPEC

/* Reserved words that qualify type: "const" or "volatile".
   yylval contains an IDENTIFIER_NODE which indicates which one.  */
%token TYPE_QUAL

/* Character or numeric constants.
   yylval is the node for the constant.  */
%token CONSTANT

/* String constants in raw form.
   yylval is a STRING_CST node.  */
%token STRING

/* "...", used for functions with variable arglists.  */
%token ELLIPSIS

/* the reserved words */
%token SIZEOF ENUM STRUCT UNION IF ELSE WHILE DO FOR SWITCH CASE DEFAULT
%token BREAK CONTINUE RETURN GOTO ASM TYPEOF ALIGNOF

/* Define the operator tokens and their precedences.
   The value is an integer because, if used, it is the tree code
   to use in the expression made from the operator.  */

%right <code> ASSIGN '='
%right <code> '?' ':'
%left <code> OROR
%left <code> ANDAND
%left <code> '|'
%left <code> '^'
%left <code> '&'
%left <code> EQCOMPARE
%left <code> ARITHCOMPARE
%left <code> LSHIFT RSHIFT
%left <code> '+' '-'
%left <code> '*' '/' '%'
%right <code> UNARY PLUSPLUS MINUSMINUS
%left HYPERUNARY
%left <code> POINTSAT '.'

%type <code> unop

%type <ttype> identifier IDENTIFIER TYPENAME CONSTANT expr nonnull_exprlist exprlist
%type <ttype> expr_no_commas cast_expr unary_expr primary string STRING
%type <ttype> typed_declspecs reserved_declspecs
%type <ttype> typed_typespecs reserved_typespecquals
%type <ttype> declmods typespec typespecqual_reserved
%type <ttype> SCSPEC TYPESPEC TYPE_QUAL nonempty_type_quals maybe_type_qual
%type <ttype> initdecls notype_initdecls initdcl notype_initdcl
%type <ttype> init initlist maybeasm
%type <ttype> asm_operands nonnull_asm_operands asm_operand asm_clobbers

%type <ttype> declarator
%type <ttype> notype_declarator after_type_declarator
%type <ttype> parm_declarator

%type <ttype> structsp component_decl_list component_decl components component_declarator
%type <ttype> enumlist enumerator
%type <ttype> typename absdcl absdcl1 type_quals
%type <ttype> xexpr parms parm identifiers

%type <ttype> parmlist parmlist_1 parmlist_2
%type <ttype> parmlist_or_identifiers parmlist_or_identifiers_1

%type <itype> setspecs

%{
/* the declaration found for the last IDENTIFIER token read in.
   yylex must look this up to detect typedefs, which get token type TYPENAME,
   so it is left around in case the identifier is not a typedef but is
   used in a context which makes it a reference to a variable.  */
static tree lastiddecl;

static tree make_pointer_declarator ();
static tree combine_strings ();
static void reinit_parse_for_function ();

/* List of types and structure classes of the current declaration */
tree current_declspecs;

char *input_filename;		/* source file current line is coming from */
char *main_input_filename;	/* top-level source file */

int undeclared_variable_notice;	/* 1 if we explained undeclared var errors. */

static int yylex ();
%}

%%
program: /* empty */
	| extdefs
	;

/* the reason for the strange actions in this rule
 is so that notype_initdecls when reached via datadef
 can find a valid list of type and sc specs in $0. */

extdefs:
	{$<ttype>$ = NULL_TREE; } extdef
	| extdefs {$<ttype>$ = NULL_TREE; } extdef
	;

extdef:
	fndef
	| datadef
	| ASM '(' string ')' ';'
		{ if (pedantic)
		    warning ("ANSI C forbids use of `asm' keyword");
		  if (TREE_CHAIN ($3)) $3 = combine_strings ($3);
		  assemble_asm ($3); }
	;

datadef:
	  setspecs notype_initdecls ';'
		{ if (pedantic)
		    error ("ANSI C forbids data definition lacking type or storage class");
		  else if (!flag_traditional)
		    warning ("data definition lacks type or storage class"); }
        | declmods setspecs notype_initdecls ';'
	  {}
	| typed_declspecs setspecs initdecls ';'
	  {}
        | declmods ';'
	  { error ("empty declaration"); }
	| typed_declspecs ';'
	  { shadow_tag ($1); }
	| error ';'
	| error '}'
	| ';'
	;

fndef:
	  typed_declspecs setspecs declarator
		{ if (! start_function ($1, $3))
		    YYERROR;
		  reinit_parse_for_function (); }
	  xdecls
		{ store_parm_decls (); }
	  compstmt_or_error
		{ finish_function (); }
	| typed_declspecs setspecs declarator error
		{ }
	| declmods setspecs notype_declarator
		{ if (! start_function ($1, $3))
		    YYERROR;
		  reinit_parse_for_function (); }
	  xdecls
		{ store_parm_decls (); }
	  compstmt_or_error
		{ finish_function (); }
	| declmods setspecs notype_declarator error
		{ }
	| setspecs notype_declarator
		{ if (! start_function (0, $2))
		    YYERROR;
		  reinit_parse_for_function (); }
	  xdecls
		{ store_parm_decls (); }
	  compstmt_or_error
		{ finish_function (); }
	| setspecs notype_declarator error
		{ }
	;

identifier:
	IDENTIFIER
	| TYPENAME
	;

unop:     '&'
		{ $$ = ADDR_EXPR; }
	| '-'
		{ $$ = NEGATE_EXPR; }
	| '+'
		{ $$ = CONVERT_EXPR; }
	| PLUSPLUS
		{ $$ = PREINCREMENT_EXPR; }
	| MINUSMINUS
		{ $$ = PREDECREMENT_EXPR; }
	| '~'
		{ $$ = BIT_NOT_EXPR; }
	| '!'
		{ $$ = TRUTH_NOT_EXPR; }
	;

expr:	nonnull_exprlist
		{ $$ = build_compound_expr ($1); }
	;

exprlist:
	  /* empty */
		{ $$ = NULL_TREE; }
	| nonnull_exprlist
	;

nonnull_exprlist:
	expr_no_commas
		{ $$ = build_tree_list (NULL_TREE, $1); }
	| nonnull_exprlist ',' expr_no_commas
		{ chainon ($1, build_tree_list (NULL_TREE, $3)); }
	;

unary_expr:
	primary
	| '*' cast_expr   %prec UNARY
		{ $$ = build_indirect_ref ($2, "unary *"); }
	| unop cast_expr  %prec UNARY
		{ $$ = build_unary_op ($1, $2, 0); }
	| SIZEOF unary_expr  %prec UNARY
		{ if (TREE_CODE ($2) == COMPONENT_REF
		      && TREE_PACKED (TREE_OPERAND ($2, 1)))
		    error ("`sizeof' applied to a bit-field");
		  $$ = c_sizeof (TREE_TYPE ($2)); }
	| SIZEOF '(' typename ')'  %prec HYPERUNARY
		{ $$ = c_sizeof (groktypename ($3)); }
	| ALIGNOF unary_expr  %prec UNARY
		{ if (TREE_CODE ($2) == COMPONENT_REF
		      && TREE_PACKED (TREE_OPERAND ($2, 1)))
		    error ("`__alignof' applied to a bit-field");
		  $$ = c_alignof (TREE_TYPE ($2)); }
	| ALIGNOF '(' typename ')'  %prec HYPERUNARY
		{ $$ = c_alignof (groktypename ($3)); }
	;

cast_expr:
	unary_expr
	| '(' typename ')' cast_expr  %prec UNARY
		{ tree type = groktypename ($2);
		  $$ = build_c_cast (type, $4); }
	| '(' typename ')' '{' initlist maybecomma '}'  %prec UNARY
		{ tree type = groktypename ($2);
		  if (pedantic)
		    warning ("ANSI C forbids constructor expressions");
		  $$ = digest_init (type, build_nt (CONSTRUCTOR, NULL_TREE, nreverse ($5)), 0);
		  if (TREE_CODE (type) == ARRAY_TYPE && TYPE_SIZE (type) == 0)
		    {
		      int failure = complete_array_type (type, $$, 1);
		      if (failure)
			abort ();
		    }
		}
	;

expr_no_commas:
	  cast_expr
	| expr_no_commas '+' expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas '-' expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas '*' expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas '/' expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas '%' expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas LSHIFT expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas RSHIFT expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas ARITHCOMPARE expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas EQCOMPARE expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas '&' expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas '|' expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas '^' expr_no_commas
		{ $$ = build_binary_op ($2, $1, $3); }
	| expr_no_commas ANDAND expr_no_commas
		{ $$ = build_binary_op (TRUTH_ANDIF_EXPR, $1, $3); }
	| expr_no_commas OROR expr_no_commas
		{ $$ = build_binary_op (TRUTH_ORIF_EXPR, $1, $3); }
	| expr_no_commas '?' xexpr ':' expr_no_commas
		{ $$ = build_conditional_expr ($1, $3, $5); }
	| expr_no_commas '=' expr_no_commas
		{ $$ = build_modify_expr ($1, NOP_EXPR, $3); }
	| expr_no_commas ASSIGN expr_no_commas
		{ $$ = build_modify_expr ($1, $2, $3); }
	;

primary:
	IDENTIFIER
		{ $$ = lastiddecl;
		  if (!$$ || $$ == error_mark_node)
		    {
		      if (yychar == YYEMPTY)
			yychar = YYLEX;
		      if (yychar == '(')
			{
			  $$ = implicitly_declare ($1);
			  assemble_external ($$);
			  TREE_USED ($$) = 1;
			}
		      else if (current_function_decl == 0)
			{
			  error ("`%s' undeclared, outside of functions",
				 IDENTIFIER_POINTER ($1));
			  $$ = error_mark_node;
			}
		      else
			{
			  if (IDENTIFIER_GLOBAL_VALUE ($1) != error_mark_node
			      || IDENTIFIER_ERROR_LOCUS ($1) != current_function_decl)
			    {
			      error ("`%s' undeclared (first use this function)",
				     IDENTIFIER_POINTER ($1));

			      if (! undeclared_variable_notice)
				{
				  error ("(Each undeclared identifier is reported only once");
				  error ("for each function it appears in.)");
				  undeclared_variable_notice = 1;
				}
			    }
			  $$ = error_mark_node;
			  /* Prevent repeated error messages.  */
			  IDENTIFIER_GLOBAL_VALUE ($1) = error_mark_node;
			  IDENTIFIER_ERROR_LOCUS ($1) = current_function_decl;
			}
		    }
		  else if (! TREE_USED ($$))
		    {
		      if (TREE_EXTERNAL ($$))
			assemble_external ($$);
		      TREE_USED ($$) = 1;
		    }
		  if (TREE_CODE ($$) == CONST_DECL)
		    $$ = DECL_INITIAL ($$);
		}
	| CONSTANT
	| string
		{ $$ = combine_strings ($1); }
	| '(' expr ')'
		{ $$ = $2; }
	| '(' error ')'
		{ $$ = error_mark_node; }
	| '(' 
		{ if (current_function_decl == 0)
		    {
		      error ("braced-group within expression allowed only inside a function");
		      YYERROR;
		    }
		  $<ttype>$ = expand_start_stmt_expr (); }
	  compstmt ')'
		{ if (pedantic)
		    warning ("ANSI C forbids braced-groups within expressions");
		  $$ = expand_end_stmt_expr ($<ttype>2); }
	| primary '(' exprlist ')'   %prec '.'
		{ $$ = build_function_call ($1, $3); }
	| primary '[' expr ']'   %prec '.'
		{ $$ = build_array_ref ($1, $3); }
	| primary '.' identifier
		{ $$ = build_component_ref ($1, $3); }
	| primary POINTSAT identifier
		{ $$ = build_component_ref (build_indirect_ref ($1, "->"), $3); }
	| primary PLUSPLUS
		{ $$ = build_unary_op (POSTINCREMENT_EXPR, $1, 0); }
	| primary MINUSMINUS
		{ $$ = build_unary_op (POSTDECREMENT_EXPR, $1, 0); }
	;

/* Produces a STRING_CST with perhaps more STRING_CSTs chained onto it.  */
string:
	  STRING
	| string STRING
		{ $$ = chainon ($1, $2); }
	;

xdecls:
	/* empty */
	| decls
	;

decls:
	decl
	| errstmt
	| decls decl
	| decl errstmt
	;

/* records the type and storage class specs to use for processing
   the declarators that follow */
setspecs: /* empty */
		{ current_declspecs = $<ttype>0;
		  $$ = suspend_momentary (); }
	;

decl:
	typed_declspecs setspecs initdecls ';'
		{ resume_momentary ($2); }
	| declmods setspecs notype_initdecls ';'
		{ resume_momentary ($2); }
	| typed_declspecs ';'
		{ shadow_tag ($1); }
	| declmods ';'
		{ warning ("empty declaration"); }
	;

/* Declspecs which contain at least one type specifier or typedef name.
   (Just `const' or `volatile' is not enough.)
   A typedef'd name following these is taken as a name to be declared.  */

typed_declspecs:
	  typespec reserved_declspecs
		{ $$ = tree_cons (NULL_TREE, $1, $2); }
	| declmods typespec reserved_declspecs
		{ $$ = chainon ($3, tree_cons (NULL_TREE, $2, $1)); }
	;

reserved_declspecs:  /* empty */
		{ $$ = NULL_TREE; }
	| reserved_declspecs typespecqual_reserved
		{ $$ = tree_cons (NULL_TREE, $2, $1); }
	| reserved_declspecs SCSPEC
		{ $$ = tree_cons (NULL_TREE, $2, $1); }
	;

/* List of just storage classes and type modifiers.
   A declaration can start with just this, but then it cannot be used
   to redeclare a typedef-name.  */

declmods:
	  TYPE_QUAL
		{ $$ = tree_cons (NULL_TREE, $1, NULL_TREE); }
	| SCSPEC
		{ $$ = tree_cons (NULL_TREE, $1, NULL_TREE); }
	| declmods TYPE_QUAL
		{ $$ = tree_cons (NULL_TREE, $2, $1); }
	| declmods SCSPEC
		{ $$ = tree_cons (NULL_TREE, $2, $1); }
	;


/* Used instead of declspecs where storage classes are not allowed
   (that is, for typenames and structure components).
   Don't accept a typedef-name if anything but a modifier precedes it.  */

typed_typespecs:
	  typespec reserved_typespecquals
		{ $$ = tree_cons (NULL_TREE, $1, $2); }
	| nonempty_type_quals typespec reserved_typespecquals
		{ $$ = chainon ($3, tree_cons (NULL_TREE, $2, $1)); }
	;

reserved_typespecquals:  /* empty */
		{ $$ = NULL_TREE; }
	| reserved_typespecquals typespecqual_reserved
		{ $$ = tree_cons (NULL_TREE, $2, $1); }
	;

/* A typespec (but not a type qualifier).
   Once we have seen one of these in a declaration,
   if a typedef name appears then it is being redeclared.  */

typespec: TYPESPEC
	| structsp
	| TYPENAME
	| TYPEOF '(' expr ')'
		{ $$ = TREE_TYPE ($3);
		  if (pedantic)
		    warning ("ANSI C forbids `typeof'"); }
	| TYPEOF '(' typename ')'
		{ $$ = groktypename ($3);
		  if (pedantic)
		    warning ("ANSI C forbids `typeof'"); }
	;

/* A typespec that is a reserved word, or a type qualifier.  */

typespecqual_reserved: TYPESPEC
	| TYPE_QUAL
	| structsp
	;

initdecls:
	initdcl
	| initdecls ',' initdcl
	;

notype_initdecls:
	notype_initdcl
	| notype_initdecls ',' initdcl
	;

maybeasm:
	  /* empty */
		{ $$ = NULL_TREE; }
	| ASM '(' string ')'
		{ if (TREE_CHAIN ($3)) $3 = combine_strings ($3);
		  $$ = $3;
		  if (pedantic)
		    warning ("ANSI C forbids use of `asm' keyword");
		}
	;

initdcl:
	  declarator maybeasm '='
		{ $<ttype>$ = start_decl ($1, current_declspecs, 1); }
	  init
/* Note how the declaration of the variable is in effect while its init is parsed! */
		{ finish_decl ($<ttype>4, $5, $2); }
	| declarator maybeasm
		{ tree d = start_decl ($1, current_declspecs, 0);
		  finish_decl (d, NULL_TREE, $2); }
	;

notype_initdcl:
	  notype_declarator maybeasm '='
		{ $<ttype>$ = start_decl ($1, current_declspecs, 1); }
	  init
/* Note how the declaration of the variable is in effect while its init is parsed! */
		{ finish_decl ($<ttype>4, $5, $2); }
	| notype_declarator maybeasm
		{ tree d = start_decl ($1, current_declspecs, 0);
		  finish_decl (d, NULL_TREE, $2); }
	;

init:
	expr_no_commas
	| '{' '}'
		{ $$ = build_nt (CONSTRUCTOR, NULL_TREE, NULL_TREE);
		  if (pedantic)
		    warning ("ANSI C forbids empty initializer braces"); }
	| '{' initlist '}'
		{ $$ = build_nt (CONSTRUCTOR, NULL_TREE, nreverse ($2)); }
	| '{' initlist ',' '}'
		{ $$ = build_nt (CONSTRUCTOR, NULL_TREE, nreverse ($2)); }
	| error
		{ $$ = NULL_TREE; }
	;

/* This chain is built in reverse order,
   and put in forward order where initlist is used.  */
initlist:
	  init
		{ $$ = build_tree_list (NULL_TREE, $1); }
	| initlist ',' init
		{ $$ = tree_cons (NULL_TREE, $3, $1); }
	;

/* Any kind of declarator (thus, all declarators allowed
   after an explicit typespec).  */

declarator:
	  after_type_declarator
	| notype_declarator
	;

/* A declarator that is allowed only after an explicit typespec.  */

after_type_declarator:
	  '(' after_type_declarator ')'
		{ $$ = $2; }
	| after_type_declarator '(' parmlist_or_identifiers  %prec '.'
		{ $$ = build_nt (CALL_EXPR, $1, $3, NULL_TREE); }
/*	| after_type_declarator '(' error ')'  %prec '.'
		{ $$ = build_nt (CALL_EXPR, $1, NULL_TREE, NULL_TREE);
		  poplevel (0, 0, 0); }  */
	| after_type_declarator '[' expr ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, $1, $3); }
	| after_type_declarator '[' ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, $1, NULL_TREE); }
	| '*' type_quals after_type_declarator  %prec UNARY
		{ $$ = make_pointer_declarator ($2, $3); }
	| TYPENAME
	;

/* Kinds of declarator that can appear in a parameter list
   in addition to notype_declarator.  This is like after_type_declarator
   but does not allow a typedef name in parentheses as an identifier
   (because it would conflict with a function with that typedef as arg).  */

parm_declarator:
	  parm_declarator '(' parmlist_or_identifiers  %prec '.'
		{ $$ = build_nt (CALL_EXPR, $1, $3, NULL_TREE); }
/*	| parm_declarator '(' error ')'  %prec '.'
		{ $$ = build_nt (CALL_EXPR, $1, NULL_TREE, NULL_TREE);
		  poplevel (0, 0, 0); }  */
	| parm_declarator '[' expr ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, $1, $3); }
	| parm_declarator '[' ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, $1, NULL_TREE); }
	| '*' type_quals parm_declarator  %prec UNARY
		{ $$ = make_pointer_declarator ($2, $3); }
	| TYPENAME
	;

/* A declarator allowed whether or not there has been
   an explicit typespec.  These cannot redeclare a typedef-name.  */

notype_declarator:
	  notype_declarator '(' parmlist_or_identifiers  %prec '.'
		{ $$ = build_nt (CALL_EXPR, $1, $3, NULL_TREE); }
/*	| notype_declarator '(' error ')'  %prec '.'
		{ $$ = build_nt (CALL_EXPR, $1, NULL_TREE, NULL_TREE);
		  poplevel (0, 0, 0); }  */
	| '(' notype_declarator ')'
		{ $$ = $2; }
	| '*' type_quals notype_declarator  %prec UNARY
		{ $$ = make_pointer_declarator ($2, $3); }
	| notype_declarator '[' expr ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, $1, $3); }
	| notype_declarator '[' ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, $1, NULL_TREE); }
	| IDENTIFIER
	;

structsp:
	  STRUCT identifier '{'
		{ $$ = start_struct (RECORD_TYPE, $2);
		  /* Start scope of tag before parsing components.  */
		}
	  component_decl_list '}'
		{ $$ = finish_struct ($<ttype>4, $5);
		  /* Really define the structure.  */
		}
	| STRUCT '{' component_decl_list '}'
		{ $$ = finish_struct (start_struct (RECORD_TYPE, NULL_TREE),
				      $3); }
	| STRUCT identifier
		{ $$ = xref_tag (RECORD_TYPE, $2); }
	| UNION identifier '{'
		{ $$ = start_struct (UNION_TYPE, $2); }
	  component_decl_list '}'
		{ $$ = finish_struct ($<ttype>4, $5); }
	| UNION '{' component_decl_list '}'
		{ $$ = finish_struct (start_struct (UNION_TYPE, NULL_TREE),
				      $3); }
	| UNION identifier
		{ $$ = xref_tag (UNION_TYPE, $2); }
	| ENUM identifier '{'
		{ $<itype>3 = suspend_momentary ();
		  $$ = start_enum ($2); }
	  enumlist maybecomma_warn '}'
		{ $$ = finish_enum ($<ttype>4, nreverse ($5));
		  resume_momentary ($<itype>3); }
	| ENUM '{'
		{ $<itype>2 = suspend_momentary ();
		  $$ = start_enum (NULL_TREE); }
	  enumlist maybecomma_warn '}'
		{ $$ = finish_enum ($<ttype>3, nreverse ($4));
		  resume_momentary ($<itype>2); }
	| ENUM identifier
		{ $$ = xref_tag (ENUMERAL_TYPE, $2); }
	;

maybecomma:
	  /* empty */
	| ','
	;

maybecomma_warn:
	  /* empty */
	| ','
		{ if (pedantic) warning ("comma at end of enumerator list"); }
	;

component_decl_list:   /* empty */
		{ $$ = NULL_TREE; }
	| component_decl_list component_decl ';'
		{ $$ = chainon ($1, $2); }
	| component_decl_list ';'
		{ if (pedantic) 
		    warning ("extra semicolon in struct or union specified"); }
	;

/* There is a shift-reduce conflict here, because `components' may
   start with a `typename'.  It happens that shifting (the default resolution)
   does the right thing, because it treats the `typename' as part of
   a `typed_typespecs'.

   It is possible that this same technique would allow the distinction
   between `notype_initdecls' and `initdecls' to be eliminated.
   But I am being cautious and not trying it.  */

component_decl:
	typed_typespecs setspecs components
		{ $$ = $3;
		  resume_momentary ($2); }
	| nonempty_type_quals setspecs components
		{ $$ = $3;
		  resume_momentary ($2); }
	| error
		{ $$ = NULL_TREE; }
	;

components:
	  /* empty */
		{ $$ = NULL_TREE; }
	| component_declarator
	| components ',' component_declarator
		{ $$ = chainon ($1, $3); }
	;

component_declarator:
	declarator
		{ $$ = grokfield (input_filename, lineno, $1, current_declspecs, NULL_TREE); }
	| declarator ':' expr_no_commas
		{ $$ = grokfield (input_filename, lineno, $1, current_declspecs, $3); }
	| ':' expr_no_commas
		{ $$ = grokfield (input_filename, lineno, NULL_TREE, current_declspecs, $2); }
	;

/* We chain the enumerators in reverse order.
   They are put in forward order where enumlist is used.
   (The order used to be significant, but no longer is so.
   However, we still maintain the order, just to be clean.)  */

enumlist:
	  enumerator
	| enumlist ',' enumerator
		{ $$ = chainon ($3, $1); }
	;


enumerator:
	  identifier
		{ $$ = build_enumerator ($1, NULL_TREE); }
	| identifier '=' expr_no_commas
		{ $$ = build_enumerator ($1, $3); }
	;

typename:
	typed_typespecs absdcl
		{ $$ = build_tree_list ($1, $2); }
	| nonempty_type_quals absdcl
		{ $$ = build_tree_list ($1, $2); }
	;
	
absdcl:   /* an absolute declarator */
	/* empty */
		{ $$ = NULL_TREE; }
	| absdcl1
	;

nonempty_type_quals:
	  TYPE_QUAL
		{ $$ = tree_cons (NULL_TREE, $1, NULL_TREE); }
	| nonempty_type_quals TYPE_QUAL
		{ $$ = tree_cons (NULL_TREE, $2, $1); }
	;

type_quals:
	  /* empty */
		{ $$ = NULL_TREE; }
	| type_quals TYPE_QUAL
		{ $$ = tree_cons (NULL_TREE, $2, $1); }
	;

absdcl1:  /* a nonempty absolute declarator */
	  '(' absdcl1 ')'
		{ $$ = $2; }
	  /* `(typedef)1' is `int'.  */
	| '*' type_quals absdcl1  %prec UNARY
		{ $$ = make_pointer_declarator ($2, $3); }
	| '*' type_quals  %prec UNARY
		{ $$ = make_pointer_declarator ($2, NULL_TREE); }
	| absdcl1 '(' parmlist  %prec '.'
		{ $$ = build_nt (CALL_EXPR, $1, $3, NULL_TREE); }
	| absdcl1 '[' expr ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, $1, $3); }
	| absdcl1 '[' ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, $1, NULL_TREE); }
	| '(' parmlist  %prec '.'
		{ $$ = build_nt (CALL_EXPR, NULL_TREE, $2, NULL_TREE); }
	| '[' expr ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, NULL_TREE, $2); }
	| '[' ']'  %prec '.'
		{ $$ = build_nt (ARRAY_REF, NULL_TREE, NULL_TREE); }
	;

/* at least one statement, the first of which parses without error.  */
/* stmts is used only after decls, so an invalid first statement
   is actually regarded as an invalid decl and part of the decls.  */

stmts:
	stmt
	| stmts stmt
	| stmts errstmt
	;

xstmts:
	/* empty */
	| stmts
	;

errstmt:  error ';'
	;

pushlevel:  /* empty */
		{ pushlevel (0);
		  clear_last_expr ();
		  push_momentary ();
		  expand_start_bindings (0); }
	;

/* This is the body of a function definition.
   It causes syntax errors to ignore to the next openbrace.  */
compstmt_or_error:
	  compstmt
	| error compstmt
	;

compstmt: '{' '}'
	| '{' pushlevel decls xstmts '}'
		{ expand_end_bindings (getdecls (), 1, 0);
		  poplevel (1, 1, 0);
		  pop_momentary (); }
	| '{' pushlevel error '}'
		{ expand_end_bindings (getdecls (), 0, 0);
		  poplevel (0, 0, 0);
		  pop_momentary (); }
	| '{' pushlevel stmts '}'
		{ expand_end_bindings (getdecls (), 0, 0);
		  poplevel (0, 0, 0);
		  pop_momentary (); }
	;

simple_if:
	  IF '(' expr ')'
		{ emit_line_note (input_filename, lineno);
		  expand_start_cond (truthvalue_conversion ($3), 0); }
	  stmt
	;

stmt:
	  compstmt
	| expr ';'
		{ emit_line_note (input_filename, lineno);
		  expand_expr_stmt ($1);
		  clear_momentary (); }
	| simple_if ELSE
		{ expand_start_else (); }
	  stmt
		{ expand_end_else (); }
	| simple_if
		{ expand_end_cond (); }
	| WHILE
		{ emit_line_note (input_filename, lineno);
		  expand_start_loop (1); }
	  '(' expr ')'
		{ emit_line_note (input_filename, lineno);
		  expand_exit_loop_if_false (truthvalue_conversion ($4)); }
	  stmt
		{ expand_end_loop (); }
	| DO
		{ emit_line_note (input_filename, lineno);
		  expand_start_loop_continue_elsewhere (1); }
	  stmt WHILE
		{ expand_loop_continue_here (); }
	  '(' expr ')' ';'
		{ emit_line_note (input_filename, lineno);
		  expand_exit_loop_if_false (truthvalue_conversion ($7));
		  expand_end_loop ();
		  clear_momentary (); }
	| FOR 
	  '(' xexpr ';'
		{ emit_line_note (input_filename, lineno);
		  if ($3) expand_expr_stmt ($3);
		  expand_start_loop_continue_elsewhere (1); }
	  xexpr ';'
		{ emit_line_note (input_filename, lineno);
		  if ($6)
		    expand_exit_loop_if_false (truthvalue_conversion ($6)); }
	  xexpr ')'
		/* Don't let the tree nodes for $9 be discarded
		   by clear_momentary during the parsing of the next stmt.  */
		{ push_momentary ();
		  $<itype>10 = lineno; }
	  stmt
		{ emit_line_note (input_filename, $<itype>10);
		  expand_loop_continue_here ();
		  if ($9)
		    expand_expr_stmt ($9);
		  pop_momentary ();
		  expand_end_loop (); }
	| SWITCH '(' expr ')'
		{ emit_line_note (input_filename, lineno);
		  c_expand_start_case ($3);
		  /* Don't let the tree nodes for $3 be discarded by
		     clear_momentary during the parsing of the next stmt.  */
		  push_momentary (); }
	  stmt
		{ expand_end_case ();
		  pop_momentary (); }
	| CASE expr ':'
		{ register tree value = fold ($2);
		  register tree label
		    = build_decl (LABEL_DECL, NULL_TREE, NULL_TREE);

		  /* build_c_cast puts on a NOP_EXPR to make a non-lvalue.
		     Strip such NOP_EXPRs.  */
		  if (TREE_CODE (value) == NOP_EXPR
		      && TREE_TYPE (value) == TREE_TYPE (TREE_OPERAND (value, 0)))
		    value = TREE_OPERAND (value, 0);

		  if (TREE_CODE (value) != INTEGER_CST
		      && value != error_mark_node)
		    {
		      error ("case label does not reduce to an integer constant");
		      value = error_mark_node;
		    }
		  else
		    /* Promote char or short to int.  */
		    value = default_conversion (value);
		  if (value != error_mark_node)
		    {
		      int success = pushcase (value, label);
		      if (success == 1)
			error ("case label not within a switch statement");
		      else if (success == 2)
			error ("duplicate case value");
		      else if (success == 3)
			warning ("case value out of range");
		    }
		}
	  stmt
	| DEFAULT ':'
		{
		  register tree label
		    = build_decl (LABEL_DECL, NULL_TREE, NULL_TREE);
		  int success = pushcase (NULL_TREE, label);
		  if (success == 1)
		    error ("default label not within a switch statement");
		  else if (success == 2)
		    error ("multiple default labels in one switch");
		}
	  stmt
	| BREAK ';'
		{ emit_line_note (input_filename, lineno);
		  if ( ! expand_exit_something ())
		    error ("break statement not within loop or switch"); }
	| CONTINUE ';'	
		{ emit_line_note (input_filename, lineno);
		  if (! expand_continue_loop ())
		    error ("continue statement not within a loop"); }
	| RETURN ';'
		{ emit_line_note (input_filename, lineno);
		  c_expand_return (NULL_TREE); }
	| RETURN expr ';'
		{ emit_line_note (input_filename, lineno);
		  c_expand_return ($2); }
	| ASM maybe_type_qual '(' string ')' ';'
		{ if (TREE_CHAIN ($4)) $4 = combine_strings ($4);
		  expand_asm ($4); }
	/* This is the case with just output operands.  */
	| ASM maybe_type_qual '(' string ':' asm_operands ')' ';'
		{ if (TREE_CHAIN ($4)) $4 = combine_strings ($4);
		  c_expand_asm_operands ($4, $6, NULL_TREE, NULL_TREE,
					 $2 == ridpointers[(int)RID_VOLATILE],
					 input_filename, lineno); }
	/* This is the case with input operands as well.  */
	| ASM maybe_type_qual '(' string ':' asm_operands ':' asm_operands ')' ';'
		{ if (TREE_CHAIN ($4)) $4 = combine_strings ($4);
		  c_expand_asm_operands ($4, $6, $8, NULL_TREE,
					 $2 == ridpointers[(int)RID_VOLATILE],
					 input_filename, lineno); }
	/* This is the case with clobbered registers as well.  */
	| ASM maybe_type_qual '(' string ':' asm_operands ':'
  	  asm_operands ':' asm_clobbers ')' ';'
		{ if (TREE_CHAIN ($4)) $4 = combine_strings ($4);
		  c_expand_asm_operands ($4, $6, $8, $10,
					 $2 == ridpointers[(int)RID_VOLATILE],
					 input_filename, lineno); }
	| GOTO identifier ';'
		{ tree decl;
		  emit_line_note (input_filename, lineno);
		  decl = lookup_label ($2);
		  expand_goto (decl); }
	| identifier ':'
		{ tree label = define_label (input_filename, lineno, $1);
		  if (label)
		    expand_label (label); }
	  stmt
	| ';'
	;

/* Either a type-qualifier or nothing.  First thing in an `asm' statement.  */

maybe_type_qual:
	/* empty */
		{ if (pedantic)
		    warning ("ANSI C forbids use of `asm' keyword");
		  emit_line_note (input_filename, lineno); }
	| TYPE_QUAL
		{ if (pedantic)
		    warning ("ANSI C forbids use of `asm' keyword");
		  emit_line_note (input_filename, lineno); }
	;

xexpr:
	/* empty */
		{ $$ = NULL_TREE; }
	| expr
	;

/* These are the operands other than the first string and colon
   in  asm ("addextend %2,%1": "=dm" (x), "0" (y), "g" (*x))  */
asm_operands: /* empty */
		{ $$ = NULL_TREE; }
	| nonnull_asm_operands
	;

nonnull_asm_operands:
	  asm_operand
	| nonnull_asm_operands ',' asm_operand
		{ $$ = chainon ($1, $3); }
	;

asm_operand:
	  STRING '(' expr ')'
		{ $$ = build_tree_list ($1, $3); }
	;

asm_clobbers:
	  STRING
		{ $$ = tree_cons (NULL_TREE, $1, NULL_TREE); }
	| asm_clobbers ',' STRING
		{ $$ = tree_cons (NULL_TREE, $3, $1); }
	;

/* This is what appears inside the parens in a function declarator.
   Its value is a list of ..._TYPE nodes.  */
parmlist:
		{ pushlevel (0); }
	  parmlist_1
		{ $$ = $2;
		  parmlist_tags_warning ();
		  poplevel (0, 0, 0); }
	;

/* This is referred to where either a parmlist or an identifier list is ok.
   Its value is a list of ..._TYPE nodes or a list of identifiers.  */
parmlist_or_identifiers:
		{ pushlevel (0); }
	  parmlist_or_identifiers_1
		{ $$ = $2;
		  parmlist_tags_warning ();
		  poplevel (0, 0, 0); }
	;

parmlist_or_identifiers_1:
	  parmlist_2 ')'
	| identifiers ')'
		{ $$ = tree_cons (NULL_TREE, NULL_TREE, $1); }
	| error ')'
		{ $$ = tree_cons (NULL_TREE, NULL_TREE, NULL_TREE); }
	;

parmlist_1:
	  parmlist_2 ')'
	| error ')'
		{ $$ = tree_cons (NULL_TREE, NULL_TREE, NULL_TREE); }
	;

/* This is what appears inside the parens in a function declarator.
   Is value is represented in the format that grokdeclarator expects.  */
parmlist_2:  /* empty */
		{ $$ = get_parm_info (0); }
	| parms
		{ $$ = get_parm_info (1); }
	| parms ',' ELLIPSIS
		{ $$ = get_parm_info (0); }
	;

parms:	
	parm
		{ push_parm_decl ($1); }
	| parms ',' parm
		{ push_parm_decl ($3); }
	;

/* A single parameter declaration or parameter type name,
   as found in a parmlist.  */
parm:
	  typed_declspecs parm_declarator
		{ $$ = build_tree_list ($1, $2)	; }
	| typed_declspecs notype_declarator
		{ $$ = build_tree_list ($1, $2)	; }
	| typed_declspecs absdcl
		{ $$ = build_tree_list ($1, $2); }
	| declmods notype_declarator
		{ $$ = build_tree_list ($1, $2)	; }
	| declmods absdcl
		{ $$ = build_tree_list ($1, $2); }
	;

/* A nonempty list of identifiers.  */
identifiers:	
	IDENTIFIER
		{ $$ = build_tree_list (NULL_TREE, $1); }
	| identifiers ',' IDENTIFIER
		{ $$ = chainon ($1, build_tree_list (NULL_TREE, $3)); }
	;
%%

/* Return something to represent absolute declarators containing a *.
   TARGET is the absolute declarator that the * contains.
   TYPE_QUALS is a list of modifiers such as const or volatile
   to apply to the pointer type, represented as identifiers.

   We return an INDIRECT_REF whose "contents" are TARGET
   and whose type is the modifier list.  */
   
static tree
make_pointer_declarator (type_quals, target)
     tree type_quals, target;
{
  return build (INDIRECT_REF, type_quals, target);
}

/* Given a chain of STRING_CST nodes,
   concatenate them into one STRING_CST
   and give it a suitable array-of-chars data type.  */

static tree
combine_strings (strings)
     tree strings;
{
  register tree value, t;
  register int length = 1;
  int wide_length = 0;
  int wide_flag = 0;

  if (TREE_CHAIN (strings))
    {
      /* More than one in the chain, so concatenate.  */
      register char *p, *q;

      /* Don't include the \0 at the end of each substring,
	 except for the last one.
	 Count wide strings and ordinary strings separately.  */
      for (t = strings; t; t = TREE_CHAIN (t))
	{
	  if (TREE_TYPE (t) == int_array_type_node)
	    {
	      wide_length += (TREE_STRING_LENGTH (t) - 1);
	      wide_flag = 1;
	    }
	  else
	    length += (TREE_STRING_LENGTH (t) - 1);
	}

      /* If anything is wide, the non-wides will be converted,
	 which makes them take more space.  */
      if (wide_flag)
	length = length * UNITS_PER_WORD + wide_length;

      p = (char *) oballoc (length);

      /* Copy the individual strings into the new combined string.
	 If the combined string is wide, convert the chars to ints
	 for any individual strings that are not wide.  */

      q = p;
      for (t = strings; t; t = TREE_CHAIN (t))
	{
	  int len = TREE_STRING_LENGTH (t) - 1;
	  if ((TREE_TYPE (t) == int_array_type_node) == wide_flag)
	    {
	      bcopy (TREE_STRING_POINTER (t), q, len);
	      q += len;
	    }
	  else
	    {
	      int i;
	      for (i = 0; i < len; i++)
		((int *) q)[i] = TREE_STRING_POINTER (t)[i];
	      q += len * UNITS_PER_WORD;
	    }
	}
      *q = 0;

      value = make_node (STRING_CST);
      TREE_STRING_POINTER (value) = p;
      TREE_STRING_LENGTH (value) = length;
      TREE_LITERAL (value) = 1;
    }
  else
    {
      value = strings;
      length = TREE_STRING_LENGTH (value);
      if (TREE_TYPE (value) == int_array_type_node)
	wide_flag = 1;
    }

  /* Create the array type for the string constant.
     -Wwrite-strings says make the string constant an array of const char
     so that copying it to a non-const pointer will get a warning.  */
  if (warn_write_strings)
    {
      tree elements
	= build_type_variant (wide_flag ? integer_type_node : char_type_node,
			      1, 0);
      TREE_TYPE (value)
	= build_array_type (elements,
			    build_index_type (build_int_2 (length - 1, 0)));
    }
  else
    TREE_TYPE (value)
      = build_array_type (wide_flag ? integer_type_node : char_type_node,
			  build_index_type (build_int_2 (length - 1, 0)));
  TREE_LITERAL (value) = 1;
  TREE_STATIC (value) = 1;
  return value;
}

int lineno;			/* current line number in file being read */

FILE *finput;			/* input file.
				   Normally a pipe from the preprocessor.  */

/* lexical analyzer */

static int maxtoken;		/* Current nominal length of token buffer.  */
static char *token_buffer;	/* Pointer to token buffer.
				   Actual allocated length is maxtoken + 2.  */
static int max_wide;		/* Current nominal length of wide_buffer.  */
static int *wide_buffer;	/* Pointer to wide-string buffer.
				   Actual allocated length is max_wide + 1.  */

/* Nonzero if end-of-file has been seen on input.  */
static int end_of_file;

/* Data type that represents the GNU C reserved words. */
struct resword { char *name; short token; enum rid rid; };

#define MIN_WORD_LENGTH     2      /* minimum size for C keyword */
#define MAX_WORD_LENGTH     9      /* maximum size for C keyword */
#define MIN_HASH_VALUE      4      /* range of the hash keys values for the */
#define MAX_HASH_VALUE      39     /* minimum perfect hash generator */
#define NORID RID_UNUSED

/* This function performs the minimum-perfect hash mapping from input
   string to reswords table index.  It only looks at the first and 
   last characters in the string, thus assuring the O(1) lookup time 
   (this keeps our constant down to an insignificant amount!).  Compiling
   the following 2 functions as inline removes all overhead of the
   function calls. */

#ifdef __GNUC__
inline 
#endif
static int 
hash (str, len)
   register char	*str;
   register int	len;
{

/* This table is used to build the hash table index that recognizes
   reserved words in 0(1) steps.  It is larger than strictly necessary, 
   but I'm trading off the space for the time-saving luxury of avoiding 
   subtraction of an offset.  All those ``39's'' (actually just a
   short-hand for MAX_HASH_VALUE #defined above) are used to speed up 
   the search when the string found on the input stream doesn't have a 
   first or last character that is part of the set of alphabetic 
   characters that comprise the first or last characters in C 
   reserved words. */

  static int hash_table[] = 
    {
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,  39,  39,  39,  39,  39,
      39,  39,  39,  39,  39,   5,  39,  32,  33,  18,
       2,   0,  13,  28,  19,  18,  39,   0,   5,   1,
      11,   3,  39,  39,  12,   6,   0,   0,   7,   1,
      39,  39,  39,  39,  39,  39,  39,  39,
    };

/* The hash function is very simple: add the length of STR
   to the hash_table value of its first and last character. 
   Putting LEN near LEN - 1 generates slightly better 
   code... */

  return len + hash_table[str[len - 1]] + hash_table[str[0]];
}

/* This routine attempts to match the string found in the reswords table
   with the one from the input stream.  If all the relevant details 
   match then an actual strcmp comparison is performed and the address of
   correct struct resword entry is returned.  Otherwise, a NULL 
   pointer is returned. */

#ifdef __GNUC__
inline 
#endif
static struct resword *
is_reserved_word (str, len)
   register char *str;
   register int len;
{

/* This is the hash table of keywords.
   The order of keywords has been chosen for perfect hashing.
   Therefore, this table cannot be updated by hand.
   Use the program ``gperf,'' available with the latest libg++ 
   distribution, to generate an updated table.  The command-line
   arguments to build this table were: gperf -g -o -j1 -t gnuc.input  */

  static struct resword reswords[] =
    {

      /* These first locations are unused, they simplify the hashing. */

		{ "",},{ "",},{ "",},{ "",},
		{ "else", ELSE, NORID },
		{ "enum", ENUM, NORID },
		{ "while", WHILE, NORID },
		{ "do", DO, NORID },
		{ "double", TYPESPEC, RID_DOUBLE },
		{ "default", DEFAULT, NORID },
		{ "unsigned", TYPESPEC, RID_UNSIGNED },
		{ "short", TYPESPEC, RID_SHORT },
		{ "struct", STRUCT, NORID },
		{ "void", TYPESPEC, RID_VOID },
		{ "signed", TYPESPEC, RID_SIGNED },
		{ "volatile", TYPE_QUAL, RID_VOLATILE },
		{ "union", UNION, NORID },
		{ "extern", SCSPEC, RID_EXTERN },
		{ "float", TYPESPEC, RID_FLOAT },
		{ "typeof", TYPEOF, NORID },
		{ "typedef", SCSPEC, RID_TYPEDEF },
		{ "int", TYPESPEC, RID_INT },
		{ "case", CASE, NORID },
		{ "const", TYPE_QUAL, RID_CONST },
		{ "inline", SCSPEC, RID_INLINE },
		{ "sizeof", SIZEOF, NORID },
		{ "continue", CONTINUE, NORID },
		{ "__alignof", ALIGNOF, NORID },
		{ "for", FOR, NORID },
		{ "return", RETURN, NORID },
		{ "static", SCSPEC, RID_STATIC },
		{ "switch", SWITCH, NORID },
		{ "register", SCSPEC, RID_REGISTER },
		{ "if", IF, NORID },
		{ "char", TYPESPEC, RID_CHAR },
		{ "goto", GOTO, NORID },
		{ "asm", ASM, NORID },
		{ "long", TYPESPEC, RID_LONG },
		{ "break", BREAK, NORID },
		{ "auto", SCSPEC, RID_AUTO },
    };

  if (len <= MAX_WORD_LENGTH && len >= MIN_WORD_LENGTH) 
    {
      register int key = hash (str, len);

      if (key <= MAX_HASH_VALUE) 
        {
          register char *s = reswords[key].name;

          if (*s == *str && !strcmp (str + 1, s + 1)) 
            return &reswords[key];
        }
    }
  return 0;
}

/* The elements of `ridpointers' are identifier nodes
   for the reserved type names and storage classes.
   It is indexed by a RID_... value.  */

tree ridpointers[(int) RID_MAX];

int check_newline ();

void
init_lex ()
{
  /* Start it at 0, because check_newline is called at the very beginning
     and will increment it to 1.  */
  lineno = 0;

  maxtoken = 40;
  token_buffer = (char *) xmalloc (maxtoken + 2);
  max_wide = 40;
  wide_buffer = (int *) xmalloc (max_wide + 1);

  ridpointers[(int) RID_INT] = get_identifier ("int");
  ridpointers[(int) RID_CHAR] = get_identifier ("char");
  ridpointers[(int) RID_VOID] = get_identifier ("void");
  ridpointers[(int) RID_FLOAT] = get_identifier ("float");
  ridpointers[(int) RID_DOUBLE] = get_identifier ("double");
  ridpointers[(int) RID_SHORT] = get_identifier ("short");
  ridpointers[(int) RID_LONG] = get_identifier ("long");
  ridpointers[(int) RID_UNSIGNED] = get_identifier ("unsigned");
  ridpointers[(int) RID_SIGNED] = get_identifier ("signed");
  ridpointers[(int) RID_INLINE] = get_identifier ("inline");
  ridpointers[(int) RID_CONST] = get_identifier ("const");
  ridpointers[(int) RID_VOLATILE] = get_identifier ("volatile");
  ridpointers[(int) RID_AUTO] = get_identifier ("auto");
  ridpointers[(int) RID_STATIC] = get_identifier ("static");
  ridpointers[(int) RID_EXTERN] = get_identifier ("extern");
  ridpointers[(int) RID_TYPEDEF] = get_identifier ("typedef");
  ridpointers[(int) RID_REGISTER] = get_identifier ("register");
}

static void
reinit_parse_for_function ()
{
}

/* If C is not whitespace, return C.
   Otherwise skip whitespace and return first nonwhite char read.  */

static int
skip_white_space (c)
     register int c;
{
#if 0
  register int inside;
#endif

  for (;;)
    {
      switch (c)
	{
	  /* Don't recognize comments in cc1: all comments are removed by cpp,
	     and cpp output can include / and * consecutively as operators.  */
#if 0
	case '/':
	  c = getc (finput);
	  if (c != '*')
	    {
	      ungetc (c, finput);
	      return '/';
	    }

	  c = getc (finput);

	  inside = 1;
	  while (inside)
	    {
	      if (c == '*')
		{
		  while (c == '*')
		    c = getc (finput);

		  if (c == '/')
		    {
		      inside = 0;
		      c = getc (finput);
		    }
		}
	      else if (c == '\n')
		{
		  lineno++;
		  c = getc (finput);
		}
	      else if (c == EOF)
		{
		  error ("unterminated comment");
		  break;
		}
	      else
		c = getc (finput);
	    }

	  break;
#endif

	case '\n':
	  c = check_newline ();
	  break;

	case ' ':
	case '\t':
	case '\f':
	case '\r':
	case '\b':
	  c = getc (finput);
	  break;

	case '\\':
	  c = getc (finput);
	  if (c == '\n')
	    lineno++;
	  else
	    error ("stray '\\' in program");
	  c = getc (finput);
	  break;

	default:
	  return (c);
	}
    }
}



/* Make the token buffer longer, preserving the data in it.
   P should point to just beyond the last valid character in the old buffer.
   The value we return is a pointer to the new buffer
   at a place corresponding to P.  */

static char *
extend_token_buffer (p)
     char *p;
{
  int offset = p - token_buffer;

  maxtoken = maxtoken * 2 + 10;
  token_buffer = (char *) xrealloc (token_buffer, maxtoken + 2);

  return token_buffer + offset;
}

/* At the beginning of a line, increment the line number
   and process any #-directive on this line.
   If the line is a #-directive, read the entire line and return a newline.
   Otherwise, return the line's first non-whitespace character.  */

int
check_newline ()
{
  register int c;
  register int token;

  lineno++;

  /* Read first nonwhite char on the line.  */

  c = getc (finput);
  while (c == ' ' || c == '\t')
    c = getc (finput);

  if (c != '#')
    {
      /* If not #, return it so caller will use it.  */
      return c;
    }

  /* Read first nonwhite char after the `#'.  */

  c = getc (finput);
  while (c == ' ' || c == '\t')
    c = getc (finput);

  /* If a letter follows, then if the word here is `line', skip
     it and ignore it; otherwise, ignore the line, with an error
     if the word isn't `pragma'.  */

  if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))
    {
      if (c == 'p')
	{
	  if (getc (finput) == 'r'
	      && getc (finput) == 'a'
	      && getc (finput) == 'g'
	      && getc (finput) == 'm'
	      && getc (finput) == 'a'
	      && ((c = getc (finput)) == ' ' || c == '\t'))
	    goto skipline;
	}

      else if (c == 'l')
	{
	  if (getc (finput) == 'i'
	      && getc (finput) == 'n'
	      && getc (finput) == 'e'
	      && ((c = getc (finput)) == ' ' || c == '\t'))
	    goto linenum;
	}
#ifdef IDENT_DIRECTIVE
      else if (c == 'i')
	{
	  if (getc (finput) == 'd'
	      && getc (finput) == 'e'
	      && getc (finput) == 'n'
	      && getc (finput) == 't'
	      && ((c = getc (finput)) == ' ' || c == '\t'))
	    {
	      extern FILE *asm_out_file;

	      if (pedantic)
		error ("ANSI C does not allow #ident");

	      /* Here we have just seen `#ident '.
		 A string constant should follow.  */

	      while (c == ' ' || c == '\t')
		c = getc (finput);

	      /* If no argument, ignore the line.  */
	      if (c == '\n')
		return c;

	      ungetc (c, finput);
	      token = yylex ();
	      if (token != STRING
		  || TREE_CODE (yylval.ttype) != STRING_CST)
		{
		  error ("invalid #ident");
		  goto skipline;
		}

#ifdef ASM_OUTPUT_IDENT
	      ASM_OUTPUT_IDENT (asm_out_file, TREE_STRING_POINTER (yylval.ttype));
#else
	      fprintf (asm_out_file, "\t.ident \"%s\"\n",
		       TREE_STRING_POINTER (yylval.ttype));
#endif

	      /* Skip the rest of this line.  */
	      goto skipline;
	    }
	}
#endif

      error ("undefined or invalid # directive");
      goto skipline;
    }

linenum:
  /* Here we have either `#line' or `# <nonletter>'.
     In either case, it should be a line number; a digit should follow.  */

  while (c == ' ' || c == '\t')
    c = getc (finput);

  /* If the # is the only nonwhite char on the line,
     just ignore it.  Check the new newline.  */
  if (c == '\n')
    return c;

  /* Something follows the #; read a token.  */

  ungetc (c, finput);
  token = yylex ();

  if (token == CONSTANT
      && TREE_CODE (yylval.ttype) == INTEGER_CST)
    {
      /* subtract one, because it is the following line that
	 gets the specified number */

      int l = TREE_INT_CST_LOW (yylval.ttype) - 1;

      /* Is this the last nonwhite stuff on the line?  */
      c = getc (finput);
      while (c == ' ' || c == '\t')
	c = getc (finput);
      if (c == '\n')
	{
	  /* No more: store the line number and check following line.  */
	  lineno = l;
	  return c;
	}
      ungetc (c, finput);

      /* More follows: it must be a string constant (filename).  */

      token = yylex ();
      if (token != STRING || TREE_CODE (yylval.ttype) != STRING_CST)
	{
	  error ("invalid #line");
	  goto skipline;
	}

      input_filename
	= (char *) permalloc (TREE_STRING_LENGTH (yylval.ttype) + 1);
      strcpy (input_filename, TREE_STRING_POINTER (yylval.ttype));
      lineno = l;

      if (main_input_filename == 0)
	main_input_filename = input_filename;
    }
  else
    error ("invalid #line");

  /* skip the rest of this line.  */
 skipline:
  while ((c = getc (finput)) != EOF && c != '\n');
  return c;
}

#define isalnum(char) ((char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z') || (char >= '0' && char <= '9'))
#define isdigit(char) (char >= '0' && char <= '9')
#define ENDFILE -1  /* token that represents end-of-file */


static int
readescape ()
{
  register int c = getc (finput);
  register int count, code;
  int firstdig;

  switch (c)
    {
    case 'x':
      code = 0;
      count = 0;
      while (1)
	{
	  c = getc (finput);
	  if (!(c >= 'a' && c <= 'f')
	      && !(c >= 'A' && c <= 'F')
	      && !(c >= '0' && c <= '9'))
	    {
	      ungetc (c, finput);
	      break;
	    }
	  code *= 16;
	  if (c >= 'a' && c <= 'f')
	    code += c - 'a' + 10;
	  if (c >= 'A' && c <= 'F')
	    code += c - 'A' + 10;
	  if (c >= '0' && c <= '9')
	    code += c - '0';
	  if (count == 0)
	    firstdig = code;
	  count++;
	}
      if (count == 0)
	error ("\\x used with no following hex digits");
      if ((count - 1) * 4 >= TYPE_PRECISION (integer_type_node)
	  || ((1 << (TYPE_PRECISION (integer_type_node) - (count - 1) * 4))
	      <= firstdig))
	warning ("hex escape out of range");
      return code;

    case '0':  case '1':  case '2':  case '3':  case '4':
    case '5':  case '6':  case '7':
      code = 0;
      count = 0;
      while ((c <= '7') && (c >= '0') && (count++ < 3))
	{
	  code = (code * 8) + (c - '0');
	  c = getc (finput);
	}
      ungetc (c, finput);
      return code;

    case '\\': case '\'': case '"':
      return c;

    case '\n':
      lineno++;
      return -1;

    case 'n':
      return TARGET_NEWLINE;

    case 't':
      return TARGET_TAB;

    case 'r':
      return TARGET_CR;

    case 'f':
      return TARGET_FF;

    case 'b':
      return TARGET_BS;

    case 'a':
      return TARGET_BELL;

    case 'v':
      return TARGET_VT;

    case 'E':
      return 033;

    case '?':
      /* `\(', etc, are used at beginning of line to avoid confusing Emacs.  */
    case '(':
    case '{':
    case '[':
      return c;
    }
  if (c >= 040 && c <= 0177)
    warning ("unknown escape sequence `\\%c'", c);
  else
    warning ("unknown escape sequence: `\\' followed by char code 0x%x", c);
  return c;
}

void
yyerror (string)
     char *string;
{
  char buf[200];

  strcpy (buf, string);

  /* We can't print string and character constants well
     because the token_buffer contains the result of processing escapes.  */
  if (end_of_file)
    strcat (buf, " at end of input");
  else if (token_buffer[0] == 0)
    strcat (buf, " at null character");
  else if (token_buffer[0] == '"')
    strcat (buf, " before string constant");
  else if (token_buffer[0] == '\'')
    strcat (buf, " before character constant");
  else if (token_buffer[0] < 040 || token_buffer[0] >= 0177)
    sprintf (buf + strlen (buf), " before character 0%o", token_buffer[0]);
  else
    strcat (buf, " before `%s'");

  error (buf, token_buffer);
}

static int nextchar = -1;

static int
yylex ()
{
  register int c;
  register char *p;
  register int value;
  int wide_flag = 0;

  if (nextchar >= 0)
    c = nextchar, nextchar = -1;
  else
    c = getc (finput);

  /* Effectively do c = skip_white_space (c)
     but do it faster in the usual cases.  */
  while (1)
    switch (c)
      {
      case ' ':
      case '\t':
      case '\f':
      case '\r':
      case '\b':
	c = getc (finput);
	break;

      case '\n':
      case '/':
      case '\\':
	c = skip_white_space (c);
      default:
	goto found_nonwhite;
      }
 found_nonwhite:

  token_buffer[0] = c;
  token_buffer[1] = 0;

/*  yylloc.first_line = lineno; */

  switch (c)
    {
    case EOF:
      end_of_file = 1;
      token_buffer[0] = 0;
      value = ENDFILE;
      break;

    case '$':
      if (dollars_in_ident)
	goto letter;
      return '$';

    case 'L':
      /* Capital L may start a wide-string or wide-character constant.  */
      {
	register int c = getc (finput);
	if (c == '\'')
	  {
	    wide_flag = 1;
	    goto char_constant;
	  }
	if (c == '"')
	  {
	    wide_flag = 1;
	    goto string_constant;
	  }
	ungetc (c, finput);
      }

    case 'A':  case 'B':  case 'C':  case 'D':  case 'E':
    case 'F':  case 'G':  case 'H':  case 'I':  case 'J':
    case 'K':		  case 'M':  case 'N':  case 'O':
    case 'P':  case 'Q':  case 'R':  case 'S':  case 'T':
    case 'U':  case 'V':  case 'W':  case 'X':  case 'Y':
    case 'Z':
    case 'a':  case 'b':  case 'c':  case 'd':  case 'e':
    case 'f':  case 'g':  case 'h':  case 'i':  case 'j':
    case 'k':  case 'l':  case 'm':  case 'n':  case 'o':
    case 'p':  case 'q':  case 'r':  case 's':  case 't':
    case 'u':  case 'v':  case 'w':  case 'x':  case 'y':
    case 'z':
    case '_':
    letter:
      p = token_buffer;
      while (isalnum (c) || c == '_' || c == '$')
	{
	  if (p >= token_buffer + maxtoken)
	    p = extend_token_buffer (p);
	  if (c == '$' && ! dollars_in_ident)
	    break;

	  *p++ = c;
	  c = getc (finput);
	}

      *p = 0;
      nextchar = c;

      value = IDENTIFIER;
      yylval.itype = 0;

      /* Try to recognize a keyword.  Uses minimum-perfect hash function */
  
      {
	register struct resword *ptr;

	if (ptr = is_reserved_word (token_buffer, p - token_buffer))
	  {
	    if (ptr->rid)
	      yylval.ttype = ridpointers[(int) ptr->rid];
	    if ((! flag_no_asm
		 /* -fno-asm means don't recognize the non-ANSI keywords.  */
		 || ((int) ptr->token != ASM
		     && (int) ptr->token != TYPEOF
		     && ptr->rid != RID_INLINE))
		/* -ftraditional means don't recognize nontraditional keywords
		   typeof, const, volatile, signed or inline.  */
		&& (! flag_traditional
		    || ((int) ptr->token != TYPE_QUAL
			&& (int) ptr->token != TYPEOF
			&& ptr->rid != RID_SIGNED
			&& ptr->rid != RID_INLINE)))
	      value = (int) ptr->token;
	  }
      }

      /* If we did not find a keyword, look for an identifier
	 (or a typename).  */

      if (value == IDENTIFIER)
	{
          yylval.ttype = get_identifier (token_buffer);
	  lastiddecl = lookup_name (yylval.ttype);

	  if (lastiddecl != 0 && TREE_CODE (lastiddecl) == TYPE_DECL)
	    value = TYPENAME;
	}

      break;

    case '0':  case '1':  case '2':  case '3':  case '4':
    case '5':  case '6':  case '7':  case '8':  case '9':
    case '.':
      {
	int base = 10;
	int count = 0;
	int largest_digit = 0;
	int numdigits = 0;
	/* for multi-precision arithmetic,
	   we store only 8 live bits in each short,
	   giving us 64 bits of reliable precision */
	short shorts[8];

	enum anon1 { NOT_FLOAT, AFTER_POINT, TOO_MANY_POINTS} floatflag
	  = NOT_FLOAT;

	for (count = 0; count < 8; count++)
	  shorts[count] = 0;

	p = token_buffer;
	*p++ = c;

	if (c == '0')
	  {
	    *p++ = (c = getc (finput));
	    if ((c == 'x') || (c == 'X'))
	      {
		base = 16;
		*p++ = (c = getc (finput));
	      }
	    else
	      {
		base = 8;
		numdigits++;
	      }
	  }

	/* Read all the digits-and-decimal-points.  */

	while (c == '.'
	       || (isalnum (c) && (c != 'l') && (c != 'L')
		   && (c != 'u') && (c != 'U')
		   && (floatflag == NOT_FLOAT || ((c != 'f') && (c != 'F')))))
	  {
	    if (c == '.')
	      {
		if (base == 16)
		  error ("floating constant may not be in radix 16");
		if (floatflag == AFTER_POINT)
		  {
		    error ("malformed floating constant");
		    floatflag = TOO_MANY_POINTS;
		  }
		else
		  floatflag = AFTER_POINT;

		base = 10;
		*p++ = c = getc (finput);
		/* Accept '.' as the start of a floating-point number
		   only when it is followed by a digit.
		   Otherwise, unread the following non-digit
		   and use the '.' as a structural token.  */
		if (p == token_buffer + 2 && !isdigit (c))
		  {
		    if (c == '.')
		      {
			c = getc (finput);
			if (c == '.')
			  {
			    *p++ = c;
			    *p = 0;
			    return ELLIPSIS;
			  }
			error ("parse error at `..'");
		      }
		    ungetc (c, finput);
		    token_buffer[1] = 0;
		    value = '.';
		    goto done;
		  }
	      }
	    else
	      {
		/* It is not a decimal point.
		   It should be a digit (perhaps a hex digit).  */

		if (isdigit (c))
		  {
		    c = c - '0';
		  }
		else if (base <= 10)
		  {
		    if ((c&~040) == 'E')
		      {
			base = 10;
			floatflag = AFTER_POINT;
			break;   /* start of exponent */
		      }
		    error ("nondigits in number and not hexadecimal");
		    c = 0;
		  }
		else if (c >= 'a')
		  {
		    c = c - 'a' + 10;
		  }
		else
		  {
		    c = c - 'A' + 10;
		  }
		if (c >= largest_digit)
		  largest_digit = c;
		numdigits++;
	    
		for (count = 0; count < 8; count++)
		  {
		    (shorts[count] *= base);
		    if (count)
		      {
			shorts[count] += (shorts[count-1] >> 8);
			shorts[count-1] &= (1<<8)-1;
		      }
		    else shorts[0] += c;
		  }
    
		if (p >= token_buffer + maxtoken - 3)
		  p = extend_token_buffer (p);
		*p++ = (c = getc (finput));
	      }
	  }

	if (numdigits == 0)
	  error ("numeric constant with no digits");

	if (largest_digit >= base)
	  error ("numeric constant contains digits beyond the radix");

	/* Remove terminating char from the token buffer and delimit the string */
	*--p = 0;

	if (floatflag != NOT_FLOAT)
	  {
	    tree type = double_type_node;
	    char f_seen = 0;
	    char l_seen = 0;
	    REAL_VALUE_TYPE value;

	    /* Read explicit exponent if any, and put it in tokenbuf.  */

	    if ((c == 'e') || (c == 'E'))
	      {
		if (p >= token_buffer + maxtoken - 3)
		  p = extend_token_buffer (p);
		*p++ = c;
		c = getc (finput);
		if ((c == '+') || (c == '-'))
		  {
		    *p++ = c;
		    c = getc (finput);
		  }
		if (! isdigit (c))
		  error ("floating constant exponent has no digits");
	        while (isdigit (c))
		  {
		    if (p >= token_buffer + maxtoken - 3)
		      p = extend_token_buffer (p);
		    *p++ = c;
		    c = getc (finput);
		  }
	      }

	    *p = 0;
	    errno = 0;
	    value = REAL_VALUE_ATOF (token_buffer);
#ifdef ERANGE
	    if (errno == ERANGE && !flag_traditional)
	      {
		char *p1 = token_buffer;
		/* Check for "0.0" and variants;
		   Sunos 4 spuriously returns ERANGE for them.  */
		while (*p1 == '0') p1++;
		if (*p1 == '.') p1++;
		while (*p1 == '0') p1++;
		if (*p1 != 0)
		  warning ("floating point number exceeds range of `double'");
	      }
#endif

	    /* Read the suffixes to choose a data type.  */
	    while (1)
	      {
		if (c == 'f' || c == 'F')
		  {
		    if (f_seen)
		      error ("two `f's in floating constant");
		    f_seen = 1;
		    type = float_type_node;
		  }
		else if (c == 'l' || c == 'L')
		  {
		    if (l_seen)
		      error ("two `l's in floating constant");
		    l_seen = 1;
		    type = long_double_type_node;
		  }
		else
		  {
		    if (isalnum (c))
		      {
			error ("garbage at end of number");
			while (isalnum (c))
			  {
			    if (p >= token_buffer + maxtoken - 3)
			      p = extend_token_buffer (p);
			    *p++ = c;
			    c = getc (finput);
			  }
		      }
		    break;
		  }
		if (p >= token_buffer + maxtoken - 3)
		  p = extend_token_buffer (p);
		*p++ = c;
		c = getc (finput);
	      }

	    /* Create a node with determined type and value.  */
	    yylval.ttype = build_real (type, value);

	    ungetc (c, finput);
	    *p = 0;
	  }
	else
	  {
	    tree type;
	    int spec_unsigned = 0;
	    int spec_long = 0;

	    while (1)
	      {
		if (c == 'u' || c == 'U')
		  {
		    if (spec_unsigned)
		      error ("two `u's in integer constant");
		    spec_unsigned = 1;
		  }
		else if (c == 'l' || c == 'L')
		  {
		    if (spec_long)
		      error ("two `l's in integer constant");
		    spec_long = 1;
		  }
		else
		  {
		    if (isalnum (c))
		      {
			error ("garbage at end of number");
			while (isalnum (c))
			  {
			    if (p >= token_buffer + maxtoken - 3)
			      p = extend_token_buffer (p);
			    *p++ = c;
			    c = getc (finput);
			  }
		      }
		    break;
		  }
		if (p >= token_buffer + maxtoken - 3)
		  p = extend_token_buffer (p);
		*p++ = c;
		c = getc (finput);
	      }

	    ungetc (c, finput);

	    if (shorts[7] | shorts[6] | shorts[5] | shorts[4])
	      warning ("integer constant out of range");

	    /* This is simplified by the fact that our constant
	       is always positive.  */
	    yylval.ttype
	      = build_int_2 ((shorts[3]<<24) + (shorts[2]<<16) + (shorts[1]<<8) + shorts[0],
			     0);
    
	    if (!spec_long && !spec_unsigned
		&& int_fits_type_p (yylval.ttype, integer_type_node))
	      type = integer_type_node;

	    else if (!spec_long && base != 10
		&& int_fits_type_p (yylval.ttype, unsigned_type_node))
	      type = unsigned_type_node;

	    else if (!spec_unsigned
		&& int_fits_type_p (yylval.ttype, long_integer_type_node))
	      type = long_integer_type_node;

	    else
	      {
		type = long_unsigned_type_node;
		if (! int_fits_type_p (yylval.ttype, long_unsigned_type_node))
		  warning ("integer constant out of range");
	      }
	    TREE_TYPE (yylval.ttype) = type;
	  }

	value = CONSTANT; break;
      }

    case '\'':
    char_constant:
      c = getc (finput);
      {
	register int code = 0;

      tryagain:

	if (c == '\\')
	  {
	    c = readescape ();
	    if (c < 0)
	      goto tryagain;
	    if (!wide_flag && c >= (1 << BITS_PER_UNIT))
	      warning ("escape sequence out of range for character");
	  }
	else if (c == '\n')
	  {
	    if (pedantic)
	      warning ("ANSI C forbids newline in character constant");
	    lineno++;
	  }

	code = c;
	token_buffer[1] = c;
	token_buffer[2] = '\'';
	token_buffer[3] = 0;

	c = getc (finput);
	if (c != '\'')
	  error ("malformatted character constant");

	/* If char type is signed, sign-extend the constant.  */
	if (! wide_flag)
	  {
	    if (TREE_UNSIGNED (char_type_node)
		|| ((code >> (BITS_PER_UNIT - 1)) & 1) == 0)
	      yylval.ttype = build_int_2 (code & ((1 << BITS_PER_UNIT) - 1), 0);
	    else
	      yylval.ttype = build_int_2 (code | ((-1) << BITS_PER_UNIT), -1);
	  }
	else
	  yylval.ttype = build_int_2 (code, 0);

	TREE_TYPE (yylval.ttype) = integer_type_node;
	value = CONSTANT; break;
      }

    case '"':
    string_constant:
      {
	int *widep;

	c = getc (finput);
	p = token_buffer + 1;

	if (wide_flag)
	  widep = wide_buffer;

	while (c != '"' && c >= 0)
	  {
	    if (c == '\\')
	      {
		c = readescape ();
		if (c < 0)
		  goto skipnewline;
		if (!wide_flag && c >= (1 << BITS_PER_UNIT))
		  warning ("escape sequence out of range for character");
	      }
	    else if (c == '\n')
	      {
		if (pedantic)
		  warning ("ANSI C forbids newline in string constant");
		lineno++;
	      }

	    /* Store the char in C into the appropriate buffer.  */

	    if (wide_flag)
	      {
		if (widep == wide_buffer + max_wide)
		  {
		    int n = widep - wide_buffer;
		    max_wide *= 2;
		    wide_buffer = (int *) xrealloc (wide_buffer, max_wide + 1);
		    widep = wide_buffer + n;
		  }
		*widep++ = c;
	      }
	    else
	      {
		if (p == token_buffer + maxtoken)
		  p = extend_token_buffer (p);
		*p++ = c;
	      }

	  skipnewline:
	    c = getc (finput);
	  }

	/* We have read the entire constant.
	   Construct a STRING_CST for the result.  */

	if (wide_flag)
	  {
	    /* If this is a L"..." wide-string, make a vector
	       of the ints in wide_buffer.  */
	    *widep = 0;
	    /* We have not implemented the case where `int'
	       on the target and on the execution machine differ in size.  */
	    if (TYPE_PRECISION (integer_type_node)
		!= sizeof (int) * BITS_PER_UNIT)
	      abort ();
	    yylval.ttype = build_string ((widep - wide_buffer) * sizeof (int),
					 wide_buffer);
	    TREE_TYPE (yylval.ttype) = int_array_type_node;
	  }
	else
	  {
	    *p = 0;
	    yylval.ttype = build_string (p - token_buffer, token_buffer + 1);
	    TREE_TYPE (yylval.ttype) = char_array_type_node;
	  }

	*p++ = '"';
	*p = 0;

	value = STRING; break;
      }
      
    case '+':
    case '-':
    case '&':
    case '|':
    case '<':
    case '>':
    case '*':
    case '/':
    case '%':
    case '^':
    case '!':
    case '=':
      {
	register int c1;

      combine:

	switch (c)
	  {
	  case '+':
	    yylval.code = PLUS_EXPR; break;
	  case '-':
	    yylval.code = MINUS_EXPR; break;
	  case '&':
	    yylval.code = BIT_AND_EXPR; break;
	  case '|':
	    yylval.code = BIT_IOR_EXPR; break;
	  case '*':
	    yylval.code = MULT_EXPR; break;
	  case '/':
	    yylval.code = TRUNC_DIV_EXPR; break;
	  case '%':
	    yylval.code = TRUNC_MOD_EXPR; break;
	  case '^':
	    yylval.code = BIT_XOR_EXPR; break;
	  case LSHIFT:
	    yylval.code = LSHIFT_EXPR; break;
	  case RSHIFT:
	    yylval.code = RSHIFT_EXPR; break;
	  case '<':
	    yylval.code = LT_EXPR; break;
	  case '>':
	    yylval.code = GT_EXPR; break;
	  }	

	token_buffer[1] = c1 = getc (finput);
	token_buffer[2] = 0;

	if (c1 == '=')
	  {
	    switch (c)
	      {
	      case '<':
		value = ARITHCOMPARE; yylval.code = LE_EXPR; goto done;
	      case '>':
		value = ARITHCOMPARE; yylval.code = GE_EXPR; goto done;
	      case '!':
		value = EQCOMPARE; yylval.code = NE_EXPR; goto done;
	      case '=':
		value = EQCOMPARE; yylval.code = EQ_EXPR; goto done;
	      }	
	    value = ASSIGN; goto done;
	  }
	else if (c == c1)
	  switch (c)
	    {
	    case '+':
	      value = PLUSPLUS; goto done;
	    case '-':
	      value = MINUSMINUS; goto done;
	    case '&':
	      value = ANDAND; goto done;
	    case '|':
	      value = OROR; goto done;
	    case '<':
	      c = LSHIFT;
	      goto combine;
	    case '>':
	      c = RSHIFT;
	      goto combine;
	    }
	else if ((c == '-') && (c1 == '>'))
	  { value = POINTSAT; goto done; }
	ungetc (c1, finput);
	token_buffer[1] = 0;

	if ((c == '<') || (c == '>'))
	  value = ARITHCOMPARE;
	else value = c;
	goto done;
      }

    case 0:
      /* Don't make yyparse think this is eof.  */
      value = 1;
      break;

    default:
      value = c;
    }

done:
/*  yylloc.last_line = lineno; */

  return value;
}
