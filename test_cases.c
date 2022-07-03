#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>

// Definicje, które wynikają z treści zadania.
#define MEM_SIZE 256

typedef struct __attribute__((packed)) {
  union {
    struct {
      uint8_t A, D, X, Y, PC;
      uint8_t unused; // Wypełniacz, aby struktura zajmowała 8 bajtów.
      bool    C, Z;
    };
    uint64_t packed64;
  };
} so_state_t;

// Wynik powinien mieć ustawione tylko bity, które są ustawione w tej masce.
static const so_state_t so_state_mask = {
  .A = 0xff, .D = 0xff, .X = 0xff, .Y = 0xff, .PC = 0xff, .unused = 0x00,
  .C = true, .Z = true
};

// Testowana funkcja
so_state_t so_emul(uint16_t const *code, uint8_t *data, size_t steps, size_t core);

// Wartość, która nie jest kodem poprawnej instrukcji i którą są wypełniane
// nieużywane komórki pamięci programu.
#define MAGIC 0xaaaa

/** WŁAŚCIWE TESTY **/

// test 0, test przykładowy, steps = sizeof code
static const uint16_t test_example_code[] = {
  0x4001, // MOVI A, 1
  0x4103, // MOVI D, 3
  0x4211, // MOVI X, 0x11
  0x4321, // MOVI Y, 0x21
  0x0400, // MOV  [X], A
  0x0d00, // MOV  [Y], D
  0x4607, // MOVI [X + D], 0x07
  0x0104, // ADD  D, A
  0x4608, // MOVI [X + D], 0x08
  0x3700, // MOV  [Y + D], [X + D]
  0x0000, // MOV  A, A; czyli NOP
};
static const so_state_t test_example_exp_state = {
  .A = 1, .D = 4, .X = 0x11, .Y = 0x21, .PC = 0x0B, .C = false, .Z = false
};
static const uint8_t test_example_exp_data[MEM_SIZE] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x01, 0x00, 0x00, 0x07, 0x08, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x03, 0x00, 0x00, 0x00, 0x08
};

// test 1, steps = 0
static const uint16_t test_empty_code[0];
static const so_state_t test_empty_exp_state = {.packed64 = 0};

// test 2, steps = 16 * 256 + 20
static const uint16_t test_nops_code[MEM_SIZE];
static const so_state_t test_nops_exp_state = {.PC = 20};

// test 3, steps = sizeof code
static const uint16_t test_movs_code[] = {
  0x4001, // MOVI A, 1
  0x4180, // MOVI D, 128
  0x427f, // MOVI X, 127
  0x43c0, // MOVI Y, 192
  0x440a, // MOVI [X], 0x0a
  0x450b, // MOVI [Y], 0x0b
  0x460c, // MOVI [X + D], 0x0c
  0x470d, // MOVI [Y + D], 0x0d
  0x0a00, // MOV  X, D
  0x2c00, // MOV  [X], [Y]
  0x0300, // MOV  Y, A
  0x2600, // MOV  [X + D], [X]
  0x2700, // MOV  [Y + D], [X]
  0x2200, // MOV  X, [X]
  0x3b00, // MOV  Y, [Y + D]
};
static const so_state_t test_movs_exp_state = {
  .A = 0x01, .D = 0x80, .X = 0x0b, .Y = 0x0b, .PC = 15, .C = false, .Z = false
};
static const uint8_t test_movs_exp_data[MEM_SIZE] = {
  0x0b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 0
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 16
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 32
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 48
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x0d, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 64
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 80
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 96
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 112
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a,
  0x0b, 0x0b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 128
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 144
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 160
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 176
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x0b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 192
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 208
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 224
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 240
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c,
};

