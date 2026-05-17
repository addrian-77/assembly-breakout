org 100h


; main function
main:                    
    
    push cs
    pop ds
    
    call graphic_init
    call level_init
    call powerups_init
    call player_init     
    call draw_score
    

             
    main_loop:
                               
        call key_listener
        
        call update_projectiles
        
    jmp main_loop
    
    
    ; dos recommends adding int 16h at the end of the program, idk why
    mov ax, 0 
    int 16h 
    push cs
    pop ds
    
    ret
    
; main end    
                                                                   
                                                                   
;-------------------------------------------------------------------
      
           
graphic_init proc
    mov ax, 0013h
    int 10h

    ; restore data segment AFTER BIOS call
    push cs
    pop ds

    ret
graphic_init endp


;-------------------------------------------------------------------

                                                                   
player_init proc
    push cs
    pop ds

    ; draw paddle
    mov ax, pos_x
    mov rect_x, ax

    mov ax, pos_y
    mov rect_y, ax

    mov ax, size_x
    mov rect_w, ax

    mov ax, size_y
    mov rect_h, ax

    mov al, color_red
    mov rect_color, al

    call draw_rect_fast

    ; draw initial projectile
    mov si, 0
    mov al, color_white
    call draw_projectile

    ret

player_init endp                                                         


;-------------------------------------------------------------------


level_init proc
    push cs
    pop ds
    
    
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


powerups_init proc
    ; 0 = normal
    ; 1 = orange: split active ball
    ; 2 = blue: spawn from paddle

    ; ---------------- orange powerups ----------------
    mov brick_type[3], 1
    mov brick_type[14], 1
    mov brick_type[27], 1

    mov brick_type[40], 1
    mov brick_type[58], 1
    mov brick_type[71], 1

    mov brick_type[94], 1
    mov brick_type[116], 1
    mov brick_type[137], 1

    mov brick_type[160], 1
    mov brick_type[188], 1
    mov brick_type[211], 1

    mov brick_type[235], 1
    mov brick_type[260], 1
    mov brick_type[287], 1

    ; ---------------- blue powerups ----------------
    mov brick_type[8], 2
    mov brick_type[22], 2

    mov brick_type[51], 2
    mov brick_type[83], 2

    mov brick_type[104], 2
    mov brick_type[129], 2

    mov brick_type[174], 2
    mov brick_type[199], 2

    mov brick_type[230], 2
    mov brick_type[255], 2

    mov brick_type[303], 2
    mov brick_type[335], 2

    ret
powerups_init endp

      
;-------------------------------------------------------------------


draw_rect_fast proc
    ; input:
    ; rect_x
    ; rect_y
    ; rect_w
    ; rect_h
    ; rect_color

    push ax
    push bx
    push cx
    push dx
    push di
    push ds
    push es

    push cs
    pop ds

    mov ax, 0A000h
    mov es, ax

    mov dx, rect_y          ; DX = current row

rect_row_loop:

    push dx                 ; save current row because MUL destroys DX

    mov ax, dx              ; AX = y
    mov bx, 320
    mul bx                  ; AX = y * 320, DX is destroyed here
    add ax, rect_x
    mov di, ax              ; DI = y * 320 + x

    mov cx, rect_w
    mov al, rect_color

rect_col_loop:
    mov es:[di], al
    inc di
    loop rect_col_loop

    pop dx                  ; restore current row

    inc dx                  ; next row

    mov ax, rect_y
    add ax, rect_h          ; AX = rect_y + rect_h

    cmp dx, ax
    jl rect_row_loop

    pop es
    pop ds
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_rect_fast endp   
     

;-------------------------------------------------------------------

     
draw_score proc
    push ax
    push bx
    push cx
    push dx
    push ds

    push cs
    pop ds

    ; erase old score area
    mov word ptr rect_x, 240
    mov word ptr rect_y, 188
    mov word ptr rect_w, 80
    mov word ptr rect_h, 12
    mov al, color_black
    mov rect_color, al
    call draw_rect_fast

    ; set cursor near bottom-right
    mov ah, 02h
    mov bh, 0
    mov dh, 23          ; row
    mov dl, 66          ; column
    int 10h

    push cs
    pop ds

    ; print "Score:"
    mov ah, 0Eh
    mov bh, 0

    mov al, 'S'
    int 10h
    mov al, 'c'
    int 10h
    mov al, 'o'
    int 10h
    mov al, 'r'
    int 10h
    mov al, 'e'
    int 10h
    mov al, ':'
    int 10h
    mov al, ' '
    int 10h

    ; convert score to 4 decimal digits
    mov ax, score

    xor dx, dx
    mov bx, 1000
    div bx
    add al, '0'
    mov score_digits[0], al

    mov ax, dx
    xor dx, dx
    mov bx, 100
    div bx
    add al, '0'
    mov score_digits[1], al

    mov ax, dx
    xor dx, dx
    mov bx, 10
    div bx
    add al, '0'
    mov score_digits[2], al

    add dl, '0'
    mov score_digits[3], dl

    ; print digits
    mov ah, 0Eh

    mov al, score_digits[0]
    int 10h

    mov al, score_digits[1]
    int 10h

    mov al, score_digits[2]
    int 10h

    mov al, score_digits[3]
    int 10h

    push cs
    pop ds

    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_score endp


