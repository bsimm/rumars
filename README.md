# RuMARS

RuMARS is a new implementation of the [Core
War](https://en.wikipedia.org/wiki/Core_War) Memory Array Redcode Simulator. It
supports the ICWS-94 standard draft and some additional extensions like read
and write limits and new features introduced by pMARS.

![Redcode IDE](/screenshots/debug.png?raw=true "Redcode IDE")

This documentation is based on material from [CoreWars.io](https://github.com/corewar/corewar.io)

## Installation

Not yet available via RubyGems.org!

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

## Usage

### Commands

The following commands can be entered into the console window to operate RuMARS.

* `battle`, `ba`

Run the loaded warrior(s) in battle mode.

* `break <address>`, `br <address>`

Toggle the breakpoint at the given address. You can use symbols and expressions to specify the address.

* `create`, `cr`

Create a new warrior.

* `debug <level>`

Set the verbosity of debug information. Levels 0 to 1 are supported.

* `exit`

Exit the RuMARS.

* `focus <pid>`, `fo <pid>`

Switch the focus to the loaded warrior with the given program ID.

* `goto <address>`, `go <address>`

Set the current program counter to the given address. You can use symbols and expressions to specify the address.

* `list <address>`, `li <address>`

Show the instruction at the given address in the core window. You can use symbols and expressions to specify the address.

* `load <filename>`, `lo <filename>`

Load the redcode file with the given file name.

* `pcs`

Show the program counters of the current program.

* `peek <address>`, `pe <address>`

Print the instruction at the given address. You can use symbols and expressions to specify the address.

* `poke <address> <instruction>`, `po <address> <instruction>`

Write the given instruction to the specified address.

* `restart`, `re`

Restart all loaded warriors.

* `run [<cycles>]`, `ru [<cycles>]`

Run the loaded warriors until the given cycle count is reached or only one is left. No execution trace will be recorded.

* `save <filename.red> [<start address>] [<end_address>]`, `sa <filename.red> [<start address>] [<end address>]`

Save the whole core or the instructions within the specified address range to the given file.

* `step`, `st`

Execute one instruction for all loaded warriors. The execution trace of the instructions will be shown in the register window.

### Opcodes

Opcodes are used to specify what operation should be performed when the
instruction is executed.

Different opcodes have different default [modifiers](modifiers) and some
opcodes require only a single [operand](operands). See [Parser](parser) for
details on how defaults are introduced into parsed instructions.

The following `opcodes` can be used in Corewar

* [dat](#dat-data)
* [mov](#mov-move)
* [add](#add-add)
* [sub](#sub-subtract)
* [mul](#mul-multiply)
* [div](#div-divide)
* [mod](#mod-modulo)
* [jmp](#jmp-jump)
* [jmz](#jmz-jump-if-zero)
* [jmn](#jmn-jump-if-not-zero)
* [djn](#djn-decrement-and-jump-if-not-zero)
* [cmp](#seq-skip-if-equal)
* [seq](#seq-skip-if-equal)
* [sne](#sne-skip-if-not-equal)
* [slt](#slt-skip-if-less-than)
* [spl](#spl-split)
* [nop](#nop-no-operation)

####Dat - Data

If one of a warrior's processes executes a `dat` instruction it is removed from
the process queue i.e. terminated. This is the main way that warriors are
killed within the game of Corewar.

Note that termination of the warrior's process happens after the
[operand](operands) [addressing modes](addressing_modes) are evaluated.

For example if a warrior were to execute the first instruction of the following
code block

```redcode
DAT.F 1, <1 ; <--this instruction is executed
DAT.F 1, 1
```

The second instruction's B operand would still be decremented, giving:

```redcode
DAT.F 1, <1 
DAT.F 1, 0 ; <--this instruction was modified
```

The default [modifier](modifiers) for the `dat` opcode is `.f`. Only one
operand needs to be specified for the `dat` instruction to be successfully
parsed. If this is the case, the A operand is defaulted to 0.

For example `dat 7` will be parsed as `DAT.F $0, $7`

####Mov - Move

The `mov` instruction copies data from the address referenced by the A
[operand](operands) to the address referenced by the B operand.

Which data is copied is determined by the instruction's [modifier](modifiers).

The default modifier for the `mov` opcode is [.i](modifiers#i).

####Add - Add

The `add` instruction adds the number(s) from the address referenced by the A
[operand](operands) to the number(s) at the address referenced by the B
operand.

As with all operations in Corewar, the add operation uses mod maths, therefore
the result of addition will be `(A + B) % CORESIZE`.

Which data is added is determined by the instruction's [modifier](modifiers).

The [.i](modifiers#i) modifier has the same effect as the [.f](modifiers#f)
modifier.

The default modifier for the `add` opcode is [.ab](modifiers#ab).

####Sub - Subtract

The `sub` instruction subtracts the number(s) from the address referenced by
the A [operand](operands) from the number(s) at the address referenced by the B
operand.

As with all operations in Corewar, the subtract operation uses mod maths,
therefore the result of subtraction will be `(A - B) % CORESIZE`.

Which data is subtracted is determined by the instruction's
[modifier](modifiers).

The [.i](modifiers#i) modifier has the same effect as the [.f](modifiers#f) modifier.

The default modifier for the `sub` opcode is [.ab](modifiers#ab).

####Mul - Multiply

The `mul` instruction multiplies the number(s) from the address referenced by
the A [operand](operands) by the number(s) at the address referenced by the B
operand.

As with all operations in Corewar, the multiply operation uses mod maths,
therefore the result of multiplication will be `(A * B) % CORESIZE`.

Which data is multiplied is determined by the instruction's
[modifier](modifiers).

The [.i](modifiers#i) modifier has the same effect as the [.f](modifiers#f)
modifier.

The default modifier for the `mul` opcode is [.ab](modifiers#ab).

####Div - Divide

The `div` instruction divides the number(s) from the address referenced by the
B [operand](operands) by the number(s) at the address referenced by the A
operand. The quotient of this division is always rounded down.

As with all operations in Corewar, the divide operation uses mod maths,
therefore the result of division will be `floor(A / B) % CORESIZE`.

Which data is divided is determined by the instruction's [modifier](modifiers).

The [.i](modifiers#i) modifier has the same effect as the [.f](modifiers#f)
modifier.

The default modifier for the `div` opcode is [.ab](modifiers#ab).

Dividing by zero is considered an illegal instruction in Corewar. The executing
warrior's process is removed from the process queue (terminated).

Note that termination of the warrior's process happens after the
[operand](operands) [addressing modes](addressing_modes) are evaluated.

####Mod - Modulo

The `mod` instruction divides the number(s) from the address referenced by the
B [operand](operands) by the number(s) at the address referenced by the A
operand. The remainder from this division is stored at the destination.

As with all operations in Corewar, the modulo operation uses mod maths,
therefore the result of modulo will be `(A % B) % CORESIZE`.

Which data is divided is determined by the instruction's [modifier](modifiers).

The [.i](modifiers#i) modifier has the same effect as the [.f](modifiers#f)
modifier.

The default modifier for the `mod` opcode is [.ab](modifiers#ab).

Dividing by zero is considered an illegal instruction in Corewar. The executing
warrior's process is removed from the process queue (terminated).

Note that termination of the warrior's process happens after the
[operand](operands) [addressing modes](addressing_modes) are evaluated.

####Jmp - Jump

The `jmp` instruction changes the address of the next instruction which will be
executed by the currently executing process. The most common usages of this
opcode are to create a loop or to skip over a section of code.

The `jmp` instruction will jump execution to the address given by the
instruction's A [operand](operands). The B operand has no purpose within the
`jmp` instruction. However the B operand will still be evaluated, see
[addressing_modes](addressing_modes).

[Modifiers](modifiers) have no effect on the `jmp` instruction, the A operand
is always used as the jump address.

The default modifier for the `jmp` opcode is [.b](modifiers#b). Only one
operand needs to be specified for the `jmp` instruction to be successfully
parsed. If this is the case, the B operand is defaulted to 0.

For example `jmp 5` will be parsed as `JMP.B $5, $0`.

####Jmz - Jump if Zero

The `jmz` instruction works in the same way as the [jmp](opcodes#jmp-jump)
instruction detailed above with the exception that the jump is only performed
if the number(s) at the address referenced by the B [operand](operands) is
zero. This allows the `jmz` instruction to function like an `if` statement in a
higher level language.

The instruction's [modifier](modifiers) controls which operands are compared
with zero at the destination address according to the following table:

|Modifier|Destination|
|---|---|
|.a|A operand|
|.b|B operand|
|.ab|B operand|
|.ba|A operand|
|.f|A and B operands|
|.x|A and B operands|
|.i|A and B operands|

We can see from this that [.a](modifiers#a) and [.ba](modifiers#ba) are
equivalent, as are [.b](modifiers#b) and [.ab](modifiers#ab). We can also see
that [.f](modifiers#f), [.x](modifiers#x) and [.i](modifiers#i) are equivalent.

Note that when comparing both A and B operands with zero, the jump will **not**
be taken if **either** operand is non-zero.

```redcode
dat 0, 1 ; <- won't jump if compared with jmz.f
dat 1, 0 ; <- won't jump if compared with jmz.f
dat 1, 1 ; <- won't jump if compared with jmz.f
dat 0, 0 ; <- will jump if compared with jmz.f
```

The default modifier for the `jmz` opcode is [.b](modifiers#b).

####Jmn - Jump if not Zero

The `jmn` instruction works in the same way as the
[jmz](opcodes#jmz-jump-if-zero) instruction detailed above with the exception
that the jump is performed if the referenced number(s) are **not** zero.

Note that when comparing both A and B operands with zero, the jump will **not**
be taken if **either** operand is zero.

```redcode
dat 0, 1 ; <- won't jump if compared with jmn.f
dat 1, 0 ; <- won't jump if compared with jmn.f
dat 1, 1 ; <- will jump if compared with jmn.f
dat 0, 0 ; <- won't jump if compared with jmn.f
```

The default modifier for the `jmn` opcode is [.b](modifiers#b).

####Djn - Decrement and Jump if not Zero

The `djn` instruction works in a similar way to the
[jmn](opcodes#jmn-jump-if-not-zero) instruction detailed above with one
addition. Before comparing the destination instruction against zero, the
number(s) at the destination instruction are decremented. One common use of
this opcode is to create the equivalent of a simple `for` loop in higher level
languages.

Unlike the `jmn` intruction, the `djn` instruction **will** perform the jump if
**either** operand is zero when using the [.f](modifiers#f), [.x](modifiers#x)
and [.i](modifiers#i) modifiers.

```redcode
dat 0, 1 ; <- will jump if compared with djn.f
dat 1, 0 ; <- will jump if compared with djn.f
dat 1, 1 ; <- will jump if compared with djn.f
dat 0, 0 ; <- won't jump if compared with jmn.f
```

Decrement happens after the [addressing modes](addressing_modes) are evaluated
and before the comparison against zero is made.

The default modifier for the `djn` opcode is [.b](modifiers#b).

####Seq - Skip if Equal

The `cmp` opcode is an alias for `seq` used to support legacy corewar
standards. `cmp` and `seq` work in exactly the same way within Corewar.

The `seq` instruction compares the number(s) at the addresses specified by its
source and destination [operands](operands) and if they are equal, increments
the next address to be executed by the current process by one - in effect
skipping the next instruction. Skip instructions are commonly used to develop
scanners which scan the [core](core) looking for other
[warriors](../corewar/warriors).

The instruction's [modifier](modifiers) determines what at the two addresses is
compared for equality. Importantly, using a modifier of [.i](modifiers#i) will
compare the entire source and destination instructions. This means even if the
instructions differ only by opcode, modifier or [addressing
mode](addressing_modes), the next instruction will not be skipped.

The default modifier for the 'seq' opcode is [.i](modifiers#i).

####Sne - Skip if not Equal

The `sne` instruction works in the same way as the
[seq](opcodes#seq-skip-if-equal) instruction detailed above with the exception
that the next instruction is skipped if the source and destination instructions
are **not** equal.

The default modifier for the 'sne' opcode is [.i](modifiers#i).

####Slt - Skip if Less Than

The `slt` instruction compares the number(s) at the addresses specified by its
source and destination [operands](operands). If the source number(s) are less
than than the destination number(s), the next address to be executed by the
current [process](../corewar/processes) is incremented by one - in effect
skipping the next instruction.

The instruction's [modifier](modifiers) controls which operands are compared at
the source and destination addresses according to the following table:

|Modifier|Source|Destination|
|---|---|---|
|.a|A operand|A operand|
|.b|B operand|B operand|
|.ab|A operand|B operand|
|.ba|B operand|A operand|
|.f|A and B operands|A and B operands|
|.x|A and B operands|B and A operands|
|.i|A and B operands|A and B operands|

We can see from this that the [.f](modifiers#f) and [.i](modifiers#i) modifiers
are equivalent.

If comparing both A and B operands (using .f, .x or .i), the instruction will
not be skipped if **either** source number is greater than or equal to its
corresponding destination number.

The default modifier for the 'slt' opcode is [.b](modifiers#b).

####Spl - Split

The `spl` instruction spawns a new process for the current warrior at the
address specified by the A [operand](operands).

The newly created process is added to the process queue **after** the currently
executing process.

Consider the following example:

```redcode
a: spl c
b: jmp 0
c: jmp 0
```

The first instruction is executed, creating a second process at `c`. The next
instruction to execute will be `b` (executed by the original process). Finally
the new process will execute at `c`.

[Modifiers](modifiers) have no effect on the `spl` instruction, the A operand
is always used as the split address.

The default [modifier](modifiers) for the `spl` opcode is `.b`. Only one
operand needs to be specified for the `spl` instruction to be successfully
parsed. If this is the case, the B operand is defaulted to 0.

For example `spl 3` will be parsed as `SPL.B $3, $0`.

####Nop - No Operation

The `nop` instruction does not perform any operation. The instruction takes a
single cycle to execute as normal, and [addressing modes](addressing_modes) are
evaluated as normal. One potential use of the `nop` instruction is to introduce
a delay in execution when working on a multi-process warrior.

[Modifiers](modifiers) have no effect on the `nop` instruction.

The default [modifier](modifiers) for the `nop` opcode is `.f`. Only one
operand needs to be specified for the `nop` instruction to be successfully
parsed. If this is the case, the B operand is defaulted to 0.

For example `nop 8` will be parsed as `NOP.F $8, $0`.

###Modifiers

Modifiers are appended to the end of an [opcode](opcodes) to modify the
opcode's behaviour.

This allows for each opcode to have a wide range of behaviours (up to 7)
without the need to introduce multiple variants of each opcode. Modifiers were
introduced in the ICWS'94 standard. In earlier standards, the modifier was
implied by the opcode. To allow backwards compatibility, each opcode has a
default modifier which is inserted by the parser if necessary.

The following `modifiers` can be used in Corewar

* [.a](#a)
* [.b](#b)
* [.ab](#ab)
* [.ba](#ba)
* [.f](#f)
* [.x](#x)
* [.i](#i)

When an instruction is executed, the modifier controls which values from the
source and destination instruction are used as follows:

|Modifier|Source|Destination|
|---|---|---|
|.a|A operand|A operand|
|.b|B operand|B operand|
|.ab|A operand|B operand|
|.ba|B operand|A operand|
|.f|A and B operands|A and B operands|
|.x|A and B operands|B and A operands|
|.i|Whole instruction|Whole instruction|

For most [opcodes](opcodes) the `.i` modifier has the same effect as the `.f`
modifier.

##A

The A [operand](operands) of the source instruction and the A operand of the
destination instruction are used by the specified [opcode](opcodes).

##B

The B [operand](operands) of the source instruction and the B operand of the
destination instruction are used by the specified [opcode](opcodes).

##AB

The A [operand](operands) of the source instruction and the B operand of the
destination instruction are used by the specified [opcode](opcodes).

##BA

The B [operand](operands) of the source instruction and the A operand of the
destination instruction are used by the specified [opcode](opcodes).

##F

Both the A and B [operand](operands)s of the source instruction and the A and B
operands of the destination instruction are used by the specified
[opcode](opcodes) respectively.

##X

Both the A and B [operand](operands)s of the source instruction and the B and A
operands of the destination instruction are used by the specified
[opcode](opcodes) respectively.

##I

The specified [opcode](opcodes) is applied to the entire source and destination
instructions. The `.i` modifier is only applicable to the
[mov](opocodes#mov-move), [seq](opcodes#skip-if-equal) and
[sne](opcodes#skip-if-not-equal) opcodes.  Other opcodes tend to default to the
behaviour of the [.f](modifiers#f) modifier.

###Operands

Each redcode instruction contains two operands. An operand is composed of an
[addressing mode](addressing_modes) and a number. The first operand is known as
the `A` operand and the second as the `B` operand.

```redcode
mov.i $1, #2
```
In the above example, the A operand is `$1` and the B operand is `#2`.

The A addressing mode is `$` (direct) and the A number is `1`.
The B addressing mode is `#` (immediate) and the B number is `2`.

If no addressing mode is specified for an operand, the [Parser](parser) inserts
a default addressing mode of `$` (direct).

Some [opcodes](opcodes) only require a single operand in order to be
successfully parsed. When this is the case, the parser inserts `$0` as the
second operand. In these situations the opcode determines whether the `A` or
`B` operand is inserted. 

###Addressing Modes

Each [operand](operands) in a Corewar instruction has an addressing mode. The
addressing mode controls how the `Source` and `Destination` instructions are
determined.

When an instruction is executed, the addressing modes for the `A` and `B`
operands of the instruction are evaluated to determine the source and
destination instruction for the current [opcode](opcodes). Additionally, some
addressing modes modify the operand number by incrementing or decrementing it
during this evaluation.

The following addressing modes can be used in Corewar

* [#](#immediate) - Immediate
* [$](#direct) - Direct
* [*](#a-indirect) - A Indirect
* [@](#b-indirect) - B Indirect
* [{](#a-pre-decrement-indirect) - A Pre-decrement Indirect
* [}](#a-post-increment-indirect) - A Post-increment Indirect
* [<](#b-pre-decrement-indirect) - B Pre-decrement Indirect
* [>](#b-post-increment-indirect) - B Post-increment Indirect

####Immediate

Operands with the immediate (`#`) addressing mode are always evaluated as an
address of 0. This allows data to be stored in the operand without affecting
the address the operand references.

For example, the follow example works just like the classic `imp` despite
having a non-zero `A` operand. This can also make the imp more resilient as it
will continue to function perfectly even if the `A` number is modified.

```redcode
mov.i #123, $1
```

####Direct

The direct (`$`) addressing mode provides a relative address from the executing
instruction to another instruction in the core.

This is used in the classic `imp`.

```redcode
mov.i $0, $1
```

The `A` operand has a direct address of 0 and the `B` operand has a direct
address of 1. This corresponds to the current and next instructions
respectively.

The direct addressing mode is the default addressing mode.

####A Indirect

The A Indirect (`*`) addressing mode uses the executing instruction's operand
as a pointer to an intermediate instruction. This second instruction's `A`
field is then used as a direct reference to the instruction of interest.

Note the intermediate instruction's address is resolved relative to this
intermediate instruction, not the executing instruction.

Let's look at an example.

```redcode
mov.i *1, $2
dat    2, 0  ; <- 2 is used as a pointer
dat    0, 0  ; <- this instruction will be overwritten
jmp    0     ; <- with this instruction
```

The `mov` instruction is about to be executed. The `B` opeand is using the
[Direct](#direct) addressing mode and is refering to the third instruction
(`dat 0, 0`).

The `A` operand is using the A Indirect addressing mode. The `A` number is `1`,
which indicates that the `A` operand of the second instruction (`dat 2, 0`)
should be used as a pointer to the `source` instruction.

The `A` number of the second instruction is `2`, therefore the `source`
instruction is found by moving 2 addresses forward from the second instruction.
This means that the fourth instruction (`jmp 0`) will be used as the `source`
for this move instruction. 

####B Indirect

The B Indirect (`@`) addressing mode works in the same way as the [A
Indirect](#a-indirect) (`*`) addressing mode described above except that it
uses the intermediate instruction's `B` field as a pointer rather than its `A`
field.

The `@` addressing mode is used by the classic warrior `dwarf` to set the
location where its bombs will fall:

```redcode
add #4,  3
mov  2, @2
jmp -2
dat #0, #0
```
The `dat` instruction is used both as a bomb and also as a pointer to the
target address. The dwarf warrior runs in an infinite loop. Each iteration of
the loop, it adds `4` (the step size) to the `dat` instructions `B` number.

After this it executes `mov 2, @2` to copy the `dat` bomb to the address
pointed to by the `dat` bomb's `B` number.

####A Pre-decrement Indirect

The A Pre-decrement Indirect (`{`) addressing mode works in the same way as the
[A Indirect](`*`) addressing mode detailed above with the addition that it
**first** decrements the `A` number **before** using it as a pointer.

```redcode
mov.i {1, $1
dat   $0, $0
```

The above example will first decrement the `A` number of the `dat` instruction
before using the `dat` instruction's `A` number as a pointer.

```redcode
mov.i  {1, $1
dat   $-1, $0
```

After decrementing, the `A` number of the `dat` instruction will be `-1` and
therefore refer to the `mov` instruction, which will be used as the `source`
instruction.

####A Post-increment Indirect

The A Post-increment Indirect (`}`) addressing mode works in the same way as
the [A Indirect](`*`) addressing mode detailed above with the addition that it
increments the `A` number **after** using it as a pointer.

```redcode
mov.i }1, $1
dat   $0, $0
```

The above example will first use the `A` number of the `dat` instruction as a
pointer. As the `dat` instruction's `A` number is `0`, the `dat` instruction is
pointing to itself and so the `dat` instruction will be used as the `source`
instruction for the move operation.

After this has happened, the `dat` instruction's `A` number will be incremented
to `1`.

```redcode
mov.i  }1, $1
dat   $1, $0
```

Finally the move operation will be applied using the **copy** of the `dat`
instruction from the `Source Register`:

```redcode
mov.i }1, $1
dat   $0, $0
```

Note, perhaps counter-intuitively, the final resulting core looks exactly the
same as the starting core. The change made by the post-increment was
overwritten by the move operation. See [execution](../corewar/execution) for
more details about the execution order within Corewar.

####B Pre-decrement Indirect

The B Pre-decrement Indirect (`<`) addressing mode works in the same way as the
[A Pre-decrement Indirect](#a-pre-decrement-indirect) addressing mode detailed
above except it decrements and uses the intermediate instruction's `B` number
as a pointer, rather than its `A` number.

####B Post-increment Indirect

The B Post-increment Indirect (`>`) addressing mode works in the same way as
the [A Post-increment Indirect](#a-post-increment-indirect) addressing mode
detailed above except it increments and uses the intermediate instruction's `B`
number as a pointer, rather than its `A` number.


### Battle View

![Battle View](/screenshots/battle.png?raw=true "Battle View")

Not yet ready for use. This software is still under development.

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/scrapper/rumars.

