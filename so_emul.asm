global so_emul

; cpu_state_t fields
reg_A    equ 0x0
reg_D    equ 0x1
reg_X    equ 0x2
reg_Y    equ 0x3
reg_PC   equ 0x4
flag_C   equ 0x6
flag_Z   equ 0x7

; addresses specified in instruction arguments
addr_X   equ 0x4
addr_Y   equ 0x5
addr_XD  equ 0x6
addr_YD  equ 0x7

; emulator instructions
SO_BRK   equ 0xFFFF

SO_MOV   equ 0x0
SO_AND   equ 0x1
SO_OR    equ 0x2
SO_XOR   equ 0x3
SO_ADD   equ 0x4
SO_SUB   equ 0x5
SO_ADC   equ 0x6
SO_SBB   equ 0x7
SO_XCHG  equ 0x8

SO_MOVI  equ 0x1
SO_ANDI  equ 0x2
SO_ORI   equ 0x3
SO_XORI  equ 0x4
SO_ADDI  equ 0x5
SO_CMPI  equ 0x6
SO_RCRI  equ 0x7

SO_CLC   equ 0x0
SO_STC   equ 0x1

SO_JMP   equ 0x0
SO_DJNZ  equ 0x1
SO_JNC   equ 0x2
SO_JC    equ 0x3
SO_JNZ   equ 0x4
SO_JZ    equ 0x5

section .rodata
align 8
; jump-table of instruction categories
jtbl_cat dq                   \
        so_emul.cat_2args    ,\
        so_emul.cat_arg_imm8 ,\
        so_emul.cat_fsets    ,\
        so_emul.cat_jumps    ,\
; jump-table of instructions that take two arguments
jtbl_2args dq                 \
        so_emul.SO_MOV       ,\
        so_emul.SO_AND       ,\
        so_emul.SO_OR        ,\
        so_emul.SO_XOR       ,\
        so_emul.SO_ADD       ,\
        so_emul.SO_SUB       ,\
        so_emul.SO_ADC       ,\
        so_emul.SO_SBB       ,\
        so_emul.SO_XCHG
; jump-table of instructions that take an argument and an immediate 8-bit value
jtbl_arg_imm8 dq              \
        so_emul.SO_MOVI      ,\
        so_emul.SO_ANDI      ,\
        so_emul.SO_ORI       ,\
        so_emul.SO_XORI      ,\
        so_emul.SO_ADDI      ,\
        so_emul.SO_CMPI      ,\
        so_emul.SO_RCRI
; jump-table of instructions that alter flags
jtbl_fsets dq                 \
        so_emul.SO_CLC       ,\
        so_emul.SO_STC
; jump-table of instructions that perform jumps
jtbl_jumps dq                 \
        so_emul.SO_JMP       ,\
        so_emul.SO_DJNZ      ,\
        so_emul.SO_JNC       ,\
        so_emul.SO_JC        ,\
        so_emul.SO_JNZ       ,\
        so_emul.SO_JZ

section .text
global main
main:
        mov rbp, rsp; for correct debugging

        mov     rdi, code
        mov     rsi, data
        mov     rdx, steps
        mov     rcx, core

        call    so_emul

        xor eax, eax
        ret


; gets a reference to a SO-register or SO-address based on r12, returns with rax
get_arg:
        cmp     r12, 0x3
        ja      .arg_is_addr
        mov     rax, rbp
        sub     rax, r12             ; rax = `&cpu_state.<A|D|X|Y>`
        ret
.arg_is_addr:
        xor     rax, rax
        cmp     r12, 0x5
        jb      .after_adding_D      ; jump if the instuction doesn't need D's value
        movzx   rax, BYTE[rbp-reg_D] ; rax = `cpu_state.D`
        sub     r12, 0x4             ; correct the switch expression
