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
BITMAP_WIDTH:   .word 64
BITMAP_HEIGHT:  .word 64

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
    

# Color for background color
COLOR_BG:   .word 0x000000   # black for empty cells
COLOR_WALL: .word 0x404040   # dark gray for walls
# Segment patterns for letters A-Z (you mentioned you have these)
# Each pattern is a 32-bit value where bits 0-10 control the segments
# Example: 'A' pattern (you'll need to define all 26)
letter_patterns: .word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  # Placeholder

char_a_pattern: .word 783  # 783 = 1100001111 in binary
char_b_pattern: .word 491  # 491 = 1111010111 in binary

# Points storage for the 7 fixed pattern points
points_x: .word 0,0,0,0,0,0,0
points_y: .word 0,0,0,0,0,0,0

.text

.globl main

start:
    j main
    nop # I just google it, I dont know how it works

main: 

    jal draw_char_a

    j main


##########################################
# draw_char_a
# Draw the letter 'A' using 11-segment display
# at fixed coordinates (10,10), size 5, color white
##########################################
draw_char_a:
    # Prologue - save registers
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    
    # Load the pattern for letter A
    la $s0, char_a_pattern
    lw $s1, 0($s0)        # s1 = line code for A
    
    # Set up parameters for draw_11seg
    li $a0, 10            # x = 10
    li $a1, 10            # y = 10
    li $a2, 5             # size = 5
    li $a3, 0x00FFFFFF    # color = white (RGB)
    
    # Push line code onto stack and call draw_11seg
    addi $sp, $sp, -4
    sw $s1, 0($sp)        # store line code on stack
    jal draw_11seg
    addi $sp, $sp, 4      # clean up stack
    
    # Epilogue - restore registers
    lw $ra, 8($sp)
    lw $s0, 4($sp)
    lw $s1, 0($sp)
    addi $sp, $sp, 12
    
    jr $ra

##########################################
# draw_11seg
# Draw an 11-segment display character
# $a0 = x coordinate
# $a1 = y coordinate  
# $a2 = size
# $a3 = color
# 0($sp) = line code (32-bit pattern)
##########################################
draw_11seg:
    # Prologue - save registers
    addi $sp, $sp, -32
    sw $ra, 28($sp)
    sw $s0, 24($sp)
    sw $s1, 20($sp)
    sw $s2, 16($sp)
    sw $s3, 12($sp)
    sw $s4, 8($sp)
    sw $s5, 4($sp)
    
    # Save arguments to saved registers
    move $s0, $a0        # s0 = x
    move $s1, $a1        # s1 = y  
    move $s2, $a2        # s2 = size
    move $s3, $a3        # s3 = color
    
    # Get line code from stack
    lw $s4, 32($sp)      # s4 = line code
    
    # Calculate all 7 points
    jal calculate_points
    
    # Draw segments based on line code
    move $a0, $s4        # line code
    move $a1, $s2        # size
    move $a2, $s3        # color
    jal draw_segments
    
    # Epilogue - restore registers
    lw $ra, 28($sp)
    lw $s0, 24($sp)
    lw $s1, 20($sp)
    lw $s2, 16($sp)
    lw $s3, 12($sp)
    lw $s4, 8($sp)
    lw $s5, 4($sp)
    addi $sp, $sp, 32
    
    jr $ra

##########################################
# calculate_points
# Calculate the 7 fixed pattern points
# Uses s0-s2 from parent function
##########################################
calculate_points:
    # Save registers
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Point 1: given (x,y)
    la $t0, points_x
    la $t1, points_y
    sw $s0, 0($t0)    # p1.x = x
    sw $s1, 0($t1)    # p1.y = y
    
    # Point 2: (x - size, y + size)
    sub $t2, $s0, $s2    # x - size
    add $t3, $s1, $s2    # y + size
    sw $t2, 4($t0)       # p2.x
    sw $t3, 4($t1)       # p2.y
    
    # Point 3: (x + size, y + size)
    add $t2, $s0, $s2    # x + size
    sw $t2, 8($t0)       # p3.x
    sw $t3, 8($t1)       # p3.y (same y as p2)
    
    # Point 4: (x, y + 2*size)
    sll $t2, $s2, 1      # 2*size
    add $t3, $s1, $t2    # y + 2*size
    sw $s0, 12($t0)      # p4.x = x
    sw $t3, 12($t1)      # p4.y
    
    # Point 5: (x - size, y + 3*size)
    li $t4, 3
    mul $t4, $s2, $t4    # 3*size
    add $t3, $s1, $t4    # y + 3*size
    sub $t2, $s0, $s2    # x - size
    sw $t2, 16($t0)      # p5.x
    sw $t3, 16($t1)      # p5.y
    
    # Point 6: (x + size, y + 3*size)
    add $t2, $s0, $s2    # x + size
    sw $t2, 20($t0)      # p6.x
    sw $t3, 20($t1)      # p6.y
    
    # Point 7: (x, y + 4*size)
    sll $t2, $s2, 2      # 4*size
    add $t3, $s1, $t2    # y + 4*size
    sw $s0, 24($t0)      # p7.x = x
    sw $t3, 24($t1)      # p7.y
    
    # Restore and return
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

