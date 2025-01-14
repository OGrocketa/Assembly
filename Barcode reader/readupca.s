
section .text
global readupca

; The only restricion is that the width of the barcode is 95px the height or dimensions
; of the bmp dont matter
readupca:
    ; Prologue
    push ebp
    mov ebp, esp
    sub esp, 16              ; Save 16 bytes for local vars
    push ebx
    push esi
    push edi

    ; Arguments from stack
    mov esi, [ebp + 8]      ; img (pointer to pixel data)

    mov ecx, [ebp + 12]     ; width (in pixels)
    mov edx, [ebp + 16]     ; height (in pixels)

calculate_stride:
    ; Calculate row stride (aligned to 4 bytes)
    mov eax, ecx            ; eax = width (in pixels)
    add eax, 7              ; Round up to nearest byte boundary (8 bits per byte)
    shr eax, 3              ; Convert from bits to bytes (width in bytes)
    add eax, 3              ; Round up to nearest 4-byte boundary
    and eax, 0xFFFFFFFC     ; Align to 4 bytes
    mov [ebp - 4], eax      ; Store the stride on the stack ebp-4


calculate_last_byte_bits:
    ; Calculate row padding
    mov eax, ecx            ; eax = width (in bits)
    and eax, 7              ; eax = width_in_bits % 8
    cmp eax, 0              ; check if remainder is zero
    jne non_zero
    mov eax, 8              ; if remainder is zero, last byte is fully used
    
non_zero:
    mov [ebp - 8], eax      ; Store the the amount of bits used in last byte on the stack ebp-8

calculate_used_bytes:
    mov eax, ecx            ; eax = width (in bits)
    add eax, 7              ; Add 7 to round up for any partial byte
    shr eax, 3              ; Divide by 8 (convert bits to bytes)
    add eax, -1
    mov [ebp - 12], eax     ; save amount of used bytes on the stack ebp-12
              

; At this point we have:
; ebx,edi = available for use
; ecx = row counter (using height)
; eax = byte counter
; esi = pointer to current byte row
; ebx = pointer to current byte
; ebp-4 = stride
; ebp-8 = amount of used bits in last byte
; ebp-12 = amount of used bytes
; edi,ebx available
;And we look for the first black bit
    
mov ecx, [ebp + 16]         ; ecx = row counter (using height)

traverse_rows:              
    cmp ecx, 0              ; Check if we traverse all rows
    je  not_found           ; if we did finish the program
    xor eax, eax            ; Reset byte counter
    mov ebx,esi             ; set current byte to start of the row 

traverse_bytes:
    cmp eax, [ebp - 12]     ; Compare Byte counter with amount of used bytes
    je check_bits           ; If equal traverse bits of the last byte
    jg next_row             ; If bigger move to next row next bytes are "fillings"

    cmp byte [ebx], 0xff    ; Compare if a byte is fully white since we expect FF for all non last bytes
    je next_byte            ; If equal keep traversing
    jmp first_black_found   ; First black byte found

next_row:
    add ecx,-1              ; Move counter one level up
    add esi, [ebp - 4]      ; Move esi to next row
    jmp traverse_rows       ; Continue traversing

next_byte:
    add ebx, 1              ; Move esi to next byte
    add eax, 1              ; Increment byte counter
    jmp traverse_bytes


check_bits:
    mov edi, ecx            ; save row counter
    ; Generate mask
    mov edx, 0xFFFFFFFF     ; Start with all 1's: 11111111
    mov eax, 8              ; Total bits in a byte
    sub eax, [ebp - 8]      ; Calculate unused bits: (8 - used_bits)
    mov cl, al              ; Move shift count to cl
    shl edx, cl             ; Shift mask left by (8 - used_bits)
    
    ; Apply mask to the last byte
    mov bl, byte [ebx]      ; Load the last byte
    and bl, dl              ; Apply the mask
    mov ecx, edi            ; store row counter back to ecx
    ; Compare masked byte with the mask
    cmp bl, dl              ; Are all used bits 1's?
    jne first_black_found   ; If not, jump to handle the failure case
    jmp next_row            ; If everything is white move to next byte


; At this point we have:
; edi = available for use
; ecx = row counter (using height)
; eax = byte counter
; esi = pointer to current byte row
; ebx = pointer to current byte
; ebp-4 = stride
; ebp-8 = amount of used bits in last byte
; ebp-12 = amount of used bytes

first_black_found:
    mov edi, ebx                ; copy first back byte to edi

; Here we just move up comparing first bit until its white then just move one down
barcode_to_read:
    add edi, [ebp - 4]          ; add stride to move 1 px up
    sub ecx, 1
    mov eax, [edi]              ; load value of edi
    cmp eax, [ebx]              ; compare values of first black and current
    je  barcode_to_read         ; continue looking for the white px

    ; When we get here it means the current edi byte is either black from lower part
    ; of the barcode or white from the top

    cmp byte [edi], 0xFF        ; Compare if white
    je move__one_lower          ; if yes move 1 level lower if not start reading   

    jmp find_guard         

