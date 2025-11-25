################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Elvis Chen, 1011772422
# Student 2: Frank Fu, 1008841372
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

# Bitmap parameters
BITMAP_WIDTH:   .word 32
BITMAP_HEIGHT:  .word 32

# Grid parameters
GRID_COLS:     .word 6
GRID_ROWS:     .word 13
GRID_LEFT:     .word 10
GRID_TOP:      .word 5
# Colors
GEM_COLOURS:
    .word 0xff0000      # red
    .word 0xff8000      # orange
    .word 0xffff00      # yellow
    .word 0x00ff00      # green
    .word 0x0000ff      # blue
    .word 0x8000ff      # purple

game_over_msg: .asciiz "game over!\n"

# Color for background color
COLOR_BG:   .word 0x000000   # black for empty cells
COLOR_WALL: .word 0x404040   # dark gray for walls

# Direction vectors: (dx, dy) for 8 directions (up, up-right, right, down-right, down, down-left, left, up-left)
DIRECTION_VECTORS:
    .word  0, -1    # 0: up
    .word  1, -1    # 1: up-right
    .word  1,  0    # 2: right
    .word  1,  1    # 3: down-right
    .word  0,  1    # 4: down
    .word -1,  1    # 5: down-left
    .word -1,  0    # 6: left
    .word -1, -1    # 7: up-left


##############################################################################
# Mutable Data
##############################################################################
# Storage for the current column's three colours:
CUR_COL0: .word 0       # top gem colour
CUR_COL1: .word 0       # middle gem colour
CUR_COL2: .word 0       # bottom gem colour

CUR_COL_X:  .word 0 # grid column of the whole column
CUR_COL_Y:  .word 0 # grid row of the TOP 

Cur_Col_Is_Landing: .word 0 # 1=landing, 0=not landing

# Gravity access table - marks which columns need gravity handling
.align 2                    # Ensure word alignment
Gravity_Access_Table: .word 0:6  # GRID_COLS=6

#-----------------
# Stack Implementation for Chain Reaction System
# Two stacks: Chain_Reax_Stack_X and Chain_Reax_Stack_Y
# Must always push/pop both X and Y together
# Stack size: GRID_COLS * GRID_ROWS = 6 * 13 = 78
#----------------
Chain_Reax_Stack_X: .word -1:78    # Stack for X coordinates
Chain_Reax_Stack_Y: .word -1:78    # Stack for Y coordinates  
Chain_Reax_Stack_Ptr: .word 0      # Stack pointer (points to next free position)

##############################################################################
# Code
##############################################################################
    .text
    .globl main
    
start:
    j main
    nop # I just google it, I dont know how it works

############################################################
# Helper procedures
############################################################

##########################################
# draw_cell
# Draw a single bitmap cell at (row, col) with a given colour.
#   $a0 = row
#   $a1 = col
#   $a2 = colour
##########################################
draw_cell:
    lw   $t0, ADDR_DSPL      # $t0 = base 
    li   $t1, 32             # Display units per row

    # t2 = row * 32
    mul  $t2, $a0, $t1

    # t2 = row * 32 + col
    add  $t2, $t2, $a1

    # t2 = (row * 32 + col) * 4 (word index -> byte offset)
    sll  $t2, $t2, 2

    # t3 = address of this cell
    add  $t3, $t0, $t2

    # store the color
    sw   $a2, 0($t3)

    jr   $ra


##########################################
# check_cell_color
# Returns the color value at the specified grid position
#   $a0 = grid column (grid x position)
#   $a1 = grid row (grid y position)
#   returns $v0 = color value at that position (0 if out of bounds)
##########################################
check_cell_color:
    # Check if coordinates are within bounds
    blt $a0, $zero, out_of_bounds
    blt $a1, $zero, out_of_bounds
    lw   $t8, GRID_COLS
    bge  $a0, $t8, out_of_bounds
    lw   $t8, GRID_ROWS
    bge  $a1, $t8, out_of_bounds

    lw   $t0, ADDR_DSPL      # $t0 = base address of display
    lw   $t1, BITMAP_WIDTH   # Display units per row (FIXED: use lw not la!)
    
    # Convert grid coordinates to bitmap coordinates
    lw   $t2, GRID_TOP       # Get grid top offset
    lw   $t3, GRID_LEFT      # Get grid left offset
    
    # Calculate bitmap row: GRID_TOP + y
    add  $t4, $t2, $a1       # $t4 = bitmap row
    
    # Calculate bitmap column: GRID_LEFT + x  
    add  $t5, $t3, $a0       # $t5 = bitmap column
    
    # Calculate memory offset: (row * 32 + col) * 4
    mul  $t6, $t4, $t1       # row * BITMAP_WIDTH
    add  $t6, $t6, $t5       # row * BITMAP_WIDTH + col
    sll  $t6, $t6, 2         # (row * BITMAP_WIDTH + col) * 4 (byte offset)
    
    # Calculate final memory address
    add  $t7, $t0, $t6       # address = base + offset
    
    # Load and return the color value
    lw   $v0, 0($t7)         # $v0 = color at that position
    jr   $ra                 # Return

out_of_bounds:
    li   $v0, 0              # Return 0 (black/empty) for out of bounds
    jr   $ra
    

#-----------------------------------------------------------
# Function: is_gem_color
# Description: Checks if a color is one of the gem colors
# Input:  $a0 - color value to check (32-bit RGB value)
# Output: $v0 - 1 if color is a gem color, 0 otherwise
# Clobbers: $t0, $t1, $t2, $t3
#-----------------------------------------------------------
is_gem_color:
    
    la    $t0, GEM_COLOURS      # $t0 = pointer to gem colors array
    li    $t1, 0                # $t1 = loop counter
    li    $t2, 6                # $t2 = number of gem colors
    
check_loop:
    beq   $t1, $t2, color_not_found
    
    lw    $t3, 0($t0)           # $t3 = current gem color
    beq   $a0, $t3, color_found
    
    addiu $t0, $t0, 4
    addiu $t1, $t1, 1
    j     check_loop
    
color_found:
    li    $v0, 1
    jr    $ra
    
color_not_found:
    li    $v0, 0
    jr    $ra


