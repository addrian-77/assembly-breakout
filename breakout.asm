org 100h


; main function
main:                    
    
    
    call graphic_init
    call player_init
    ;jmp mainskip 
    call level_init 
    
    mainskip:
             
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
    
    
    ; current row index
    mov si, 0
    ; this loop computes the y-offset
    bricks_draw_row:
    
    ; yellow bricks, 2 rows
    cmp si, 2
    jg next_color_1
        push bx
        mov bl, color_d_red
        mov current_color, bl
        pop bx
        jmp color_skip
    
    next_color_1:
    
    ; green bricks, 2 rows
    cmp si, 5
    jg next_color_2
        push bx
        mov bl, color_red
        mov current_color, bl
        pop bx
        jmp color_skip
    
    next_color_2:
    
    ; red bricks, 3 rows
    cmp si, 8
    jg next_color_3
        push bx
        mov bl, color_green
        mov current_color, bl
        pop bx
        jmp color_skip
    
    next_color_3:
    
    ; last rows, we reach here after 7
        push bx
        mov bl, color_yellow
        mov current_color, bl
        pop bx
    
    color_skip: 
        
        ; save bx and ax to preserve them
        push bx
        push ax
        
        ; we need ax to make multiplications... great design
        ; row number * stride_y
        mov ax, si
        mul brick_stride_y          
        
        ; save result in bx
        mov bx, ax
        
        ; retrieve ax
        pop ax 
        
        ; one more pixel, so the bricks won't be glued to the ceiling
        inc bx
        
        ; save the current offset
        mov brick_offset_y, bx 
        ; retrieve bx
        pop bx
        
        push si
        ; current column index
        mov si, 0
        ; this loop computes the x-offset
        bricks_draw_column:
            
            ; just as before, save bx and ax
            push bx 
            push ax
            ; make the multiplication using ax
            
            ; col number * stride_x
            mov ax, si
            mul brick_stride_x     
            
            ; save result in bx
            mov bx, ax
            
            ; retrieve ax
            pop ax
            
            ; inc bx, so we have 1 pixel offset on the left of the screen
            ; we will also have 1 pixel offset to the right
            inc bx
            
            ; save the current x offset
            mov brick_offset_x, bx     
            
            ; retrieve bx
            pop bx
            
            ; ------------------------this is where drawing begins-------------------------------
            call draw_brick
                    
            inc si
        cmp si, 29
        jl bricks_draw_column 
        
        pop si
        inc si
        
    cmp si, 12
    jl bricks_draw_row
    
    
    ret
level_init endp


;-------------------------------------------------------------------


draw_brick proc
; set up the drawing interrupt
    mov ah, 0ch
    mov al, current_color
    mov bh, 0   
    
    ; draw cx rows
    mov cx, brick_offset_x
    
    brick_draw_row:
        
        ; draw dx columns
        mov dx, brick_offset_y
        
        brick_draw_column:
            
            ; call the drawing interrupt
            int 10h               
            
            ; move to the next column
            inc dx
            
            ; use bx to compare if we drew enough columns
            ; offset + height
            ; push current bx
            push bx
            mov bx, brick_offset_y
            add bx, brick_height
        cmp dx, bx
            ; retrieve bx
            pop bx
        ; jum back if we're not finished
        jl brick_draw_column 
        
        ; move to the next row
        inc cx
        
        ; use bx to compare if we drew enough rows
        ; offset + width
        ; push current bx
        push bx
        mov bx, brick_offset_x
        add bx, brick_width
    cmp cx, bx
        ; retrieve bx
        pop bx
    ; jump back if we're not finished
    jl brick_draw_row
    
    ret

draw_brick endp                                                                    

                                                                    
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

    cmp word ptr proj_active[si], 1
    jne skip_proj_update

    push bx

    ; save last position
    mov bx, proj_pos_x[si]
    mov proj_lastpos_x[si], bx

    mov bx, proj_pos_y[si]
    mov proj_lastpos_y[si], bx


    ; ---------------- update X ----------------

    cmp proj_steps_x[si], 0
    je continue_update_x

        dec proj_steps_x[si]
        jmp skip_update_x

