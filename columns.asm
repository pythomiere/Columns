################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Elvis Chen, 1011772422
# Student 2: Frank Fu, Student Number (if applicable)
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

# Storage for the current column's three colours:
CUR_COL0: .word 0       # top gem colour
CUR_COL1: .word 0       # middle gem colour
CUR_COL2: .word 0       # bottom gem colour

# Color for background color
COLOR_BG:   .word 0x000000   # black for empty cells
COLOR_WALL: .word 0x404040   # dark gray for walls


##############################################################################
# Mutable Data
##############################################################################
CUR_COL_X:  .word 0 # grid column of the whole column
CUR_COL_Y:  .word 0 # grid row of the TOP 

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

    jal clear_screen

    jal draw_grid
    jal draw_column

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra






############################################################
# Main program
############################################################
main:
    # I might delete this later
    jal init_game       # set up the intial column etc.
    jal draw_scene      # draw grid and start columns 
    
    # Exit (I will do the rest later)
    li $v0, 10
    syscall


game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
    j game_loop
