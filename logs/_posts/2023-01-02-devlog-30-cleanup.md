# January 02, 2023

1. [Log 30](#log-30)
2. [Cleanup](#cleanup)
3. [Closing thoughts](#closing-thoughts)

### Log 30

I can't seem to find my way through `fiveforths.s` anymore. The file has grown to over **700 lines** and even with a good text editor I have trouble finding stuff. In this session I'll split things into various files to simplify my life.

### Cleanup

Since `GNU Assembler` has very primitive _include_ functionality, I'll make sure to move the source files to the `src/` sub-directory, and each file will be prefixed with a number, to clearly indicate the correct loading order.

The first change is to include `src` in the search path for the assembler, so we'll modify the `Makefile` like this:

```
-               $(AS) $(CFLAGS) -march=$(ARCH) -o $@ $<
+               $(AS) $(CFLAGS) -march=$(ARCH) -I src -o $@ $<
```

Next, I modified `fiveforths.s` by including each file in numerical order:

```
.include "01-variables-constants.s"
.include "02-macros.s"
.include "03-interrupts.s"

# include board-specific functions
.include "gd32vf103.s"

.include "04-io-helpers.s"
.include "05-internal-functions.s"
.include "06-initialization.s"
.include "07-error-handling.s"
.include "08-forth-primitives.s"
.include "09-interpreter.s"
```

Finally, I simply moved the pieces of code into separate files. It seems like quite a big change, but the functionality remains exactly the same. Just type `make` and it will rebuild everything as usual.

### Closing thoughts

This change was purely aesthetic but I think it was really necessary to preserve my sanity. I'll get back to fixing the `execute` issue in the next session.
