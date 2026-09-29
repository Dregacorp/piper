#include <stdint.h>
#include <time.h>

#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/mlvalues.h>

CAMLprim value piper_clock_monotonic_ns(value unit)
{
    struct timespec ts;

    (void)unit;

    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
        caml_failwith(
            "clock_gettime(CLOCK_MONOTONIC) failed"
        );
    }

    uint64_t ns =
        ((uint64_t)ts.tv_sec * UINT64_C(1000000000)) +
        (uint64_t)ts.tv_nsec;

    return caml_copy_int64(
        (int64_t)ns
    );
}