draw_segments:
    # Save registers
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)

    move $s0, $a0        # s0 = line code
    move $s1, $a1        # s1 = size
    move $s2, $a2        # s2 = color

    # Load points arrays
    la $s4, points_x
    la $s5, points_y

    # Now we don't need to use $a0 and $a1 for the points arrays anymore.

    # Bit 0: p1 diagonal down-left
    andi $t0, $s0, 0x0001
    beqz $t0, skip_bit0
    lw $a2, 0($s4)       # p1.x
    lw $a3, 0($s5)       # p1.y
    move $t0, $s1        # length = size
    addi $t0, $t0, 1     # length = size + 1
    move $t1, $s2        # color
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    li $a0, -1           # dx = -1 (left)
    li $a1, 1            # dy = 1 (down)
    jal draw_diagonal_line
    addi $sp, $sp, 8
skip_bit0:

    # Bit 1: p1 diagonal down-right
    andi $t0, $s0, 0x0002
    beqz $t0, skip_bit1
    lw $a2, 0($s4)       # p1.x
    lw $a3, 0($s5)       # p1.y
    move $t0, $s1        # length = size
    addi $t0, $t0, 1     # length = size + 1
    move $t1, $s2        # color
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    li $a0, 1            # dx = 1 (right)
    li $a1, 1            # dy = 1 (down)
    jal draw_diagonal_line
    addi $sp, $sp, 8
skip_bit1:

    # Bit 2: p2 diagonal down-right
    andi $t0, $s0, 0x0004
    beqz $t0, skip_bit2
    lw $a2, 4($s4)       # p2.x
    lw $a3, 4($s5)       # p2.y
    move $t0, $s1        # length = size
    addi $t0, $t0, 1     # length = size + 1
    move $t1, $s2        # color
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    li $a0, 1            # dx = 1 (right)
    li $a1, 1            # dy = 1 (down)
    jal draw_diagonal_line
    addi $sp, $sp, 8
skip_bit2:

    # Bit 3: p3 diagonal down-left
    andi $t0, $s0, 0x0008
    beqz $t0, skip_bit3
    lw $a2, 8($s4)       # p3.x
    lw $a3, 8($s5)       # p3.y
    move $t0, $s1        # length = size
    addi $t0, $t0, 1     # length = size + 1
    move $t1, $s2        # color
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    li $a0, -1           # dx = -1 (left)
    li $a1, 1            # dy = 1 (down)
    jal draw_diagonal_line
    addi $sp, $sp, 8
skip_bit3:

    # Bit 4: p4 diagonal down-left
    andi $t0, $s0, 0x0010
    beqz $t0, skip_bit4
    lw $a2, 12($s4)      # p4.x
    lw $a3, 12($s5)      # p4.y
    move $t0, $s1        # length = size
    addi $t0, $t0, 1     # length = size + 1
    move $t1, $s2        # color
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    li $a0, -1           # dx = -1 (left)
    li $a1, 1            # dy = 1 (down)
    jal draw_diagonal_line
    addi $sp, $sp, 8
skip_bit4:

    # Bit 5: p4 diagonal down-right
    andi $t0, $s0, 0x0020
    beqz $t0, skip_bit5
    lw $a2, 12($s4)      # p4.x
    lw $a3, 12($s5)      # p4.y
    move $t0, $s1        # length = size
    addi $t0, $t0, 1     # length = size + 1
    move $t1, $s2        # color
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    li $a0, 1            # dx = 1 (right)
    li $a1, 1            # dy = 1 (down)
    jal draw_diagonal_line
    addi $sp, $sp, 8
