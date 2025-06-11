BITS 16
ORG 0x1000

TRAMPOLINE_ADDR  equ 0x2000
CODE_SEG         equ 0x08
DATA_SEG         equ 0x10
MAIN_ENTRY       equ 0x10000

section .data
stage2_state:
    dd 0         ; esp
    dw 0         ; ss

section .text
global stage2_start

stage2_start:
    ; Inicializar segmentos
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; Habilitar A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Ativar modo gráfico VESA 640x480x8bpp (modo 0x101)
    mov ax, 0x4F02
    mov bx, 0x101
    int 0x10
    ; opcional: verificar se modo foi ativado
    ; cmp ax, 0x004F
    ; jne .mode_fail

    ; Copiar trampoline para endereço fixo
    mov si, trampoline_start
    mov di, TRAMPOLINE_ADDR
    mov cx, trampoline_end - trampoline_start
    rep movsb

    ; Carregar GDT
    cli
    lgdt [gdt_descriptor]

    ; Salvar esp e ss antes de entrar em modo protegido
    mov [stage2_state], esp
    mov [stage2_state+4], ss

    ; Entrar no trampoline (modo protegido)
    jmp TRAMPOLINE_ADDR

; trampoline que ativa modo protegido e pula para kernel
align 16
trampoline_start:
    cli
    ; salto para rotina 32-bit que ativa modo protegido
    jmp dword trampoline_pm

[BITS 32]
trampoline_pm:
    ; Ativar modo protegido (bit PE no CR0)
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; Salto para modo protegido (code segment)
    jmp dword CODE_SEG:protected_mode

protected_mode:
    ; Configurar segmentos dados
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Restaurar stack salvo
    mov esp, [stage2_state]

    ; Limpar tela gráfica VESA (memória 0xA0000)
    mov edi, 0xA0000
    mov ecx, 640*480
    mov al, 0x00
    rep stosb

    ; Pular para kernel (em modo 32 bits)
    jmp MAIN_ENTRY

trampoline_end:

align 8
gdt_start:
    dq 0
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x9A
    db 0xCF
    db 0x00

    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92
    db 0xCF
    db 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510-($-$$) db 0
dw 0xAA55
