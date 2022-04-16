%include "io64.inc"
global so_emul

; compilation-time constant for max number of cores used at once
%ifndef DCORES
%define DCORES 4
%endif

%define SO_CPU rel states+rcx*8

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
align 8
; jump-table of instruction categories
    jtbl_cat dq               \
        so_emul.cat_2args    ,\
        so_emul.cat_arg_imm8 ,\
        so_emul.cat_fsets    ,\
        so_emul.cat_jumps    ,\
; jump-table of instructions that take two arguments
    jtbl_2args dq             \
        so_emul.SO_MOV       ,\
        so_emul.after_switch ,\
        so_emul.SO_OR        ,\
        so_emul.after_switch ,\
        so_emul.SO_ADD       ,\
        so_emul.SO_SUB       ,\
        so_emul.SO_ADC       ,\
        so_emul.SO_SBB       ,\
        so_emul.SO_XCHG
; jump-table of instructions that take an argument and an immediate 8-bit value
    jtbl_arg_imm8 dq          \
        so_emul.SO_MOVI      ,\
        so_emul.after_switch ,\
        so_emul.after_switch ,\
        so_emul.SO_XORI      ,\
        so_emul.SO_ADDI      ,\
        so_emul.SO_CMPI      ,\
        so_emul.SO_RCR
; jump-table of instructions that perform jumps
    jtbl_jumps dq             \
        so_emul.SO_JMP       ,\
        so_emul.after_switch ,\
        so_emul.SO_JNC       ,\
        so_emul.SO_JC        ,\
        so_emul.SO_JNZ       ,\
        so_emul.SO_JZ

section .data
    code  dw  \
        0b0000000000000000,\
        0b0000100000000000,\
        0b0001000000000000,\
        0b0001100000000000,\
        0b0010000000000000,\
        0b0010100000000000,\
        0b0011000000000000,\
        0b0011100000000000,\
        0b0000000100000000,\
        0b0000100100000000,\
        0b0001000100000000,\
        0b0001100100000000,\
        0b0010000100000000,\
        0b0010100100000000,\
        0b0011000100000000,\
        0b0011100100000000,\
        0b0000001000000000,\
        0b0000101000000000,\
        0b0001001000000000,\
        0b0001101000000000,\
        0b0010001000000000,\
        0b0010101000000000,\
        0b0011001000000000,\
        0b0011101000000000,\
        0b0000001100000000,\
        0b0000101100000000,\
        0b0001001100000000,\
        0b0001101100000000,\
        0b0010001100000000,\
        0b0010101100000000,\
        0b0011001100000000,\
        0b0011101100000000,\
        0b0000010000000000,\
        0b0000110000000000,\
        0b0001010000000000,\
        0b0001110000000000,\
        0b0010010000000000,\
        0b0010110000000000,\
        0b0011010000000000,\
        0b0011110000000000,\
        0b0000010100000000,\
        0b0000110100000000,\
        0b0001010100000000,\
        0b0001110100000000,\
        0b0010010100000000,\
        0b0010110100000000,\
        0b0011010100000000,\
        0b0011110100000000,\
        0b0000011000000000,\
        0b0000111000000000,\
        0b0001011000000000,\
        0b0001111000000000,\
        0b0010011000000000,\
        0b0010111000000000,\
        0b0011011000000000,\
        0b0011111000000000,\
        0b0000011100000000,\
        0b0000111100000000,\
        0b0001011100000000,\
        0b0001111100000000,\
        0b0010011100000000,\
        0b0010111100000000,\
        0b0011011100000000,\
        0b0011111100000000
    data  db  1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
    ;data db 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110
    steps equ 8 ;TODO: crash na i=4
    core  equ 0
    ; spin-lock granting atomicity of SO_XCHG, initialized to 0 (unlocked)
    spin_lock dd 0 

section .bss
    states: resb 8 * DCORES       

section .text
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
        pop     rdi
        pop     rax
        ret
        
global main
main:
        mov     rbp, rsp; for correct debugging
           
        mov     rdi, 0
        shl     rdi, 1
        add     rdi, code
 
        mov     rsi, data
        mov     rdx, steps
        mov     rcx, core
        
        mov  BYTE[SO_CPU+0], 0x1
        mov  BYTE[SO_CPU+1], 0x2  
        mov  BYTE[SO_CPU+2], 0x3
        mov  BYTE[SO_CPU+3], 0x4  
        mov  BYTE[SO_CPU+4], 0x5
        mov  BYTE[SO_CPU+5], 0x6
        mov  BYTE[SO_CPU+6], 0x7
        mov  BYTE[SO_CPU+7], 0x8    
        ;mov     rax, states
        ;mov     BYTE[states], 1

        call    so_emul

        xor eax, eax
        ret

; gets a reference to a SO-register or SO-address based on r12, returns with rax
get_arg: 
        push    rdx                     ; need this as a scratch register
        mov     rax, rcx
        shl     rax, 3       
        mov     rdx, rax     
        add     rax, states             ; prepare reference to `states[core]`
        cmp     r12, 0x3
        ja      .arg_is_addr        
        add     rax, r12                ; rax = `&so_cpu.<A|D|X|Y>`
        pop     rdx
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
        add     rax, rsi                ; rax += `data`            ; 
        pop     rdx
        ret

