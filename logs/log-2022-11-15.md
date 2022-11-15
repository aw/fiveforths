# November 15, 2022

## Dive into the code

In this log entry, we'll dive directly into the code and try to understand what's been written so far, and why.

### Log 2

Upon opening `fiveforths.s`, we're immediately thrown into a long list of variables for use throughout the rest of the code. Afterwards, we're greeted with macros to simplify our ASM code, followed by the actual functions and _Forth_ words.

#### Variables, pt.1

The first few variables hardcode some values used to define the size of the RAM, a cell, a stack, etc. We've seen seen the memory map in [Log 1](log-2022-11-14.md), and those addresses are defined relative to variables before them. This allows us to change one value and have the entire memory map adjusted automatically.

I found `fiveforths.ld` in this repo's directory, but I hadn't commited the file. I'm not sure where it came from so I'll just keep using it for now. It hardcodes the FLASH and RAM addresses, as well as their sizes, making the variables somewhat redundant, but I'll fix that once I have a better idea of what I'm doing.

I made some minor changes to the `Makefile` in order to link with that _layout_ file, and I also modified the `_start` function to load the top of the stack address into the `sp` register. I did that because that's where our stack pointer should be at the start of the program, but I'm getting a bit ahead of myself now. Back to the variables!

#### Variables, pt.2

I used the `.space` directive to "reserve" the 1KiB stack spaces, but I think those might be completely unnecessary. I'll probably remove them, again, once I have a better idea of what I'm doing.

Next, I reserved some space for the `STATE, HERE, LATEST, NOOP` variables, as well as some `PAD` area. The first 3 variables are commonly used by Forth, but `NOOP` is not. I don't remember exactly why I created a `NOOP` variable but I'm sure I had a good reason, so I'll leave it there for now. Same for the `PAD` area.

#### Registers

Forth, by convention, uses some specific names for registers, and I mapped them to RISC-V registers as shown below:

```
# sp = DSP = data stack pointer
# a0 = W   = working register
# s0 = FP  = frame pointer (unused for now)
# s1 = IP  = instruction pointer
# s2 = RSP = return stack pointer
# s3 = TOS = top of stack pointer
# s4 = TIB = terminal input buffer
```

I mapped `TOS` to `s3`, a "saved register", because it's something I use a frequently in my implementation. This is one of the areas where I opted to do things a bit differently from _jonesforth_ etc. I wanted to use one (1) specific register which always holds the top element in the stack. It seems like it might be needlessly juggling data around, particularly on an MCU where RAM access has practicaly zero-latency, but I kind of liked how it simplifies operations which only need the top element in the stack.

That might be changed in the future during the code optimization phase.

#### Macros

I guess one of the good things about GNU AS is its support for macros. This makes the assembly code much simpler and easier to follow (in my opinion).

I've written a few macros such as `NEXT` and `defcode`, but I want to focus on `PUSH` and its friends. I made an early design decision to align things to 16 bytes (128-bit). That's the requirement to be compliant with the RISC-V ABI, however I think that only applies for programs running on Linux, since there will be strict compatibility needs. On a microcontroller, 4-byte (32-bit) alignment might be more than enough, and less wasteful considering the limited resources. I'll probably adjust that and align to 4-bytes like every other implementation.

Those macros are all implemented and fully functional, but I'm not sure what `RCALL` does so I'll need to dig into my Forth books to refresh my memory.

#### Closing thoughts

I guess overall I have no idea what i'm doing. Jumping back into this incomplete/nonfunctional code after a year hiatus has been quite challenging, but I think I'll soon be ready to pick up where I left off.

I'm getting tired after this mostly unproductive session, so I'll discuss the functions and _Forth_ words in the next log.
