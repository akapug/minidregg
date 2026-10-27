/* The Lean side of native/mini-kernels (HOT-PATH 2d): ByteArray marshalling for the two
 * `@[extern]` declarations `Theory/Sp800185Cshake256Native.lean` `cshake256Kernel`
 * (`mini_cshake256_32`) and `Compiler/Sp800185Kmac256.lean` `kmac256Kernel`
 * (`mini_kmac256_32`). Like native/resource-client/channel-lib/shim.c: lean.h's allocation and
 * accessor helpers are static inline, so the Rust kernel never sees a lean_object; this file
 * does exactly the copy in and the copy out. No hash semantics live here. Both arguments are
 * borrowed (`@&` in Lean: b_lean_obj_arg), the result is a fresh 32-byte ByteArray. */
#include <lean/lean.h>
#include <stddef.h>
#include <stdint.h>

void mini_kernels_cshake256_32(const uint8_t *customization, size_t customization_len,
                               const uint8_t *input, size_t input_len, uint8_t *output);
void mini_kernels_kmac256_32(const uint8_t *key, size_t key_len,
                             const uint8_t *customization, size_t customization_len,
                             const uint8_t *input, size_t input_len, uint8_t *output);

static lean_obj_res mini_kernels_fresh_32(void) {
  return lean_alloc_sarray(1, 32, 32);
}

LEAN_EXPORT lean_obj_res mini_cshake256_32(b_lean_obj_arg customization, b_lean_obj_arg input) {
  lean_obj_res out = mini_kernels_fresh_32();
  mini_kernels_cshake256_32(lean_sarray_cptr(customization), lean_sarray_size(customization),
                            lean_sarray_cptr(input), lean_sarray_size(input),
                            lean_sarray_cptr(out));
  return out;
}

LEAN_EXPORT lean_obj_res mini_kmac256_32(b_lean_obj_arg key, b_lean_obj_arg customization,
                                         b_lean_obj_arg input) {
  lean_obj_res out = mini_kernels_fresh_32();
  mini_kernels_kmac256_32(lean_sarray_cptr(key), lean_sarray_size(key),
                          lean_sarray_cptr(customization), lean_sarray_size(customization),
                          lean_sarray_cptr(input), lean_sarray_size(input),
                          lean_sarray_cptr(out));
  return out;
}
