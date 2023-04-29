# Commands

The following commands can be entered into the console window to operate RuMARS.

## `battle`, `ba`

Run the loaded warrior(s) in battle mode.

## `break <address>`, `br <address>`

Toggle the breakpoint at the given address. You can use symbols and expressions to specify the address.

## `create`, `cr`

Create a new warrior.

## `debug <level>`

Set the verbosity of debug information. Levels 0 to 1 are supported.

## `exit`

Exit the RuMARS.

## `focus <pid>`, `fo <pid>`

Switch the focus to the loaded warrior with the given program ID.

## `goto <address>`, `go <address>`

Set the current program counter to the given address. You can use symbols and expressions to specify the address.

## `list <address>`, `li <address>`

Show the instruction at the given address in the core window. You can use symbols and expressions to specify the address.

## `load <filename>`, `lo <filename>`

Load the redcode file with the given file name.

## `pcs`

Show the program counters of the current program.

## `peek <address>`, `pe <address>`

Print the instruction at the given address. You can use symbols and expressions to specify the address.

## `poke <address> <instruction>`, `po <address> <instruction>`

Write the given instruction to the specified address.

## `restart`, `re`

Restart all loaded warriors.

## `run [<cycles>]`, `ru [<cycles>]`

Run the loaded warriors until the given cycle count is reached or only one is left. No execution trace will be recorded.

## `save <filename.red> [<start address>] [<end_address>]`, `sa <filename.red> [<start address>] [<end address>]`

Save the whole core or the instructions within the specified address range to the given file.

## `step`, `st`

Execute one instruction for all loaded warriors. The execution trace of the instructions will be shown in the register window.