; Might be an issue if the last bit is black
; so 00000001 but the move lower should be fixiing it
move__one_lower:
    sub edi, [ebp - 4]          ; move one px lower
    add ecx, 1                  ; keep the height aligned (just for debuging)               
    jmp find_guard                 

not_found:
    mov eax, 228                ; No black pixel found


; At this point we have:
; ebx = 
; edi = points to the first byte with black px
; ecx = cl = bit counter for shifting bits
; eax = al = bit extraction
; esi = 
; edx = dl = buffer to extract numbers
; ebp-4 = stride
; ebp-8 = amount of used bits in last byte
; ebp-12 = amount of used bytes

find_guard: 
    
    mov al, byte[edi]            ; now we have current byte in al

; here we check for black byte
    xor ecx, ecx                 ; ecx is the counter for which bit is black, cl positon of black bit
    test al, 0b10000000                    
    jz guard_found

    add cl, 1
    test al, 0b01000000  
    jz guard_found

    add cl, 1
    test al, 0b00100000  
    jz guard_found

    add cl, 1
    test al, 0b00010000  
    jz guard_found

    add cl, 1
    test al, 0b00001000  
    jz guard_found

    add cl, 1
    test al, 0b00000100  
    jz guard_found

    add cl, 1
    test al, 0b00000010  
    jz guard_found

    add cl, 1
    test al, 0b00000001  
    jz guard_found

guard_found:
    mov dl, byte[edi]       ; save current byte which we read into dl
    cmp cl, 5               ; if black bit is 5th
    je cl_5
    cmp cl, 6               ; if black bit is 6th
    je cl_6
    cmp cl, 7               ; if black bit is 6th
    je cl_7

    add cl, 3               ; this is for skipping the guard
    jmp read_barcode        ; in other cases start reading the barcode
    


cl_5:
    add edi, 1              
    mov dl, byte[edi]       ; move to next byte since actual number is in next one 
    xor ecx, ecx            ; this is for skipping the guard
    jmp read_barcode

cl_6:
    add edi, 1             
    mov dl, byte[edi]       ; move to next byte since actual number is in next one 
    mov cl, 1               ; this is for skipping the guard
    jmp read_barcode

cl_7:
    add edi, 1              
    mov dl, byte[edi]       ; move to next byte since actual number is in next one 
    mov cl, 2               ; this is for skipping the guard   
    jmp read_barcode

; At this point dl points to byte to read first number from and cl is the position of the first bit
; cl = position of bit to read from
; dl = copy of current byte
; al = store barcode bar decocded
; edi = pointer to current btye
read_barcode:
    mov dword [ebp-16], 0   ; counter of read numbers
    mov esi, [ebp + 20]     ;pointer to the array of digits
read_number:
    cmp dword [ebp-16], 6
    je skip_middle_guard
    mov dl, byte[edi]
    cmp cl, 0
    je all_in_current_byte
    cmp cl, 1
    je all_in_current_byte

    mov al, dl
    shl al, cl
    mov bl, 8           
    sub bl, cl          ; bl - amount of bits saved 
    mov ah, 7           
    sub ah, bl          ; ah = amount of bits to get from next byte

    add edi, 1          ; move to next byte
    mov dl, byte[edi]
    mov bl, dl
    mov ch, cl          ; save bit position to ch
    mov cl, 8           
    sub cl, ah          ; cl = amount by which we shift the next byte
    shr bl, cl          ; shift to get lhigher bits
    mov cl, 7
    sub cl,  ah
    shr al, 1           ; shift buffer register to add found bits
    or al, bl           ; add last bits    
    mov cl, ch

    jmp compare_left_numbers

all_in_current_byte:
    mov al, dl
    shl al, cl
    shr al, 1
    cmp cl, 1           ; if cl = 0 dont add if cl = 1 move to next byte
    je move_register_to_next_byte
    jmp compare_left_numbers

move_register_to_next_byte:
    mov ebx, 1          
    add edi, ebx
    jmp compare_left_numbers

compare_left_numbers:
    add dword [ebp-16], 1
    cmp al, 0x72
    je store_0
    cmp al, 0x66
    je store_1
    cmp al, 0x6C
    je store_2
    cmp al, 0x42
    je store_3
    cmp al, 0x5C
    je store_4
    cmp al, 0x4E
    je store_5
    cmp al, 0x50
    je store_6
    cmp al, 0x44
    je store_7
    cmp al, 0x48
    je store_8
    cmp al, 0x74
    je store_9


store_0:
    add esi, 1
    jmp next_number

store_1:
    mov byte [esi], 1
    add esi, 1
    jmp next_number