##########################################
# draw_grid()
# Draws the grid (why am I writing this?)
##########################################
draw_grid:
    # Save caller stuff
    addi $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s0, 16($sp)    # r
    sw   $s1, 12($sp)    # c
    sw   $s2, 8($sp)     # GRID_ROWS
    sw   $s3, 4($sp)     # GRID_COLS
    sw   $s4, 0($sp)     # temp

    lw   $s2, GRID_ROWS
    lw   $s3, GRID_COLS

    li   $s0, 0          # r = 0

grid_row_loop:
    bge  $s0, $s2, grid_done   # if r >= GRID_ROWS, finish

    li   $s1, 0          # c = 0

grid_col_loop:
    bge  $s1, $s3, next_grid_row   # if c >= GRID_COLS, go to next row

    # Decide colour: walls vs interior
    # walls: c == 0 or c == GRID_COLS-1 or r == GRID_ROWS-1
    lw   $t0, COLOR_BG
    lw   $t1, COLOR_WALL

    # default color = background
    move $t2, $t0

    # if c == 0 or c == GRID_COLS-1 or r == GRID_ROWS-1 => wall colour
    beqz $s1, grid_use_wall     # c == 0 ?
    addi $t3, $s3, -1
    beq  $s1, $t3, grid_use_wall
    addi $t3, $s2, -1
    beq  $s0, $t3, grid_use_wall
    j    grid_have_color

grid_use_wall:
    move $t2, $t1               # t2 = wall color

grid_have_color:
    # Convert grid (r,c) to bitmap (row,col)
    lw   $t4, GRID_TOP
    lw   $t5, GRID_LEFT
    add  $a0, $t4, $s0          # bitmap_row = GRID_TOP + r
    add  $a1, $t5, $s1          # bitmap_col = GRID_LEFT + c
    move $a2, $t2               # colour

    jal  draw_cell

    addi $s1, $s1, 1
    j    grid_col_loop

next_grid_row:
    addi $s0, $s0, 1
    j    grid_row_loop

grid_done:
    lw   $s4, 0($sp)
    lw   $s3, 4($sp)
    lw   $s2, 8($sp)
    lw   $s1, 12($sp)
    lw   $s0, 16($sp)
    lw   $ra, 20($sp)
    addi $sp, $sp, 24
    jr   $ra

##########################################
# draw_walls()
# Draws only the walls of the grid without backgrounds
# Walls are: left column (c=0), right column (c=GRID_COLS-1), and bottom row (r=GRID_ROWS-1)
##########################################
draw_walls:
    # Save caller registers
    addi $sp, $sp, -32
    sw   $ra, 28($sp)
    sw   $s0, 24($sp)    # r (row)
    sw   $s1, 20($sp)    # c (column)
    sw   $s2, 16($sp)    # GRID_ROWS
    sw   $s3, 12($sp)    # GRID_COLS
    sw   $s4, 8($sp)     # Wall color
    sw   $s5, 4($sp)     # GRID_TOP
    sw   $s6, 0($sp)     # GRID_LEFT

    lw   $s2, GRID_ROWS
    lw   $s3, GRID_COLS
    lw   $s4, COLOR_WALL  # Wall color (saved register)
    lw   $s5, GRID_TOP    # GRID_TOP (saved register)
    lw   $s6, GRID_LEFT   # GRID_LEFT (saved register)

    # Draw left wall (c = 0, all rows)
    li   $s0, 0          # r = 0
draw_left_wall_loop:
    bge  $s0, $s2, draw_right_wall  # if r >= GRID_ROWS, done with left wall
    
    # Convert grid (r,0) to bitmap coordinates
    add  $a0, $s5, $s0          # bitmap_row = GRID_TOP + r
    move $a1, $s6               # bitmap_col = GRID_LEFT + 0
    move $a2, $s4               # wall colour
    
    jal  draw_cell

    addi $s0, $s0, 1
    j    draw_left_wall_loop

draw_right_wall:
    # Draw right wall (c = GRID_COLS-1, all rows)
    li   $s0, 0          # r = 0
    addi $s1, $s3, -1    # c = GRID_COLS - 1
draw_right_wall_loop:
    bge  $s0, $s2, draw_bottom_wall  # if r >= GRID_ROWS, done with right wall
    
    # Convert grid (r, GRID_COLS-1) to bitmap coordinates
    add  $a0, $s5, $s0          # bitmap_row = GRID_TOP + r
    add  $a1, $s6, $s1          # bitmap_col = GRID_LEFT + (GRID_COLS-1)
    move $a2, $s4               # wall colour
    
    jal  draw_cell

    addi $s0, $s0, 1
    j    draw_right_wall_loop

draw_bottom_wall:
    # Draw bottom wall (r = GRID_ROWS-1, all columns)
    addi $s0, $s2, -1    # r = GRID_ROWS - 1
    li   $s1, 0          # c = 0
draw_bottom_wall_loop:
    bge  $s1, $s3, walls_done  # if c >= GRID_COLS, done with bottom wall
    
    # Convert grid (GRID_ROWS-1, c) to bitmap coordinates
    add  $a0, $s5, $s0          # bitmap_row = GRID_TOP + (GRID_ROWS-1)
    add  $a1, $s6, $s1          # bitmap_col = GRID_LEFT + c
    move $a2, $s4               # wall colour
    
    jal  draw_cell

    addi $s1, $s1, 1
    j    draw_bottom_wall_loop

walls_done:
    # Restore registers and return
    lw   $s6, 0($sp)
    lw   $s5, 4($sp)
    lw   $s4, 8($sp)
    lw   $s3, 12($sp)
    lw   $s2, 16($sp)
    lw   $s1, 20($sp)
    lw   $s0, 24($sp)
    lw   $ra, 28($sp)
    addi $sp, $sp, 32
    jr   $ra

##########################################
# init_column()
# Sets the initial column position and random colours.
##########################################
init_column:
    addi $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s0, 8($sp)
    sw   $s1, 4($sp)
    sw   $s2, 0($sp)

    # Set starting position
    lw   $t0, GRID_COLS
    sra  $t0, $t0, 1          # middle_col = GRID_COLS / 2
    sw   $t0, CUR_COL_X

    li   $t1, 0               # top row
    sw   $t1, CUR_COL_Y

    ## la   $s0, GEM_COLOURS

    # Top gem
    jal  get_random_colour
    sw   $v0, CUR_COL0

    # Middle gem
    jal  get_random_colour
    sw   $v0, CUR_COL1

    # Bottom gem
    jal  get_random_colour
    sw   $v0, CUR_COL2

    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addi $sp, $sp, 16
    jr   $ra

