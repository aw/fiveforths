target extended-remote :3333

# print demangled symbols
set print asm-demangle on

set confirm off

# set backtrace limit to not have infinite backtrace loops
set backtrace limit 32

set pagination off
monitor reset halt
#load
break _continue
break gpio_done