continue_update_x:

    mov word ptr proj_steps_x[si], 300

    mov bx, proj_speed_x[si]
    add proj_pos_x[si], bx

    mov bx, max_speed_x
    sub proj_pos_x[si], bx

skip_update_x:


    ; ---------------- update Y ----------------

    cmp proj_steps_y[si], 0
    je continue_update_y

        dec proj_steps_y[si]
        jmp skip_update_y

continue_update_y:

    mov word ptr proj_steps_y[si], 50

    mov bx, proj_speed_y[si]
    add proj_pos_y[si], bx

    mov bx, max_speed_y
    sub proj_pos_y[si], bx

skip_update_y:


    ; ---------------- brick collision, coordinate based ----------------

    cmp proj_pos_y[si], 65
    jg skip_bricks_check

    call check_projectile_brick_collision

    cmp brick_found, 1
    jne skip_bricks_check

        ; decide bounce direction based on movement
        mov bx, proj_lastpos_y[si]
        cmp bx, proj_pos_y[si]
        jne bounce_from_brick_y

        mov bx, proj_lastpos_x[si]
        cmp bx, proj_pos_x[si]
        jne bounce_from_brick_x

        jmp destroy_brick_after_bounce

bounce_from_brick_y:
        call flip_proj_y
        jmp destroy_brick_after_bounce

bounce_from_brick_x:
        call flip_proj_x

destroy_brick_after_bounce:

        mov current_color, 0h
        call draw_brick

        push si
        mov si, brick_ind
        mov bricks[si], 0
        pop si

skip_bricks_check:


    ; ---------------- paddle collision ----------------

    push bx
    mov bx, proj_pos_y[si]
    add bx, 3

    cmp bx, pos_y
    pop bx
    jne skip_paddle_check

        mov bx, proj_pos_x[si]
        inc bx

        cmp bx, pos_x
        jl skip_paddle_check

        sub bx, pos_x

        cmp bx, 5
        jg check_x_1

            cmp proj_speed_x[si], 1
            je flip_y_paddle

            dec proj_speed_x[si]
            jmp flip_y_paddle

check_x_1:

        cmp bx, 9
        jg check_x_2

            jmp flip_y_paddle

check_x_2:

        cmp bx, 15
        jg skip_paddle_check

            cmp proj_speed_x[si], 5
            je flip_y_paddle

            inc proj_speed_x[si]

flip_y_paddle:

        mov proj_pos_y[si], 167
        call flip_proj_y

skip_paddle_check:


    ; ---------------- screen bounds ----------------

    ; left wall
    cmp proj_pos_x[si], 0
    jg skip_flip_x_min

        mov word ptr proj_pos_x[si], 0
        call flip_proj_x

skip_flip_x_min:

    ; right wall
    cmp proj_pos_x[si], 318
    jl skip_flip_x_max

        mov word ptr proj_pos_x[si], 316
        call flip_proj_x

skip_flip_x_max:

    ; ceiling
    cmp proj_pos_y[si], 0
    jg skip_flip_y_min

        mov word ptr proj_pos_y[si], 0
        call flip_proj_y

skip_flip_y_min:

    ; bottom: despawn ball instead of bouncing
    cmp proj_pos_y[si], 196
    jl skip_flip_y_max
        
        ; remove these lines, these lines bounce the ball
        call flip_proj_y
        jmp skip_flip_y_max
        ; delete above
        
        mov al, color_black
        call draw_projectile

        mov word ptr proj_active[si], 0

        pop bx
        jmp skip_proj_update

skip_flip_y_max:


    ; ---------------- redraw projectile ----------------

    pop bx

    mov bx, proj_lastpos_x[si]
    cmp proj_pos_x[si], bx
    jne proj_redraw

    mov bx, proj_lastpos_y[si]
    cmp proj_pos_y[si], bx
    je skip_proj_redraw

