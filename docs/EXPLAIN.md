# FiveForths: Explain

[FiveForths](https://github.com/aw/fiveforths) is a tiny [Forth](https://www.forth.com/starting-forth/) written in hand-coded RISC-V assembly, initially designed to run on the 32-bit [Longan Nano](https://longan.sipeed.com/en/) (GD32VF103) microcontroller.

---

This document provides an explanation of _FiveForths_ and the story behind it.

## Menu

1. [Why another Forth?](#why-another-forth)
2. [Why not Lisp?](#why-not-lisp)
3. [Why indirect threading?](#why-indirect-threading)
4. [Why word hashing?](#why-word-hashing)
5. [Why so few primitives?](#why-so-few-primitives)

### Why another Forth

Most likely, every **Forth** creator in this millenium has faced this question. I've already blogged about my [decision here](https://a1w.ca/p/2021-03-15-the-future-of-computing-with-riscv-fpgas-and-forth/) and [here](https://a1w.ca/p/2023-01-03-year-of-the-microcontroller/). To resume, I think _Forth_ is a nice way to start fresh in the world of microcontrollers and FPGAs. I think if we want to go back to owning our tools and creating things that run the way they should, then we need to start from a good minimal base.

My initial goal was to start from [derzforth](https://github.com/theandrew168/derzforth/pulls?q=is%3Apr+is%3Aclosed) by contributing to the project and help bring it to a fully useable implementation, but I eventually decided to create my own which was more aligned with my personal goals.

I want to use _FiveForths_ as an alternative to my current C++/Lua-based microcontroller projects. I also want to use it as a building block for deploying to larger RISC-V instruction sets (ex: 64-bit) on much more powerful devices. Eventually, like most dreamers, I'd like to create an operating system or something like that, so I guess I had to start somewhere.

### Why not Lisp

Those who know me are aware that I've been programming in [PicoLisp](https://picolisp.com) for almost a decade. It's been my go-to language for almost everything at the high level, but I've been unable to get it to lower-level microcontroller projects. In the end, I'm not even sure that Lisp (of any kind) is suitable for a microcontroller.

### Why indirect threading

At the start of 2023, I wrote about [what kind of threading](https://aw.github.io/fiveforths/devlog-29-what-kind-of-threads) I planned on using (direct-threading), but the implementation was ugly and buggy, so I switched to indirect-threading shortly after. The implementation is very similar to existing implementations such as [jonesforth](https://github.com/nornagon/jonesforth), so it was very easy to get it working perfectly and it's also easy to reason about.

I'm aware that it may have some disadvantages on a modern RISC-V CPU architecture, but it's something that can eventually be changed if I start to notice some performance issues, and if I have time to work on it.

### Why word hashing

A typical _Forth_ will have a variable word length for dictionary entries. The header that's built in memory would then store the word length and the characters of the word, and add padding to words for it to align on a boundary (ex: 4 byte boundary). A 32-character word header would end up requiring 11 CELLs of memory compared to a hash which would only require 3 CELLs for the header.

The disadvantage of hashing is the number of cycles required to compute the hash. We're looking at an order of magnitude more time, but on a _Longan Nano_ running at 8 million cycles per second (8 MHz) it's still blazingly fast.

Considering the relatively small memory size of the _Longan Nano Lite_ (20 KBytes), I feel like it would be a massive waste to use nearly 3x more memory by storing words the traditional way. Since it can be also be clocked up to 108 MHz, it seems much more sensible to focus on optimizing memory usage rather than optimizing the code execution path.


### Why so few primitives

_FiveForths_ only has 19 built-in primitives, which is at least 150 less than a typical _Forth_. This means to get a "real" _Forth_ would require writing (or pasting) hundreds of lines of code into the terminal. Keeping with the idea of having an extremely minimal implementation, this approach seems fine for me. Not all primitives are needed for every use-case, and this allows the dictionary to be built specifically to suit ones needs.

---

Now that you've read the answer to various questions, you're ready to read the other documents below:

* [TUTORIALS](TUTORIALS.md): a quick guide to **get started**
* [HOWTO](HOWTO.md): build, usage, and code examples in Forth and RISC-V Assembly
* [REFERENCE](REFERENCE.md): learn the technical details, what's under the hood

# License

[MIT License](LICENSE)

FiveForths documentation and source code copyright © 2021~ [Alexander Williams](https://a1w.ca) and licensed under the permissive open source [MIT](https://opensource.org/licenses/MIT) license.
