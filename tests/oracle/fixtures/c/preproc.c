#ifndef GUARD_H
#define GUARD_H
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define VERSION 3
#if defined(VERSION) && VERSION > 2
int new_api(void);
#else
int old_api(void);
#endif
/* block
   comment */
static inline int sq(int x) { return x * x; } // trailing
#endif
