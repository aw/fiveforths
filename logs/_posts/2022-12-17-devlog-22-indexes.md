# December 17, 2022

1. [Log 22](#log-22)
2. [Indexes](#indexes)
3. [Closing thoughts](#closing-thoughts)

### Log 22

Before I continue with the interpreter, I want to review an idea I had about indexing words.

### Indexes

In _devlog 10_ I mentioned removing indexes because they're not necessary, but I think it's such a cool feature that I decided I'll give it a shot just for fun.

The idea is instead of linking a word to the previously defined word in the dictionary, using `HERE` and `LATEST`, we would link it to the latest word of the same length... something like `LATEST5` for a word with 5 characters, or `LATEST17` for a word with 17 characters. We would also keep track with `HERE5` or `HERE17`. In total we would need to dedicate 64 CELLs for indexes (one `HERE` and one `LATEST` for each character length: 1 to 32, total 256 Bytes) because we're limited to only 32 characters for a word's length (5 bits). We would continue to update `HERE` and `LATEST` as usual, to make it easy to unhide a word in `SEMI`, but the _linking_ part would keep all words of the same length together.

Essentially, the indexes would be a new feature to make lookups quicker than the current `O(N)` dictionary word lookup. Another added benefit is in the future it would make _removing_ a word much easier, since we wouldn't need to wipe a huge chunk of the dictionary just to remove 1 word. It would be a _somewhat_ simple matter of relinking the words of the same length, which might only be between 1 and 10 words (instead of possibly hundreds, depending on the size of the dictionary). All of this can easily be automated into a simple `forget` function or something like that.

I realize this is probably an unnecessary optimization when the dictionary only contains a few words, but it seems like an interesting challenge that I could totally implement given a few hours of focus time.

### Closing thoughts

Yes I know, I didn't write any new code, I just wanted to flesh out an idea before I _forget_ it haha.

In the next session I'll continue with the interpreter and then jump over to implement the _indexes_ feature before coming back to the interpreter's `lookup` function.