;-------------------------------------------------------------------

draw_game_over_text proc
    push ax
    push bx
    push dx
    push ds

    push cs
    pop ds

    ; optional black background rectangle behind text
    mov word ptr rect_x, 70
    mov word ptr rect_y, 90
    mov word ptr rect_w, 190
    mov word ptr rect_h, 25
    mov al, color_black
    mov rect_color, al
    call draw_rect_fast

    ; set cursor around center
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov dl, 24
    int 10h

    push cs
    pop ds

    mov ah, 0Eh
    mov bh, 0

    mov al, 'G'
    int 10h
    mov al, 'A'
    int 10h
    mov al, 'M'
    int 10h
    mov al, 'E'
    int 10h
    mov al, ' '
    int 10h
    mov al, 'O'
    int 10h
    mov al, 'V'
    int 10h
    mov al, 'E'
    int 10h
    mov al, 'R'
    int 10h

    ; second line
    mov ah, 02h
    mov bh, 0
    mov dh, 14
    mov dl, 17
    int 10h

    push cs
    pop ds

    mov ah, 0Eh
    mov bh, 0

    mov al, 'P'
    int 10h
    mov al, 'r'
    int 10h
    mov al, 'e'
    int 10h
    mov al, 's'
    int 10h
    mov al, 's'
    int 10h
    mov al, ' '
    int 10h
    mov al, 'S'
    int 10h
    mov al, 'p'
    int 10h
    mov al, 'a'
    int 10h
    mov al, 'c'
    int 10h
    mov al, 'e'
    int 10h
    mov al, ' '
    int 10h
    mov al, 't'
    int 10h
    mov al, 'o'
    int 10h
    mov al, ' '
    int 10h
    mov al, 'r'
    int 10h
    mov al, 'e'
    int 10h
    mov al, 's'
    int 10h
    mov al, 'e'
    int 10h
    mov al, 't'
    int 10h

    push cs
    pop ds

    pop ds
    pop dx
    pop bx
    pop ax
    ret
draw_game_over_text endp


;-------------------------------------------------------------------


reset_game proc
    push ax
    push si
    push ds

    push cs
    pop ds

    ; reset score/state
    mov word ptr score, 0
    mov word ptr game_started, 0
    mov word ptr game_over, 0

    ; reset bricks
    mov si, 0

reset_bricks_loop:
    mov bricks[si], 1
    mov brick_type[si], 0

    inc si
    cmp si, 348
    jl reset_bricks_loop

    ; reset projectiles
    mov si, 0

reset_projectiles_loop:
    mov word ptr proj_active[si], 0
    mov word ptr proj_speed_x[si], 3
    mov word ptr proj_speed_y[si], 2
    mov word ptr proj_steps_x[si], 0
    mov word ptr proj_steps_y[si], 0
    mov word ptr proj_pos_x[si], 0
    mov word ptr proj_pos_y[si], 0
    mov word ptr proj_lastpos_x[si], 0
    mov word ptr proj_lastpos_y[si], 0

    add si, 2
    cmp si, 50
    jl reset_projectiles_loop

    ; reset first ball position
    mov word ptr proj_pos_x[0], 106
    mov word ptr proj_pos_y[0], 167
    mov word ptr proj_lastpos_x[0], 106
    mov word ptr proj_lastpos_y[0], 167
    ;mov word ptr proj_pos_x[2], 106
    ;mov word ptr proj_pos_y[2], 167
    ;mov word ptr proj_lastpos_x[2], 106
    ;mov word ptr proj_lastpos_y[2], 167
    ;mov word ptr proj_pos_x[4], 106
    ;mov word ptr proj_pos_y[4], 167
    ;mov word ptr proj_lastpos_x[4], 106
    ;mov word ptr proj_lastpos_y[4], 167
    ;mov word ptr proj_pos_x[6], 106
    ;mov word ptr proj_pos_y[6], 167
    ;mov word ptr proj_lastpos_x[6], 106
    ;mov word ptr proj_lastpos_y[6], 167
    
    mov word ptr pos_x, 100
    
    

    ; redraw everything
    call graphic_init
    call level_init
    call powerups_init
    call player_init
    call draw_score

    pop ds
    pop si
    pop ax
    ret
