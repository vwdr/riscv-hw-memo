/* SPDX-License-Identifier: MIT
 * bench_ptrcall.c — illustrative microbench with indirect calls.
 * This is NOT compiled in this MVP; it documents the patterns we memoize.
 *
 * Pattern: indirect calls (through function pointers) to small handlers
 * that do ONLY register-ALU work and return. The tracer would record the
 * post-state (register writes) and next_pc per calling context.
 */

typedef int (*handler_t)(int);

static int f_add7(int x)   { return x + 7; }
static int f_twiddle(int x){ return (x ^ 0x1234) & 0xFFFF; }

int main(void) {
  handler_t table[2] = { f_add7, f_twiddle };
  volatile int acc = 0;

  for (int i = 0; i < 100000; i++) {
    handler_t h = table[i & 1];  // indirect call
    int arg = (i & 1) ? 3 : 5;   // small domain, repeats often
    acc += h(arg);
  }

  return acc;
}
