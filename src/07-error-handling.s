##
# Error handling
##

print_error error, 4, reset
print_error ok, 6, tib_init
print_error reboot, 16, _start
print_error tib, 14, reset
print_error mem, 16, reset
print_error token, 14, reset
print_error underflow, 20, reset
print_error overflow, 20, reset

msg_error: .ascii "  ?\n"
msg_ok: .ascii "   ok\n"
msg_reboot: .ascii "   ok rebooting\n"
msg_tib: .ascii "   ? tib full\n"
msg_mem: .ascii "  ? memory full\n"
msg_token: .ascii "  ? big token\n"
msg_underflow: .ascii "  ? stack underflow\n"
msg_overflow: .ascii "   ? stack overflow\n"