// test 4, cztery uruchomienia: steps = 2, steps = 2, steps = 1, steps = 1
static const uint16_t test_addi_cmpi_code[] = {
  0x6081, // ADDI A, 129
  0x607f, // ADDI A, 127
  0x6002, // ADDI A, 2
  0x6803, // CMPI A, 3
  0x6802, // CMPI A, 2
  0x6801, // CMPI A, 1
};
static const so_state_t test_addi_cmpi_exp_state_1 = {
  .A = 0x00, .D = 0x00, .X = 0x00, .Y = 0x00, .PC = 2, .C = false, .Z = true
};
static const so_state_t test_addi_cmpi_exp_state_2 = {
  .A = 0x02, .D = 0x00, .X = 0x00, .Y = 0x00, .PC = 4, .C = true, .Z = false
};
static const so_state_t test_addi_cmpi_exp_state_3 = {
  .A = 0x02, .D = 0x00, .X = 0x00, .Y = 0x00, .PC = 5, .C = false, .Z = true
};
static const so_state_t test_addi_cmpi_exp_state_4 = {
  .A = 0x02, .D = 0x00, .X = 0x00, .Y = 0x00, .PC = 6, .C = false, .Z = false
};

// test 5, steps = sizeof code
static const uint16_t test_rcr_clc_stc_code[] = {
  0x7001, // RCR A
  0x8000, // CLC
  0x7001, // RCR A
  0x8100, // STC
  0x8000, // CLC
  0x7001, // RCR A
  0x8100, // STC
  0x7001, // RCR A
  0x8100, // STC
  0x7101, // RCR D
  0x8100, // STC
  0x7101, // RCR D
  0x7101, // RCR D
  0x7101, // RCR D
  0x7101, // RCR D
  0x7101, // RCR D
  0x7101, // RCR D
  0x7101, // RCR D
  0x7101, // RCR D
  0x7001, // RCR A
  0x7001, // RCR A
};
static const so_state_t test_rcr_clc_stc_exp_state = {
  .A = 0x60, .D = 0x01, .X = 0x00, .Y = 0x00, .PC = 21, .C = false, .Z = false
};

// test 6, cztery uruchomienia: steps = 1, steps = 2, steps = 2, steps = 1
static const uint16_t test_logic_code[] = {
  0x0002, // OR   A, A
  0x5955, // XORI D, 0x55
  0x0a00, // MOV  X, D
  0x8100, // STC
  0x5a55, // XORI X, 0x55
  0x0802, // OR   A, D
};
static const so_state_t test_logic_exp_state_1 = {
  .A = 0x00, .D = 0x00, .X = 0x00, .Y = 0x00, .PC = 1, .C = false, .Z = true
};
static const so_state_t test_logic_exp_state_2 = {
  .A = 0x00, .D = 0x55, .X = 0x55, .Y = 0x00, .PC = 3, .C = false, .Z = false
};
static const so_state_t test_logic_exp_state_3 = {
  .A = 0x00, .D = 0x55, .X = 0x00, .Y = 0x00, .PC = 5, .C = true, .Z = true
};
static const so_state_t test_logic_exp_state_4 = {
  .A = 0x55, .D = 0x55, .X = 0x00, .Y = 0x00, .PC = 6, .C = true, .Z = false
};

// test 7, steps = sizeof code
static const uint16_t test_arithmetic_code[] = {
  0x40f0, // MOVI A, 0xF0
  0x4101, // MOVI D, 0x01
  0x4202, // MOVI X, 0x02
  0x4303, // MOVI Y, 0x03
  0x1102, // OR   D, X;   D = 0x03, X = 0x02
  0x7001, // RCR  A
  0x0904, // ADD  D, D;   D = 0x06
  0x7001, // RCR  A
  0x0a05, // SUB  X, D;   X = 0x02 - 0x06 = 0xFC
  0x7001, // RCR  A
  0x8000, // CLC
  0x1906, // ADC  D, Y;   D = 0x06 + 0x03 + 0x00 = 0x09
  0x7001, // RCR  A
  0x8100, // STC
  0x1906, // ADC  D, Y;   D = 0x09 + 0x03 + 0x01 = 0x0D
  0x7001, // RCR  A
  0x43fb, // MOVI Y, 0xFB
  0x8100, // STC
  0x1a07, // SBB  X, Y;   X = 0xFC - 0xFB - 0x01 = 0x00
  0x7001, // RCR  A
};
static const so_state_t test_arithmetic_exp_state = {
  .A = 0x03, .D = 0x0D, .X = 0x00, .Y = 0xFB, .PC = 20, .C = true, .Z = true
};

