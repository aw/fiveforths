##
# Error handling
##

.balign CELL
# print an error message to the UART
error:
    li a0, CHAR_SPACE
    call uart_put
    li a0, '?'
    call uart_put
    li a0, CHAR_NEWLINE
    call uart_put

    j reset             # jump to reset the stack pointers, variables, etc before jumping to the interpreter

.balign CELL
# print an OK message to the UART
ok:
    li a0, CHAR_SPACE
    call uart_put
    li a0, 'o'
    call uart_put
    li a0, 'k'
    call uart_put
    li a0, CHAR_NEWLINE
    call uart_put

    j tib_init          # jump to reset the terminal input buffer before jumping to the interpreter