so_emul: ; (rdi,rsi,rdx,rcx) = (uint16_t const *code, uint8_t *data, size_t steps, size_t core)
        sub     rsp, 0x8                ; offset to 16 bytes
        xor     r8, r8                  ; prepare loop index `size_t `i = 0
        jmp      .loop_instructions_test
.loop_instructions:
        ; increment the instruction counter (so_cpu.PC)
        mov     r10b, BYTE[SO_CPU+REG_PC]
        inc     r10b
        mov     BYTE[SO_CPU+REG_PC], r10b
        movzx   rax, WORD[rdi+r8*2]     ; r9w = code[i]
        cmp     rax, SO_BRK             ; if opcode was BRK then stop execution
        je      .after_loop_instructions

        PRINT_STRING "======i = "
        PRINT_UDEC 8, r8
        PRINT_STRING "======="
        NEWLINE
        call    dump_so_cpu
        
; a switch statement that determines an instruction from the provided opcode
        push    r12                     ; save non-scratch register
        push    rdx                     ; save this reg in order not to lose `steps`
        ; load arg1 into r9b
        movzx   r9, WORD[rdi+r8*2]
        shr     r9, 8
        and     r9, 0b111
        ; load arg2 into r10b
        movzx   r10, WORD[rdi+r8*2]
        shr     r10, 11
        and     r10, 0b111
         ; load imm8 into r11b
        movzx   r11, WORD[rdi+r8*2]
        and     r11, 0xFF
        PRINT_STRING "arg1 = "
        PRINT_UDEC 2, r9
        PRINT_STRING ", arg2 = "
        PRINT_UDEC 2, r10
        PRINT_STRING ", imm8 = "
        PRINT_UDEC 2, r11
        NEWLINE

        shr     rax, 14
        jmp     [rel jtbl_cat+rax*8]        ; jump to the appropriate category of instructions

.cat_2args:
        cmp     r10w, 0x8
        ja      .after_switch           ; opcode not recognized
        ; r9 = `get_arg(arg1)`
        mov     r12, r9 
        call    get_arg
        mov     r9, rax    
        ; r10 = `get_arg(arg2)`
        mov     r12, r10
        call    get_arg
        mov     r10, rax
        PRINT_STRING "$arg1 = "
        PRINT_UDEC 1, [r9]    
        PRINT_STRING ", $arg2 = "
        PRINT_UDEC 1, [r10]   
        NEWLINE     
        mov     al, [r10]      
        jmp     [rel jtbl_2args+r11*8]      ; jump to the appropriate instruction
.SO_MOV: ;TODO: te rzeczy w ogóle da się skrócić korzystając z makr i "fptrów" xD
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
        
        .acquire_spinlock_loop: ;TODO: zrobić z tego makro
        mov     r12d, 0x1
        xchg    DWORD[rel spin_lock], r12d  ; try to acquire the spin_lock
        test    r12d, r12d                   ; check success
        jnz     .acquire_spinlock_loop     ; loop again if lock not acquired
        
        mov     al, [r10]
        xchg    [r9], al
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
        mov     r12, r9 
        call    get_arg
        jmp     [rel jtbl_arg_imm8+r10*8]   ; jump to the appropriate instruction
.SO_MOVI:
        PRINT_STRING "MOVI"
        NEWLINE
        mov     [rax], r11
        jmp     .after_switch
.SO_ANDI:
        PRINT_STRING "ANDI"
        NEWLINE
        and     [rax], r11
        jmp     .after_switch
.SO_ORI:
        PRINT_STRING "ORI"
        NEWLINE
        or      [rax], r11
        jmp     .set_ZF
.SO_XORI:
        PRINT_STRING "XORI"
        NEWLINE
        xor     [rax], r11
        jmp     .set_ZF
.SO_ADDI:
        PRINT_STRING "ADDI"
        NEWLINE
        add     [rax], r11
        jmp     .set_ZF
.SO_CMPI:
        PRINT_STRING "CMPI"
        NEWLINE
        cmp     [rax], r11
        jmp     .set_CF
.SO_RCR:
        PRINT_STRING "RCR"
        NEWLINE
        ;todo!!!
        jmp     .after_switch

.cat_fsets:
        cmp     r11w, 0x1
        ja      .after_switch           ; opcode not recognized
        PRINT_STRING "FLAG-SET"
        NEWLINE
        mov     BYTE[SO_CPU+FLAG_C], r11b


.cat_jumps: ; arg1 - r9b
        cmp     r9w, 0x5
        ja      .after_switch           ; opcode not recognized
        jmp     [rel jtbl_jumps+r9*8]   ; jump to the appropriate instruction
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
        PRINT_STRING "some JUMP"
        NEWLINE
        .not_jmp:
        add     [SO_CPU+REG_PC], r11b

.after_switch:
        pop     rdx
        pop     r12                     ; restore non-scratch register
        call    dump_so_cpu
        NEWLINE
        inc     r8
.loop_instructions_test:
        cmp     r8, rdx
        jl      .loop_instructions
.after_loop_instructions:
        mov     rax, [SO_CPU]           ; move the so_cpu to rax to return it
        add     rsp, 0x8                ; restore the stack
        ret
