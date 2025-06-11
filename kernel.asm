[BITS 32]
[ORG 0x10000]

NOTEPAD_LOAD_ADDR equ 0x200000

section .bss
    screen_offset resd 1

section .data
    notepad_size dd 0x00012000   ; valor fixo para teste (ex: 72 KiB)

    msg_loaded db 'NOTEPAD.EXE loaded.', 0
    msg_size   db 'Size: ', 0
    msg_addr   db 'Addr: ', 0

section .text
global MAIN_ENTRY

MAIN_ENTRY:
    mov dword [screen_offset], 0
    call clear_screen

    ; Exibe debug visual
    mov si, msg_loaded
    call print_string

    mov si, msg_size
    call print_string
    mov eax, [notepad_size]
    call print_hex32

    mov si, msg_addr
    call print_string
    mov eax, NOTEPAD_LOAD_ADDR
    call print_hex32

    jmp hang

hang:
    jmp hang

; ---------------------------------------------------
; FUNÇÕES GRÁFICAS (DEBUG EM VESA 640x480x8bpp)
; ---------------------------------------------------

clear_screen:
    mov edi, 0xA0000
    mov ecx, 640*480
    mov al, 0
    rep stosb
    ret

print_string:
    mov edi, 0xA0000
    mov eax, [screen_offset]
    add edi, eax
.print_char:
    lodsb
    test al, al
    jz .done
    mov [edi], al
    inc edi
    jmp .print_char
.done:
    add dword [screen_offset], 20*8  ; pula linha (20 caracteres largura)
    ret

print_hex32:
    mov ecx, 8
    mov edi, 0xA0000
    mov eax, [screen_offset]
    add edi, eax
    mov ebx, eax
    mov eax, [notepad_size]
.print_nibble:
    rol eax, 4
    mov dl, al
    and dl, 0xF
    cmp dl, 9
    jbe .digit
    add dl, 'A' - 10
    jmp .store
.digit:
    add dl, '0'
.store:
    mov [edi], dl
    inc edi
    loop .print_nibble
    add dword [screen_offset], 10
    ret
