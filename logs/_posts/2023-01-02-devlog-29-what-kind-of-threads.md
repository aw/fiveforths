# January 02, 2023

1. [Log 29](#log-29)
2. [What kind of threads](#what-kind-of-threads)
3. [Adjusting for DTC](#adjusting-for-dtc)
4. [Closing thoughts](#closing-thoughts)

### Log 29

Happy New Year! In my last post, I was clearly confused about the type of jumps (direct/indirect) my Forth was making, and in fact I kinda of still have no idea what I'm talking about. In this session I'll try to clear up a few things and hopefully set myself in the right direction for completing this Forth.

### What kind of threads

The main question I've been asking myself since I first started writing this **Forth** is: "What kind of threading does it use?". There's a few types discussed in detail in [Moving Forth by Brad Rodriguez](https://www.bradrodriguez.com/papers/moving1.htm):

* Indirect Threaded Code (ITC), with address codefields
* Direct Threaded Code (DTC), with `jump` or `call` codefields
* Subrouting Threaded Code (STC), with `call` codefields
* Token Threaded Code (TTC), using a token lookup table

And probably a bunch of other hybrid approaches in between (ex: Segment Threaded Code).

After some careful reading over the last few days, I realized _derzforth_ is designed using `ITC` but performing double-indirect jumps, _sectorforth_ is designed using `DTC` which literally jumps directly to an address in a register but also behaves as an `ITC` for colon definitions, and _jonesforth_ is designed using `ITC` and a indirect jumps as well.

In the end, everyone's use-case is different, but _Brad Rodriguez_ highlighted something important:

> _The only way to know for sure is to write sample code_

So I'm going to take that approach and test different types. I'll start with adjusting my code for `DTC` with jump instructions, since I think I'm already halfway there.

### Adjusting for DTC

The first step is to add one level of indirection when executing a word. We don't want to jump directly to the address stored in the `IP` (`s1`) register. We want to jump to the address pointed by it, so in `execute` we'll make the following change:

```
-    la s1, ok               # load the address of the interpreter into the IP register
+    la s1, .loop            # load the address of the interpreter into the IP register
```

and then outside of that function we'll add a memory address for that:

```
.loop: .word ok             # indirect jump to interpreter after executing a word
```

Now I'm not sure yet if this is exactly what should happen. At the moment it is jumping to the `ok` function, which will print `ok` and reset the `TIB` before jumping back to the `interpreter_start` function. Perhaps I don't want to reset the `TIB` just yet.

The next step is to modify the `NEXT` macro so it actually performs that indirect jump:

```
-    mv a0, s1           # load memory address from IP into W
+    lw a0, 0(s1)        # load memory address from IP into W
```

Without this change, we would be jumping to the address of `.loop` instead of the address pointed to by `.loop` (aka `ok`). This is important because `COLON` defined words will also need this indirection. Let's modify `COLON` while we're at it:

```
-    la a2, docol        # load the codeword address into Y working register
+    la a2, .addr        # load the codeword address into Y working register
```

It's jumping to a different address, which I defined below:

```
.addr: .word docol      # indirect jump to docol from a colon definition
```

This is similar to the `execute` function and will allow `NEXT` to behave the same way for both types of words (primitives and colon words). At least, that's what I understood so far.

I can confirm this by typing `latest<Enter>` in the terminal:

```
latest ok
```

and then inspecting the `TOS` (`s3`) register to see what it contains:

```
(gdb) i r s3
s3             0x80004f0	134218992
(gdb) x/xw 0x080004f0
0x80004f0 <word_SEMI>:	0x080004e4
```

Perfect! It contains the memory address which points to the `LATEST` primitive word defined in the `fiveforths.s`: `SEMI`.

### Closing thoughts

I believe the above implemention is not complete, and it's likely linked to incorrect assignment to the `IP` instruction pointer, or the resetting of the `TIB` (which makes no sense after only executing 1 word)... In the next session I'll focus on fixing that issue before jumping to _compile mode_.