// test 8, steps = 2 + 7 * 300
static const uint16_t test_adc_sbb_code[] = {
  0x4101, // MOVI D, 1
  0x4302, // MOVI Y, 2
  0x8100, // STC
  0x0406, // ADC  [X], A
  0x2606, // ADC  [X + D], [X]
  0x0507, // SBB  [Y], A
  0x2707, // SBB  [Y + D], [X]
  0x0506, // ADC  [Y], A
  0xc0f9, // JMP  -7
};
static const so_state_t test_adc_sbb_exp_state = {
  .A = 0, .D = 1, .X = 0, .Y = 2, .PC = 2, .C = false, .Z = false
};
static const uint8_t test_adc_sbb_exp_data[MEM_SIZE] = {
  0x2c, 0x5f, 0x01, 0xa2
};

// test 9, steps = 100
static const uint16_t test_var_jumps_code[] = {
  0xc004, // JMP  4
  0x6201, // ADDI X, 0x01
  0x6201, // ADDI X, 0x01
  0xc003, // JMP  3
  0x6201, // ADDI X, 0x01
  0xc0fd, // JMP  -3
  0x42f0, // MOVI X, 0xF0
  0xc001, // JMP  1
  0x40f0, // MOVI A, 0xF0
  0x8100, // STC
  0x8000, // CLC
  0xc301, // JC   1
  0x4101, // MOVI D, 0x01
  0xc201, // JNC  1
  0x4102, // MOVI D, 0x02
  0xc501, // JZ   1
  0x5902, // XORI D, 2
  0x6105, // ADDI D, 0x05
  0xc401, // JNZ  1
  0x42f0, // MOVI X, 0xF0
  0xc0ff, // JMP  -1
};
static const so_state_t test_var_jumps_exp_state = {
  .A = 0x00, .D = 0x08, .X = 0x00, .Y = 0x00, .PC = 0x14, .C = false, .Z = false
};

// test 10, steps = sizeof code
static const uint16_t test_no_jumps_code[] = {
  0xc000, // JMP  0
  0x4002, // MOVI A, 2
  0xc500, // JZ   0
  0x4101, // MOVI D, 1
  0xc400, // JNZ  0
  0x4203, // MOVI X, 3
  0xc300, // JC   0
  0x4304, // MOVI Y, 4
  0xc200, // JNC  0
  0x6301, // ADDI Y, 1
  0x6b05, // CMPI Y, 5
  0x8100, // STC
  0xc000, // JMP  0
  0x4401, // MOVI [X], 1
  0xc500, // JZ   0
  0x4502, // MOVI [Y], 2
  0xc400, // JNZ  0
  0x4603, // MOVI [X + D], 3
  0xc300, // JC   0
  0x4704, // MOVI [Y + D], 4
  0xc200, // JNC  0
  0x4306, // MOVI Y, 6
};
static const so_state_t test_no_jumps_exp_state = {
  .A = 2, .D = 1, .X = 3, .Y = 6, .PC = 22, .C = true, .Z = true
};
static const uint8_t test_no_jumps_exp_data[MEM_SIZE] = {
  0x00, 0x00, 0x00, 0x01, 0x03, 0x02, 0x04
};

