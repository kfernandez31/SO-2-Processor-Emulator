;todo: ujednolicić nazewnictwo (so, cpu)

; compilation-time constant for max number of cores used at once
%ifndef DCORES
%define DCORES 4
%endif

%define SO_CPU          rbx+rcx*8
%define JTBL_CAT        r12
%define JTBL_2ARGS      r13
%define JTBL_ARG_IMM8   r14
%define JTBL_JUMPS      r15

; so_cpu_t fields
REG_A    equ 0x0
REG_D    equ 0x1
REG_X    equ 0x2
REG_Y    equ 0x3
REG_PC   equ 0x4
FLAG_C   equ 0x6
FLAG_Z   equ 0x7

; addresses specified in instruction arguments
addr_X   equ 0x4
addr_Y   equ 0x5
addr_XD  equ 0x6
addr_YD  equ 0x7

; emulator instructions
SO_BRK   equ 0xFFFF

SO_MOV   equ 0x0
SO_OR    equ 0x2
SO_ADD   equ 0x4
SO_SUB   equ 0x5
SO_ADC   equ 0x6
SO_SBB   equ 0x7
SO_XCHG  equ 0x8

SO_MOVI  equ 0x1
SO_XORI  equ 0x4
SO_ADDI  equ 0x5
SO_CMPI  equ 0x6
SO_RCR   equ 0x7

SO_CLC   equ 0x0
SO_STC   equ 0x1

SO_JMP   equ 0x0
SO_JNC   equ 0x2
SO_JC    equ 0x3
SO_JNZ   equ 0x4
SO_JZ    equ 0x5

section .rodata
; jump-table of instruction categories
    jtbl_cat:
        dq main.cat_2args    - jtbl_cat
        dq main.cat_arg_imm8 - jtbl_cat
        dq main.cat_fsets    - jtbl_cat
        dq main.cat_jumps    - jtbl_cat
; jump-table of instructions that take two arguments
    jtbl_2args:
        dq main.SO_MOV       - jtbl_2args
        dq main.after_switch - jtbl_2args
        dq main.SO_OR        - jtbl_2args
        dq main.after_switch - jtbl_2args
        dq main.SO_ADD       - jtbl_2args
        dq main.SO_SUB       - jtbl_2args
        dq main.SO_ADC       - jtbl_2args
        dq main.SO_SBB       - jtbl_2args
        dq main.SO_XCHG      - jtbl_2args
; jump-table of instructions that take an argument and an immediate 8-bit value
    jtbl_arg_imm8:
        dq main.SO_MOVI       - jtbl_arg_imm8
        dq main.after_switch  - jtbl_arg_imm8
        dq main.after_switch  - jtbl_arg_imm8
        dq main.SO_XORI       - jtbl_arg_imm8
        dq main.SO_ADDI       - jtbl_arg_imm8
        dq main.SO_CMPI       - jtbl_arg_imm8
        dq main.SO_RCR        - jtbl_arg_imm8
; jump-table of instructions that perform jumps
    jtbl_jumps:
        dq main.SO_JMP       - jtbl_jumps
        dq main.after_switch - jtbl_jumps
        dq main.SO_JNC       - jtbl_jumps
        dq main.SO_JC        - jtbl_jumps
        dq main.SO_JNZ       - jtbl_jumps
        dq main.SO_JZ        - jtbl_jumps

section .bss
; array of cpu states for each core. The current core's state is at `states[core]`
    states: resb 8 * DCORES

section .text
; gets a reference to a SO-register or SO-address based on r12, returns with rax
get_arg: ;TODO: zrobić z tego makro, żeby zwolnić r12
        lea     rax, [SO_CPU]           ; prepare reference to `states[core]`
        mov     rdx, rax
        cmp     r12, 0x3
        ja      .arg_is_addr
        add     rax, r12                ; rax = `&so_cpu.<A|D|X|Y>`
        ret
.arg_is_addr:
        xor     rax, rax
        cmp     r12, 0x6
        jb      .after_adding_D         ; jump if the instruction doesn't need D's value
        movzx   rax, BYTE[rdx+REG_D]    ; rax = `so_cpu.D`
        sub     r12, 0x2                ; correction for proper addressing - D is not needed anymore
