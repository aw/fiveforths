# December 24, 2022

1. [Log 23](#log-23)
2. [Terminal input buffer](#terminal-input-buffer)
3. [Indexes pt2](#indexes-pt2)
4. [Closing thoughts](#closing-thoughts)

### Log 23

The plan today was to move the interpreter forward, but I discovered a design flaw in the terminal input buffer.

### Terminal input buffer

In the last session, we were already processing the backspace character to "erase" characters from the `TIB`, but we haven't even added characters to the `TIB` yet.

The idea was to add characters to the `TIB` as they arrive through the UART, to check them individually, and process them until a _newline_ is seen, which would indicate the end of a command (unless in compile mode). That's typically how **Forth** works:

```
1 1 + .<enter>2  ok
```

The approach used for reading a token (a word from the buffer) is to read backwards from the `TOIN` variable until a _space_ character is found, and keep track of the length of the word. Then you move the address in `TOIN` backwards to where that word starts.

This works, but combined with the reference interpreter implementation (_derzforth_ which copies _sectorforth_ which assumes keyboard entry), we have a few problems:

1. UART characters sometimes get lost
2. The buffer won't hold multiline definitions
3. The data stack is not even used!

I'll explain each issue in the order listed above:

#### 1. UART characters missing

You see, as our reference design suggests, we're forced to process each character as it arrives over the UART. If there's any kind of delay in processing, or if characters arrive too quickly, they will be lost. This happens when "pasting" or "uploading" code over a slow UART.

#### 2. No multiline

For a multiline definition, you want to ignore the _newline_ character and just keep going until you get the _semicolon_. The reference design checks each character as it arrives, and then uses the _newline_ as a separator thus making it impossible to hold a multiline definition.

#### 3. No data stack!

A typical **Forth** stores words on the _data stack_, and executes words based on what's stored in there. The reference interpreter design does not even use the stack - at all.

I plan to fix these issues in a future session, once the `v1` of this implementation is complete.

### Indexes pt2

Upon reviewing my _Indexes_ idea from _devlog 22_, I decided to also put this on hold until I've completed the `v1` implementation of this Forth. I realize I might need to undo a lot of code in order to go back and implement indexing and alternative buffering, but for the moment I just want to get a working Forth haha.

### Closing thoughts

This session was brief, again with no code, but I'll get to that in the next session, where I plan to finish the interpreter and the `lookup` function.