// test 11, dwa uruchomienia: steps = 100, steps = 2
static const uint16_t test_brk_code[] = {
  0x4001, // MOVI A, 0x01
  0xffff, // BRK
  0x4302, // MOVI Y, 0x02
  0x4103, // MOVI D, 0x03
};
static const so_state_t test_brk_exp_state_1 = { // po pierwszym uruchomieniu
  .A = 0x01, .D = 0x00, .X = 0x00, .Y = 0x00, .PC = 2, .C = false, .Z = false
};
static const so_state_t test_brk_exp_state_2 = { // po drugim uruchomieniu
  .A = 0x01, .D = 0x03, .X = 0x00, .Y = 0x02, .PC = 4, .C = false, .Z = false
};

// testy 12-15 na podstawie testu przykładowego
static const uint16_t test_mul_code[] = {
  0x4201, // MOVI X, 1
  0x4300, // MOVI Y, 0
  0x2800, // MOV  A, [Y]
  0x4500, // MOVI [Y], 0
  0x4108, // MOVI D, 8
  0x7401, // RCR  [X]
  0xc202, // JNC  +2
  0x8000, // CLC
  0x0506, // ADC  [Y], A
  0x7501, // RCR  [Y]
  0x7401, // RCR  [X]
  0x61ff, // ADDI D, -1
  0xc4f9, // JNZ  -7
  0x0000, // MOV  A, A
};
// test 12, steps = 47
static       uint8_t test_mul_data_1[MEM_SIZE]     = {0x00, 0x00};
static const uint8_t test_mul_exp_data_1[MEM_SIZE] = {0x00, 0x00};
static const so_state_t test_mul_exp_state_1 = {
  .A = 0x00, .D = 0x00, .X = 0x01, .Y = 0x00, .PC = 0x0e, .C = false, .Z = true
};
// test 13, steps = 55
static       uint8_t test_mul_data_2[MEM_SIZE]     = {0xaa, 0x55};
static const uint8_t test_mul_exp_data_2[MEM_SIZE] = {0x38, 0x72};
static const so_state_t test_mul_exp_state_2 = {
  .A = 0xaa, .D = 0x00, .X = 0x01, .Y = 0x00, .PC = 0x0e, .C = false, .Z = true
};
// test 14, steps = 55
static       uint8_t test_mul_data_3[MEM_SIZE]     = {0x01, 0x66};
static const uint8_t test_mul_exp_data_3[MEM_SIZE] = {0x00, 0x66};
static const so_state_t test_mul_exp_state_3 = {
  .A = 0x01, .D = 0x00, .X = 0x01, .Y = 0x00, .PC = 0x0e, .C = false, .Z = true
};
// test 15, steps = 63
static       uint8_t test_mul_data_4[MEM_SIZE]     = {0xff, 0xff};
static const uint8_t test_mul_exp_data_4[MEM_SIZE] = {0xfe, 0x01};
static const so_state_t test_mul_exp_state_4 = {
  .A = 0xff, .D = 0x00, .X = 0x01, .Y = 0x00, .PC = 0x0e, .C = false, .Z = true
};

// test 40, steps = 79999997, core = 0
static const uint16_t test_xchg_code[MEM_SIZE] = {
  0x2208, // XCHG X, [X]
  0x1008, // XCHG A, X
  0x2308, // XCHG Y, [X]
  0x2e08, // XCHG [X + D], [Y]
  0x0008, // XCHG A, A
  0x3308, // XCHG Y, [X + D]
  0x3508, // XCHG [Y], [X + D]
  0x0108, // XCHG D, A
  0x3608, // XCHG [X + D], [X + D]
  0x1308, // XCHG Y, X
  0x3408, // XCHG [X], [X + D]
  0x1208, // XCHG X, X
  0x3f08, // XCHG [Y + D], [Y + D]
  0x0b08, // XCHG Y, D
  0x2d08, // XCHG [Y], [Y]
  0x1908, // XCHG D, Y
  0x2508, // XCHG [Y], [X]
  0x2908, // XCHG D, [Y]
  0x2c08, // XCHG [X], [Y]
  0x0308, // XCHG Y, A
  0x3808, // XCHG A, [Y + D]
  0x2808, // XCHG A, [Y]
  0x1a08, // XCHG X, Y
  0x3908, // XCHG D, [Y + D]
  0x0908, // XCHG D, D
  0x3108, // XCHG D, [X + D]
  0x0a08, // XCHG X, D
  0x0808, // XCHG A, D
  0x3c08, // XCHG [X], [Y + D]
  0x0208, // XCHG X, A
  0x3008, // XCHG A, [X + D]
  0x3b08, // XCHG Y, [Y + D]
  0x2408, // XCHG [X], [X]
  0x1108, // XCHG D, X
  0x2108, // XCHG D, [X]
  0x3d08, // XCHG [Y], [Y + D]
  0x2a08, // XCHG X, [Y]
  0x2008, // XCHG A, [X]
  0x3208, // XCHG X, [X + D]
  0x1808, // XCHG A, Y
  0x3e08, // XCHG [X + D], [Y + D]
  0x2608, // XCHG [X + D], [X]
  0x3708, // XCHG [Y + D], [X + D]
  0x3a08, // XCHG X, [Y + D]
  0x2708, // XCHG [Y + D], [X]
  0x2f08, // XCHG [Y + D], [Y]
  0x2b08, // XCHG Y, [Y]
  0x1b08, // XCHG Y, Y
  0xc0cf, // JMP -49
};
static uint8_t test_xchg_data_0[MEM_SIZE] = {
  0x07, 0x17, 0x27, 0x37, 0x47, 0x57, 0x67, 0x77,
  0x87, 0x97, 0xa7, 0xb7, 0xc7, 0xd7, 0xe7, 0xf7,
  0x08, 0x18, 0x28, 0x38, 0x48, 0x58, 0x68, 0x78,
  0x88, 0x98, 0xa8, 0xb8, 0xc8, 0xd8, 0xe8, 0xf8,
  0x09, 0x19, 0x29, 0x39, 0x49, 0x59, 0x69, 0x79,
  0x89, 0x99, 0xa9, 0xb9, 0xc9, 0xd9, 0xe9, 0xf9,
  0x0a, 0x1a, 0x2a, 0x3a, 0x4a, 0x5a, 0x6a, 0x7a,
  0x8a, 0x9a, 0xaa, 0xba, 0xca, 0xda, 0xea, 0xfa,
  0x0b, 0x1b, 0x2b, 0x3b, 0x4b, 0x5b, 0x6b, 0x7b,
  0x8b, 0x9b, 0xab, 0xbb, 0xcb, 0xdb, 0xeb, 0xfb,
  0x0c, 0x1c, 0x2c, 0x3c, 0x4c, 0x5c, 0x6c, 0x7c,
  0x8c, 0x9c, 0xac, 0xbc, 0xcc, 0xdc, 0xec, 0xfc,
  0x0d, 0x1d, 0x2d, 0x3d, 0x4d, 0x5d, 0x6d, 0x7d,
  0x8d, 0x9d, 0xad, 0xbd, 0xcd, 0xdd, 0xed, 0xfd,
  0x0e, 0x1e, 0x2e, 0x3e, 0x4e, 0x5e, 0x6e, 0x7e,
  0x8e, 0x9e, 0xae, 0xbe, 0xce, 0xde, 0xee, 0xfe,
  0x0f, 0x1f, 0x2f, 0x3f, 0x4f, 0x5f, 0x6f, 0x7f,
  0x8f, 0x9f, 0xaf, 0xbf, 0xcf, 0xdf, 0xef, 0xff,
  0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80,
  0x90, 0xa0, 0xb0, 0xc0, 0xd0, 0xe0, 0xf0, 0x00,
  0x11, 0x21, 0x31, 0x41, 0x51, 0x61, 0x71, 0x81,
  0x91, 0xa1, 0xb1, 0xc1, 0xd1, 0xe1, 0xf1, 0x01,
  0x12, 0x22, 0x32, 0x42, 0x52, 0x62, 0x72, 0x82,
  0x92, 0xa2, 0xb2, 0xc2, 0xd2, 0xe2, 0xf2, 0x02,
  0x13, 0x23, 0x33, 0x43, 0x53, 0x63, 0x73, 0x83,
  0x93, 0xa3, 0xb3, 0xc3, 0xd3, 0xe3, 0xf3, 0x03,
  0x14, 0x24, 0x34, 0x44, 0x54, 0x64, 0x74, 0x84,
  0x94, 0xa4, 0xb4, 0xc4, 0xd4, 0xe4, 0xf4, 0x04,
  0x15, 0x25, 0x35, 0x45, 0x55, 0x65, 0x75, 0x85,
  0x95, 0xa5, 0xb5, 0xc5, 0xd5, 0xe5, 0xf5, 0x05,
  0x16, 0x26, 0x36, 0x46, 0x56, 0x66, 0x76, 0x86,
  0x96, 0xa6, 0xb6, 0xc6, 0xd6, 0xe6, 0xf6, 0x06,
};
static const uint8_t test_xchg_exp_data_0[MEM_SIZE] = {
  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
  0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
  0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
  0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
  0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
  0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f,
  0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
  0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f,
  0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
  0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f,
  0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
  0x58, 0x59, 0x5a, 0x66, 0x5c, 0x5d, 0x5e, 0x5f,
  0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x9d, 0x67,
  0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f,
  0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
  0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e, 0x7f,
  0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
  0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
  0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97,
  0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x5b, 0x9e, 0x9f,
  0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7,
  0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf,
  0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7,
  0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe, 0xbf,
  0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7,
  0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf,
  0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7,
  0xd8, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde, 0xdf,
  0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7,
  0xe8, 0xe9, 0xea, 0xeb, 0xec, 0xed, 0xee, 0xef,
  0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7,
  0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff,
};
static const so_state_t test_xchg_exp_state_0 = {
  .A = 0, .D = 0, .X = 0, .Y = 0, .PC = 0, .C = false, .Z = false
};

// test 41, na podstawie testu przykładowego, steps = SIZE_MAX
static const uint16_t test_inc_code_0[MEM_SIZE] = { // core = 0
  0x4307, // MOVI Y, 7
  0xc012, // JMP  +18
  0x4001, // MOVI A, 1
  0x4205, // MOVI X, 5
  0x0408, // XCHG [X], A
  0x6800, // CMPI A, 0
  0xc4fd, // JNZ  -3
  0x42ff, // MOVI X, 255
  0x4104, // MOVI D, 4
  0x8100, // STC
  0x0606, // ADC  [X + D], A
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x4205, // MOVI X, 5
  0x0400, // MOV [X], A
  0x4104, // MOVI D, 4
  0x8100, // STC
  0x0707, // SBB  [Y + D], A
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x4104, // MOVI D, 4
  0x3800, // MOV  A, [Y + D]
  0x61ff, // ADDI D, -1
  0x3802, // OR   A, [Y + D]
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x6800, // CMPI A, 0
  0xc4e6, // JNZ  -26
  0xffff, // BRK
};
static const uint16_t test_inc_code_1[MEM_SIZE] = { // core = 1
  0x420b, // MOVI X, 11
  0xc012, // JMP  +18
  0x4001, // MOVI A, 1
  0x4305, // MOVI Y, 5
  0x0508, // XCHG [Y], A
  0x6800, // CMPI A, 0
  0xc4fd, // JNZ  -3
  0x43ff, // MOVI Y, 255
  0x4104, // MOVI D, 4
  0x8100, // STC
  0x0706, // ADC  [Y + D], A
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x4305, // MOVI Y, 5
  0x0500, // MOV [Y], A
  0x4104, // MOVI D, 4
  0x8100, // STC
  0x0607, // SBB  [X + D], A
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x4104, // MOVI D, 4
  0x3000, // MOV  A, [X + D]
  0x61ff, // ADDI D, -1
  0x3002, // OR   A, [X + D]
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x6800, // CMPI A, 0
  0xc4e6, // JNZ  -26
  0xffff, // BRK
};
static const uint16_t test_inc_code_2[MEM_SIZE] = { // core = 2
  0x430f, // MOVI Y, 15
  0xc013, // JMP  +19
  0x4101, // MOVI D, 1
  0x4205, // MOVI X, 5
  0x0c08, // XCHG [X], D
  0x6900, // CMPI D, 0
  0xc4fd, // JNZ  -3
  0x42ff, // MOVI X, 255
  0x4104, // MOVI D, 4
  0x4000, // MOVI A, 0
  0x8100, // STC
  0x0606, // ADC  [X + D], A
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x4205, // MOVI X, 5
  0x0400, // MOV [X], A
  0x4104, // MOVI D, 4
  0x8100, // STC
  0x0707, // SBB  [Y + D], A
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x4104, // MOVI D, 4
  0x3800, // MOV  A, [Y + D]
  0x61ff, // ADDI D, -1
  0x3802, // OR   A, [Y + D]
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x6800, // CMPI A, 0
  0xc4e5, // JNZ  -27
  0xffff, // BRK
};
static const uint16_t test_inc_code_3[MEM_SIZE] = { // core = 3
  0x4213, // MOVI X, 19
  0xc013, // JMP  +19
  0x4101, // MOVI D, 1
  0x4305, // MOVI Y, 5
  0x0d08, // XCHG [Y], D
  0x6900, // CMPI D, 0
  0xc4fd, // JNZ  -3
  0x43ff, // MOVI Y, 255
  0x4104, // MOVI D, 4
  0x4000, // MOVI A, 0
  0x8100, // STC
  0x0706, // ADC  [Y + D], A
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x4305, // MOVI Y, 5
  0x0500, // MOV [Y], A
  0x4104, // MOVI D, 4
  0x8100, // STC
  0x0607, // SBB  [X + D], A
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x4104, // MOVI D, 4
  0x3000, // MOV  A, [X + D]
  0x61ff, // ADDI D, -1
  0x3002, // OR   A, [X + D]
  0x61ff, // ADDI D, -1
  0xc4fd, // JNZ  -3
  0x6800, // CMPI A, 0
  0xc4e5, // JNZ  -27
  0xffff, // BRK
};
static uint8_t test_inc_data[MEM_SIZE] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x03, 0x0d, 0x44, 0x00, 0x03, 0x0d, 0x43,
  0x00, 0x03, 0x0d, 0x42, 0x00, 0x03, 0x0d, 0x41,
};
static const uint8_t test_inc_exp_data[MEM_SIZE] = {
  0x00, 0x0c, 0x35, 0x0a
};
static const so_state_t test_inc_exp_state_0 = { // core = 0
  .A = 0, .D = 0, .X = 5, .Y = 7, .PC = 29, .C = false, .Z = true
};
static const so_state_t test_inc_exp_state_1 = { // core = 1
  .A = 0, .D = 0, .X = 11, .Y = 5, .PC = 29, .C = false, .Z = true
};
static const so_state_t test_inc_exp_state_2 = { // core = 2
  .A = 0, .D = 0, .X = 5, .Y = 15, .PC = 30, .C = false, .Z = true
};
static const so_state_t test_inc_exp_state_3 = { // core = 3
  .A = 0, .D = 0, .X = 19, .Y = 5, .PC = 30, .C = false, .Z = true
};

// test 42, steps = SIZE_MAX, dwukrotne uruchomienie
static const uint16_t test_spinlock_code_0[MEM_SIZE] = { // core = 0
  0x40ff, // MOVI A, 255
  0x6800, // CMPI A, 0
  0xc402, // JNZ  +2
  0xffff, // BRK
  0xc0fb, // JMP  -5
  0x4202, // MOVI X, 2       ; wirująca blokada
  0x1408, // XCHG [X], X
  0x6a00, // CMPI X, 0
  0xc4fc, // JNZ  -4
  0x4203, // MOVI X, 3       ; sekcja krytyczna
  0x6401, // ADDI [X], 1
  0x4202, // MOVI X, 2       ; zwolnienie wirującej blokady
  0x4400, // MOVI [X], 0
  0x60ff, // ADDI A, -1
  0xc0f2, // JMP  -14
};
static const uint16_t test_spinlock_code_1[MEM_SIZE] = { // core = 1
  0x40ff, // MOVI A, 255
  0x6800, // CMPI A, 0
  0xc402, // JNZ  +2
  0xffff, // BRK
  0xc0fb, // JMP  -5
  0x4302, // MOVI Y, 2       ; wirująca blokada
  0x1d08, // XCHG [Y], Y
  0x6b00, // CMPI Y, 0
  0xc4fc, // JNZ  -4
  0x4303, // MOVI Y, 3       ; sekcja krytyczna
  0x6501, // ADDI [Y], 1
  0x4302, // MOVI Y, 2       ; zwolnienie wirującej blokady
  0x4500, // MOVI [Y], 0
  0x60ff, // ADDI A, -1
  0xc0f2, // JMP  -14
};
static const uint16_t test_spinlock_code_2[MEM_SIZE] = { // core = 2
  0x4101, // MOVI D, 1
  0x40ff, // MOVI A, 255
  0x6800, // CMPI A, 0
  0xc402, // JNZ  +2
  0xffff, // BRK
  0xc0fb, // JMP  -5
  0x4201, // MOVI X, 1       ; wirująca blokada
  0x1608, // XCHG [X + D], X
  0x6a00, // CMPI X, 0
  0xc4fc, // JNZ  -4
  0x4203, // MOVI X, 3       ; sekcja krytyczna
  0x6401, // ADDI [X], 1
  0x4202, // MOVI X, 2       ; zwolnienie wirującej blokady
  0x4400, // MOVI [X], 0
  0x60ff, // ADDI A, -1
  0xc0f2, // JMP  -14
};
static const uint16_t test_spinlock_code_3[MEM_SIZE] = { // core = 3
  0x4101, // MOVI D, 1
  0x40ff, // MOVI A, 255
  0x6800, // CMPI A, 0
  0xc402, // JNZ  +2
  0xffff, // BRK
  0xc0fb, // JMP  -5
  0x4301, // MOVI Y, 1        ; wirująca blokada
  0x1f08, // XCHG [Y + D], Y
  0x6b00, // CMPI Y, 0
  0xc4fc, // JNZ  -4
  0x4303, // MOVI Y, 3        ; sekcja krytyczna
  0x6501, // ADDI [Y], 1
  0x4302, // MOVI Y, 2        ; zwolnienie wirującej blokady
  0x4500, // MOVI [Y], 0
  0x60ff, // ADDI A, -1
  0xc0f2, // JMP  -14
};
static uint8_t test_spinlock_data[MEM_SIZE] = {
  0x00, 0x00, 0x00, 0x00
};
static const uint8_t test_spinlock_exp_data[MEM_SIZE] = {
  0x00, 0x00, 0x00, 0xf8
};
static const so_state_t test_spinlock_exp_state_0 = { // core = 0
  .A = 0, .D = 0, .X = 2, .Y = 0, .PC = 4, .C = false, .Z = true
};
static const so_state_t test_spinlock_exp_state_1 = { // core = 1
  .A = 0, .D = 0, .X = 0, .Y = 2, .PC = 4, .C = false, .Z = true
};
static const so_state_t test_spinlock_exp_state_2 = { // core = 2
  .A = 0, .D = 1, .X = 2, .Y = 0, .PC = 5, .C = false, .Z = true
};
static const so_state_t test_spinlock_exp_state_3 = { // core = 3
  .A = 0, .D = 1, .X = 0, .Y = 2, .PC = 5, .C = false, .Z = true
};
