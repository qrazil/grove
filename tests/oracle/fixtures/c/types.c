// types and declarations
typedef unsigned long size_t_;
struct point { int x, y; };
union value { int i; float f; char *s; };
enum color { RED, GREEN = 2, BLUE };
static const char *names[] = { "a", "b", "c" };
extern int counter;
int (*callback)(void *, size_t_);
struct point origin = { .x = 0, .y = 0 };