proj_redraw:

    mov al, color_black
    call draw_projectile

    mov al, color_white
    call draw_projectile

skip_proj_redraw:


skip_proj_update:

    add si, 2
    cmp si, 100
    jl proj_updater_loop

    ret

update_projectiles endp


;-------------------------------------------------------------------


check_projectile_brick_collision proc
    ; checks all 4 ball corners
    ; output:
    ; brick_found = 1 if hit
    ; brick_ind, brick_offset_x, brick_offset_y set by check_brick_at_point

    mov brick_found, 0

    push bx

    ; top-left
    mov bx, proj_pos_x[si]
    mov brick_coords_x, bx

    mov bx, proj_pos_y[si]
    mov brick_coords_y, bx

    call check_brick_at_point

    cmp brick_found, 1
    je projectile_collision_done


    ; top-right
    mov bx, proj_pos_x[si]
    add bx, proj_size
    dec bx
    mov brick_coords_x, bx

    mov bx, proj_pos_y[si]
    mov brick_coords_y, bx

    call check_brick_at_point

    cmp brick_found, 1
    je projectile_collision_done


    ; bottom-left
    mov bx, proj_pos_x[si]
    mov brick_coords_x, bx

    mov bx, proj_pos_y[si]
    add bx, proj_size
    dec bx
    mov brick_coords_y, bx

    call check_brick_at_point

    cmp brick_found, 1
    je projectile_collision_done


    ; bottom-right
    mov bx, proj_pos_x[si]
    add bx, proj_size
    dec bx
    mov brick_coords_x, bx

    mov bx, proj_pos_y[si]
    add bx, proj_size
    dec bx
    mov brick_coords_y, bx

    call check_brick_at_point

projectile_collision_done:

    pop bx
    ret

check_projectile_brick_collision endp


;-------------------------------------------------------------------  


check_brick_at_point proc
    ; input:
    ; brick_coords_x
    ; brick_coords_y
    ;
    ; output:
    ; brick_found = 1 or 0
    ; brick_ind
    ; brick_offset_x
    ; brick_offset_y

    mov brick_found, 0

    push ax
    push bx
    push dx
    push si

    ; x must be >= 1
    mov ax, brick_coords_x
    cmp ax, 1
    jl no_brick_at_point

    dec ax
    xor dx, dx
    mov bx, brick_stride_x
    div bx

    mov brick_ind_x, ax       ; column
    mov bx, dx                ; x inside cell

    cmp brick_ind_x, 29
    jge no_brick_at_point

    cmp bx, brick_width
    jge no_brick_at_point


    ; y must be >= 1
    mov ax, brick_coords_y
    cmp ax, 1
    jl no_brick_at_point

    dec ax
    xor dx, dx
    mov bx, brick_stride_y
    div bx

    mov brick_ind_y, ax       ; row
    mov bx, dx                ; y inside cell

    cmp brick_ind_y, 12
    jge no_brick_at_point

    cmp bx, brick_height
    jge no_brick_at_point


    ; index = row * 29 + col
    mov ax, brick_ind_y
    mov bx, 29
    mul bx
    add ax, brick_ind_x
    mov brick_ind, ax

    mov si, ax
    cmp bricks[si], 0
    je no_brick_at_point


    ; brick_offset_x = col * stride_x + 1
    mov ax, brick_ind_x
    mov bx, brick_stride_x
    mul bx
    inc ax
    mov brick_offset_x, ax


    ; brick_offset_y = row * stride_y + 1
    mov ax, brick_ind_y
    mov bx, brick_stride_y
    mul bx
    inc ax
    mov brick_offset_y, ax

    mov brick_found, 1

no_brick_at_point:

    pop si
    pop dx
    pop bx
    pop ax
    ret

check_brick_at_point endp
      
      
;-------------------------------------------------------------------  


