org 100h


; main function
main:                    

    call graphic_init
    call player_init
    call level_init 
    
             
    main_loop:
                               
        call key_listener
        
        call update_projectiles
        
    jmp main_loop
    
    
    ; dos recommends adding int 16h at the end of the program, idk why
    mov ax, 0 
    int 16h
    
    ret
    
; main end    
                                                                   
                                                                   
;-------------------------------------------------------------------
      
           
graphic_init proc
    ; set graphical mode          
    mov al, 13h
    mov ah, 0
    mov bh, 0
    int 10h 
    
    ret    
graphic_init endp

                                                                    
;-------------------------------------------------------------------

                                                                   
player_init proc   
        
    mov ah, 0ch
    mov al, color_red
    mov bh, 0
    
    ; start drawing rows at pos_x    
    mov cx, pos_x
    
    draw_loop_row:  
        
        ; start drawing columns at pos_y
        mov dx, pos_y
        draw_loop_column:
            ; draw pixel
            int 10h
            
            ; go to the next column
            inc dx
            
            ; save bx on stack, use bx to compute the end for drawing
            push bx
            mov bx, pos_y
            add bx, size_y
            
            ; compare, jump back 
            cmp dx, bx
            pop bx
            
        jl draw_loop_column
        
        ; go to next row
        inc cx
        
        ; use bx to compare
        push bx
        mov bx, pos_x
        add bx, size_x
        
        cmp cx, bx   
        pop bx
        
    jl draw_loop_row
    
    ; projectile index
    mov si, 0
    ; color
    mov al, color_white
    call draw_projectile         
        
    ret    

player_init endp                                                         


;-------------------------------------------------------------------


level_init proc
    ret
level_init endp
                                                                    
                                                                    
;-------------------------------------------------------------------


move_player_right proc     
    ; compute the right bound using bx
    push bx
    mov bx, 319
    sub bx, size_x
    
    cmp pos_x, bx
    pop bx
    je skip_right
    
    ; set up drawing mode
    mov ah, 0ch
    mov al, color_black
    mov bh, 0
    
    mov cx, pos_x                
    
    ; draw a black column at posx
    call draw_column_player
    
    ; move right
    add cx, size_x     
    
    mov al, color_red
    
    ; draw a red column on the right
    call draw_column_player
    
    inc pos_x
    
    skip_right:
    ret
    
move_player_right endp


                                                                    
;------------------------------------------------------------------- 



move_player_left proc
    ; left bound
    cmp pos_x, 0
    je skip_left
    
    ; decrement xpos
    dec pos_x
    
    ; set up drawing mode
    mov ah, 0ch
    mov al, color_red
    mov bh, 0
    
    mov cx, pos_x
    
    ; draw a red column at the new posx
    call draw_column_player
    
    ; move right
    add cx, size_x
    
    mov al, color_black
    
    ; draw a black column on the right
    call draw_column_player
    
    skip_left:
    ret 
move_player_left endp

                                                                    
;-------------------------------------------------------------------


draw_column_player proc
    ; start drawing at pos_y, increment until size_y
    mov dx, pos_y
    draw_column_player_loop:
        int 10h
        
        inc dx
        
        ; use bx to compute the height, compare and jump back
        push bx
        mov bx, pos_y
        add bx, size_y
        cmp dx, bx
        pop bx
    jl draw_column_player_loop 
    ret
draw_column_player endp


;-------------------------------------------------------------------


update_projectiles proc
    
    mov si, 0
    proj_updater_loop:
        
        cmp proj_active[si], 1
        jne skip_proj_update
            
            mov al, color_black
            call draw_projectile
            
            push bx         
            
            mov bx, proj_speed_x[si]
            add proj_pos_x[si], bx 
            mov bx, max_speed_x 
            sub proj_pos_x[si], bx  
            
            mov bx, proj_speed_y[si]
            add proj_pos_y[si], bx 
            mov bx, max_speed_y 
            sub proj_pos_y[si], bx
                                
            pop bx
            
            mov al, color_white
            call draw_projectile
            
            
        skip_proj_update:
        
        inc si
        cmp si, 51 
    jl proj_updater_loop
    
    ret
update_projectiles endp


;------------------------------------------------------------------- 

 
draw_projectile proc
    ; drawing mode
    mov ah, 0ch    
    mov bh, 0     
    
    ; start at posx
    mov cx, proj_pos_x[si]
    draw_projectile_loop_row:
        ; column
        mov dx, proj_pos_y[si]
        draw_projectile_loop_column: 
            ; draw
            int 10h
            
            ; move down
            inc dx   
            push bx
            mov bx, proj_pos_y[si]
            add bx, proj_size
                
            ; compare, jump back 
            cmp dx, bx
            pop bx
                                      
        jl draw_projectile_loop_column
            
        ; go to next row
        inc cx
            
        ; use bx to compare
        push bx
        mov bx, proj_pos_x[si]
        add bx, proj_size
            
        cmp cx, bx   
        pop bx
    jl draw_projectile_loop_row
    ret
draw_projectile endp                                                                    
                                                                    
                                                                    
;-------------------------------------------------------------------


key_listener proc
    ; interrupt for reading keyboard input, value is sent to `al`
    mov ah, 01h
    int 16h
    
    jz key_listener_skip    
    
    ; a, decrease y
    cmp al, 'a'    
    jne n1
        ; call the move_left function player_speed times
        ; save original bx on stack
        push bx
        mov bx, player_speed_x
        speed_loop_left:
            ; save bx on stack                
            push bx
            call move_player_left
            ; get bx back, decrement, compare and jump back
            pop bx                    
            dec bx
            cmp bx, 0
        jg speed_loop_left   
        ; retrieve the original bx
        pop bx
    n1:
    
    ; d, increase y
    cmp al, 'd'    
    jne n2
        ; call the move_right function player_speed times                
        ; save original bx on stack
        push bx
        mov bx, player_speed_x
        speed_loop_right:
            ; save bx on stack
            push bx
            call move_player_right
            ; get bx back, decrement, compare and jump back     
            pop bx
            dec bx
            cmp bx, 0
        jg speed_loop_right
        ; retrieve the original bx
        pop bx
    n2:
          
    
    cmp al, 32
    jne n3
        mov proj_active[0], 1
        mov proj_speed_y[0], 2
        
    n3:
    
    key_listener_skip: 
    
    ; flush the input, as the read interrupt is not blocking
    mov ah, 0ch                                             
    ; set al to an out of bounds function, so it gets ignored and we just flush the buffer
    mov al, 0ch
    int 21h
                         
    ret
    
key_listener endp

                                                                    
;-------------------------------VARS--------------------------------


; player vars
pos_x           dw 100
pos_y           dw 170
size_x          dw 14
size_y          dw 3
player_speed_x  dw 3

; bricks vars
brick_size      dw 10

; projectile vars
proj_pos_x      dw 106, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_pos_y      dw 167, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_speed_x    dw 50 dup(3)
proj_speed_y    dw 50 dup(3)
proj_steps_x    dw 50 dup(0)
proj_steps_y    dw 50 dup(0)
proj_active     dw 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_size       dw 3
game_started    dw 0
max_speed_x     dw 3
max_speed_y     dw 3     


; colors
color_red       db 0ch
color_black     db 0h 
color_white     db 0fh
