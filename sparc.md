;;- Machine description for SPARC chip for GNU C compiler
;;   Copyright (C) 1988 Free Software Foundation, Inc.
;;   Contributed by Michael Tiemann (tiemann@mcc.com)

;; This file is part of GNU CC.

;; GNU CC is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY.  No author or distributor
;; accepts responsibility to anyone for the consequences of using it
;; or for whether it serves any particular purpose or works at all,
;; unless he says so in writing.  Refer to the GNU CC General Public
;; License for full details.

;; Everyone is granted permission to copy, modify and redistribute
;; GNU CC, but only under the conditions described in the
;; GNU CC General Public License.   A copy of this license is
;; supposed to have been given to you along with GNU CC so you
;; can know your rights and responsibilities.  It should be in a
;; file named COPYING.  Among other things, the copyright notice
;; and this notice must be preserved on all copies.


;;- See file "rtl.def" for documentation on define_insn, match_*, et. al.

;;- cpp macro #define NOTICE_UPDATE_CC in file tm.h handles condition code
;;- updates for most instructions.

;;- Operand classes for the register allocator:

;; Compare instructions.
;; This controls RTL generation and register allocation.
(define_insn "cmpsi"
  [(set (cc0)
	(minus (match_operand:SI 0 "arith_operand" "rK")
	       (match_operand:SI 1 "arith_operand" "rK")))]
  ""
  "*
{
  if (! REG_P (operands[0]))
    {
      cc_status.flags |= CC_REVERSED;
      return \"cmp %1,%0\";
    }
  return \"cmp %0,%1\";
}")

(define_insn "cmpdf"
  [(set (cc0)
	(minus:DF (match_operand:DF 0 "nonmemory_operand" "fG")
		  (match_operand:DF 1 "nonmemory_operand" "fG")))
   (use (reg:DF 32))]
  ""
  "*
{
  if ((cc_status.flags & (CC_F0_IS_0|CC_F1_IS_0)) == 0
      && (GET_CODE (operands[0]) == CONST_DOUBLE
	  || GET_CODE (operands[1]) == CONST_DOUBLE))
    make_f0_contain_0 (2);

  cc_status.flags |= CC_IN_FCCR | CC_F0_IS_0 | CC_F1_IS_0;

  if (GET_CODE (operands[0]) == CONST_DOUBLE)
    return \"fcmped %%f0,%1\;nop\";
  if (GET_CODE (operands[1]) == CONST_DOUBLE)
    return \"fcmped %0,%%f0\;nop\";
  return \"fcmped %0,%1\;nop\";
}")

(define_insn "cmpsf"
  [(set (cc0)
	(minus:SF (match_operand:SF 0 "nonmemory_operand" "fG")
		  (match_operand:SF 1 "nonmemory_operand" "fG")))
   (use (reg:SF 32))]
  ""
  "*
{
  if ((cc_status.flags & (CC_F0_IS_0)) == 0
      && (GET_CODE (operands[0]) == CONST_DOUBLE
	  || GET_CODE (operands[1]) == CONST_DOUBLE))
    make_f0_contain_0 (1);

  cc_status.flags |= CC_IN_FCCR | CC_F0_IS_0;

  if (GET_CODE (operands[0]) == CONST_DOUBLE)
    return \"fcmpes %%f0,%1\;nop\";
  if (GET_CODE (operands[1]) == CONST_DOUBLE)
    return \"fcmpes %0,%%f0\;nop\";
  return \"fcmpes %0,%1\;nop\";
}")

;; We have to have these because cse can optimize the previous patterns
;; into this one.

(define_insn "tstsi"
  [(set (cc0)
	(match_operand:SI 0 "register_operand" "r"))]
  ""
  "tst %0")

(define_insn "tstdf"
  [(set (cc0)
	(match_operand:DF 0 "register_operand" "f"))
   (use (reg:DF 32))]
  ""
  "*
{
  if ((cc_status.flags & (CC_F0_IS_0|CC_F1_IS_0)) == 0)
    make_f0_contain_0 (2);

  cc_status.flags |= CC_IN_FCCR | CC_F0_IS_0 | CC_F1_IS_0;

  return \"fcmped %0,%%f0\;nop\";
}")

(define_insn "tstsf"
  [(set (cc0)
	(match_operand:SF 0 "register_operand" "f"))
   (use (reg:DF 32))]
  ""
  "*
{
  if ((cc_status.flags & (CC_F0_IS_0)) == 0)
    make_f0_contain_0 (1);

  cc_status.flags |= CC_IN_FCCR | CC_F0_IS_0;

  return \"fcmpes %0,%%f0\;nop\";
}")

;; These control RTL generation for conditional jump insns
;; and match them for register allocation.

(define_insn "beq"
  [(set (pc)
	(if_then_else (eq (cc0)
			  (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbe %l0\;nop\";
  return \"be %l0\;nop\";
}")

(define_insn "bne"
  [(set (pc)
	(if_then_else (ne (cc0)
			  (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbne %l0\;nop\";
  return \"bne %l0\;nop\";
}")

(define_insn "bgt"
  [(set (pc)
	(if_then_else (gt (cc0)
			  (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbgt %l0\;nop\";
  return \"bgt %l0\;nop\";
}")

(define_insn "bgtu"
  [(set (pc)
	(if_then_else (gtu (cc0)
			   (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbgu %l0\;nop\";
  return \"bgu %l0\;nop\";
}")

(define_insn "blt"
  [(set (pc)
	(if_then_else (lt (cc0)
			  (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbl %l0\;nop\";
  return \"bl %l0\;nop\";
}")

(define_insn "bltu"
  [(set (pc)
	(if_then_else (ltu (cc0)
			   (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fblu %l0\;nop\";
  return \"blu %l0\;nop\";
}")

(define_insn "bge"
  [(set (pc)
	(if_then_else (ge (cc0)
			  (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbge %l0\;nop\";
  return \"bge %l0\;nop\";
}")

(define_insn "bgeu"
  [(set (pc)
	(if_then_else (geu (cc0)
			   (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbgeu %l0\;nop\";
  return \"bgeu %l0\;nop\";
}")

(define_insn "ble"
  [(set (pc)
	(if_then_else (le (cc0)
			  (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fble %l0\;nop\";
  return \"ble %l0\;nop\";
}")

(define_insn "bleu"
  [(set (pc)
	(if_then_else (leu (cc0)
			   (const_int 0))
		      (label_ref (match_operand 0 "" ""))
		      (pc)))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbleu %l0\;nop\";
  return \"bleu %l0\;nop\";
}")

;; These match inverted jump insns for register allocation.

(define_insn ""
  [(set (pc)
	(if_then_else (eq (cc0)
			  (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbne %l0\;nop\";
  return \"bne %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (ne (cc0)
			  (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbe %l0\;nop\";
  return \"be %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (gt (cc0)
			  (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fble %l0\;nop\";
  return \"ble %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (gtu (cc0)
			   (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbleu %l0\;nop\";
  return \"bleu %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (lt (cc0)
			  (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbge %l0\;nop\";
  return \"bge %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (ltu (cc0)
			   (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbgeu %l0\;nop\";
  return \"bgeu %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (ge (cc0)
			  (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbl %l0\;nop\";
  return \"bl %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (geu (cc0)
			   (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fblu %l0\;nop\";
  return \"blu %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (le (cc0)
			  (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbg %l0\;nop\";
  return \"bg %l0\;nop\";
}")

(define_insn ""
  [(set (pc)
	(if_then_else (leu (cc0)
			   (const_int 0))
		      (pc)
		      (label_ref (match_operand 0 "" ""))))]
  ""
  "*
{
  if (cc_status.flags & CC_IN_FCCR)
    return \"fbgu %l0\;nop\";
  return \"bgu %l0\;nop\";
}")

;; Move instructions

(define_insn "swapsi"
  [(set (match_operand:SI 0 "general_operand" "r,rm")
	(match_operand:SI 1 "general_operand" "m,r"))
   (set (match_dup 1) (match_dup 0))]
  ""
  "*
{
  if (! REG_P (operands[1]))
    return \"swap %1,%0\";
  if (REG_P (operands[0]))
    {
      if (REGNO (operands[0]) == REGNO (operands[1]))
	return \"\";
      return \"xor %0,%1,%0\;xor %1,%0,%1\;xor %0,%1,%0\";
    }
  return \"swap %0,%1\";
}")

(define_insn "movsi"
  [(set (match_operand:SI 0 "general_operand" "=r,m")
	(match_operand:SI 1 "general_operand" "rmi,rJ"))]
  ""
  "*
{
  if (GET_CODE (operands[0]) == MEM)
    return \"st %r1,%0\";
  if (GET_CODE (operands[1]) == MEM)
    return \"ld %1,%0\";
  if (REG_P (operands[1]))
    return \"mov %1,%0\";
  return \"set %1,%0\";
}")

(define_insn ""
  [(set (match_operand:SI 0 "register_operand" "=r")
	(mem:SI (plus:SI (match_operand:SI 1 "register_operand" "r")
			 (match_operand:SI 2 "register_operand" "r"))))]
  ""
  "ld [%1+%2],%0")

(define_insn "movhi"
  [(set (match_operand:HI 0 "general_operand" "=r,m")
	(match_operand:HI 1 "general_operand" "rmi,rJ"))]
  ""
  "*
{
  if (GET_CODE (operands[0]) == MEM)
    return \"sth %r1,%0\";
  if (GET_CODE (operands[1]) == MEM)
    return \"ldsh %1,%0\";
  if (REG_P (operands[1]))
    return \"mov %1,%0\";
  return \"set %1,%0\";
}")

(define_insn "movqi"
  [(set (match_operand:QI 0 "general_operand" "=r,m")
	(match_operand:QI 1 "general_operand" "rmi,rJ"))]
  ""
  "*
{
  if (GET_CODE (operands[0]) == MEM)
    return \"stb %r1,%0\";
  if (GET_CODE (operands[1]) == MEM)
    return \"ldsb %1,%0\";
  if (REG_P (operands[1]))
    return \"mov %1,%0\";
  return \"set %1,%0\";
}")

;; The definition of this insn does not really explain what it does,
;; but it should suffice
;; that anything generated as this insn will be recognized as one
;; and that it won't successfully combine with anything.
(define_insn "movstrsi"
  [(set (match_operand:BLK 0 "general_operand" "=g")
	(match_operand:BLK 1 "general_operand" "g"))
   (use (match_operand:SI 2 "arith32_operand" "rn"))
   (clobber (reg:SI 8))
   (clobber (reg:SI 9))
   (clobber (reg:SI 10))]
  ""
  "* return output_block_move (operands);")

;; Floating point move insns

(define_insn ""
  [(set (match_operand:DF 0 "general_operand" "=fm")
	(mem:DF (match_operand:SI 1 "immediate_operand" "i")))]
  ""
  "*
{
  if (FP_REG_P (operands[0]))
    return \"set %1,%%o7\;ldd [%%o7],%0\";
  return \"set %1,%%o7\;ldd [%%o7],%%f0\;std %%f0,%0\";
}")

(define_insn ""
  [(set (match_operand:SF 0 "general_operand" "=fm")
	(mem:SF (match_operand:SI 1 "immediate_operand" "i")))]
  ""
  "*
{
  if (FP_REG_P (operands[0]))
    return \"set %1,%%o7\;ld [%%o7],%0\";
  return \"set %1,%%o7\;ld [%%o7],%%f0\;st %%f0,%0\";
}")

;; This pattern forces (set (reg:DF ...) (const_double ...))
;; to be reloaded by putting the constant into memory.
;; It must come before the more general movdf pattern.
(define_insn ""
  [(set (match_operand:DF 0 "general_operand" "=r,f,o")
	(match_operand:DF 1 "" "mG,m,G"))]
  "GET_CODE (operands[1]) == CONST_DOUBLE"
  "*
{
  if (FP_REG_P (operands[0]))
    return output_fp_move_double (operands);
  if (operands[1] == dconst0_rtx && GET_CODE (operands[0]) == REG)
    {
      operands[1] = gen_rtx (REG, SImode, REGNO (operands[0]) + 1);
      return \"add %%g0,0x0,%0\;add %%g0,0x0,%1\";
    }
  if (operands[1] == dconst0_rtx && GET_CODE (operands[0]) == MEM)
    {
      operands[1] = adj_offsetable_operand (operands[0], 4);
      return \"st %%g0,%0\;st %%g0,%1\";
    }
  return output_move_double (operands);
}")

(define_insn "movdf"
  [(set (match_operand:DF 0 "general_operand" "=r,m,?f,?rm")
	(match_operand:DF 1 "general_operand" "rm,r,rfm,f"))]
  ""
  "*
{
  if (FP_REG_P (operands[0]) || FP_REG_P (operands[1]))
    return output_fp_move_double (operands);
  return output_move_double (operands);
}")

(define_insn "movdi"
  [(set (match_operand:DI 0 "general_operand" "=r,m,?f,?rm")
	(match_operand:DI 1 "general_operand" "rm,r,rfm,f"))]
  ""
  "*
{
  if (FP_REG_P (operands[0]) || FP_REG_P (operands[1]))
    return output_fp_move_double (operands);
  return output_move_double (operands);
}")

(define_insn "movsf"
  [(set (match_operand:SF 0 "general_operand" "=rf,m")
	(match_operand:SF 1 "general_operand" "rfm,rf"))]
  ""
  "*
{
  if (FP_REG_P (operands[0]))
    {
      if (FP_REG_P (operands[1]))
	return \"fmovs %0,%1\";
      if (GET_CODE (operands[1]) == REG)
/* No good, since a signal would probably clobber that word on the stack.  */
/*	return \"st %1,[%%sp-4]\;ld [%%sp-4],%0\"; */
	{
	  rtx xoperands[2];
	  int offset = - get_frame_size () - 8;
	  xoperands[1] = operands[1];
	  xoperands[0] = gen_rtx (CONST_INT, VOIDmode, offset);
	  output_asm_insn (\"st %1,[%%fp+%0]\", xoperands);
	  xoperands[1] = operands[0];
	  output_asm_insn (\"ld [%%fp+%0],%1\", xoperands);
	  return \"\";
	}
      return \"ld %1,%0\";
    }
  if (FP_REG_P (operands[1]))
    {
      if (GET_CODE (operands[0]) == REG)
/* No good, since a signal would probably clobber that word on the stack.  */
/*	return \"st %1,[%%sp-4]\;ld [%%sp-4],%0\"; */
	{
	  rtx xoperands[2];
	  int offset = - get_frame_size () - 8;
	  xoperands[0] = gen_rtx (CONST_INT, VOIDmode, offset);
	  xoperands[1] = operands[1];
	  output_asm_insn (\"st %1,[%%fp+%0]\", xoperands);
	  xoperands[1] = operands[0];
	  output_asm_insn (\"ld [%%fp+%0],%1\", xoperands);
	  return \"\";
	}
      return \"st %1,%0\";
    }
  if (GET_CODE (operands[0]) == MEM)
    return \"st %r1,%0\";
  if (GET_CODE (operands[1]) == MEM)
    return \"ld %1,%0\";
  return \"mov %1,%0\";
}")

;;- truncation instructions
(define_insn "truncsiqi2"
  [(set (match_operand:QI 0 "general_operand" "=g")
	(truncate:QI
	 (match_operand:SI 1 "register_operand" "r")))]
  ""
  "*
{
  if (GET_CODE (operands[0]) == MEM)
    return \"stb %1,%0\";
  return \"or %1,%%g0,%0\";
}")

(define_insn "trunchiqi2"
  [(set (match_operand:QI 0 "general_operand" "=g")
	(truncate:QI
	 (match_operand:HI 1 "register_operand" "r")))]
  ""
  "*
{
  if (GET_CODE (operands[0]) == MEM)
    return \"stb %1,%0\";
  return \"or %1,%%g0,%0\";
}")

(define_insn "truncsihi2"
  [(set (match_operand:HI 0 "general_operand" "=g")
	(truncate:HI
	 (match_operand:SI 1 "register_operand" "r")))]
  ""
  "*
{
  if (GET_CODE (operands[0]) == MEM)
    return \"sth %1,%0\";
  return \"or %1,%%g0,%0\";
}")

;;- zero extension instructions

;; Note that the one starting from HImode comes before those for QImode
;; so that a constant operand will match HImode, not QImode.

(define_insn "zero_extendhisi2"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(zero_extend:SI
	 (match_operand:HI 1 "general_operand" "g")))]
  ""
  "*
{
  if (REG_P (operands[1]))
    return \"sll %1,0x10,%0\;srl %0,0x10,%0\";
  if (GET_CODE (operands[1]) == CONST_INT)
    abort ();
  return \"lduh %1,%0\";
}")

(define_insn "zero_extendqihi2"
  [(set (match_operand:HI 0 "register_operand" "=r")
	(zero_extend:HI
	 (match_operand:QI 1 "general_operand" "g")))]
  ""
  "*
{
  if (REG_P (operands[1]))
    return \"and %1,0xff,%0\";
  if (GET_CODE (operands[1]) == CONST_INT)
    abort ();
  return \"ldub %1,%0\";
}")

(define_insn "zero_extendqisi2"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(zero_extend:SI
	 (match_operand:QI 1 "general_operand" "g")))]
  ""
  "*
{
  if (REG_P (operands[1]))
    return \"and %1,0xff,%0\";
  if (GET_CODE (operands[1]) == CONST_INT)
    abort ();
  return \"ldub %1,%0\";
}")

;;- sign extension instructions
;; Note that the one starting from HImode comes before those for QImode
;; so that a constant operand will match HImode, not QImode.

(define_insn "extendhisi2"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(sign_extend:SI
	 (match_operand:HI 1 "general_operand" "g")))]
  ""
  "*
{
  if (REG_P (operands[1]))
    return \"sll %1,0x10,%0\;sra %0,0x10,%0\";
  if (GET_CODE (operands[1]) == CONST_INT)
    abort ();
  return \"ldsh %1,%0\";
}")

(define_insn "extendqihi2"
  [(set (match_operand:HI 0 "register_operand" "=r")
	(sign_extend:HI
	 (match_operand:QI 1 "general_operand" "g")))]
  ""
  "*
{
  if (REG_P (operands[1]))
    return \"sll %1,0x18,%0\;sra %0,0x18,%0\";
  if (GET_CODE (operands[1]) == CONST_INT)
    abort ();
  return \"ldsb %1,%0\";
}")

(define_insn "extendqisi2"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(sign_extend:SI
	 (match_operand:QI 1 "general_operand" "g")))]
  ""
  "*
{
  if (REG_P (operands[1]))
    return \"sll %1,0x18,%0\;sra %0,0x18,%0\";
  if (GET_CODE (operands[1]) == CONST_INT)
    abort ();
  return \"ldsb %1,%0\";
}")

;; Conversions between float and double.

(define_insn "extendsfdf2"
  [(set (match_operand:DF 0 "register_operand" "=f")
	(float_extend:DF
	 (match_operand:SF 1 "register_operand" "f")))]
  ""
  "fstod %1,%0")

(define_insn "truncdfsf2"
  [(set (match_operand:SF 0 "register_operand" "=f")
	(float_truncate:SF
	 (match_operand:DF 1 "register_operand" "f")))]
  ""
  "fdtos %1,%0")

;; Conversion between fixed point and floating point.
;; Note that among the fix-to-float insns
;; the ones that start with SImode come first.
;; That is so that an operand that is a CONST_INT
;; (and therefore lacks a specific machine mode).
;; will be recognized as SImode (which is always valid)
;; rather than as QImode or HImode.

;(define_insn "floatsisf2"
;  [(set (match_operand:SF 0 "general_operand" "=f")
;	(float:SF (match_operand:SI 1 "general_operand" "g")))]
;  ""
;  "*
;{
;  if (GET_CODE (operands[1]) == MEM)
;    if (FP_REG_P (operands[0]))
;      return \"ld %1,%0\;fitos %0,%0\";
;    else
;      {
;	int offset = - get_frame_size () - 4;
;	output_asm_insn (\"ld %1,%%f2\;fitos %%f2,%%f2\", operands);
;	if (GET_CODE (operands[0]) == MEM)
;	  return \"st %%f2,%0\";
;	operands[1] = gen_rtx (CONST_INT, VOIDmode, offset);
;	output_asm_insn (\"st %%f2,[%%fp+%1]\;ld [%%fp+%1],%0\", operands);
;      }
;  else if (FP_REG_P (operands[1]))
;    if (FP_REG_P (operands[0]))
;      return \"fitos %1,%0\";
;    else
;      {
;	int offset = - get_frame_size () - 4;
;	output_asm_insn (\"ld %1,%f2\;fitos %%f2,%%f2\", operands);
;	return \"st %%f2,%0\";
;      }
;  else
;    {
;      rtx xoperands[2];
;      int offset = - get_frame_size () - 4;
;      xoperands[0] = gen_rtx (CONST_INT, VOIDmode, offset);
;      xoperands[1] = operands[1];
;      output_asm_insn (\"st %1,[%%fp+%0]\", xoperands);
;      xoperands[1] = operands[0];
;      output_asm_insn (\"ld [%%fp+%0],%1\;fitos %1,%1\", xoperands);
;      return \"\";
;    }
;}")

(define_insn "floatsisf2"
  [(set (match_operand:SF 0 "general_operand" "=f")
	(float:SF (match_operand:SI 1 "general_operand" "g")))]
  ""
  "*
{
  if (GET_CODE (operands[1]) == MEM)
    return \"ld %1,%0\;fitos %0,%0\";
  else if (FP_REG_P (operands[1]))
    return \"fitos %1,%0\";
/* No good, since a signal would probably clobber that word on the stack.  */
/*  return \"st %1,[%%sp-4]\;ld [%%sp-4],%%f0\;fitos %%f0,%0\"; */
  else
    {
      rtx xoperands[2];
      int offset = - get_frame_size () - 4;
      xoperands[0] = gen_rtx (CONST_INT, VOIDmode, offset);
      xoperands[1] = operands[1];
      output_asm_insn (\"st %1,[%%fp+%0]\", xoperands);
      xoperands[1] = operands[0];
      output_asm_insn (\"ld [%%fp+%0],%1\;fitos %1,%1\", xoperands);
      return \"\";
    }
")

;(define_insn "floatsidf2"
;  [(set (match_operand:DF 0 "general_operand" "=f")
;	(float:DF (match_operand:SI 1 "general_operand" "g")))]
;  ""
;  "*
;{
;  if (GET_CODE (operands[1]) == MEM)
;    if (FP_REG_P (operands[0]))
;      return \"ld %1,%0\;fitod %0,%0\";
;    else
;      {
;	rtx xoperands[3];
;	xoperands[0] = operands[0];
;	xoperands[1] = gen_rtx (REG, VOIDmode, REGNO (operands[0]) + 1);
;	xoperands[2] = operands[1];
;	/* deal with loading a zero in.  */
;	abort ();
;	return \"ld %2,%0\;fmovs %%f0,%1\;fitod %0,%0\";
;      }
;  else if (FP_REG_P (operands[1]))
;    if (FP_REG_P (operands[0]))
;      return \"fitod %1,%0\";
;    else
;      {
;	output_asm_insn (\"ld %1,%f2\;fitod %%f2,%%f2\", operands);
;	return \"std %%f2,%0\";
;      }
;  else
;    {
;      rtx xoperands[3];
;      int offset = - get_frame_size () - 4;
;      xoperands[0] = gen_rtx (CONST_INT, VOIDmode, offset);
;      xoperands[1] = operands[1];
;      output_asm_insn (\"st %1,[%%fp+%0]\", xoperands);
;      xoperands[1] = operands[0];
;      xoperands[2] = gen_rtx (REG, VOIDmode, REGNO (operands[0]) + 1);
;      output_asm_insn (\"ld [%%fp+%0],%1\;fmovs %%f0,%2\;fitod %1,%1\", xoperands);
;      return \"\";
;    }
;}")

(define_insn "floatsidf2"
  [(set (match_operand:DF 0 "general_operand" "=f")
	(float:DF (match_operand:SI 1 "general_operand" "g")))]
  ""
  "*
{
  if (GET_CODE (operands[1]) == MEM)
    return \"ld %1,%0\;fitod %0,%0\";
  else if (FP_REG_P (operands[1]))
    return \"fitod %1,%0\";
  else
/* No good, since a signal would probably clobber that word on the stack.  */
/*  return \"st %1,[%%sp-4]\;ld [%%sp-4],%%f0\;fitod %%f0,%0\"; */
    {
      rtx xoperands[3];
      int offset = - get_frame_size () - 4;
      xoperands[0] = gen_rtx (CONST_INT, VOIDmode, offset);
      xoperands[1] = operands[1];
      output_asm_insn (\"st %1,[%%fp+%0]\", xoperands);
      xoperands[1] = operands[0];
      xoperands[2] = gen_rtx (REG, VOIDmode, REGNO (operands[0]) + 1);
      output_asm_insn (\"ld [%%fp+%0],%1\;fmovs %%f0,%2\;fitod %1,%1\", xoperands);
      return \"\";
    }
}")

;; Convert a float to an actual integer.
;; Truncation is performed as part of the conversion.
(define_insn "fix_truncsfsi2"
  [(set (match_operand:SI 0 "general_operand" "=rm")
	(fix:SI (fix:SF (match_operand:SF 1 "general_operand" "fm"))))]
  ""
  "*
{
  if (FP_REG_P (operands[1]))
    output_asm_insn (\"fstoi %1,%%f0\", operands);
  else
    output_asm_insn (\"ld %1,%%f0\;fstoi %%f0,%%f0\", operands);
  if (GET_CODE (operands[0]) == MEM)
    return \"st %%f0,%0\";
  else
/* No good, since a signal would probably clobber that word on the stack.  */
/*  return \"st %%f0,[%%sp-4]\;ld [%%sp-4],%0\"; */
    {
      int offset = - get_frame_size () - 4;
      operands[1] = gen_rtx (CONST_INT, VOIDmode, offset);
      return \"st %%f2,[%%fp+%1]\;ld [%%fp+%1],%0\";
    }
}")

(define_insn "fix_truncdfsi2"
  [(set (match_operand:SI 0 "general_operand" "=rm")
	(fix:SI (fix:DF (match_operand:DF 1 "general_operand" "fm"))))]
  ""
  "*
{
  if (FP_REG_P (operands[1]))
    output_asm_insn (\"fdtoi %1,%%f0\", operands);
  else
    output_asm_insn (\"ldd %1,%%f0\;fdtoi %%f0,%%f0\", operands);
  if (GET_CODE (operands[0]) == MEM)
    return \"st %%f0,%0\";
  else
/* No good, since a signal would probably clobber that word on the stack.  */
/*  return \"st %%f0,[%%sp-4]\;ld [%%sp-4],%0\"; */
    {
      int offset = - get_frame_size () - 4;
      operands[1] = gen_rtx (CONST_INT, VOIDmode, offset);
      return \"st %%f2,[%%fp+%1]\;ld [%%fp+%1],%0\";
    }
}")

;;- arithmetic instructions

(define_insn "addsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(plus:SI (match_operand:SI 1 "arith32_operand" "%r")
		 (match_operand:SI 2 "arith32_operand" "rn")))]
  ""
  "*
{
  if (REG_P (operands[2]))
    return \"add %1,%2,%0\";
  if (SMALL_INT (operands[2]))
    return \"add %1,%2,%0\";
  return \"set %2,%%o7\;add %1,%%o7,%0\";
}")

(define_insn "subsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(minus:SI (match_operand:SI 1 "register_operand" "r")
		  (match_operand:SI 2 "arith32_operand" "rn")))]
  ""
  "*
{
  if (REG_P (operands[2]))
    return \"sub %1,%2,%0\";
  if (SMALL_INT (operands[2]))
    return \"sub %1,%2,%0\";
  return \"set %2,%%o7\;sub %1,%%o7,%0\";
}")

(define_expand "mulsi3"
  [(set (match_operand:SI 0 "register_operand" "")
	(mult:SI (match_operand:SI 1 "general_operand" "")
		 (match_operand:SI 2 "general_operand" "")))]
  ""
  "
{
  rtx src;

  if (GET_CODE (operands[1]) == CONST_INT)
    if (GET_CODE (operands[2]) == CONST_INT)
      {
	emit_move_insn (operands[0],
			gen_rtx (CONST_INT, VOIDmode,
				 INTVAL (operands[1]) * INTVAL (operands[2])));
	DONE;
      }
    else
      src = gen_rtx (MULT, SImode,
		     copy_to_mode_reg (SImode, operands[2]),
		     operands[1]);
  else if (GET_CODE (operands[2]) == CONST_INT)
    src = gen_rtx (MULT, SImode,
		   copy_to_mode_reg (SImode, operands[1]),
		   operands[2]);
  else src = 0;

  if (src)
    emit_insn (gen_rtx (SET, VOIDmode, operands[0], src));
  else
    emit_insn (gen_rtx (PARALLEL, VOIDmode, gen_rtvec (5,
	       gen_rtx (SET, VOIDmode, operands[0],
			gen_rtx (MULT, SImode, operands[1], operands[2])),
	       gen_rtx (CLOBBER, VOIDmode, reg_o0_rtx),
	       gen_rtx (CLOBBER, VOIDmode, reg_o1_rtx),
	       gen_rtx (CLOBBER, VOIDmode, gen_rtx (REG, SImode, 12)),
	       gen_rtx (CLOBBER, VOIDmode, gen_rtx (REG, SImode, 13)))));
  DONE;
}")

(define_expand "umulsi3"
  [(set (match_operand:SI 0 "register_operand" "")
	(umult:SI (match_operand:SI 1 "general_operand" "")
		  (match_operand:SI 2 "general_operand" "")))]
  ""
  "
{
  rtx src;

  if (GET_CODE (operands[1]) == CONST_INT)
    if (GET_CODE (operands[2]) == CONST_INT)
      {
	emit_move_insn (operands[0],
			gen_rtx (CONST_INT, VOIDmode,
				 (unsigned)INTVAL (operands[1]) * (unsigned)INTVAL (operands[2])));
	DONE;
      }
    else
      src = gen_rtx (UMULT, SImode,
		     copy_to_mode_reg (SImode, operands[2]),
		     operands[1]);
  else if (GET_CODE (operands[2]) == CONST_INT)
    src = gen_rtx (UMULT, SImode,
		   copy_to_mode_reg (SImode, operands[1]),
		   operands[2]);
  else src = 0;

  if (src)
    emit_insn (gen_rtx (SET, VOIDmode, operands[0], src));
  else
    emit_insn (gen_rtx (PARALLEL, VOIDmode, gen_rtvec (5,
	       gen_rtx (SET, VOIDmode, operands[0],
			gen_rtx (UMULT, SImode, operands[1], operands[2])),
	       gen_rtx (CLOBBER, VOIDmode, gen_rtx (REG, SImode, 8)),
	       gen_rtx (CLOBBER, VOIDmode, gen_rtx (REG, SImode, 9)),
	       gen_rtx (CLOBBER, VOIDmode, gen_rtx (REG, SImode, 12)),
	       gen_rtx (CLOBBER, VOIDmode, gen_rtx (REG, SImode, 13)))));
  DONE;
}")

(define_insn ""
  [(set (match_operand:SI 0 "register_operand" "=r")
	(mult:SI (match_operand:SI 1 "register_operand" "r")
		 (match_operand:SI 2 "immediate_operand" "n")))]
  ""
  "* return output_mul_by_constant (insn, operands, 0);")

(define_insn ""
  [(set (match_operand:SI 0 "register_operand" "=r")
	(umult:SI (match_operand:SI 1 "register_operand" "r")
		  (match_operand:SI 2 "immediate_operand" "n")))]
  ""
  "* return output_mul_by_constant (insn, operands, 1);")

(define_insn ""
  [(set (match_operand:SI 0 "register_operand" "=r")
	(mult:SI (match_operand:SI 1 "general_operand" "%r")
		 (match_operand:SI 2 "general_operand" "r")))
   (clobber (reg:SI 8))
   (clobber (reg:SI 9))
   (clobber (reg:SI 12))
   (clobber (reg:SI 13))]
  ""
  "* return output_mul_insn (operands, 0);")

(define_insn ""
  [(set (match_operand:SI 0 "register_operand" "=r")
	(umult:SI (match_operand:SI 1 "general_operand" "%r")
		  (match_operand:SI 2 "general_operand" "r")))
   (clobber (reg:SI 8))
   (clobber (reg:SI 9))
   (clobber (reg:SI 12))
   (clobber (reg:SI 13))]
  ""
  "* return output_mul_insn (operands, 1);")

;; this pattern is needed because CSE may eliminate the multiplication,
;; but leave the clobbers behind.

(define_insn ""
  [(set (match_operand:SI 0 "register_operand" "=r")
	(match_operand:SI 1 "register_operand" "r"))
   (clobber (reg:SI 8))
   (clobber (reg:SI 9))
   (clobber (reg:SI 12))
   (clobber (reg:SI 13))]
  ""
  "mov %1,%0")

;;- and instructions (with compliment also)			   
(define_insn "andsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(and:SI (match_operand:SI 1 "arith32_operand" "%r")
		(match_operand:SI 2 "arith32_operand" "rn")))]
  ""
  "*
{
  if (REG_P (operands[2]))
    return \"and %1,%2,%0\";
  if (SMALL_INT (operands[2]))
    return \"and %1,%2,%0\";
  return \"set %2,%%o7\;and %1,%%o7,%0\";
}")

(define_insn "andcbsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(and:SI (match_operand:SI 1 "register_operand" "%r")
		(not:SI (match_operand:SI 2 "register_operand" "r"))))]
  ""
  "andn %1,%2,%0")

(define_insn "iorsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(ior:SI (match_operand:SI 1 "arith32_operand" "%r")
		(match_operand:SI 2 "arith32_operand" "rn")))]
  ""
  "*
{
  if (REG_P (operands[2]))
    return \"or %1,%2,%0\";
  if (SMALL_INT (operands[2]))
    return \"or %1,%2,%0\";
  return \"set %2,%%o7\;or %1,%%o7,%0\";
}")

(define_insn "iorcbsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(ior:SI (match_operand:SI 1 "register_operand" "%r")
		(not:SI (match_operand:SI 2 "register_operand" "r"))))]
  ""
  "orn %1,%2,%0")

(define_insn "xorsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(xor:SI (match_operand:SI 1 "arith32_operand" "%r")
		(match_operand:SI 2 "arith32_operand" "rn")))]
  ""
  "*
{
  if (REG_P (operands[2]))
    return \"xor %1,%2,%0\";
  if (SMALL_INT (operands[2]))
    return \"xor %1,%2,%0\";
  return \"set %2,%%o7\;xor %1,%%o7,%0\";
}")

(define_insn "xorcbsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(xor:SI (match_operand:SI 1 "register_operand" "%r")
		(not:SI (match_operand:SI 2 "register_operand" "r"))))]
  ""
  "xnor %1,%2,%0")

(define_insn "negsi2"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(neg:SI (match_operand:SI 1 "arith32_operand" "rn")))]
  ""
  "neg %1,%0")

(define_insn "one_cmplsi2"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(not:SI (match_operand:SI 1 "register_operand" "r")))]
  ""
  "not %1,%0")

;; Floating point arithmetic instructions.

(define_insn "adddf3"
  [(set (match_operand:DF 0 "register_operand" "=f")
	(plus:DF (match_operand:DF 1 "register_operand" "f")
		 (match_operand:DF 2 "register_operand" "f")))]
  ""
  "faddd %1,%2,%0")

(define_insn "addsf3"
  [(set (match_operand:SF 0 "register_operand" "=f")
	(plus:SF (match_operand:SF 1 "register_operand" "f")
		 (match_operand:SF 2 "register_operand" "f")))]
  ""
  "fadds %1,%2,%0")

(define_insn "subdf3"
  [(set (match_operand:DF 0 "register_operand" "=f")
	(minus:DF (match_operand:DF 1 "register_operand" "f")
		  (match_operand:DF 2 "register_operand" "f")))]
  ""
  "fsubd %1,%2,%0")

(define_insn "subsf3"
  [(set (match_operand:SF 0 "register_operand" "=f")
	(minus:SF (match_operand:SF 1 "register_operand" "f")
		  (match_operand:SF 2 "register_operand" "f")))]
  ""
  "fsubs %1,%2,%0")

(define_insn "muldf3"
  [(set (match_operand:DF 0 "register_operand" "=f")
	(mult:DF (match_operand:DF 1 "register_operand" "f")
		 (match_operand:DF 2 "register_operand" "f")))]
  ""
  "fmuld %1,%2,%0")

(define_insn "mulsf3"
  [(set (match_operand:SF 0 "register_operand" "=f")
	(mult:SF (match_operand:SF 1 "register_operand" "f")
		 (match_operand:SF 2 "register_operand" "f")))]
  ""
  "fmuls %1,%2,%0")

(define_insn "divdf3"
  [(set (match_operand:DF 0 "register_operand" "=f")
	(div:DF (match_operand:DF 1 "register_operand" "f")
		(match_operand:DF 2 "register_operand" "f")))]
  ""
  "fdivd %1,%2,%0")

(define_insn "divsf3"
  [(set (match_operand:SF 0 "register_operand" "=f")
	(div:SF (match_operand:SF 1 "register_operand" "f")
		(match_operand:SF 2 "register_operand" "f")))]
  ""
  "fdivs %1,%2,%0")

(define_insn "negdf2"
  [(set (match_operand:DF 0 "register_operand" "=f")
	(neg:DF (match_operand:DF 1 "register_operand" "f")))]
  ""
  "*
{
  if (REGNO (operands[0]) != REGNO (operands[1]))
    output_asm_insn (\"fmovs %1,%0\", operands);
  operands[0] = gen_rtx (REG, VOIDmode, REGNO (operands[0]) + 1);
  operands[1] = gen_rtx (REG, VOIDmode, REGNO (operands[1]) + 1);
  return \"fnegs %1,%0\";
}")

(define_insn "negsf2"
  [(set (match_operand:SF 0 "register_operand" "=f")
	(neg:SF (match_operand:SF 1 "register_operand" "f")))]
  ""
  "fnegs %1,%0")

(define_insn "absdf2"
  [(set (match_operand:DF 0 "register_operand" "=f")
	(abs:DF (match_operand:DF 1 "register_operand" "f")))]
  ""
  "*
{
  if (REGNO (operands[0]) != REGNO (operands[1]))
    output_asm_insn (\"fmovs %1,%0\", operands);
  operands[0] = gen_rtx (REG, VOIDmode, REGNO (operands[0]) + 1);
  operands[1] = gen_rtx (REG, VOIDmode, REGNO (operands[1]) + 1);
  return \"fabss %1,%0\";
}")

(define_insn "abssf2"
  [(set (match_operand:SF 0 "register_operand" "=f")
	(abs:SF (match_operand:SF 1 "register_operand" "f")))]
  ""
  "fabss %1,%0")

;; Shift instructions

;; Optimized special case of shifting.
;; Must precede the general case.

(define_insn ""
  [(set (match_operand:SI 0 "register_operand" "=r")
	(ashiftrt:SI (match_operand:SI 1 "memory_operand" "m")
		     (const_int 24)))]
  ""
  "ldsb %1,%0")

(define_insn ""
  [(set (match_operand:SI 0 "register_operand" "=r")
	(lshiftrt:SI (match_operand:SI 1 "memory_operand" "m")
		     (const_int 24)))]
  ""
  "ldub %1,%0")

;;- arithmetic shift instructions
(define_insn "ashlsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(ashift:SI (match_operand:SI 1 "register_operand" "r")
		   (match_operand:SI 2 "arith32_operand" "rn")))]
  ""
  "*
{
  if (GET_CODE (operands[2]) == CONST_INT
      && INTVAL (operands[2]) >= 32)
    return \"mov %%g0,%0\";
  return \"sll %1,%2,%0\";
}")

(define_insn "ashrsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(ashiftrt:SI (match_operand:SI 1 "register_operand" "r")
		     (match_operand:SI 2 "arith32_operand" "rn")))]
  ""
  "*
{
  if (GET_CODE (operands[2]) == CONST_INT
      && INTVAL (operands[2]) >= 32)
    return \"sra %1,31,%0\";
  return \"sra %1,%2,%0\";
}")

(define_insn "lshrsi3"
  [(set (match_operand:SI 0 "register_operand" "=r")
	(lshiftrt:SI (match_operand:SI 1 "register_operand" "r")
		   (match_operand:SI 2 "arith32_operand" "rn")))]
  ""
  "*
{
  if (GET_CODE (operands[2]) == CONST_INT
      && INTVAL (operands[2]) >= 32)
    return \"mov %%g0,%0\";
  return \"srl %1,%2,%0\";
}")

;; Unconditional and other jump instructions
(define_insn "jump"
  [(set (pc)
	(label_ref (match_operand 0 "" "")))]
  ""
  "b %l0\;nop")

(define_insn "tablejump"
  [(set (pc) (match_operand:SI 0 "register_operand" "r"))
   (use (label_ref (match_operand 1 "" "")))]
  ""
  "jmp %0\;nop")

;;- jump to subroutine
(define_insn "call"
  [(call (match_operand:SI 0 "memory_operand" "m")
	 (match_operand:SI 1 "general_operand" "g"))
   (use (reg:SI 31))]
  ;;- Don't use operand 1 for most machines.
  ""
  "*
{
  /* strip the MEM.  */
  operands[0] = XEXP (operands[0], 0);
  return \"jmpl %a0,%%o7\;nop\";
}")

(define_insn "call_value"
  [(set (match_operand 0 "" "rf")
	(call (match_operand:SI 1 "memory_operand" "m")
	      (match_operand:SI 2 "general_operand" "g")))
   (use (reg:SI 31))]
  ;;- Don't use operand 1 for most machines.
  ""
  "*
{
  /* strip the MEM.  */
  operands[1] = XEXP (operands[1], 0);
  return \"jmpl %a1,%%o7\;nop\";
}")

;; A memory ref with constant address is not normally valid.
;; But it is valid in a call insns.  This pattern allows the
;; loading of the address to combine with the call.
(define_insn ""
  [(call (mem:SI (match_operand:SI 0 "" "i"))
	 (match_operand:SI 1 "general_operand" "g"))
   (use (reg:SI 31))]
  "GET_CODE (operands[0]) == SYMBOL_REF"
  "call %0\;nop")

(define_insn ""
  [(set (match_operand 0 "" "rf")
	(call (mem:SI (match_operand:SI 1 "" "i"))
	      (match_operand:SI 2 "general_operand" "g")))
   (use (reg:SI 31))]
  "GET_CODE (operands[1]) == SYMBOL_REF"
  "call %1\;nop")

;; A purely functional call will have HImode.  (Experimental hack)
;; (define_insn ""
;;   [(call:HI (mem:SI (match_operand:SI 0 "" "i"))
;; 	 (match_operand:SI 1 "general_operand" "g"))
;;    (use (reg:SI 31))]
;;   "GET_CODE (operands[0]) == SYMBOL_REF"
;;   "call %0\t! no clobbers\;nop")

;; Extensions go here
;(define_insn "alloca"
;  [(set (match_operand:SI 0 "general_operand" "g")
;	(alloca (match_operand:SI 1 "general_operand" "g")))
;   (clobber (reg:SI 8))
;   (clobber (reg:SI 9))
;   (clobber (reg:SI 10))
;   (clobber (reg:SI 11))
;   (clobber (reg:SI 12))
;   (clobber (reg:SI 13))
;   (use (reg:SI 31))]
;  ""
;  "*
;{
;  rtx xoperands[1];
;  int save_reg1 = -1;
;  int save_reg2 = -1;
;
;  if (GET_CODE (operands[0]) == MEM)
;    {
;      rtx t = XEXP (operands[0], 0);
;      if (REG_P (t))
;	{
;	  if (REGNO (t) <= 13 && REGNO (t) >= 8)
;	    save_reg1 = REGNO (t);
;	}
;      else if (GET_CODE (t) == PLUS)
;	{
;	  rtx t1 = XEXP (t, 0);
;	  if (REG_P (t1) && REGNO (t1) <= 13 && REGNO (t1) >= 8)
;	    save_reg1 = REGNO (t1);
;	  t1 = XEXP (t, 1);
;	  if (REG_P (t1) && REGNO (t1) <= 13 && REGNO (t1) >= 8)
;	    save_reg2 = REGNO (t1);
;	}
;      else abort ();
;    }
;
;  if (save_reg1 >= 0)
;    {
;      xoperands[0] = gen_rtx (REG, SImode, save_reg1);
;      output_asm_insn (\"mov %0,%%g1\", xoperands);
;    }
;  if (save_reg2 >= 0)
;    {
;      xoperands[0] = gen_rtx (REG, SImode, save_reg2);
;      output_asm_insn (\"mov %0,%%g2\", xoperands);
;    }
;
;  if (GET_CODE (operands[1]) == MEM)
;    {
;      output_asm_insn (\"ld %1,%%o0\;add %%o0,0x7,%%o0\;and %%o0,-0x8,%%o0\",
;		       operands);
;    }
;  else if (REG_P (operands[1]))
;    {
;      output_asm_insn (\"add %1,0x7,%%o0\;and %%o0,-0x8,%%o0\", operands);
;    }
;  else if (GET_CODE (operands[1]) == CONST_INT)
;    {
;      int i = (INTVAL (operands[1]) + 7) & -8;
;      operands[1] = gen_rtx (CONST_INT, VOIDmode, i);
;      output_asm_insn (\"set %1,%%o0\", operands);
;    }
;  else abort ();
;
;  output_asm_insn (\"set Lt%x0,%%o2\;call ___builtin_alloca,3\;mov Lp%x0,%%o1\",
;		   operands);
;
;  if (REG_P (operands[0]))
;    if (REGNO (operands[0]) != 8)
;      return \"mov %%o0,%0\";
;    else
;      return \"\";
;
;  if (save_reg1 >= 0 || save_reg2 >= 0)
;    {
;      rtx t = XEXP (operands[0], 0);
;
;      if (GET_CODE (t) == REG)
;	operands[0] = gen_rtx (MEM, SImode, gen_rtx (REG, SImode, 1));
;      else if (GET_CODE (t) == PLUS)
;	{
;	  if (save_reg1 >= 0 && save_reg2 >= 0)
;	    operands[0] = gen_rtx (MEM, SImode,
;				   gen_rtx (PLUS, SImode,
;					    gen_rtx (REG, SImode, 1),
;					    gen_rtx (REG, SImode, 2)));
;	  else if (save_reg1 >= 0)
;	    operands[0] = gen_rtx (MEM, SImode,
;				   gen_rtx (PLUS, SImode,
;					    gen_rtx (REG, SImode, 1),
;					    XEXP (t, 1)));
;	  else
;	    operands[0] = gen_rtx (MEM, SImode,
;				   gen_rtx (PLUS, SImode, XEXP (t, 0),
;					    gen_rtx (REG, SImode, 2)));
;	}
;    }
;  return \"st %%o0,%0\";
;}")

;;- Local variables:
;;- mode:emacs-lisp
;;- comment-start: ";;- "
;;- eval: (set-syntax-table (copy-sequence (syntax-table)))
;;- eval: (modify-syntax-entry ?[ "(]")
;;- eval: (modify-syntax-entry ?] ")[")
;;- eval: (modify-syntax-entry ?{ "(}")
;;- eval: (modify-syntax-entry ?} "){")
;;- End:
