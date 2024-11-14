.global sm4neon_encrypt_block4
.global sm4_initialize_cache
.global sm4_key_expansion

/*
  Perform non-linear tao transformation

  In : w0 SM4WORD
  Out: w0 non-linear-tao transformed SM4WOR
*/
sm4_tao_transform:

    and w13, w0, #0x000000FF
    ubfx w14, w0, 8, 8
    ubfx w15, w0, 16, 8
    ubfx w16, w0, 24, 8

    mov w0, wzr
    adr x0, sm4_sbox
    
    ldrb w13, [x0, w13, uxtw]
    ldrb w14, [x0, w14, uxtw]
    ldrb w15, [x0, w15, uxtw]
    ldrb w16, [x0, w16, uxtw]

    mov w0, w13
    bfi w0, w14, 8, 8
    bfi w0, w15, 16, 8
    bfi w0, w16, 24, 8

    ret

/*
  Perform L transformation
  In : w0 SM4WORD
  Out: w0 L transformed SM4WORD
*/
sm4_lk_transform:
    mov x13, x30
    
//  Since ROL(number, n) = ROR(number, 32 - n), we can use ROR instead
//  Should be ROL 13 and ROL 23
    ror w14, w0, 19
    eor w14, w0, w14

    ror w0, w0, 9 
    eor w0, w14, w0

    mov x30, x13
    ret

/*
  SM4 Round F Function

  In : w1  SM4WORD
  In : w2  SM4WORD
  In : w3  SM4WORD
  In : w4  SM4WORD
  In : w5  CK
  Out: w0  F Function result SM4WORD 
*/
sm4_round_fk_function:
    mov x12, x30

    eor w0, w2, w3
    eor w0, w0, w4
    eor w0, w0, w5

    // T(w0: SM4WORD) = L(tao(w0))
    bl sm4_tao_transform
    bl sm4_lk_transform

    eor w0, w1, w0
 
    mov x30, x12
    ret

_memory_set_zr:
    mov x7, x0
    mov w6, wzr
1:  cbz w5, 2f
    strb w6, [x7], 1
    sub w5, w5, 1
    b 1b
2:  ret

/*
  In : x0 Buffer
  In : w1 SM4WORD
  In : w2 SM4WORD
  In : w3 SM4WORD
  In : w4 SM4WORD
  Out: x0 Ptr[RoundKey]
*/
sm4_key_expansion:
    stp x21, x30, [sp, -0x10]!

    // Prepare key generation
    adr x9, fk
    ldr w5, [x9], 4
    ldr w6, [x9], 4
    ldr w7, [x9], 4
    ldr w8, [x9]

    eor w1, w1, w5
    eor w2, w2, w6
    eor w3, w3, w7
    eor w4, w4, w8

    adr x10, ck

    // Make backups for output
    mov x8, x0
    mov x9, x0

    // Begin key generation
    mov w7, wzr
1:  cmp w7, 31
    bgt 2f // w7 >= 31 (Loop executes 32 times)

    // Xi+4 = F(Xi, Xi+1, Xi+2, Xi+3, RKi)
    // Load CK into w5
    ldr w5, [x10], 4

    // w0 = Xi+4 = F(w1, w2, w3, w4, w5(RKi))
    bl sm4_round_fk_function
    
    // Register status: w0,    w1, w2,   w3,   w4,   w5,  w6, w7, w8, w9, x10
    //                  Xi+4,  Xi, Xi+1, Xi+2, Xi+3, RKi, /,  i,  /,  /, Ptr[Rkey]

    // Do Xi shifting

    mov w1, w2 // assume i already incremented
    mov w2, w3
    mov w3, w4
    mov w4, w0
    

    // Register status: w0,    w1,   w2,   w3,   w4,   w5,  w6, w7, w8, w9, x10
    //                  Xi+4,  Xi+1, Xi+2, Xi+3, Xi+4, RKi, /,  i,  /,  /, Ptr[Rkey]

    // Rki = Xi+4
    str w4, [x9], 4 

    add w7, w7, 1
    b 1b // Loop End

2:  mov x0, x8

    ldp x21, x30, [sp], 0x10
    ret

/*
  SM4 vF(v1, v2, v3, v4, v5) function
  Perform one sm4 round for 4 blocks with inlined sm4_vt, sm4_vl and fastvtao. 
  
  F(x1, x2, x3, x4, rki) = x1 eor T(x2 eor x3 eor x4 eor rki) = x1 eor L(tao(x2 eor x3 eor x4 eor rki))

  In : v1  Vec[block1.1, block 2.1, block 3.1, block 4.1] 
  In : v2  Vec[block1.2, block 2.2, block 3.2, block 4.2] 
  In : v3  Vec[block1.3, block 2.3, block 3.3, block 4.3] 
  In : v4  Vec[block1.4, block 2.4, block 3.4, block 4.4]
  In : v5  Vec[rkey_i, rkey_i, rkey_i, rkey_i]
  In : v10 Vec[sbox[0x00-0x0F]]
  In : v11 Vec[sbox[0x10-0x1F]]
  In : v12 Vec[sbox[0x20-0x2F]]
  In : v13 Vec[sbox[0x30-0x3F]]
  In : v14 Vec[sbox[0x40-0x4F]]
  In : v15 Vec[sbox[0x50-0x5F]]
  In : v16 Vec[sbox[0x60-0x6F]]
  In : v17 Vec[sbox[0x70-0x7F]]
  In : v18 Vec[sbox[0x80-0x8F]]
  In : v19 Vec[sbox[0x90-0x9F]]
  In : v20 Vec[sbox[0xA0-0xAF]]
  In : v21 Vec[sbox[0xB0-0xBF]]
  In : v22 Vec[sbox[0xC0-0xCF]]
  In : v23 Vec[sbox[0xD0-0xDF]]
  In : v24 Vec[sbox[0xE0-0xEF]]
  In : v25 Vec[sbox[0xF0-0xFF]]

  Out: v1  Vec[block 2.1, block 3.1, block 4.1, block 5.1] 
  Out: v2  Vec[block 2.2, block 3.2, block 4.2, block 5.2] 
  Out: v3  Vec[block 2.3, block 3.3, block 4.3, block 5.3] 
  Out: v4  Vec[block 2.4, block 3.4, block 4.4, block 5.4] 
  Out: v5  unchanged

*/
sm4neon_f:
    
    // inline subroutine sm4_vt
    //
    // In : v1-v4
    // Out: v6-v9

    // x2     x3     x4     rki
    // v2 eor v3 eor v4 eor v5
    eor v0.16b, v2.16b, v3.16b
    eor v0.16b, v0.16b, v4.16b
    eor v0.16b, v0.16b, v5.16b

    // inline subroutine sm4_fastvtao
    //
    // In : v0
    // Out: v6
    movi v7.16b, 0x40 // TBL can only lookup for 0x40 at the same time
    
    // fastvsbox(v0) -> v6
    tbl v6.16b, { v10.16b, v11.16b, v12.16b, v13.16b }, v0.16b
    sub v0.16b, v0.16b, v7.16b
    tbx v6.16b, { v14.16b, v15.16b, v16.16b, v17.16b }, v0.16b
    sub v0.16b, v0.16b, v7.16b
    tbx v6.16b, { v18.16b, v19.16b, v20.16b, v21.16b }, v0.16b
    sub v0.16b, v0.16b, v7.16b
    tbx v6.16b, { v22.16b, v23.16b, v24.16b, v25.16b }, v0.16b

    // end subroutine sm4_fastvtao
    

    // inline subroutine sm4_vl_transform
    // 
    // In : v6
    // Out: v0

    // Since no ror instruction for vector so we have to impl rol by ourself
    // vrol(v6, #amount) = (v6 lsl #amount) and (v6 lsr 32-#amount)
    //                   = sri (v6 lsl #amount) v6 32-#amount
    // sri = lsr + and
    // shl and sri are performed in SM4WORD (4s)
    // vl(v6)

    // vrol(v6, 2)
    shl.4s v7, v6, 2
    sri.4s v7, v6, 30
    eor v0.16b, v7.16b, v6.16b

    // vrol(v7, 10)
    shl.4s v7, v6, 10
    sri.4s v7, v6, 22
    eor v0.16b, v7.16b, v0.16b

    // vrol(v7, 18)
    shl.4s v7, v6, 18
    sri.4s v7, v6, 14
    eor v0.16b, v7.16b, v0.16b

    // vrol(v7, 24)
    shl.4s v7, v6, 24
    sri.4s v7, v6, 8
    eor v0.16b, v7.16b, v0.16b

    // end subroutine sm4_vl_transform
    // end subroutine sm4_vt
    
    eor v0.16b, v1.16b, v0.16b

    // Swap register
    
    mov v1.16b, v2.16b
    mov v2.16b, v3.16b
    mov v3.16b, v4.16b
    mov v4.16b, v0.16b

    ret

/*
  Encrypt 4 blocks
  
  In : x0 Ptr(rkey)
  In : x1 Ptr(data) in Little-Endian
  In : x2 Ptr(result)
  Out: x2 Ptr(result)
*/
sm4neon_encrypt_block4:
    stp x30, x21, [sp, -0x10]!
    
    mov x3, x0
    
    // Load 4 blocks at the same time
    // Data layout:
    // REG       BLOCK1           BLOCK2           BLOCK3           BLOCK4 
    // v1  [ block1.sm4word1, block2.sm4word1, block3.sm4word1, block4.sm4word1 ]
    // v2  [ block1.sm4word2, block2.sm4word2, block3.sm4word2, block4.sm4word2 ]
    // v3  [ block1.sm4word3, block2.sm4word3, block3.sm4word3, block4.sm4word3 ]
    // v4  [ block1.sm4word4, block2.sm4word4, block3.sm4word4, block4.sm4word4 ]
    ld4 { v1.4s, v2.4s, v3.4s, v4.4s }, [x1]
    
    mov w5, 32
1:  cbz w5, 2f
   
    // Load rki into v5
    ldr w4, [x3], 4

    // ** Keep little-endian **
    // rev w4, w4
    // ** Keep little-endian **

    mov v5.s[0], w4
    mov v5.s[1], w4
    mov v5.s[2], w4
    mov v5.s[3], w4
    
    bl sm4neon_f

    sub w5, w5, 1
    b 1b
2: 
    // Block flip & Write into output (finalization)
    mov v0.16b, v1.16b
    mov v1.16b, v4.16b
    mov v4.16b, v0.16b

    mov v0.16b, v2.16b
    mov v2.16b, v3.16b
    mov v3.16b, v0.16b

    st4 { v1.4s, v2.4s, v3.4s, v4.4s }, [x2]

    ldp x30, x21, [sp], 0x10
    ret

sm4_initialize_cache:
    // prefetch to L1 Cache
    prfm PLDL1KEEP, fk 
    prfm PLDL1KEEP, ck 
    prfm PLDL1KEEP, sm4_sbox

    // preload sbox lookup table into v10-v25
    // used for fastvsbox
    adr x0, sm4_sbox
    ldr q10, [x0], 0x10
    ldr q11, [x0], 0x10
    ldr q12, [x0], 0x10
    ldr q13, [x0], 0x10
    ldr q14, [x0], 0x10
    ldr q15, [x0], 0x10
    ldr q16, [x0], 0x10
    ldr q17, [x0], 0x10
    ldr q18, [x0], 0x10
    ldr q19, [x0], 0x10
    ldr q20, [x0], 0x10
    ldr q21, [x0], 0x10
    ldr q22, [x0], 0x10
    ldr q23, [x0], 0x10
    ldr q24, [x0], 0x10
    ldr q25, [x0]

    ret

