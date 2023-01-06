##
# Error handling
##

.balign CELL
# print an error message to the UART
error:
    la a1, msg_error    # load string message
    addi a2, a1, 4      # load string length
    call uart_print     # call uart print function
    j reset             # jump to reset the stack pointers, variables, etc before jumping to the interpreter

.balign CELL
# print an OK message to the UART
ok:
    la a1, msg_ok       # load string message
    addi a2, a1, 6      # load string length
    call uart_print     # call uart print function
    j tib_init          # jump to reset the terminal input buffer before jumping to the interpreter

.balign CELL
# print a REBOOTING message to the UART
reboot:
    la a1, msg_reboot   # load string message
    addi a2, a1, 12     # load string length
    call uart_print     # call uart print function
    j _start            # reboot when print returns

msg_error: .ascii "  ?\n"
msg_ok: .ascii "   ok\n"
msg_reboot: .ascii "  rebooting\n"