.after_adding_D:
        sub     r12, 0x2                ; correction for proper addressing to access X/Y
        movzx   rdx, BYTE[rdx+r12]      ; rdx = `so_cpu.<X|Y>
        add     rax, rdx
        add     rax, rsi                ; rax += `data`
        ret

%include "io64.inc"
;global so_emul
global main
main:
        mov rbp, rsp; for correct debugging ; (rdi,rsi,rdx,rcx) = (uint16_t const *code, uint8_t *data, size_t steps, size_t core)
 

        mov     rdi, 0
        shl     rdi, 1
        add     rdi, code

        mov     rsi, data
        mov     rdx, steps
        mov     rcx, core
        ;;;;;;;;;;;;;;;;;
        
        sub     rsp, 0x8                ; offset to 16 bytes
        ; save non-scratch registers
        push    rbx
        push    r12
        push    r13
        push    r14
        push    r15
        lea     rbx, [rel states]
        lea     r12, [rel jtbl_cat]
        lea     r13, [rel jtbl_2args]
        lea     r14, [rel jtbl_arg_imm8]
        lea     r15, [rel jtbl_jumps]
                ;mov  BYTE[SO_CPU+0], 0x1
                ;mov  BYTE[SO_CPU+1], 0x2
                mov  BYTE[SO_CPU+2], 0x3
                mov  BYTE[SO_CPU+3], 0x4
                ;mov  BYTE[SO_CPU+4], 0x5
                ;mov  BYTE[SO_CPU+5], 0x6
                ;mov  BYTE[SO_CPU+6], 0x7
                ;mov  BYTE[SO_CPU+7], 0x8

        xor     r8, r8                  ; prepare loop index `size_t i = 0`
        jmp      .loop_instructions_test
.loop_instructions:
        ; increment the instruction counter (so_cpu.PC)
        inc     BYTE[SO_CPU+REG_PC]
        movzx   rax, WORD[rdi+r8*2]     ; r9w = code[i]
        cmp     rax, SO_BRK             ; if opcode was BRK then stop execution
        je      .after_loop_instructions
                PRINT_STRING "======i = "
                PRINT_UDEC 8, r8
                PRINT_STRING "======="
                NEWLINE
                call    dump_so_cpu
; a switch statement that determines an instruction from the provided opcode
        push    rdx                     ; save this reg in order not to lose `steps`
        ; load arg1 into r9b
        mov     r9, rax
        shr     r9, 8
        and     r9, 0b111
        ; load arg2 into r10b
        mov     r10, rax
        shr     r10, 11
        and     r10, 0b111
         ; load imm8 into r11b
        mov     r11, rax
        and     r11, 0xFF

                PRINT_STRING "arg1 = "
                PRINT_UDEC 2, r9
                PRINT_STRING ", arg2 = "
                PRINT_UDEC 2, r10
                PRINT_STRING ", imm8 = "
                PRINT_UDEC 2, r11
                NEWLINE
        shr     rax, 14                 ; the outer switch case needs the opcode's 2 leftmost bits
        mov     rdx, [JTBL_CAT+rax*8]   ; rdx = `jtbl_cat[rax]`
        add     rdx, JTBL_CAT           ; rdx += `jtbl_cat`, now rdx holds the address of the appropriate label
        jmp     rdx                     ; jump to the appropriate category of instructions

.cat_2args:
        cmp     r10w, 0x8
        ja      .after_switch           ; opcode not recognized
        ; r9 = `get_arg(arg1)`
        push    r12 ;TODO: pozbyć się wszystkich push r12 przerabiając to na makro
        mov     r12, r9
        call    get_arg
        mov     r9, rax
        ; r10 = `get_arg(arg2)`
        mov     r12, r10
        call    get_arg
        mov     r10, rax
        pop     r12
                PRINT_STRING "$arg1 = "
                PRINT_UDEC 1, [r9]
                PRINT_STRING ", $arg2 = "
                PRINT_UDEC 1, [r10]
                NEWLINE
        mov     al, [r10]               ; rax - value of arg2
        mov     rdx, [JTBL_2ARGS+r11*8] ; rdx = `jtbl_2args[r11]`
        add     rdx, JTBL_2ARGS         ; rdx += `jtbl_2args`, now rdx holds the address of the appropriate label
        jmp     rdx                     ; jump to the appropriate instruction

.SO_MOV:
                PRINT_STRING "MOV"
                NEWLINE
        mov     [r9], al
        jmp     .after_switch
.SO_OR:
                PRINT_STRING "OR"
                NEWLINE
        or      [r9], al
        jmp     .set_ZF
.SO_ADD:
                PRINT_STRING "ADD"
                NEWLINE
        add     [r9], al
        jmp     .set_ZF
.SO_SUB:
                PRINT_STRING "SUB"
                NEWLINE
        sub     [r9], al
        jmp     .set_ZF
.SO_ADC:
                PRINT_STRING "ADC"
                NEWLINE
        mov     r11b, [SO_CPU+FLAG_C]
        add     [r9], r11b
        add     [r9], al
        jmp     .set_CF
.SO_SBB:
                PRINT_STRING "SBB"
                NEWLINE
        mov     r11b, [SO_CPU+FLAG_C]
        sub     [r9], r11b
        sub     [r9], al
        jmp     .set_CF
.SO_XCHG:
                PRINT_STRING "XCHG"
                NEWLINE
        xchg    [r9], al                ; this is already atomic, so no need to lock
        mov     [r10], al
        jmp     .after_switch
.set_CF:
        setc    BYTE[SO_CPU+FLAG_C]
.set_ZF:
        setz    BYTE[SO_CPU+FLAG_Z]
        jmp     .after_switch


.cat_arg_imm8:
        cmp     r10w, 0x6
        ja      .after_switch           ; opcode not recognized
        ; r9 = `get_arg(arg1)`
        push    r12
        mov     r12, r9
        call    get_arg
        pop     r12
        
        mov     rdx, [JTBL_ARG_IMM8+r10*8] ; rdx = `jtbl_arg_imm8[r10]` ;TODO: wyrównaj kolumny
        add     rdx, JTBL_ARG_IMM8         ; rdx += `jtbl_arg_imm8`, now rdx holds the address of the appropriate label
        jmp     rdx                     ; jump to the appropriate instruction
.SO_MOVI:
                PRINT_STRING "MOVI"
                NEWLINE
        mov     BYTE[rax], r11b
        jmp     .after_switch
.SO_ANDI:
                PRINT_STRING "ANDI"
                NEWLINE
        and     BYTE[rax], r11b
        jmp     .after_switch
.SO_ORI:
                PRINT_STRING "ORI"
                NEWLINE
        or      BYTE[rax], r11b
        jmp     .set_ZF
.SO_XORI:
                PRINT_STRING "XORI"
                NEWLINE
        xor     BYTE[rax], r11b
        jmp     .set_ZF
.SO_ADDI:
                PRINT_STRING "ADDI"
                NEWLINE
        add     BYTE[rax], r11b
        jmp     .set_ZF
.SO_CMPI:
                PRINT_STRING "CMPI"
                NEWLINE
        cmp     BYTE[rax], r11b
        jmp     .set_CF
.SO_RCR:
                PRINT_STRING "RCR"
                NEWLINE
        cmp     BYTE[rax], 0x1
        jne     .after_switch           ; rotations by more than 1 bit are to be ignored
        cmp     BYTE[SO_CPU+FLAG_C], 0x0
        cmc                             ; the actual carry is that of the above cmp with the arguments reversed
        rcr     BYTE[rax], 0x1                    
        setc    BYTE[SO_CPU+FLAG_C]     ; set if rotation caused carry
        jmp     .after_switch

.cat_fsets:
                PRINT_STRING "FLAGSET"
                NEWLINE
        cmp     r11w, 0x1
        ja      .after_switch           ; opcode not recognized
        mov     BYTE[SO_CPU+FLAG_C], r11b

.cat_jumps: ; arg1 - r9b
        cmp     r9w, 0x5
        ja      .after_switch           ; opcode not recognized        
        mov     rdx, [JTBL_JUMPS+r9*8]  ; rdx = `jtbl_jumps[r9]` ;TODO: wyrównaj kolumny
        add     rdx, JTBL_JUMPS         ; rdx += `jtbl_jumps`, now rdx holds the address of the appropriate label
        jmp     rdx                     ; jump to the appropriate instruction
.SO_JNC:
                PRINT_STRING "JNC"
                NEWLINE
        cmp     BYTE[SO_CPU+FLAG_C], 0x1
        je      .after_switch
        jmp     .SO_JMP
.SO_JC:
                PRINT_STRING "JC"
                NEWLINE
        cmp     BYTE[SO_CPU+FLAG_C], 0x0
        je      .after_switch
        jmp     .SO_JMP
.SO_JNZ:
                PRINT_STRING "JNZ"
                NEWLINE
        cmp     BYTE[SO_CPU+FLAG_Z], 0x1
        je      .after_switch
        jmp     .SO_JMP
.SO_JZ:
                PRINT_STRING "JZ"
                NEWLINE
        cmp     BYTE[SO_CPU+FLAG_Z], 0x0
        je      .after_switch
.SO_JMP: ; each jump has to alter the instruction counter
                PRINT_STRING "JMP"
                NEWLINE
        add     [SO_CPU+REG_PC], r11b

.after_switch:
        pop     rdx                     ; restore value of `steps`
        inc     r8
                call    dump_so_cpu
                NEWLINE
.loop_instructions_test:
        cmp     r8, rdx
        jl      .loop_instructions
.after_loop_instructions:
        ; make rax hold this core's cpu_state  
        mov     rax, QWORD[SO_CPU]  
        ; restore non-scratch registers
        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        ; restore the stack
        add     rsp, 0x8              
        ret

dump_so_cpu:
        push    rax
        push    rdi
        PRINT_STRING "A = "
        PRINT_UDEC 1, [SO_CPU+REG_A]

        PRINT_STRING ", D = "
        PRINT_UDEC 1, [SO_CPU+REG_D]

        PRINT_STRING ", X = "
        PRINT_UDEC 1, [SO_CPU+REG_X]

        PRINT_STRING ", Y = "
        PRINT_UDEC 1, [SO_CPU+REG_Y]
        NEWLINE



        movzx   rax, BYTE[SO_CPU+REG_X]
        add     rax, rsi
        PRINT_STRING "[X] = "
        PRINT_UDEC 1, [rax]

        movzx   rax, BYTE[SO_CPU+REG_Y]
        add     rax, rsi
        PRINT_STRING ", [Y] = "
        PRINT_UDEC 1, [rax]

        PRINT_STRING ", [X+D] = "
        movzx   rax, BYTE[SO_CPU+REG_X]
        movzx   rdi, BYTE[SO_CPU+REG_D]
        add     rax, rdi
        add     rax, rsi
        PRINT_UDEC 1, [rax]

        PRINT_STRING ", [Y+D] = "
        movzx   rax, BYTE[SO_CPU+REG_Y]
        movzx   rdi, BYTE[SO_CPU+REG_D]
        add     rax, rdi
        add     rax, rsi
        PRINT_UDEC 1, [rax]
        NEWLINE
        
        PRINT_STRING "PC = "
        PRINT_UDEC 1, [SO_CPU+REG_PC]
        PRINT_STRING ", C = "
        PRINT_UDEC 1, [SO_CPU+FLAG_C]
        PRINT_STRING ", Z = "
        PRINT_UDEC 1, [SO_CPU+FLAG_Z]
        NEWLINE
        
        pop     rdi
        pop     rax
        ret

;global main
;main:
;        mov     rbp, rsp; for correct debugging;
;
;        mov     rdi, 64
;        shl     rdi, 1
;        add     rdi, code

;        mov     rsi, data
;        mov     rdx, steps
;        mov     rcx, core

;        call    so_emul

;        xor eax, eax
;        ret

section .data
    ;code for mov
    ;code dw 16385, 16643, 16913, 17185, 1024, 3328, 17927, 260, 17928, 14080, 0
    ; code for mul
    code  dw 16897, 17152, 10240, 17664, 16648, 29697, 49666, 32768, 1286, 29953, 29952, 25087, 50425, 49152

    data  db  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
    steps equ 14 ;;11/14
    core  equ 0