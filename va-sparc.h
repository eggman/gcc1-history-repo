/*  varargs.h for SPARC.  */

/* NB.  This is NOT the definition needed for the new ANSI proposed
   standard */
 

struct __va_struct { char regs[24]; };

#define va_alist __va_regs, __va_stack

#define va_dcl struct __va_struct __va_regs; int __va_stack;

typedef int va_list;

#define va_start(pvar) ((pvar) = 0)

#define va_arg(pvar,type)  \
    ({  type __va_result; \
        if ((pvar) >= 24) { \
           __va_result = *( (type *) (&__va_stack + ((pvar) - 24)/4)); \
	   (pvar) += (sizeof(type) + 3) & ~3; \
	} \
	else if ((pvar) + sizeof(type) > 24) { \
	   __va_result = * (type *) &__va_stack; \
	   (pvar) = 24 + ( (sizeof(type) + 3) & ~3); \
	} \
	else if (sizeof(type) == 8) { \
	   union {double d; int i[2];} __u; \
	   __u.i[0] = *(int *) (__va_regs.regs + (pvar)); \
	   __u.i[1] = *(int *) (__va_regs.regs + (pvar) + 4); \
	   __va_result = * (type *) &__u; \
	   (pvar) += (sizeof(type) + 3) & ~3; \
	} \
	else { \
	   __va_result = * (type *) (__va_regs.regs + (pvar)); \
	   (pvar) += (sizeof(type) + 3) & ~3; \
	} \
	__va_result; })

#define va_end(pvar) (pvar)