store_2:
    mov byte [esi], 2
    add esi, 1
    jmp next_number

store_3:
    mov byte [esi], 3
    add esi, 1
    jmp next_number

store_4:
    mov byte [esi], 4
    add esi, 1
    jmp next_number

store_5:
    mov byte [esi], 5
    add esi, 1
    jmp next_number

store_6:
    mov byte [esi], 6
    add esi, 1
    jmp next_number

store_7:
    mov byte [esi], 7
    add esi, 1
    jmp next_number

store_8:
    mov byte [esi], 8
    add esi, 1
    jmp next_number

store_9:
    mov byte [esi], 9
    add esi, 1
    jmp next_number

next_number:
    ;move posion counter
    add cl, 7
    cmp cl, 8
    jl read_number
    sub cl, 8
    jmp read_number


; We read first 6 digits now we need to skip the guard 
; cl = position of the start of the guard in the byte
; edi = current byte
; esi = pointer to posioin to write next number to
; ebp - 16 = counter of the numbers to write left

skip_middle_guard:
    mov al, 8         ; Total bits in a byte
    sub al, cl        ; Calculate remaining bits in the current byte: 8 - cl
    cmp al, 5         ; Check if there are at least 5 bits left
    jae same_byte     ; If yes, the guard fits in the same byte

    ; Guard spans two bytes
    sub cl, 8         ; Adjust cl for the current byte (wrap around)
    add cl, 5         ; Move cl forward by 5 bits
    add edi, 1        ; Move to the next byte

    jmp read_number_right

same_byte:
    add cl, 5         ; Move cl forward by 5 bits
    cmp cl, 8         ; Check if cl overflows the current byte
    jl read_number_right         ; If cl < 8, we done
    sub cl, 8         ; Adjust cl for the next byte
    add edi, 1        ; Move to the next byte







    read_number_right:
    cmp dword [ebp-16], 12
    je finish
    mov dl, byte[edi]
    cmp cl, 0
    je all_in_current_byte_right
    cmp cl, 1
    je all_in_current_byte_right

    mov al, dl
    shl al, cl
    mov bl, 8           
    sub bl, cl          ; bl - amount of bits saved 
    mov ah, 7           
    sub ah, bl          ; ah = amount of bits to get from next byte

    add edi, 1          ; move to next byte
    mov dl, byte[edi]
    mov bl, dl
    mov ch, cl          ; save bit position to ch
    mov cl, 8           
    sub cl, ah          ; cl = amount by which we shift the next byte
    shr bl, cl          ; shift to get lhigher bits
    mov cl, 7
    sub cl,  ah
    shr al, 1           ; shift buffer register to add found bits
    or al, bl           ; add last bits  
    mov cl, ch

    jmp compare_right_numbers

all_in_current_byte_right:
    mov al, dl
    shl al, cl
    shr al, 1
    cmp cl, 1           ; if cl = 0 dont add if cl = 1 move to next byte
    je move_register_to_next_byte_right
    jmp compare_right_numbers

move_register_to_next_byte_right:
    mov ebx, 1          
    add edi, ebx
    jmp compare_right_numbers

compare_right_numbers:
    add dword [ebp-16], 1
    cmp al, 0x0D
    je store_0_right
    cmp al, 0x19
    je store_1_right
    cmp al, 0x13
    je store_2_right
    cmp al, 0x3D
    je store_3_right
    cmp al, 0x23
    je store_4_right
    cmp al, 0x31
    je store_5_right
    cmp al, 0x2F
    je store_6_right
    cmp al, 0x3B
    je store_7_right
    cmp al, 0x37
    je store_8_right
    cmp al, 0x0B
    je store_9_right


store_0_right:
    add esi, 1
    jmp next_number_right

store_1_right:
    mov byte [esi], 1
    add esi, 1
    jmp next_number_right

store_2_right:
    mov byte [esi], 2
    add esi, 1
    jmp next_number_right

store_3_right:
    mov byte [esi], 3
    add esi, 1
    jmp next_number_right

store_4_right:
    mov byte [esi], 4
    add esi, 1
    jmp next_number_right

store_5_right:
    mov byte [esi], 5
    add esi, 1
    jmp next_number_right

store_6_right:
    mov byte [esi], 6
    add esi, 1
    jmp next_number_right

store_7_right:
    mov byte [esi], 7
    add esi, 1
    jmp next_number_right

store_8_right:
    mov byte [esi], 8
    add esi, 1
    jmp next_number_right

store_9_right:
    mov byte [esi], 9
    add esi, 1
    jmp next_number_right

next_number_right:
    ;move posion counter
    add cl, 7
    cmp cl, 8
    jl read_number_right
    sub cl, 8
    jmp read_number_right





finish:
    ; Epilogue
    pop edi
    pop esi
    pop ebx
    leave
    ret