##########################################
# create_new_column()
# Creates a new column with random colors at initial position
# Sets CUR_COL_X, CUR_COL_Y and three color variables
# Checks if initial position is occupied - if so, game over
##########################################
create_new_column:
    # Prologue - save return address
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)

    # Set starting position to middle column, top row
    lw   $s0, GRID_COLS
    sra  $s0, $s0, 1          # middle_col = GRID_COLS / 2
    sw   $s0, CUR_COL_X

    li   $s1, 0               # top row
    sw   $s1, CUR_COL_Y

    # Check if initial position is occupied by checking all three cells
    # Check top cell (middle, 0)
    move $a0, $s0
    move $a1, $s1
    jal  check_cell_color
    move $a0, $v0
    jal  is_gem_color
    beq  $v0, 1, game_over
    
    # Check middle cell (middle, 1)
    move $a0, $s0
    addi $a1, $s1, 1
    jal  check_cell_color
    move $a0, $v0
    jal  is_gem_color
    beq  $v0, 1, game_over
    
    # Check bottom cell (middle, 2)
    move $a0, $s0
    addi $a1, $s1, 2
    jal  check_cell_color
    move $a0, $v0
    jal  is_gem_color
    beq  $v0, 1, game_over
    
    # No collision - generate three random colors for the column
    jal  get_random_colour
    sw   $v0, CUR_COL0        # Top gem color

    jal  get_random_colour
    sw   $v0, CUR_COL1        # Middle gem color

    jal  get_random_colour
    sw   $v0, CUR_COL2        # Bottom gem color

    # Epilogue
    lw   $s1, 0($sp)
    lw   $s0, 4($sp)
    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##########################################
# game_over()
# Prints "game over" message and exits the program
##########################################
game_over:
    # Print "game over" message
    li   $v0, 4               # syscall 4 = print string
    la   $a0, game_over_msg
    syscall
    
    # Exit the program
    li   $v0, 10              # syscall 10 = exit
    syscall

##########################################
# get_random_colour()
# Returns a random color
# Uses syscall 42 with max = 6.
##########################################
get_random_colour:
    # generate random index in [0, 6)
    li   $v0, 42       # syscall 42 = random int [0, max)
    li   $a0, 0        # RNG ID
    li   $a1, 6        # max = 6
    syscall            # result index in $a0

    # compute address = GEM_COLOURS + index*4
    la   $t0, GEM_COLOURS
    sll  $t1, $a0, 2   # index * 4
    add  $t0, $t0, $t1
    lw   $v0, 0($t0)   # v0 = colour

    jr   $ra

##########################################
# draw_column()
# Draws the column
##########################################
draw_column:
    addi $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s0, 8($sp)
    sw   $s1, 4($sp)
    sw   $s2, 0($sp)

    lw   $s0, CUR_COL_X      # column x
    lw   $s1, CUR_COL_Y      # top gem y

    lw   $t4, GRID_TOP
    lw   $t5, GRID_LEFT

    # Top
    # grid_y = CUR_COL_Y + 0
    add  $t0, $s1, $zero
    add  $t1, $s0, $zero

    # bitmap row/col
    add  $a0, $t4, $t0      # row
    add  $a1, $t5, $t1      # col

    lw   $a2, CUR_COL0      # colour
    jal  draw_cell

    # Middle
    addi $t0, $s1, 1        # grid_y = CUR_COL_Y + 1
    add  $t1, $s0, $zero

    add  $a0, $t4, $t0      # row
    add  $a1, $t5, $t1      # col

    lw   $a2, CUR_COL1
    jal  draw_cell

    # Bottom
    addi $t0, $s1, 2        # grid_y = CUR_COL_Y + 2
    add  $t1, $s0, $zero

    add  $a0, $t4, $t0      # row
    add  $a1, $t5, $t1      # col

    lw   $a2, CUR_COL2
    jal  draw_cell

    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addi $sp, $sp, 16
    jr   $ra
    
##########################################
# init_game()
# TODO: I need to add more later
##########################################
init_game:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    jal  init_column    # position + random colours

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    
##########################################
# clear_screen()
# Clears the screen with kuro
##########################################
clear_screen:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    lw   $t0, ADDR_DSPL      # base
    li   $t1, 1024          # number of units
    li   $t2, 0x000000       # black

    li   $s0, 0              # i = 0

clear_loop:
    beq  $s0, $t1, clear_done

    # address = base + i*4
    sll  $t3, $s0, 2
    add  $t4, $t0, $t3
    sw   $t2, 0($t4)

    addi $s0, $s0, 1
    j    clear_loop

clear_done:
    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addi $sp, $sp, 8
    jr   $ra


##############################################################################
# draw_scene()
# Things that it does (Will add more later)
#   - clear screen
#   - draw grid
#   - draw first column
##############################################################################
draw_scene:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # jal clear_screen

    # jal draw_grid

    jal draw_walls


    jal draw_column

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


##########################################
# clear_current_column()
# Sets the color of the current column's three cells to background color
# Clobbers: $a0, $a1, $a2, $t0, $t1
##########################################
clear_current_column:
    # Prologue - save return address
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    # Load background color once
    lw   $a2, COLOR_BG        # Background color
    
    # Clear top cell (x, y)
    lw   $a0, CUR_COL_X
    lw   $a1, CUR_COL_Y
    jal  set_cell_color
    
    # Clear middle cell (x, y+1)
    lw   $a0, CUR_COL_X
    lw   $a1, CUR_COL_Y
    addi $a1, $a1, 1
    jal  set_cell_color
    
    # Clear bottom cell (x, y+2)
    lw   $a0, CUR_COL_X
    lw   $a1, CUR_COL_Y
    addi $a1, $a1, 2
    jal  set_cell_color
    
    # Epilogue
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra


##############################################################################
# check_landing()
# Check if the current column is landing on something. (the top of a colored cell or the bottom of the playing area.)
# Modifies: Cur_Col_Is_Landing in memory (1 if landing, 0 otherwise)
##############################################################################
check_landing:
    addi $sp, $sp, -4       # Store old $ra.
    sw   $ra, 0($sp)

    lw $t0, CUR_COL_Y       # $t0 = current column y position.
    addi $t0, $t0, 3        # $t0 = current column y position + 3.
    
    lw $t1, GRID_ROWS        # $t1 = grid rows.
    addi $t1, $t1, -1       # $t1 = bottom grid row index (12)

    beq $t0, $t1, landing   # hit bottom, landing

    #Else, check whether $t0 is a colored cell

    addi $sp, $sp, -8       # Store old $a0 and $a1.
    sw   $a1, 4($sp)
    sw   $a0, 0($sp)
        
    lw $a0, CUR_COL_X       # $a0 = current column x position.
    move $a1, $t0           # $a1 = position BELOW bottom gem (CUR_COL_Y + 3)

    jal check_cell_color
    move $a0, $v0           # $a0 = returned color of check_cell_color().

    jal is_gem_color

    # Restore $a0-$a1
    lw   $a0, 0($sp)
    lw   $a1, 4($sp)
    addi $sp, $sp, 8
    
    beq  $v0, 1, landing
    j not_landing

landing:
    li $t2, 1    
    sw $t2, Cur_Col_Is_Landing  # Cur_Col_Is_Landing = 1
    j fin_check_landing

not_landing:
    li $t2, 0
    sw $t2, Cur_Col_Is_Landing  # Cur_Col_Is_Landing = 0

fin_check_landing:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


##############################################################################
# handle_landing()
# If Cur_Col_Is_Landing is 1:
#   0. Add the x and y of all 3 column cells to Chain_Reax_Stack.
#   1. Call helper check_handle_matching to check if there is any matching and handle the chain reaction.
#   2. Create a new Column
# Modifies: Chain_Reax_Stack
##############################################################################
handle_landing:
    # Prologue - save return address and saved registers
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)        # Save x coordinate
    sw   $s1, 0($sp)        # Save y coordinate

    # Check if current column is landing
    lw   $t0, Cur_Col_Is_Landing
    beq  $t0, $zero, fin_handle_landing  # If not landing, skip processing

    # Step 0: Add all 3 column cells to Chain_Reax_Stack
    lw   $s0, CUR_COL_X       # $s0 = current column x position
    lw   $s1, CUR_COL_Y       # $s1 = current column y position (top gem)

    # Push top gem (x, y)
    move $a0, $s0
    move $a1, $s1
    jal  push_chain_stack

    # Push middle gem (x, y+1)
    move $a0, $s0
    addi $a1, $s1, 1
    jal  push_chain_stack

    # Push bottom gem (x, y+2)  
    move $a0, $s0
    addi $a1, $s1, 2
    jal  push_chain_stack

    # Step 1: Check for matches and handle chain reaction
    jal  check_handle_matching

    # Step 2: Create a new column
    jal  create_new_column

    # Reset landing flag for next time
    sw   $zero, Cur_Col_Is_Landing

fin_handle_landing:
    # Epilogue - restore registers and return address
    lw   $s1, 0($sp)
    lw   $s0, 4($sp)
    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra


##############################################################################
# check_handle_matching()
# Check all cells in Chain_Reax_Stack whether has a matching (consecutive 3 
# cells with same color in one direction) and handle the chain reaction.
# Algorithm:
# While Chain_Reax_Stack is not empty:
#   0. Pop the top cell. If this cell is gem color, goto 1, otherwise goto start
#   1. Check 8 directions for matches
#   2. For each direction with match, remove the run and mark columns
#   3. Handle gravity for marked columns
##############################################################################
check_handle_matching:
    # Prologue - save return address and saved registers
    addi $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s0, 16($sp)        # Current x coordinate
    sw   $s1, 12($sp)        # Current y coordinate  
    sw   $s2, 8($sp)         # Base color for matching
    sw   $s3, 4($sp)         # Direction counter
    sw   $s4, 0($sp)         # Temporary for column index

main_chain_loop:
    # Check if chain stack is empty
    jal  is_chain_stack_empty
    beq  $v0, 1, chain_reaction_done  # If empty, we're done

    # Step 0: Pop the top cell from chain stack
    jal  pop_chain_stack
    move $s0, $v0           # $s0 = x coordinate
    move $s1, $v1           # $s1 = y coordinate

    # Check if popped cell is still a gem color
    move $a0, $s0
    move $a1, $s1
    jal  check_cell_color
    move $a0, $v0
    jal  is_gem_color
    
    # If not gem color, skip to next cell in stack
    beq  $v0, 0, main_chain_loop

    # Store base color for matching
    move $a0, $s0
    move $a1, $s1
    jal  check_cell_color
    move $s2, $v0           # $s2 = base color for matching

    # Step 1: Check all 8 directions for matches
    li   $s3, 0             # $s3 = direction counter (0-7)

direction_loop:
    # Check if we've checked all 8 directions
    beq  $s3, 8, directions_done

    # Check current direction for a match of 3 consecutive gems
    move $a0, $s0           # x coordinate
    move $a1, $s1           # y coordinate  
    move $a2, $s2           # base color
    move $a3, $s3           # direction
    jal  check_direction_match
    
    # If no match in this direction, try next direction
    beq  $v0, 0, next_direction

    # Step 1b: Match found - remove the run in this direction
    move $a0, $s0           # x coordinate
    move $a1, $s1           # y coordinate
    move $a2, $s2           # base color
    move $a3, $s3           # direction
    jal  remove_direction_run

next_direction:
    addi $s3, $s3, 1        # Move to next direction
    j    direction_loop

directions_done:
    # Step 1c: Handle gravity for all marked columns
    li   $s4, 0             # $s4 = column index