flip_proj_x proc

    push bx

    mov bx, 6
    sub bx, proj_speed_x[si]
    mov proj_speed_x[si], bx

    pop bx
    ret

flip_proj_x endp    
                                                                     
                                                                     
;------------------------------------------------------------------- 
    
    
flip_proj_y proc

    push bx

    mov bx, 6
    sub bx, proj_speed_y[si]
    mov proj_speed_y[si], bx

    pop bx
    ret

flip_proj_y endp


;------------------------------------------------------------------- 

 
draw_projectile proc
    ; drawing mode
    mov ah, 0ch    
    mov bh, 0     
    
    ; start at posx
    cmp al, color_black
    jne draw_white_row
        mov cx, proj_lastpos_x[si]
        jmp draw_projectile_loop_row 
    draw_white_row:
    mov cx, proj_pos_x[si]
    draw_projectile_loop_row:
        ; column
        cmp al, color_black
        jne draw_white_column
            mov dx, proj_lastpos_y[si]
            jmp draw_projectile_loop_column
        draw_white_column:
        mov dx, proj_pos_y[si]
        draw_projectile_loop_column: 
            ; draw
            int 10h
            
            ; move down
            inc dx   
            push bx
            cmp al, color_black
            jne use_curr_y_bound
                mov bx, proj_lastpos_y[si]
                jmp got_y_bound
            use_curr_y_bound:
                mov bx, proj_pos_y[si]
            got_y_bound:
            add bx, proj_size

                
            ; compare, jump back 
            cmp dx, bx
            pop bx
                                      
        jl draw_projectile_loop_column
            
        ; go to next row
        inc cx
            
        ; use bx to compare
        push bx
        cmp al, color_black
        jne use_curr_x_bound
            mov bx, proj_lastpos_x[si]
            jmp got_x_bound
        use_curr_x_bound:
            mov bx, proj_pos_x[si]
        got_x_bound:
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
          
    
    cmp game_started, 0
    jne n3 
    cmp al, 32
    jne n3
        mov word ptr proj_active[0], 1
        mov word ptr proj_speed_y[0], 2
        mov word ptr proj_speed_x[0], 2
        
        mov word ptr proj_active[2], 1
        mov word ptr proj_speed_y[2], 2
        mov word ptr proj_speed_x[2], 2
        
        mov word ptr proj_active[4], 1
        mov word ptr proj_speed_y[4], 2
        mov word ptr proj_speed_x[4], 4
        
        mov word ptr proj_active[6], 1
        mov word ptr proj_speed_y[6], 2
        mov word ptr proj_speed_x[6], 5
        
        mov game_started, 1
        
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
brick_width     dw 10 
brick_height    dw 4

brick_stride_x  dw 11
brick_stride_y  dw 5

brick_offset_x  dw 0
brick_offset_y  dw 0
bricks          db 348 dup (1)

brick_coords_x  dw 0
brick_coords_y  dw 0
brick_ind       dw 0
brick_ind_x     dw 0
brick_ind_y     dw 0
brick_found     dw 0     

; projectile vars
proj_pos_x      dw 106, 106, 106, 106, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_pos_y      dw 167, 167, 167, 167, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_speed_x    dw 50 dup(3)
proj_speed_y    dw 50 dup(3)
proj_steps_x    dw 50 dup(0)
proj_steps_y    dw 50 dup(0)
proj_active     dw 50 dup(0)

proj_lastpos_x  dw 106, 106, 106, 106, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_lastpos_y  dw 167, 167, 167, 167, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

proj_size       dw 2
proj_top_left   db 0
proj_top_right  db 0
proj_bot_left   db 0
proj_bot_right  db 0
game_started    dw 0
max_speed_x     dw 3
max_speed_y     dw 3     


; colors
color_red       db 0ch
color_black     db 0h 
color_white     db 0fh 
color_yellow    db 0eh
color_green     db 0ah
color_d_red     db 04h

current_color   db 0ch
