global so_emul

; compilation-time constant for max number of cores used at once
%ifndef CORES
%define CORES 4
%endif

%define SO_CPU          rbx+rcx*8
%define JTBL_CAT        r12
%define JTBL_2ARGS      r13
%define JTBL_ARG_IMM8   r14

; so_cpu_t fields
;REG_A    equ 0x0
REG_D    equ 0x1
;REG_X    equ 0x2
;REG_Y    equ 0x3
REG_PC   equ 0x4
;UNUSED_BYTE equ 0x5
FLAG_C   equ 0x6
FLAG_Z   equ 0x7

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

section .rodata
; jump-table of instruction categories
    jtbl_cat:
        dw so_emul.cat_2args    - jtbl_cat
        dw so_emul.cat_arg_imm8 - jtbl_cat
        dw so_emul.cat_flagset  - jtbl_cat
        dw so_emul.cat_jumps    - jtbl_cat
; jump-table of instructions that take two arguments
    jtbl_2args:
        dw so_emul.SO_MOV       - jtbl_2args
        dw so_emul.after_switch - jtbl_2args
        dw so_emul.SO_OR        - jtbl_2args
        dw so_emul.after_switch - jtbl_2args
        dw so_emul.SO_ADD       - jtbl_2args
        dw so_emul.SO_SUB       - jtbl_2args
        dw so_emul.SO_ADC       - jtbl_2args
        dw so_emul.SO_SBB       - jtbl_2args
        dw so_emul.SO_XCHG      - jtbl_2args
; jump-table of instructions that take an argument and an immediate 8-bit value
    jtbl_arg_imm8:
        dw so_emul.SO_MOVI       - jtbl_arg_imm8
        dw so_emul.after_switch  - jtbl_arg_imm8
        dw so_emul.after_switch  - jtbl_arg_imm8
        dw so_emul.SO_XORI       - jtbl_arg_imm8
        dw so_emul.SO_ADDI       - jtbl_arg_imm8
        dw so_emul.SO_CMPI       - jtbl_arg_imm8
        dw so_emul.SO_RCR        - jtbl_arg_imm8

section .bss
; array of cpu states for each core. The current core's state is at `states[core]`
    states: resb 8 * CORES

section .text
; gets a reference to a SO-register or SO-address based on r12, returns with rax
get_arg:
        lea     rax, [SO_CPU]                   ; prepare reference to `states[core]`
        mov     r15, rax
        cmp     r12, 0x3
        ja      .arg_is_addr
        add     rax, r12                        ; rax = `&so_cpu.<A|D|X|Y>`
        ret
.arg_is_addr:
        xor     rax, rax
        cmp     r12, 0x6
        jb      .after_adding_D                 ; jump if the instruction doesn't need D's value
        movzx   rax, BYTE[r15+REG_D]            ; rax = `so_cpu.D`
        sub     r12, 0x2                        ; correction for proper addressing - D is not needed anymore