gravity_table_loop:
    # Check if we've processed all columns
    lw   $t0, GRID_COLS
    beq  $s4, $t0, main_chain_loop

    # Check if this column is marked in Gravity_Access_Table
    la   $t1, Gravity_Access_Table
    
    # Verify column index is within bounds
    blt  $s4, $zero, next_gravity_column    # Skip if negative
    bge  $s4, $t0, next_gravity_column      # Skip if >= GRID_COLS
    
    sll  $t2, $s4, 2        # Multiply by 4 (word size)
    add  $t1, $t1, $t2      # $t1 = address in table
    
    # Verify address is word-aligned (multiple of 4)
    andi $t3, $t1, 0x3      # Check if address is word-aligned
    bne  $t3, $zero, next_gravity_column  # Skip if not aligned
    
    lw   $t3, 0($t1)        # $t3 = table value
    
    # If column not marked, skip
    beq  $t3, 0, next_gravity_column

    # Step 1c: Call handle_gravity for this column
    move $a0, $s4           # column index
    jal  handle_gravity

    # Reset the table entry to 0 - with address validation
    andi $t4, $t1, 0x3      # Check alignment again
    beq  $t4, $zero, store_ok  # Only store if aligned
    j    next_gravity_column   # Skip store if not aligned

store_ok:
    sw   $zero, 0($t1)

next_gravity_column:
    addi $s4, $s4, 1        # Move to next column
    j    gravity_table_loop

chain_reaction_done:
    # Epilogue - restore registers and return
    lw   $s4, 0($sp)
    lw   $s3, 4($sp)
    lw   $s2, 8($sp)
    lw   $s1, 12($sp)
    lw   $s0, 16($sp)
    lw   $ra, 20($sp)
    addi $sp, $sp, 24
    jr   $ra

##############################################################################
# check_direction_match(x, y, base_color, direction)
# Check if there are 3 consecutive gems in the given direction
# Now checks: forward (current, +1, +2) AND reverse (-1, current, +1) patterns
# Input: $a0 = x, $a1 = y, $a2 = base_color, $a3 = direction (0-7)
# Output: $v0 = 1 if match found, 0 otherwise
##############################################################################
check_direction_match:
    # Prologue
    addi $sp, $sp, -28
    sw   $ra, 24($sp)
    sw   $s0, 20($sp)        # x coordinate
    sw   $s1, 16($sp)        # y coordinate
    sw   $s2, 12($sp)        # base color
    sw   $s3, 8($sp)         # direction
    sw   $s4, 4($sp)         # dx (direction vector x)
    sw   $s5, 0($sp)         # dy (direction vector y)

    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3

    # Get direction vector
    move $a0, $s3
    jal  get_direction_vector
    move $s4, $v0           # $s4 = dx (saved register)
    move $s5, $v1           # $s5 = dy (saved register)

    # Check Pattern 1: Forward direction (current, +1, +2)
    # Check first cell in direction
    add  $a0, $s0, $s4      # x + dx
    add  $a1, $s1, $s5      # y + dy
    jal  check_cell_color
    bne  $v0, $s2, check_reverse_pattern  # Color doesn't match, try reverse pattern

    # Check second cell in direction  
    add  $a0, $s0, $s4      # x + dx
    add  $a1, $s1, $s5      # y + dy
    add  $a0, $a0, $s4      # x + 2*dx
    add  $a1, $a1, $s5      # y + 2*dy
    jal  check_cell_color
    beq  $v0, $s2, match_found  # Pattern 1 found!

check_reverse_pattern:
    # Check Pattern 2: Reverse direction (-1, current, +1) - current cell in middle
    # Check reverse cell (-dx, -dy)
    sub  $a0, $s0, $s4      # x - dx
    sub  $a1, $s1, $s5      # y - dy
    
    # Check if reverse cell is within grid bounds
    blt  $a0, $zero, no_match
    blt  $a1, $zero, no_match
    lw   $t0, GRID_COLS
    bge  $a0, $t0, no_match
    lw   $t0, GRID_ROWS
    bge  $a1, $t0, no_match
    
    jal  check_cell_color
    bne  $v0, $s2, no_match  # Reverse cell doesn't match

    # Check forward cell again (+dx, +dy) - we know current cell matches (base_color)
    add  $a0, $s0, $s4      # x + dx
    add  $a1, $s1, $s5      # y + dy
    
    # Check if forward cell is within grid bounds
    blt  $a0, $zero, no_match
    blt  $a1, $zero, no_match
    lw   $t0, GRID_COLS
    bge  $a0, $t0, no_match
    lw   $t0, GRID_ROWS
    bge  $a1, $t0, no_match
    
    jal  check_cell_color
    bne  $v0, $s2, no_match  # Forward cell doesn't match

    # Pattern 2 found! (reverse, current, forward)
    j    match_found

no_match:
    li   $v0, 0
    j    check_direction_done

match_found:
    li   $v0, 1

check_direction_done:
    # Epilogue
    lw   $s5, 0($sp)
    lw   $s4, 4($sp)
    lw   $s3, 8($sp)
    lw   $s2, 12($sp)
    lw   $s1, 16($sp)
    lw   $s0, 20($sp)
    lw   $ra, 24($sp)
    addi $sp, $sp, 28
    jr   $ra

##############################################################################
# remove_direction_run(x, y, base_color, direction)
# Remove all consecutive gems in the given direction and mark columns
# Input: $a0 = x, $a1 = y, $a2 = base_color, $a3 = direction
##############################################################################
remove_direction_run:
    # Prologue
    addi $sp, $sp, -28
    sw   $ra, 24($sp)
    sw   $s0, 20($sp)        # x coordinate
    sw   $s1, 16($sp)        # y coordinate
    sw   $s2, 12($sp)        # base color
    sw   $s3, 8($sp)         # direction
    sw   $s4, 4($sp)         # dx
    sw   $s5, 0($sp)         # dy

    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3

    # Get direction vector
    move $a0, $s3
    jal  get_direction_vector
    move $s4, $v0           # $s4 = dx
    move $s5, $v1           # $s5 = dy

    # Remove in positive direction (from starting cell outward)
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    move $a3, $s3
    li   $t0, 1             # positive direction
    jal  remove_direction

    # Remove in reverse direction (opposite of given direction)
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    move $a3, $s3
    li   $t0, -1            # reverse direction
    jal  remove_direction

    lw   $s5, 0($sp)
    lw   $s4, 4($sp)
    lw   $s3, 8($sp)
    lw   $s2, 12($sp)
    lw   $s1, 16($sp)
    lw   $s0, 20($sp)
    lw   $ra, 24($sp)
    addi $sp, $sp, 28
    jr   $ra