skip_bit5:

    # Bit 6: p5 diagonal down-right
    andi $t0, $s0, 0x0040
    beqz $t0, skip_bit6
    lw $a2, 16($s4)      # p5.x
    lw $a3, 16($s5)      # p5.y
    move $t0, $s1        # length = size
    addi $t0, $t0, 1     # length = size + 1
    move $t1, $s2        # color
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    li $a0, 1            # dx = 1 (right)
    li $a1, 1            # dy = 1 (down)
    jal draw_diagonal_line
    addi $sp, $sp, 8
skip_bit6:

    # Bit 7: p6 diagonal down-left
    andi $t0, $s0, 0x0080
    beqz $t0, skip_bit7
    lw $a2, 20($s4)      # p6.x
    lw $a3, 20($s5)      # p6.y
    move $t0, $s1        # length = size
    addi $t0, $t0, 1     # length = size + 1
    move $t1, $s2        # color
    addi $sp, $sp, -8
    sw $t0, 0($sp)
    sw $t1, 4($sp)
    li $a0, -1           # dx = -1 (left)
    li $a1, 1            # dy = 1 (down)
    jal draw_diagonal_line
    addi $sp, $sp, 8
skip_bit7:

    # Bit 8: p2 down (vertical)
    andi $t0, $s0, 0x0100
    beqz $t0, skip_bit8
    lw $a0, 4($s4)       # p2.x
    lw $a3, 4($s5)       # p2.y
    sll $t0, $s1, 1      # 2*size
    addi $a1, $t0, 0    # length = 2*size
    move $a2, $s2        # color
    jal draw_vertical_line
skip_bit8:

    # Bit 9: p3 down (vertical)
    andi $t0, $s0, 0x0200
    beqz $t0, skip_bit9
    lw $a0, 8($s4)       # p3.x
    lw $a3, 8($s5)       # p3.y
    sll $t0, $s1, 1      # 2*size
    addi $a1, $t0, 0    # length = 2*size 
    move $a2, $s2        # color
    jal draw_vertical_line
skip_bit9:

    # Bit 10: p1 down (vertical)
    andi $t0, $s0, 0x0400
    beqz $t0, skip_bit10
    lw $a0, 0($s4)       # p1.x
    lw $a3, 0($s5)       # p1.y
    sll $t0, $s1, 2      # 4*size
    addi $a1, $t0, 0    # length = 4*size
    move $a2, $s2        # color
    jal draw_vertical_line
skip_bit10:

    # Restore registers
    lw $ra, 20($sp)
    lw $s0, 16($sp)
    lw $s1, 12($sp)
    lw $s2, 8($sp)
    lw $s3, 4($sp)
    lw $s4, 0($sp)
    addi $sp, $sp, 24
    jr $ra

##########################################
# draw_diagonal_line
# Draw a diagonal line at 45 degrees
# $a0 = dx direction (-1 left, 1 right)
# $a1 = dy direction (1 down)
# $a2 = start x
# $a3 = start y
# 0($sp) = length
# 4($sp) = color
##########################################
draw_diagonal_line:
    # Prologue - save registers
    addi $sp, $sp, -32
    sw $ra, 28($sp)
    sw $s0, 24($sp)
    sw $s1, 20($sp)
    sw $s2, 16($sp)
    sw $s3, 12($sp)
    sw $s4, 8($sp)
    sw $s5, 4($sp)
    sw $s6, 0($sp)
    
    # Get arguments and save them in saved registers
    move $s0, $a0        # s0 = dx
    move $s1, $a1        # s1 = dy
    move $s2, $a2        # s2 = current x
    move $s3, $a3        # s3 = current y
    
    # Get length and color from stack
    lw $s4, 32($sp)      # s4 = length
    lw $s5, 36($sp)      # s5 = color
    
diagonal_loop:
    blez $s4, diagonal_done
    
    # Save ALL caller-saved registers that might be modified by draw_cell
    # $a0, $a1, $a2, $a3, $t0, $t1, $t2, $t3, $t4, $t5, $t6, $t7, $t8, $t9, $v0, $v1
    addi $sp, $sp, -16
    sw $a0, 12($sp)
    sw $a1, 8($sp)
    sw $a2, 4($sp)
    sw $a3, 0($sp)
    
    # Draw current cell
    move $a0, $s3        # row = y
    move $a1, $s2        # col = x
    move $a2, $s5        # color
    jal draw_cell
    
    # Restore caller-saved registers
    lw $a3, 0($sp)
    lw $a2, 4($sp)
    lw $a1, 8($sp)
    lw $a0, 12($sp)
    addi $sp, $sp, 16
    
    # Move to next position
    add $s2, $s2, $s0    # x += dx
    add $s3, $s3, $s1    # y += dy
    addi $s4, $s4, -1    # length--
    j diagonal_loop