// Official system parameters
sm4_sbox: 
    .byte 0xd6,0x90,0xe9,0xfe,0xcc,0xe1,0x3d,0xb7,0x16,0xb6,0x14,0xc2,0x28,0xfb,0x2c,0x05,0x2b,0x67,0x9a,0x76,0x2a,0xbe,0x04,0xc3,0xaa,0x44,0x13,0x26,0x49,0x86,0x06,0x99,0x9c,0x42,0x50,0xf4,0x91,0xef,0x98,0x7a,0x33,0x54,0x0b,0x43,0xed,0xcf,0xac,0x62,0xe4,0xb3,0x1c,0xa9,0xc9,0x08,0xe8,0x95,0x80,0xdf,0x94,0xfa,0x75,0x8f,0x3f,0xa6,0x47,0x07,0xa7,0xfc,0xf3,0x73,0x17,0xba,0x83,0x59,0x3c,0x19,0xe6,0x85,0x4f,0xa8,0x68,0x6b,0x81,0xb2,0x71,0x64,0xda,0x8b,0xf8,0xeb,0x0f,0x4b,0x70,0x56,0x9d,0x35,0x1e,0x24,0x0e,0x5e,0x63,0x58,0xd1,0xa2,0x25,0x22,0x7c,0x3b,0x01,0x21,0x78,0x87,0xd4,0x00,0x46,0x57,0x9f,0xd3,0x27,0x52,0x4c,0x36,0x02,0xe7,0xa0,0xc4,0xc8,0x9e,0xea,0xbf,0x8a,0xd2,0x40,0xc7,0x38,0xb5,0xa3,0xf7,0xf2,0xce,0xf9,0x61,0x15,0xa1,0xe0,0xae,0x5d,0xa4,0x9b,0x34,0x1a,0x55,0xad,0x93,0x32,0x30,0xf5,0x8c,0xb1,0xe3,0x1d,0xf6,0xe2,0x2e,0x82,0x66,0xca,0x60,0xc0,0x29,0x23,0xab,0x0d,0x53,0x4e,0x6f,0xd5,0xdb,0x37,0x45,0xde,0xfd,0x8e,0x2f,0x03,0xff,0x6a,0x72,0x6d,0x6c,0x5b,0x51,0x8d,0x1b,0xaf,0x92,0xbb,0xdd,0xbc,0x7f,0x11,0xd9,0x5c,0x41,0x1f,0x10,0x5a,0xd8,0x0a,0xc1,0x31,0x88,0xa5,0xcd,0x7b,0xbd,0x2d,0x74,0xd0,0x12,0xb8,0xe5,0xb4,0xb0,0x89,0x69,0x97,0x4a,0x0c,0x96,0x77,0x7e,0x65,0xb9,0xf1,0x09,0xc5,0x6e,0xc6,0x84,0x18,0xf0,0x7d,0xec,0x3a,0xdc,0x4d,0x20,0x79,0xee,0x5f,0x3e,0xd7,0xcb,0x39,0x48
fk:
    .byte 0xC6, 0xBA, 0xB1, 0xA3, 0x50, 0x33, 0xAA, 0x56, 0x97, 0x91, 0x7D, 0x67, 0xDC, 0x22, 0x70, 0xB2
ck:
    .byte 0x15, 0x0e, 0x07, 0x00, 0x31, 0x2a, 0x23, 0x1c, 0x4d, 0x46, 0x3f, 0x38, 0x69, 0x62, 0x5b, 0x54, 0x85, 0x7e, 0x77, 0x70, 0xa1, 0x9a, 0x93, 0x8c, 0xbd, 0xb6, 0xaf, 0xa8, 0xd9, 0xd2, 0xcb, 0xc4, 0xf5, 0xee, 0xe7, 0xe0, 0x11, 0x0a, 0x03, 0xfc, 0x2d, 0x26, 0x1f, 0x18, 0x49, 0x42, 0x3b, 0x34, 0x65, 0x5e, 0x57, 0x50, 0x81, 0x7a, 0x73, 0x6c, 0x9d, 0x96, 0x8f, 0x88, 0xb9, 0xb2, 0xab, 0xa4, 0xd5, 0xce, 0xc7, 0xc0, 0xf1, 0xea, 0xe3, 0xdc, 0x0d, 0x06, 0xff, 0xf8, 0x29, 0x22, 0x1b, 0x14, 0x45, 0x3e, 0x37, 0x30, 0x61, 0x5a, 0x53, 0x4c, 0x7d, 0x76, 0x6f, 0x68, 0x99, 0x92, 0x8b, 0x84, 0xb5, 0xae, 0xa7, 0xa0, 0xd1, 0xca, 0xc3, 0xbc, 0xed, 0xe6, 0xdf, 0xd8, 0x09, 0x02, 0xfb, 0xf4, 0x25, 0x1e, 0x17, 0x10, 0x41, 0x3a, 0x33, 0x2c, 0x5d, 0x56, 0x4f, 0x48, 0x79, 0x72, 0x6b, 0x64
