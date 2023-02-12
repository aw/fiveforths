: dup sp@ @ ;
: invert -1 nand ;
: negate invert 1 + ;
: - negate + ;
: drop dup - + ;
: over sp@ 4 + @ ;
: swap over over sp@ 12 + ! sp@ 4 + ! ;
: nip swap drop ;
: 2dup over over ;
: 2drop drop drop ;
: and nand invert ;
: or invert swap invert nand ;
: = - 0= ;
: <> = invert ;
: , here @ ! here @ 4 + here ! ;
: immediate latest @ 4 + dup @ 0x80000000 or swap ! ;
: [ 0 state ! ; immediate
: ] 1 state ! ;
: branch rp@ @ dup @ + rp@ ! ;