.after_adding_D:
        sub     r12, 0x2                        ; correction for proper addressing to access X/Y
        movzx   r15, BYTE[r15+r12]              ; r15 = `so_cpu.<X|Y>
        add     al, r15b
        add     rax, rsi                        ; rax += `data`
        ret

so_emul: ; (rdi,rsi,rdx,rcx) = (uint16_t const *code, uint8_t *data, size_t steps, size_t core)
        ; save non-scratch registers
        push    rbx
        push    r12
        push    r13
        push    r14
        push    r15                             ; used as a scratch register
        lea     rbx, [rel states]
        lea     r12, [rel jtbl_cat]
        lea     r13, [rel jtbl_2args]
        lea     r14, [rel jtbl_arg_imm8]
        ; prepare loop index `size_t i = 0`
        xor     r8, r8
        jmp      .loop_instructions_test
.loop_instructions:
        movzx   rax, BYTE[SO_CPU+REG_PC]
        movzx   rax, WORD[rdi+rax*2]            ; rax = `code[i]`
        inc     BYTE[SO_CPU+REG_PC]             ; `so_cpu.PC++`
        inc     r8                              ; `i++`
        cmp     rax, SO_BRK
        je      .after_loop_instructions        ; if opcode was BRK then stop execution
.switch: ; a switch statement that determines an instruction from the provided opcode
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
        shr     rax, 14                         ; the outer switch case needs the opcode's 2 leftmost bits
        ; prepare the address of the appropriate category of instructions to jump to
        movsx   rax, WORD[JTBL_CAT+rax*2]       ; rax = `jtbl_cat[rax]`
        add     rax, JTBL_CAT                   ; rax += `jtbl_cat`, now rax holds the address of the appropriate label
        push    r12                             ; need r12 as as a scratch register, save it
        jmp     rax

.cat_2args:
        cmp     r10w, 0x8
        ja      .after_switch                   ; opcode not recognized
        ; r9 = `get_arg(arg1)`
        mov     r12, r9
        call    get_arg
        mov     r9, rax
        ; r10 = `get_arg(arg2)`
        mov     r12, r10
        call    get_arg
        mov     r10, rax
        ; prepare the address of the appropriate instruction to jump to
        mov     al, [r10]                       ; rax - value of arg2
        movsx   r11, WORD[JTBL_2ARGS+r11*2]     ; r11 = `jtbl_2args[r11]`
        add     r11, JTBL_2ARGS                 ; r11 += `jtbl_2args`, now r11 holds the address of the appropriate label
        jmp     r11
.SO_MOV:
        mov     BYTE[r9], al
        jmp     .after_switch
.SO_OR:
        or      BYTE[r9], al
        jmp     .set_ZF
.SO_ADD:
        add     BYTE[r9], al
        jmp     .set_ZF
.SO_SUB:
        sub     BYTE[r9], al
        jmp     .set_ZF
.SO_ADC:
        rcr     BYTE[SO_CPU+FLAG_C], 0x1        ; sets carry to `so_cpu.C`, overrides the ms-bit of FLAG_C but that will be corrected after the jump
        adc     BYTE[r9], al
        jmp     .set_CF
.SO_SBB:
        rcr     BYTE[SO_CPU+FLAG_C], 0x1        ; sets carry to `so_cpu.C`, overrides the ms-bit of FLAG_C but that will be corrected after the jump
        sbb     BYTE[r9], al
        jmp     .set_CF
.SO_XCHG:
        xchg    [r9], al                        ; this is already atomic, so no need to lock
        mov     [r10], al
        jmp     .after_switch
.set_CF:
        setc    BYTE[SO_CPU+FLAG_C]
.set_ZF:
        setz    BYTE[SO_CPU+FLAG_Z]
        jmp     .after_switch

.cat_arg_imm8:
        cmp     r10w, 0x6
        ja      .after_switch                   ; opcode not recognized
        ; rax = `get_arg(arg1)`
        mov     r12, r9
        call    get_arg
         ; prepare the address of the appropriate instruction to jump to
        movsx   r10, WORD[JTBL_ARG_IMM8+r10*2]  ; r10 = `jtbl_arg_imm8[r10]`
        add     r10, JTBL_ARG_IMM8              ; r10 += `jtbl_arg_imm8`, now r10 holds the address of the appropriate label
        jmp     r10
.SO_MOVI:
        mov     BYTE[rax], r11b
        jmp     .after_switch
.SO_ANDI:
        and     BYTE[rax], r11b
        jmp     .after_switch
.SO_ORI:
        or      BYTE[rax], r11b
        jmp     .set_ZF
.SO_XORI:
        xor     BYTE[rax], r11b
        jmp     .set_ZF
.SO_ADDI:
        add     BYTE[rax], r11b
        jmp     .set_ZF
.SO_CMPI:
        cmp     BYTE[rax], r11b
        jmp     .set_CF
.SO_RCR:
        cmp     r11b, 0x1
        jne     .after_switch                   ; rotations by more than 1 bit are to be ignored
        rcr     BYTE[SO_CPU+FLAG_C], 0x1        ; sets carry to `so_cpu.C`, overrides the ms-bit of FLAG_C but that will be corrected two lines below
        rcr     BYTE[rax], 0x1
        setc    BYTE[SO_CPU+FLAG_C]             ; set if rotation caused carry
        jmp     .after_switch

.cat_flagset:
        cmp     r9b, 0x1
        ja      .after_switch                   ; opcode not recognized
        mov     BYTE[SO_CPU+FLAG_C], r9b

.cat_jumps:
        cmp     r9b, 0x5
        ja      .after_switch                   ; opcode not recognized
        test    r9b, r9b
        jz      .SO_JMP                         ; proceed directly to the jump if the instruction was SO_JMP
        setp    al                              ; al  = (JNC || JNZ)? 0 : 1
        shr     r9b, 0x2                        ; r9b = (JC || JNC)? 0 : 1
        add     r9b, 0x6                        ; r9b = (r9b == 1)? REG_C : REG_Z
        lea     r10, [SO_CPU]
        add     r10, r9                         ; r10 = &so_cpu[r9b]
        cmp     BYTE[r10], al                   ; check if the jump's condition is satisfied
        jne     .after_switch
.SO_JMP: ; each jump has to alter the instruction counter
        add     [SO_CPU+REG_PC], r11b

.after_switch:
        pop     r12                             ; restore value of `JTBL_CAT`
.loop_instructions_test:
        cmp     r8, rdx
        jb      .loop_instructions
.after_loop_instructions:
        ; make rax hold this core's cpu state
        mov     rax, QWORD[SO_CPU]
        ; restore non-scratch registers
        pop     r15
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        ; return
        ret
