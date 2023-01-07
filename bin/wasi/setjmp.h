#ifndef __ARCH_NONE_INCLUDE_SETJUMP_H
#define __ARCH_NONE_INCLUDE_SETJUMP_H 1

/****************************************************************************
 * Public Types
 ****************************************************************************/
#include <stdio.h>

struct setjmp_buf_s
{
  unsigned ctx_id;
};

/* Traditional typedef for setjmp_buf */

typedef struct setjmp_buf_s jmp_buf[1];

/****************************************************************************
 * Public Function Prototypes
 ****************************************************************************/

/*
int setjmp(jmp_buf env);
static void longjmp(jmp_buf env, int val) {

}
*/

static void longjmp(jmp_buf env, int val) {
    puts("longjmp:noreturn");
}


#endif /* __ARCH_NONE_INCLUDE_SETJUMP_H */