##############################################################################
# remove_direction(x, y, base_color, direction, sign)
# Remove gems in one direction (positive or negative)
# Input: $a0 = x, $a1 = y, $a2 = base_color, $a3 = direction, $t0 = sign (1 or -1)
##############################################################################
remove_direction:
    # Prologue
    addi $sp, $sp, -32
    sw   $ra, 28($sp)
    sw   $s0, 24($sp)        # current x
    sw   $s1, 20($sp)        # current y
    sw   $s2, 16($sp)        # base color
    sw   $s3, 12($sp)        # step multiplier
    sw   $s4, 8($sp)         # dx
    sw   $s5, 4($sp)         # dy
    sw   $s6, 0($sp)         # temporary for calculations

    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $t0            # step multiplier

    # Get direction vector
    move $a0, $a3
    jal  get_direction_vector
    move $s4, $v0           # $s4 = dx (saved register)
    move $s5, $v1           # $s5 = dy (saved register)

    # Apply sign to direction vector
    mul  $s4, $s4, $s3      # dx * sign
    mul  $s5, $s5, $s3      # dy * sign

    # If reverse direction, start from one step away to avoid removing center twice
    beq  $s3, 1, remove_loop
    add  $s0, $s0, $s4      # x + dx (skip center for reverse)
    add  $s1, $s1, $s5      # y + dy (skip center for reverse)

remove_loop:
    # Check if current cell has the base color
    move $a0, $s0
    move $a1, $s1
    jal  check_cell_color
    bne  $v0, $s2, remove_done  # Different color, stop removing

    # Remove this gem (set to background color)
    move $a0, $s0
    move $a1, $s1
    li   $a2, 0x000000      # Background color (black)
    jal  set_cell_color

    # Mark this column in Gravity_Access_Table
    la   $s6, Gravity_Access_Table
    sll  $t0, $s0, 2        # Multiply by 4 (word size) - $t0 is safe here
    add  $s6, $s6, $t0      # $s6 = table address
    li   $t0, 1
    sw   $t0, 0($s6)        # Mark column for gravity handling

    # Move to next cell in direction
    add  $s0, $s0, $s4
    add  $s1, $s1, $s5

    # Check if we're still within grid bounds
    blt  $s0, 0, remove_done
    blt  $s1, 0, remove_done
    lw   $t0, GRID_COLS     # $t0 is safe - used immediately
    bge  $s0, $t0, remove_done
    lw   $t0, GRID_ROWS     # $t0 is safe - used immediately
    bge  $s1, $t0, remove_done

    j    remove_loop

remove_done:
    # Epilogue
    lw   $s6, 0($sp)
    lw   $s5, 4($sp)
    lw   $s4, 8($sp)
    lw   $s3, 12($sp)
    lw   $s2, 16($sp)
    lw   $s1, 20($sp)
    lw   $s0, 24($sp)
    lw   $ra, 28($sp)
    addi $sp, $sp, 32
    jr   $ra

##############################################################################
# get_direction_vector(direction)
# Returns the dx, dy for the given direction (0-7)
# Input: $a0 = direction (0-7)
# Output: $v0 = dx, $v1 = dy
##############################################################################
get_direction_vector:
    # Direction vectors for 8 directions (clockwise from up)
    la   $t0, DIRECTION_VECTORS
    sll  $t1, $a0, 3        # Multiply by 8 (2 words per direction)
    add  $t0, $t0, $t1
    lw   $v0, 0($t0)        # dx
    lw   $v1, 4($t0)        # dy
    jr   $ra

##############################################################################
# handle_gravity()
# Given a grid x position, handle any gravity changes at that x position.
# Params: $a0 = grid x position
# Algorithm:
# 1. Start at y = GRID_ROWS - 2 (second to bottom row)
# 2. While current y >= 0:
#    a. Check if current cell is gem color
#    b. If not gem, search upward for first gem and swap it down
#    c. Push the landing position to chain reaction stack
#    d. Move to next cell upward
##############################################################################
handle_gravity:
    # Prologue - save return address and saved registers
    addi $sp, $sp, -20
    sw   $ra, 16($sp)
    sw   $s0, 12($sp)        # Save x position
    sw   $s1, 8($sp)         # Save current y position  
    sw   $s2, 4($sp)         # Save search y position
    sw   $s3, 0($sp)         # Temporary for color values

    move $s0, $a0            # $s0 = grid x position (parameter)

    # Step 1: Start at y = GRID_ROWS - 2
    lw   $s1, GRID_ROWS      # $s1 = grid rows
    addi $s1, $s1, -2        # $s1 = GRID_ROWS - 2 (starting y position)

gravity_loop:
    # Step 3: While current y >= 0
    blt  $s1, 0, gravity_done  # If y < 0, we're done

    # Step 3a: Check if current cell (x, y) is gem color
    move $a0, $s0            # x position
    move $a1, $s1            # y position
    jal  check_cell_color    # $v0 = color at (x, y)
    
    move $a0, $v0            # Prepare color for is_gem_color
    jal  is_gem_color        # $v0 = 1 if gem color, 0 otherwise
    
    # If current cell is gem color, move to next cell upward
    beq  $v0, 1, next_cell_up
    
    # Step a1: Current cell is NOT gem color - search upward for first gem
    move $s2, $s1            # $s2 = search y position (start at current y)
    
