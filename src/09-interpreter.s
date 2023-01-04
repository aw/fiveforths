##
# Interpreter
##

.balign CELL

.section .rodata

# here's where the program starts (the interpreter)
interpreter_start:
    li t2, TIB                                  # load TIB memory address
    li t3, TOIN                                 # load the TOIN variable into unused temporary register
    lw a1, 0(t3)                                # load TOIN address value into X working register

interpreter:
    call uart_get                               # read a character from UART
    li t4, CHAR_NEWLINE                         # load newline into temporary
    beq a0, t4, skip_send                       # don't send the character if it's a newline
    call uart_put                               # send the character to UART

skip_send:
    # validate the character which is located in the W (a0) register
    li t0, CHAR_COMMENT                         # load comment character into temporary
    beq a0, t0, skip_comment                    # skip the comment if it matches

    li t0, CHAR_COMMENT_OPARENS                 # load opening parens into temporary
    beq a0, t0, skip_oparens                    # skip the opening parens if it matches

    li t0, CHAR_BACKSPACE                       # load backspace into temporary
    beq a0, t0, process_backspace               # process the backspace if it matches

    li t0, CHAR_CARRIAGE                        # load carriage return into temporary
    beq a0, t0, process_carriage                # process the carriage return if it matches

    # TODO: check if character is printable

interpreter_tib:
    # add the character to the TIB
    li t4, TIB_TOP                              # load TIB_TOP memory address
    bge a1, t4, error                           # error if the terminal input buffer is full # FIXME: handle this better
    sb a0, 0(a1)                                # store the character from W register in the TIB
    addi a1, a1, 1                              # increment TOIN value by 1
    li t0, CHAR_NEWLINE                         # load newline into temporary
    beq a0, t0, replace_newline                 # process the token if it matches

    j interpreter                               # return to the interpreter if it's not a newline

skip_comment:
    checkchar CHAR_NEWLINE, interpreter         # check if character is a newline
    j skip_comment                              # loop until it's a newline

skip_oparens:
    checkchar CHAR_COMMENT_CPARENS, interpreter # check if character is a closing parens
    j skip_oparens                              # loop until it's a closing parens

process_backspace:
    # erase the previous character on screen by sending a space then backspace character
    li a0, ' '
    call uart_put
    li a0, '\b'
    call uart_put

    # erase a character from the terminal input buffer (TIB) if there is one
    beq a1, t2, interpreter # return to interpreter if TOIN == TIB
    addi a1, a1, -1         # decrement TOIN by 1 to erase a character
    sw a1, 0(t3)            # store new TOIN value in memory

    j interpreter           # return to the interpreter after erasing the character

process_carriage:
    li a0, CHAR_NEWLINE     # convert a carriage return to a newline
    j interpreter_tib       # jump to add the character to the TIB

.balign CELL
replace_newline:
    li a0, CHAR_SPACE       # convert newline to a space
    sb a0, -1(a1)           # replace previous newline character with space in W register

process_token:
    # process the token
    li t3, TOIN             # load TOIN variable into unused temporary register
    lw a0, 0(t3)            # load TOIN address value into temporary
    call token              # read the token

    # move TOIN
    add t0, a0, a1          # add the size of the token to TOIN
    sw t0, 0(t3)            # move TOIN to process the next word in the TIB

    # bounds checks on token size
    beqz a1, ok             # ok if token size is 0
    li t0, 32               # load max token size  (2^5 = 32) in temporary
    bgtu a1, t0, error      # error if token size is greater than 32

    call djb2_hash          # hash the token

    li a1, LATEST           # load LATEST variable into X working register
    lw a1, 0(a1)            # load LATEST value into X working register
    call lookup             # lookup the hash in the dictionary

    # check if the word is immediate
    lw t0, CELL(a1)         # load the hash of the found word into temporary
    li t1, F_IMMEDIATE      # load the IMMEDIATE flag into temporary
    and t0, t0, t1          # read the status of the immediate flag bit

    # load the STATE variable value
    li t1, STATE            # load the address of the STATE variable into temporary
    lw t1, 0(t1)            # load the current state into a temporary

    # decide if we want to execute or compile the word
    or t0, t0, t1           # logical OR the immediate flag and state
    addi t0, t0, -1         # decrement the result by 1
    beqz t0, compile        # compile the word if the result is 0

.balign CELL
execute:
    la s1, .loop            # load the address of the interpreter into the IP register
    addi a0, a1, 2*CELL     # increment the address of the found word by 8 to get the codeword address
    lw t0, 0(a0)            # load memory address from W into temporary
execute_done:
    jr t0                   # jump to the address in temporary

.loop: .word process_token  # indirect jump to interpreter after executing a word

.balign CELL
compile:
compile_done:
    j ok
