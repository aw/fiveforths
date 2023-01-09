##
# Variables and constants
##

.equ FORTH_VERSION, 1

##
# Memory map
##

# DSP, RSP, TIB stacks grow downward from the top of memory
.equ DSP_TOP, RAM_BASE + RAM_SIZE       # address of top of data stack
.equ RSP_TOP, DSP_TOP - STACK_SIZE      # address of top of return stack
.equ TIB_TOP, RSP_TOP - STACK_SIZE      # address of top of terminal buffer
.equ TIB, TIB_TOP - STACK_SIZE          # address of bottom of terminal buffer

# variables
.equ STATE, TIB - CELL                  # 1 CELL for STATE variable
.equ TOIN, STATE - CELL                 # 1 CELL for TOIN variable (looks into TIB)
.equ HERE, TOIN - CELL                  # 1 CELL for HERE variable
.equ LATEST, HERE - CELL                # 1 CELL for LATEST variable
.equ NOOP, LATEST - CELL                # 1 CELL for NOOP variable
.equ PAD, NOOP - (CELL * 64)            # 64 CELLS between NOOP and PAD

# dictionary grows upward from the RAM base address
.equ FORTH_SIZE, PAD - RAM_BASE         # remaining memory for Forth

##
# Interpreter constants
##

.equ CHAR_NEWLINE, '\n'         # newline character 0x0A
.equ CHAR_CARRIAGE, '\r'        # carriage return character 0x0D
.equ CHAR_SPACE, ' '            # space character 0x20
.equ CHAR_BACKSPACE, '\b'       # backspace character 0x08
.equ CHAR_COMMENT, '\\'         # backslash character 0x5C
.equ CHAR_COMMENT_OPARENS, '('  # open parenthesis character 0x28
.equ CHAR_COMMENT_CPARENS, ')'  # close parenthesis character 0x29
.equ CHAR_MINUS, '-'            # minus character 0x2D

##
# Flags
###

.equ F_IMMEDIATE, 0x80000000    # inverse = 0x7fffffff, immediate flag mask
.equ F_HIDDEN, 0x40000000       # inverse = 0xbfffffff, hidden flag mask
.equ F_USER, 0x20000000         # inverse = 0xdfffffff, user flag mask
.equ FLAGS_MASK, 0xe0000000     # inverse = 0x1fffffff, 3-bit flags mask
.equ FLAGS_LEN, 0xff000000      # inverse = 0x00ffffff, 8-bit flags+length mask