search_up_loop:
    # Move search position upward
    addi $s2, $s2, -1        # search_y = search_y - 1
    
    # Check if we've reached the top (y < 0)
    blt  $s2, 0, next_cell_up  # No gem found above, move to next cell
    
    # Check if cell at search_y is gem color
    move $a0, $s0            # x position
    move $a1, $s2            # search y position  
    jal  check_cell_color    # $v0 = color at (x, search_y)
    
    move $a0, $v0            # Prepare color for is_gem_color
    jal  is_gem_color        # $v0 = 1 if gem color, 0 otherwise
    
    # If not gem color, continue searching upward
    bne  $v0, 1, search_up_loop
    
    # Found a gem at (x, search_y) - swap it with current cell (x, y)
    # First get both colors
    move $a0, $s0            # x position
    move $a1, $s2            # search y position (gem location)
    jal  check_cell_color    # $v0 = gem color
    move $s3, $v0            # $s3 = gem color (save for swapping)
    
    move $a0, $s0            # x position  
    move $a1, $s1            # current y position (empty location)
    jal  check_cell_color    # $v0 = empty color
    # $v0 has empty color, $s3 has gem color
    
    # Now swap: put gem color at current y, empty color at search y
    
    # Set gem color at current position (x, y) - where gem lands
    move $a0, $s0            # x position
    move $a1, $s1            # y position
    move $a2, $s3            # gem color
    jal  set_cell_color
    
    # Set empty color at search position (x, search_y) - where gem came from
    move $a0, $s0            # x position
    move $a1, $s2            # search y position  
    move $a2, $v0            # empty color (from earlier check_cell_color)
    jal  set_cell_color
    
    # NEW FEATURE: Push the landing position to chain reaction stack
    # This marks the cell where a gem just landed for potential chain reactions
    move $a0, $s0            # x coordinate of landing position
    move $a1, $s1            # y coordinate of landing position
    jal  push_chain_stack    # Add to chain reaction tracking
    
    # After swap and stack push, continue with next cell
    j    next_cell_up

next_cell_up:
    # Step b: Move to cell upward (y = y - 1)
    addi $s1, $s1, -1        # current y = current y - 1
    j    gravity_loop

gravity_done:
    # Epilogue - restore registers and return
    lw   $s3, 0($sp)
    lw   $s2, 4($sp)
    lw   $s1, 8($sp)
    lw   $s0, 12($sp)
    lw   $ra, 16($sp)
    addi $sp, $sp, 20
    jr   $ra

##############################################################################
# set_cell_color
# Sets the color value at the specified grid position
#   $a0 = grid column (grid x position)
#   $a1 = grid row (grid y position) 
#   $a2 = color value to set
##############################################################################
set_cell_color:
    # Add bounds checking first
    blt $a0, $zero, set_cell_done
    blt $a1, $zero, set_cell_done
    lw   $t8, GRID_COLS
    bge  $a0, $t8, set_cell_done
    lw   $t8, GRID_ROWS
    bge  $a1, $t8, set_cell_done

    lw   $t0, ADDR_DSPL      # $t0 = base address of display
    lw   $t1, BITMAP_WIDTH   # FIXED: Use lw not la! Display units per row
    
    # Convert grid coordinates to bitmap coordinates
    lw   $t2, GRID_TOP       # Get grid top offset
    lw   $t3, GRID_LEFT      # Get grid left offset
    
    # Calculate bitmap row: GRID_TOP + y
    add  $t4, $t2, $a1       # $t4 = bitmap row
    
    # Calculate bitmap column: GRID_LEFT + x  
    add  $t5, $t3, $a0       # $t5 = bitmap column
    
    # Calculate memory offset: (row * BITMAP_WIDTH + col) * 4
    mul  $t6, $t4, $t1       # row * BITMAP_WIDTH
    add  $t6, $t6, $t5       # row * BITMAP_WIDTH + col
    sll  $t6, $t6, 2         # (row * BITMAP_WIDTH + col) * 4 (byte offset)
    
    # Calculate final memory address
    add  $t7, $t0, $t6       # address = base + offset
    
    # Store the color value
    sw   $a2, 0($t7)         # Set color at that position
    
set_cell_done:
    jr   $ra                 # Return


##############################################################################
# push_chain_stack
# Push x and y coordinates onto the chain reaction stacks
# Input: $a0 = x coordinate, $a1 = y coordinate
# Clobbers: $t0, $t1, $t2
##############################################################################
push_chain_stack:
    la   $t0, Chain_Reax_Stack_Ptr
    lw   $t1, 0($t0)               # $t1 = current stack pointer
    
    # Check if stack is full (pointer >= 78)
    li   $t2, 78
    bge  $t1, $t2, push_stack_full
    
    # Calculate address for X stack
    la   $t2, Chain_Reax_Stack_X
    sll  $t3, $t1, 2               # Multiply by 4 (word size)
    add  $t2, $t2, $t3             # $t2 = address in X stack
    
    # Store X coordinate
    sw   $a0, 0($t2)
    
    # Calculate address for Y stack  
    la   $t2, Chain_Reax_Stack_Y
    add  $t2, $t2, $t3             # $t2 = address in Y stack
    
    # Store Y coordinate
    sw   $a1, 0($t2)
    
    # Increment stack pointer
    addi $t1, $t1, 1
    sw   $t1, 0($t0)               # Update stack pointer
    
push_stack_full:
    jr   $ra

##############################################################################
# pop_chain_stack
# Pop x and y coordinates from the chain reaction stacks
# Output: $v0 = x coordinate, $v1 = y coordinate
#         If stack empty, returns (-1, -1)
# Clobbers: $t0, $t1, $t2
##############################################################################
pop_chain_stack:
    la   $t0, Chain_Reax_Stack_Ptr
    lw   $t1, 0($t0)               # $t1 = current stack pointer
    
    # Check if stack is empty
    blez $t1, pop_stack_empty
    
    # Decrement stack pointer first
    addi $t1, $t1, -1
    sw   $t1, 0($t0)               # Update stack pointer
    
    # Calculate address for X stack
    la   $t0, Chain_Reax_Stack_X
    sll  $t2, $t1, 2               # Multiply by 4 (word size)
    add  $t0, $t0, $t2             # $t0 = address in X stack
    
    # Load X coordinate
    lw   $v0, 0($t0)
    
    # Calculate address for Y stack
    la   $t0, Chain_Reax_Stack_Y
    add  $t0, $t0, $t2             # $t0 = address in Y stack
    
    # Load Y coordinate
    lw   $v1, 0($t0)
    
    jr   $ra

pop_stack_empty:
    # Return (-1, -1) for empty stack
    li   $v0, -1
    li   $v1, -1
    jr   $ra

##############################################################################
# is_chain_stack_empty
# Check if the chain reaction stack is empty
# Output: $v0 = 1 if empty, 0 if not empty
# Clobbers: $t0
##############################################################################
is_chain_stack_empty:
    la   $t0, Chain_Reax_Stack_Ptr
    lw   $t1, 0($t0)               # $t1 = current stack pointer
    
    # Check if pointer == 0 (empty)
    seq  $v0, $t1, $zero           # $v0 = 1 if pointer == 0, else 0
    
    jr   $ra