reset_game endp


;-------------------------------------------------------------------


draw_brick proc
    push ax
    push bx

    mov bx, brick_offset_x
    mov rect_x, bx

    mov bx, brick_offset_y
    mov rect_y, bx

    mov bx, brick_width
    mov rect_w, bx

    mov bx, brick_height
    mov rect_h, bx

    mov al, current_color
    mov rect_color, al

    call draw_rect_fast

    pop bx
    pop ax
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
    ; input:
    ; CX = x
    ; AL = color

    push ax
    push bx

    mov rect_x, cx

    mov bx, pos_y
    mov rect_y, bx

    mov word ptr rect_w, 1

    mov bx, size_y
    mov rect_h, bx

    mov rect_color, al

    call draw_rect_fast

    pop bx
    pop ax
    ret
draw_column_player endp


;-------------------------------------------------------------------


update_projectiles proc
    push cs
    pop ds
    
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

    mov word ptr proj_steps_y[si], 150

    mov bx, proj_speed_y[si]
    add proj_pos_y[si], bx

    mov bx, max_speed_y
    sub proj_pos_y[si], bx

skip_update_y:


    ; ---------------- brick collision, coordinate based ----------------

    ; skip brick collision if projectile is below brick area
    cmp proj_pos_y[si], 65
    jg skip_bricks_check
    
    ; skip brick collision if projectile did not actually move this frame
    mov bx, proj_lastpos_x[si]
    cmp proj_pos_x[si], bx
    jne do_collision_checks
    
    mov bx, proj_lastpos_y[si]
    cmp proj_pos_y[si], bx
    jne do_collision_checks
    
    jmp skip_bricks_check
    
    do_collision_checks:

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
                
        inc score
        call draw_score
        
        call handle_brick_powerup

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

        mov word ptr proj_pos_x[si], 318
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
        ;call flip_proj_y
        ;jmp skip_flip_y_max
        ; delete above
        
        mov al, color_black
        call draw_projectile

        mov word ptr proj_active[si], 0   
        
        call check_game_over

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
    cmp si, 50
    jl proj_updater_loop

    ret

update_projectiles endp


;-------------------------------------------------------------------


handle_brick_powerup proc
    ; SI = current projectile
    ; brick_ind = destroyed brick index

    push ax
    push bx
    push si

    mov si, brick_ind
    mov al, brick_type[si]

    cmp al, 1
    je orange_powerup_hit

    cmp al, 2
    je blue_powerup_hit

    jmp powerup_done


orange_powerup_hit:
    pop si
    call spawn_orange_split_balls
    push si
    jmp powerup_done


blue_powerup_hit:
    pop si
    call spawn_blue_paddle_balls
    push si
    jmp powerup_done


powerup_done:
    pop si
    pop bx
    pop ax
    ret

handle_brick_powerup endp


;-------------------------------------------------------------------


find_free_projectile proc
    ; output:
    ; projectile_found = 1 if found
    ; free_projectile_index = free SI offset

    mov projectile_found, 0

    push si

    mov si, 0

find_free_projectile_loop:

    cmp word ptr proj_active[si], 0
    je found_free_projectile

    add si, 2
    cmp si, 50
    jl find_free_projectile_loop

    pop si
    ret


found_free_projectile:

    mov free_projectile_index, si
    mov projectile_found, 1

    pop si
    ret

find_free_projectile endp


;-------------------------------------------------------------------


spawn_orange_split_balls proc
    ; SI = source projectile
    ; same Y speed as source
    ; one ball left, one ball right

    push ax
    push bx
    push dx
    push di

    ; save source index
    mov source_projectile_index, si


    ; ---------- first ball: left ----------

    call find_free_projectile
    cmp projectile_found, 1
    jne orange_done

    mov di, free_projectile_index
    mov si, source_projectile_index

    mov ax, proj_pos_x[si]
    sub ax, 3
    mov proj_pos_x[di], ax

    mov ax, proj_pos_y[si]
    mov proj_pos_y[di], ax

    mov ax, proj_speed_y[si]
    mov proj_speed_y[di], ax

    mov word ptr proj_speed_x[di], 1
    mov word ptr proj_steps_x[di], 0
    mov word ptr proj_steps_y[di], 0
    mov word ptr proj_active[di], 1


    ; ---------- second ball: right ----------

    call find_free_projectile
    cmp projectile_found, 1
    jne orange_done

    mov di, free_projectile_index
    mov si, source_projectile_index

    mov ax, proj_pos_x[si]
    add ax, 3
    mov proj_pos_x[di], ax

    mov ax, proj_pos_y[si]
    mov proj_pos_y[di], ax

    mov ax, proj_speed_y[si]
    mov proj_speed_y[di], ax

    mov word ptr proj_speed_x[di], 5
    mov word ptr proj_steps_x[di], 0
    mov word ptr proj_steps_y[di], 0
    mov word ptr proj_active[di], 1


orange_done:

    mov si, source_projectile_index

    pop di
    pop dx
    pop bx
    pop ax
    ret

spawn_orange_split_balls endp


;-------------------------------------------------------------------


spawn_blue_paddle_balls proc
    ; one ball left/up, one ball right/up

    push ax
    push bx
    push di
    push si


    ; ---------- left ball ----------

    call find_free_projectile
    cmp projectile_found, 1
    jne blue_done

    mov di, free_projectile_index

    mov ax, pos_x
    add ax, 5
    mov proj_pos_x[di], ax

    mov ax, pos_y
    sub ax, 3
    mov proj_pos_y[di], ax

    mov word ptr proj_speed_x[di], 1
    mov word ptr proj_speed_y[di], 1

    mov word ptr proj_steps_x[di], 0
    mov word ptr proj_steps_y[di], 0
    mov word ptr proj_active[di], 1


    ; ---------- right ball ----------

    call find_free_projectile
    cmp projectile_found, 1
    jne blue_done

    mov di, free_projectile_index

    mov ax, pos_x
    add ax, 8
    mov proj_pos_x[di], ax

    mov ax, pos_y
    sub ax, 3
    mov proj_pos_y[di], ax

    mov word ptr proj_speed_x[di], 5
    mov word ptr proj_speed_y[di], 1

    mov word ptr proj_steps_x[di], 0
    mov word ptr proj_steps_y[di], 0
    mov word ptr proj_active[di], 1


blue_done:

    pop si
    pop di
    pop bx
    pop ax
    ret

spawn_blue_paddle_balls endp


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

        
check_game_over proc
    push si

    ; only check game over after the game has started
    cmp game_started, 1
    jne not_game_over

    mov si, 0

check_alive_loop:

    cmp word ptr proj_active[si], 1
    je not_game_over

    add si, 2
    cmp si, 50
    jl check_alive_loop

    ; no active projectiles left
    mov game_over, 1
    mov game_started, 0

    call draw_game_over_text

not_game_over:

    pop si
    ret
check_game_over endp    


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

    mov bx, 4
    sub bx, proj_speed_y[si]
    mov proj_speed_y[si], bx

    pop bx
    ret

flip_proj_y endp


;------------------------------------------------------------------- 

 
draw_projectile proc
    ; input:
    ; SI = projectile index
    ; AL = color

    push ax
    push bx

    mov rect_color, al

    cmp al, color_black
    jne draw_projectile_current

        mov bx, proj_lastpos_x[si]
        mov rect_x, bx

        mov bx, proj_lastpos_y[si]
        mov rect_y, bx

        jmp draw_projectile_rect

draw_projectile_current:

    mov bx, proj_pos_x[si]
    mov rect_x, bx

    mov bx, proj_pos_y[si]
    mov rect_y, bx

draw_projectile_rect:

    mov bx, proj_size
    mov rect_w, bx

    mov bx, proj_size
    mov rect_h, bx

    call draw_rect_fast

    pop bx
    pop ax
    ret

draw_projectile endp                                                                    
                                                                    
                                                                    
;-------------------------------------------------------------------


key_listener proc 
    push cs
    pop ds
    
    cmp ai_input, 0
    je ai_input_skip 
        ; if game over, Space resets everything
        cmp game_over, 1
        jne ai_not_reset_key
        
        cmp ai_input, 3
        jne ai_input_skip
        
        call reset_game
        jmp ai_input_skip
        
        ai_not_reset_key:
    
        cmp game_started, 0
        jne ain3
        cmp ai_input, 3     ; space
        jne ain4
            mov ai_input, 0
            mov word ptr proj_active[0], 1
            mov word ptr proj_speed_y[0], 1
            mov word ptr proj_speed_x[0], 2
            
            ;mov word ptr proj_active[2], 1
            ;mov word ptr proj_speed_y[2], 1
            ;mov word ptr proj_speed_x[2], 2
            
            ;mov word ptr proj_active[4], 1
            ;mov word ptr proj_speed_y[4], 1
            ;mov word ptr proj_speed_x[4], 4
            
            ;mov word ptr proj_active[6], 1
            ;mov word ptr proj_speed_y[6], 1
            ;mov word ptr proj_speed_x[6], 5
            
            mov game_started, 1
            
        ain4:
        jmp ai_input_skip
        
        ain3:
        
        ; a, decrease y
        cmp ai_input, 1    
        jne ain1 
            mov ai_input, 0
            ; call the move_left function player_speed times
            ; save original bx on stack
            push bx
            mov bx, player_speed_x
            ai_speed_loop_left:
                ; save bx on stack                
                push bx
                call move_player_left
                ; get bx back, decrement, compare and jump back
                pop bx                    
                dec bx
                cmp bx, 0
            jg ai_speed_loop_left   
            ; retrieve the original bx
            pop bx
        ain1:
        
        ; d, increase y
        cmp ai_input, 2    
        jne ain2
            mov ai_input, 0
            ; call the move_right function player_speed times                
            ; save original bx on stack
            push bx
            mov bx, player_speed_x
            ai_speed_loop_right:
                ; save bx on stack
                push bx
                call move_player_right
                ; get bx back, decrement, compare and jump back     
                pop bx
                dec bx
                cmp bx, 0
            jg ai_speed_loop_right
            ; retrieve the original bx
            pop bx
        ain2:
    
    ai_input_skip:
    
    ; check if key exists
    mov ah, 01h
    int 16h     
    push cs
    pop ds
    jz key_listener_skip

    ; actually consume/read the key
    mov ah, 00h
    int 16h     

    ; restore DS AFTER BIOS call
    push cs
    pop ds  
    
    ; if game over, Space resets everything
    cmp game_over, 1
    jne not_reset_key
    
    cmp al, 32
    jne key_listener_skip
    
    call reset_game
    jmp key_listener_skip
    
    not_reset_key: 
          
    
    cmp game_started, 0
    jne n3 
    cmp al, 32
    jne n4
        mov word ptr proj_active[0], 1
        mov word ptr proj_speed_y[0], 1
        mov word ptr proj_speed_x[0], 2
        
        ;mov word ptr proj_active[2], 1
        ;mov word ptr proj_speed_y[2], 1
        ;mov word ptr proj_speed_x[2], 2
        
        ;mov word ptr proj_active[4], 1
        ;mov word ptr proj_speed_y[4], 1
        ;mov word ptr proj_speed_x[4], 4
        
        ;mov word ptr proj_active[6], 1
        ;mov word ptr proj_speed_y[6], 1
        ;mov word ptr proj_speed_x[6], 5
        
        mov game_started, 1
    
    n4:    
    jmp key_listener_skip
    
    n3:
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
    
    key_listener_skip:
    ret
    
    
key_listener endp

                                                                    
;-------------------------------VARS--------------------------------

;memory begin offset, for memory reading
memory_begin db 'BREAKOUT MEMORY START'


; player vars
pos_x           dw 100
pos_y           dw 170
size_x          dw 14
size_y          dw 3
player_speed_x  dw 5

; bricks vars
brick_width     dw 10 
brick_height    dw 4

brick_stride_x  dw 11
brick_stride_y  dw 5

brick_offset_x  dw 0
brick_offset_y  dw 0
bricks          db 348 dup (1)

brick_type db 348 dup(0)

brick_coords_x  dw 0
brick_coords_y  dw 0
brick_ind       dw 0
brick_ind_x     dw 0
brick_ind_y     dw 0
brick_found     dw 0     

; projectile vars
proj_pos_x      dw 106, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_pos_y      dw 167, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_speed_x    dw 25 dup(3)
proj_speed_y    dw 25 dup(2)
proj_steps_x    dw 25 dup(0)
proj_steps_y    dw 25 dup(0)
proj_active     dw 25 dup(0)

free_projectile_index dw 0
projectile_found dw 0
source_projectile_index dw 0

proj_lastpos_x  dw 106, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
proj_lastpos_y  dw 167, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

proj_size       dw 2
proj_top_left   db 0
proj_top_right  db 0
proj_bot_left   db 0
proj_bot_right  db 0
game_started    dw 0
max_speed_x     dw 3
max_speed_y     dw 2     


; colors
color_red       db 0ch
color_black     db 0h 
color_white     db 0fh 
color_yellow    db 0eh
color_green     db 0ah
color_d_red     db 04h

current_color   db 0ch    

rect_x     dw 0
rect_y     dw 0
rect_w     dw 0
rect_h     dw 0
rect_color db 0  

score           dw 0
game_over       dw 0

score_digits    db '0000'  

ai_input    db 0
