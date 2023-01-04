##
# Internal functions
##

# compute a hash of a word
# arguments: a0 = buffer address, a1 = buffer size
# returns: a0 = 32-bit hash value
djb2_hash:
    li t0, 5381         # t0 = hash value
    li t1, 33           # t1 = multiplier
    mv t3, a1           # t3 = word length
    slli t3, t3, 24     # shift the length left by 24 bits
djb2_hash_loop:
    beqz a1, djb2_hash_done
    lbu t2, 0(a0)       # load 1 byte from a0 into t2
    mul t0, t0, t1      # multiply hash by 33
    add t0, t0, t2      # add character value to hash
    addi a0, a0, 1      # increase buffer address by 1
    addi a1, a1, -1     # decrease buffer size by 1
    j djb2_hash_loop    # repeat
djb2_hash_done:
    li t1, ~FLAGS_LEN   # load the inverted 8-bit flags+length mask into temporary
    and a0, t0, t1      # clear the top eight bits (used for flags and length)
    or a0, a0, t3       # add the length to the final hash value
    ret                 # a0 = final hash value

# obtain a word (token) from the terminal input buffer
# arguments: a0 = buffer start address
# returns: a0 = token start address, a1 = token size (length in bytes)
token:
    li t1, CHAR_SPACE           # initialize temporary to 'space' character
    mv t2, zero                 # initialize temporary counter to 0
token_char:
    lbu t0, 0(a0)               # read char from buffer
    addi a0, a0, 1              # move buffer pointer up
    beqz t0, token_zero         # compare char with 0
    bgeu t1, t0, token_space    # compare char with space
    addi t2, t2, 1              # increment the token size for each non-space byte read
    j token_char                # loop to read the next character
token_space:
    beqz t2, token_char         # loop to read next character if token size is 0
    addi a0, a0, -1             # move buffer pointer down to ignore the space character
    sub a0, a0, t2              # store the start address in W
    j token_done
token_zero:
    addi a0, a0, -1             # move buffer pointer down to ignore the 0
token_done:
    mv a1, t2                   # store the size in X
    ret

# convert a string token to a 32-bit integer
# arguments: a0 = token buffer start address, a1 = token size (length in bytes)
# returns: a0 = integer value, a1 = 1=OK, 0=ERROR
number:
    li t1, 10                   # initialize temporary to 10: multiplier
    mv t0, zero                 # initialize temporary to 0: holds the final integer
    li t3, CHAR_MINUS           # initialize temporary to minus character '-'
    mv t4, zero                 # initialize temporary to 0: sign flag of integer
    lbu t2, 0(a0)               # load first character from W working register
    bne t2, t3, number_digit    # jump to number digit loop if the first character is not a minus sign
    # first character is a minus sign, so the number will be negative
    li t4, 1                    # number is negative, store a 1 flag in temporary
    addi a0, a0, 1              # increment buffer address by 1 character
    addi a1, a1, -1             # decrease buffer size by 1
number_digit:
    # check if the character in the token is a digit between "0" (0x30) and "9" (0x39)
    # if we take the digit and subtract 0x30 and the result is < 0, then it's not a digit (error)
    # if we take the digit and subtract 0x30 and the result is > 9, then it's not a digit (error)
    # otherwise it's a digit (loop)
    beqz a1, number_done        # if the size of the buffer is 0 then we're done
    lbu t2, 0(a0)               # load next character into temporary
    addi t2, t2, -0x30          # subtract 0x30 from the character
    bgeu t2, t1, number_error   # check if character is < 0 or >= 10
    mul t0, t0, t1              # multiply previous number by 10 (base 10)
    add t0, t0, t2              # add previous number to current digit
    addi a0, a0, 1              # increment buffer address by 1 character
    addi a1, a1, -1             # decrease buffer size by 1
    j number_digit              # loop to check the next character
number_error:
    li a1, 0                    # number is too large or not an integer, return 0
    ret
number_done:
    beqz t4, number_store       # don't negate the number if it's positive
    neg t0, t0                  # negate the number using two's complement
number_store:
    mv a0, t0                   # copy final number to W working register
    li a1, 1                    # number is an integer, return 1
    ret

# search for a hash in the dictionary
# arguments: a0 = hash of the word, a1 = address of the LATEST word
# returns: a0 = hash of the word, a1 = address of the word if found
lookup:
    beqz a1, error              # error if the address is 0 (end of the dictionary)
    lw t0, 4(a1)                # load the hash of the word from the X working register

    # check if the word is hidden
    li t1, F_HIDDEN            # load the HIDDEN flag into temporary
    and t1, t0, t1             # read the hidden flag bit
    bnez t1, lookup_next       # skip the word if it's hidden

    # remove the 3-bit flags using a mask
    li t1, ~FLAGS_MASK         # load the inverted 3-bit flags mask into temporary
    and t0, t0, t1             # ignore flags when comparing the hashes
    beq t0, a0, lookup_done    # done if the hashes match
lookup_next:
    lw a1, 0(a1)               # follow link to next word in dict
    j lookup
lookup_done:
    ret