.after_adding_D:
        add     rax, rbp
        sub     rax, r12
        add     rax, rsi
        mov     rax, [rax]           ; rax = `&data[<X|Y|X+D|Y+D>]
        ret

so_emul: ; (rdi,rsi,rdx,rcx) = (uint16_t const *code, uint8_t *data, size_t steps, size_t core)
        push    rbp
        mov     rbp, rsp
        sub     rsp, 0x10               ; 8 bytes for an instance of `cpu_state_t`

        mov     QWORD[rbp-0x8], 0x0     ; zero-out cpu_state

        xor     r8, r8                  ; prepare loop index `size_t `i = 0
        jmp     .loop_instructions_test
.loop_instructions:
        ; increment the instruction counter (cpu_state.PC)
        mov     r10b, BYTE[rbp-reg_PC]
        inc     r10b
        mov     BYTE[rbp-reg_PC], r10b
        movzx   rax, WORD[rdi+r8*4]     ; r9w = code[i]        ;TODO: czemu jak tu jest +2 to nie działa?
        cmp     rax, SO_BRK             ; if opcode was BRK then stop execution
        je      .after_loop_instructions


; a switch statement that determines an instruction from the opcode
; r9w - arg1, r10w - arg2, r11w - imm8
        push    r12                     ; save non-scratch register
        ; load arg1 into r9b
        movzx   r9, WORD[rdi+r8*4]
        shl     r9, 8
        and     r9, 0b111
        ; load arg2 into r10b
        movzx   r10, WORD[rdi+r8*4]
        shl     r10, 11
        and     r10, 0b111
         ; load imm8 into r11b
        movzx   r11, WORD[rdi+r8*4]
        and     r11, 0xFF

        shr     rax, 14
        jmp     [jtbl_cat+rax*8]        ; jump to the appropriate category of instructions

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
        jmp     [jtbl_2args+r10*8]      ; jump to the appropriate instruction
.SO_MOV:;TODO
        mov     rax, [r10]
        mov     [r9], rax
        jmp     .after_switch
.SO_AND:
        mov     rax, [r10]
        and     [r9], rax
        jnz     .after_switch
        mov     BYTE[rbp-flag_C], 0x1
        jmp     .after_switch
.SO_OR:
        jmp     .after_switch
.SO_XOR:
        jmp     .after_switch
.SO_ADD:
        jmp     .after_switch
.SO_SUB:
        jmp     .after_switch
.SO_ADC:
        jmp     .after_switch
.SO_SBB:
        jmp     .after_switch
.SO_XCHG:
        jmp     .after_switch

.cat_arg_imm8:
        cmp     r10w, 0x6
        ja      .after_switch           ; opcode not recognized
        ; r9 = `get_arg(arg1)`
        mov     r12, r9 
        call    get_arg
        mov     r9, rax       
        jmp     [jtbl_arg_imm8+r10*8]   ; jump to the appropriate instruction
.SO_MOVI:
        jmp     .after_switch
.SO_ANDI:
        jmp     .after_switch
.SO_ORI:
        jmp     .after_switch
.SO_XORI:
        jmp     .after_switch
.SO_ADDI:
        jmp     .after_switch
.SO_CMPI:
        jmp     .after_switch
.SO_RCRI:
        jmp     .after_switch

.cat_fsets:
        cmp     r11w, 0x1
        ja      .after_switch           ; opcode not recognized
        jmp     [jtbl_fsets+r11*8]      ; jump to the appropriate instruction
.SO_CLC:
        jmp     .after_switch
.SO_STC:
        jmp     .after_switch


.cat_jumps: ; arg1 - r9b
        cmp     r9w, 0x5
        ja      .after_switch           ; opcode not recognized
        jmp     [jtbl_jumps+r9*8]       ; jump to the appropriate instruction
.SO_DJNZ:
        jmp     .SO_JMP
.SO_JNC:
        jmp     .SO_JMP
.SO_JC:
        jmp     .SO_JMP
.SO_JNZ:
        jmp     .SO_JMP
.SO_JZ:
.SO_JMP: ; each jump has to alter the instruction counter
        ;...


.after_switch:
        pop    r12                     ; restore non-scratch register
        inc     r8
.loop_instructions_test:
        cmp     r8, rdx
        jl      .loop_instructions
.after_loop_instructions:
        mov     rax, QWORD[rbp-0x8]     ; move the cpu_state to rax to return it
        leave                           ; restore the stack
        ret


section .data
        code  dd  0, 1, 2, 3, 4, 5, 6, 7, 8, 9
        data  db  48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64
        steps equ 10
        core  equ 0