diagonal_done:
    # Epilogue - restore registers
    lw $s6, 0($sp)
    lw $s5, 4($sp)
    lw $s4, 8($sp)
    lw $s3, 12($sp)
    lw $s2, 16($sp)
    lw $s1, 20($sp)
    lw $s0, 24($sp)
    lw $ra, 28($sp)
    addi $sp, $sp, 32
    jr $ra

##########################################
# draw_vertical_line
# Draw a vertical line
# $a0 = x coordinate
# $a1 = length
# $a2 = color
# $a3 = start y
##########################################
draw_vertical_line:
    # Prologue - save registers
    addi $sp, $sp, -28
    sw $ra, 24($sp)
    sw $s0, 20($sp)
    sw $s1, 16($sp)
    sw $s2, 12($sp)
    sw $s3, 8($sp)
    sw $s4, 4($sp)
    sw $s5, 0($sp)
    
    move $s0, $a0        # s0 = x (constant)
    move $s1, $a1        # s1 = remaining length
    move $s2, $a2        # s2 = color
    move $s3, $a3        # s3 = current y
    
vertical_loop:
    blez $s1, vertical_done
    
    # Save ALL caller-saved registers before calling draw_cell
    addi $sp, $sp, -16
    sw $a0, 12($sp)
    sw $a1, 8($sp)
    sw $a2, 4($sp)
    sw $a3, 0($sp)
    
    # Draw current cell
    move $a0, $s3        # row = current y
    move $a1, $s0        # col = x
    move $a2, $s2        # color
    jal draw_cell
    
    # Restore caller-saved registers
    lw $a3, 0($sp)
    lw $a2, 4($sp)
    lw $a1, 8($sp)
    lw $a0, 12($sp)
    addi $sp, $sp, 16
    
    # Move down
    addi $s3, $s3, 1     # y++
    addi $s1, $s1, -1    # length--
    j vertical_loop

vertical_done:
    # Epilogue - restore registers
    lw $s5, 0($sp)
    lw $s4, 4($sp)
    lw $s3, 8($sp)
    lw $s2, 12($sp)
    lw $s1, 16($sp)
    lw $s0, 20($sp)
    lw $ra, 24($sp)
    addi $sp, $sp, 28
    jr $ra

##########################################
# draw_cell
# Draw a single bitmap cell at (row, col) with a given colour.
#   $a0 = row
#   $a1 = col
#   $a2 = colour
##########################################
draw_cell:
    lw   $t0, ADDR_DSPL      # $t0 = base 
    lw   $t1, BITMAP_WIDTH            # Display units per row

    # t2 = row * BITMAP_WIDTH 
    mul  $t2, $a0, $t1

    # t2 = row * BITMAP_WIDTH  + col
    add  $t2, $t2, $a1

    # t2 = (row * BITMAP_WIDTH  + col) * 4 (word index -> byte offset)
    sll  $t2, $t2, 2

    # t3 = address of this cell
    add  $t3, $t0, $t2

    # store the color
    sw   $a2, 0($t3)

    jr   $ra

##########################################
# Helper function to draw a specific letter
# $a0 = x, $a1 = y, $a2 = size, $a3 = color
# 0($sp) = character (ASCII value)
##########################################
draw_11seg_letter:
    # Save registers
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    # Get character and calculate pattern index
    lw $t0, 8($sp)       # character
    addi $t0, $t0, -65   # Convert to 0-based index (A=0, B=1, etc.)
    sll $t0, $t0, 2      # Multiply by 4 (word size)
    
    # Load pattern for this letter
    la $t1, letter_patterns
    add $t1, $t1, $t0
    lw $t2, 0($t1)       # t2 = line code for this letter
    
    # Push line code and call draw_11seg
    addi $sp, $sp, -4
    sw $t2, 0($sp)
    jal draw_11seg
    addi $sp, $sp, 4
    
    # Restore and return
    lw $ra, 4($sp)
    lw $s0, 0($sp)
    addi $sp, $sp, 8
    jr $ra