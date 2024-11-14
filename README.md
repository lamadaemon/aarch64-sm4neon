# Fast sm4 implementation

Hand written ARMv8-a assembly. Requires SHA-3 and Advanced_SIMD support. Supports Android and is PIC.

## Benchmark

Platform: Xiaomi 13, sm8550 SOC

```
$ time sm4cO3 # C implementation with -O3
    0m00.24s real   0m00.22s user   0m00.00s system
$ time sm4asm # This implementation
    0m00.18s real   0m00.17s user   0m00.00s system
```