##############################################################################
# clear_chain_stack
# Clear the chain reaction stack (reset pointer to 0)
# Clobbers: $t0
##############################################################################
clear_chain_stack:
    la   $t0, Chain_Reax_Stack_Ptr
    sw   $zero, 0($t0)             # Reset stack pointer to 0
    jr   $ra

############################################################
# Main program
############################################################
main:
    jal init_game
    
    # Game on!
    j game_loop


############################################################
# game_loop:
#   - Poll keyboard
#   - Update column state
#   - Redraw scene
#   - Sleep a little
############################################################
game_loop:
    # 0. Check if current column is landing on something
    jal check_landing

    # 1. Handle landing if Cur_Col_Is_Landing is 1
    jal handle_landing

    # 2. Handle keyboard input (may change CUR_COL_X/Y or colours)
    jal handle_input

    # 3. Redraw everything based on updated state
    jal draw_scene

    # 4. Sleep for a short time (60 fps)
    li  $v0, 32
    li  $a0, 16
    syscall

    # 5. Repeat
    j   game_loop
    
    
##########################################
# handle_input
#   - Checks if a key was pressed
#   - If so, acts on: a, d, w, s, q
#       a: move column left (with collision detection)
#       d: move column right (with collision detection)
#       s: move column down one row
#       w: shuffle colours
#       q: quit game
##########################################
handle_input:
    # Prologue
    addi $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s0, 8($sp)
    sw   $s1, 4($sp)
    sw   $s2, 0($sp)
    
    # Load keyboard base addr
    lw   $t0, ADDR_KBRD
    
    # Check "key ready"
    lw   $t1, 0($t0)
    beq  $t1, $zero, hi_done

    # A key was pressed
    lw   $t2, 4($t0)
    
    #'a'
    li   $t3, 'a'
    beq  $t2, $t3, hi_left

    # 'd'
    li   $t3, 'd'
    beq  $t2, $t3, hi_right

    # 'w'
    li   $t3, 'w'
    beq  $t2, $t3, hi_shuffle

    #'s'
    li   $t3, 's'
    beq  $t2, $t3, hi_down

    # 'q'
    li   $t3, 'q'
    beq  $t2, $t3, hi_quit

    # ignore
    j    hi_done
    
hi_left:
    # Check if we can move left (target x = CUR_COL_X - 1)
    lw   $s0, CUR_COL_X      # Current x position
    lw   $s1, CUR_COL_Y      # Current y position
    
    # Check bounds first
    li   $t4, 1
    ble  $s0, $t4, hi_done   # Can't move left if x <= 1 (since 0 is wall)
    
    # Check collision for all three cells at new position (x-1)
    addi $a0, $s0, -1        # Target x = x - 1
    move $a1, $s1            # Current y (top gem)
    jal  check_column_collision
    
    # If collision detected (v0 == 1), can't move
    beq  $v0, 1, hi_done
    
    # No collision - clear current column and move
    jal  clear_current_column
    
    addi $s0, $s0, -1
    sw   $s0, CUR_COL_X
    j    hi_done
    
hi_right:
    # Check if we can move right (target x = CUR_COL_X + 1)
    lw   $s0, CUR_COL_X      # Current x position
    lw   $s1, CUR_COL_Y      # Current y position
    lw   $t5, GRID_COLS
    
    # Check bounds first
    addi $t5, $t5, -2        # Right wall is at GRID_COLS-1
    bge  $s0, $t5, hi_done   # Can't move right if x >= GRID_COLS-2
    
    # Check collision for all three cells at new position (x+1)
    addi $a0, $s0, 1         # Target x = x + 1
    move $a1, $s1            # Current y (top gem)
    jal  check_column_collision
    
    # If collision detected (v0 == 1), can't move
    beq  $v0, 1, hi_done
    
    # No collision - clear current column and move
    jal  clear_current_column
    
    addi $s0, $s0, 1
    sw   $s0, CUR_COL_X
    j    hi_done
    
hi_down:
    # Clear current column before moving
    jal  clear_current_column
    
    lw   $t0, CUR_COL_Y
    addi $t1, $t0, 1 
    addi $t2, $t1, 2
    lw   $t3, GRID_ROWS
    addi $t3, $t3, -1

    bge  $t2, $t3, hi_done
    sw   $t1, CUR_COL_Y
    j    hi_done

hi_shuffle:
    # Clear current column before shuffling colors
    jal  clear_current_column
    
    lw   $t0, CUR_COL0
    lw   $t1, CUR_COL1
    lw   $t2, CUR_COL2
    sw   $t2, CUR_COL0
    sw   $t0, CUR_COL1
    sw   $t1, CUR_COL2

    j    hi_done
    
hi_quit:
    li  $v0, 10
    syscall
    
hi_done:
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra, 12($sp)
    addi $sp, $sp, 16
    jr   $ra

##########################################
# check_column_collision(x, y)
# Checks if any of the three cells in a column position is occupied by a gem
# Input: $a0 = target x position, $a1 = top y position
# Output: $v0 = 1 if collision (gem found), 0 if clear
# Clobbers: $a0, $a1, $t0
##########################################
check_column_collision:
    # Prologue - save return address and incoming y
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $s0, 4($sp)
    sw   $s1, 0($sp)

    move $s0, $a0            # Save target x position
    move $s1, $a1            # Save top y position passed in

    # Check top cell (x, y)
    move $a0, $s0
    move $a1, $s1
    jal  check_cell_color
    move $a0, $v0
    jal  is_gem_color
    beq  $v0, 1, collision_found

    # Check middle cell (x, y+1)
    move $a0, $s0
    addi $a1, $s1, 1
    jal  check_cell_color
    move $a0, $v0
    jal  is_gem_color
    beq  $v0, 1, collision_found

    # Check bottom cell (x, y+2)
    move $a0, $s0
    addi $a1, $s1, 2
    jal  check_cell_color
    move $a0, $v0
    jal  is_gem_color
    beq  $v0, 1, collision_found

    # No collision found
    li   $v0, 0
    j    collision_done

collision_found:
    li   $v0, 1

collision_done:
    # Epilogue
    lw   $s1, 0($sp)
    lw   $s0, 4($sp)
    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra
