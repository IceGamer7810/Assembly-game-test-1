.eqv FB_BASE       0x10008000
.eqv KB_CTRL       0xFFFF0000
.eqv KB_DATA       0xFFFF0004
.eqv GRID_W        32
.eqv GRID_H        32
.eqv COLOR_A       0x00669999
.eqv COLOR_B       0x0099CC66
.eqv COLOR_PLAYER  0x00FF4444
.eqv COLOR_CROSS   0x00FFFFFF
.eqv JUMP_VEL      4
.eqv GRAVITY       1
.eqv FRAME_MS      33

.data
player_x:      .word 15
player_y:      .word 15
player_z:      .word 0
player_vz:     .word 0
crouch_mode:   .word 0

.text
.globl main

main:
game_loop:
    jal handle_input
    jal apply_physics
    jal draw_checkerboard
    jal draw_player
    jal draw_crosshair

    li $v0, 32
    li $a0, FRAME_MS
    syscall
    j game_loop

# Non-blocking keyboard input from MARS Keyboard and Display MMIO.
# Shift + WASD is handled via uppercase letters (W/A/S/D) => run speed 2.
handle_input:
    li $t0, KB_CTRL
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, hi_end

    li $t0, KB_DATA
    lw $t2, 0($t0)
    andi $t2, $t2, 0x00FF

    li $t3, 1

    # lowercase movement (speed = 1)
    li $t4, 'w'
    beq $t2, $t4, move_up
    li $t4, 'a'
    beq $t2, $t4, move_left
    li $t4, 's'
    beq $t2, $t4, move_down
    li $t4, 'd'
    beq $t2, $t4, move_right

    # uppercase movement (shift + key, speed = 2)
    li $t3, 2
    li $t4, 'W'
    beq $t2, $t4, move_up
    li $t4, 'A'
    beq $t2, $t4, move_left
    li $t4, 'S'
    beq $t2, $t4, move_down
    li $t4, 'D'
    beq $t2, $t4, move_right

    # Jump: space
    li $t4, 32
    beq $t2, $t4, do_jump

    # Crouch toggle: Ctrl may not be reported alone in MARS.
    # Supported keys: 'c' or 'C' (and Ctrl+Q code 17 as fallback).
    li $t4, 'c'
    beq $t2, $t4, toggle_crouch
    li $t4, 'C'
    beq $t2, $t4, toggle_crouch
    li $t4, 17
    beq $t2, $t4, toggle_crouch

    j hi_end

move_up:
    la $t5, player_y
    lw $t6, 0($t5)
    sub $t6, $t6, $t3
    bgez $t6, store_y
    li $t6, 0
store_y:
    sw $t6, 0($t5)
    j hi_end

move_down:
    la $t5, player_y
    lw $t6, 0($t5)
    add $t6, $t6, $t3
    li $t7, 30
    ble $t6, $t7, store_y2
    li $t6, 30
store_y2:
    sw $t6, 0($t5)
    j hi_end

move_left:
    la $t5, player_x
    lw $t6, 0($t5)
    sub $t6, $t6, $t3
    bgez $t6, store_x
    li $t6, 0
store_x:
    sw $t6, 0($t5)
    j hi_end

move_right:
    la $t5, player_x
    lw $t6, 0($t5)
    add $t6, $t6, $t3
    li $t7, 30
    ble $t6, $t7, store_x2
    li $t6, 30
store_x2:
    sw $t6, 0($t5)
    j hi_end

do_jump:
    la $t5, player_z
    lw $t6, 0($t5)
    bnez $t6, hi_end
    la $t5, player_vz
    li $t6, JUMP_VEL
    sw $t6, 0($t5)
    j hi_end

toggle_crouch:
    la $t5, crouch_mode
    lw $t6, 0($t5)
    xori $t6, $t6, 1
    sw $t6, 0($t5)

hi_end:
    jr $ra

apply_physics:
    la $t0, player_z
    lw $t1, 0($t0)
    la $t2, player_vz
    lw $t3, 0($t2)

    beqz $t1, maybe_ground
    j update_air

maybe_ground:
    beqz $t3, ap_end

update_air:
    add $t1, $t1, $t3
    li $t4, GRAVITY
    sub $t3, $t3, $t4

    bgez $t1, still_air
    li $t1, 0
    li $t3, 0

still_air:
    sw $t1, 0($t0)
    sw $t3, 0($t2)

ap_end:
    jr $ra

draw_checkerboard:
    li $t0, 0              # y
cb_y_loop:
    bge $t0, GRID_H, cb_done
    li $t1, 0              # x
cb_x_loop:
    bge $t1, GRID_W, cb_next_row

    add $t2, $t0, $t1
    andi $t2, $t2, 1
    beqz $t2, cb_color_a
    li $a2, COLOR_B
    j cb_draw
cb_color_a:
    li $a2, COLOR_A

cb_draw:
    move $a0, $t1
    move $a1, $t0
    jal draw_pixel

    addi $t1, $t1, 1
    j cb_x_loop

cb_next_row:
    addi $t0, $t0, 1
    j cb_y_loop

cb_done:
    jr $ra

draw_player:
    la $t0, player_x
    lw $t1, 0($t0)         # x
    la $t0, player_y
    lw $t2, 0($t0)         # y
    la $t0, player_z
    lw $t3, 0($t0)         # z
    sub $t4, $t2, $t3      # screen y with jump offset

    li $t5, 2              # width
    li $t6, 2              # height
    la $t0, crouch_mode
    lw $t7, 0($t0)
    beqz $t7, dp_dims_ok
    li $t6, 1
dp_dims_ok:
    li $t8, 0              # dy
dp_y_loop:
    bge $t8, $t6, dp_done
    li $t9, 0              # dx
dp_x_loop:
    bge $t9, $t5, dp_next_row

    add $a0, $t1, $t9
    add $a1, $t4, $t8
    li $a2, COLOR_PLAYER
    jal draw_pixel

    addi $t9, $t9, 1
    j dp_x_loop

dp_next_row:
    addi $t8, $t8, 1
    j dp_y_loop

dp_done:
    jr $ra

draw_crosshair:
    li $t0, 16             # center x
    li $t1, 16             # center y
    li $t2, COLOR_CROSS

    # center
    move $a0, $t0
    move $a1, $t1
    move $a2, $t2
    jal draw_pixel

    # left
    addi $a0, $t0, -1
    move $a1, $t1
    move $a2, $t2
    jal draw_pixel

    # right
    addi $a0, $t0, 1
    move $a1, $t1
    move $a2, $t2
    jal draw_pixel

    # up
    move $a0, $t0
    addi $a1, $t1, -1
    move $a2, $t2
    jal draw_pixel

    # down
    move $a0, $t0
    addi $a1, $t1, 1
    move $a2, $t2
    jal draw_pixel

    jr $ra

draw_pixel:
    bltz $a0, px_end
    bltz $a1, px_end
    li $t0, GRID_W
    bge $a0, $t0, px_end
    li $t0, GRID_H
    bge $a1, $t0, px_end

    li $t0, GRID_W
    mul $t1, $a1, $t0
    add $t1, $t1, $a0
    sll $t1, $t1, 2
    li $t0, FB_BASE
    add $t1, $t1, $t0
    sw $a2, 0($t1)

px_end:
    jr $ra
