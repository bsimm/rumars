# RuMARS

RuMARS is a new implementation of the [Core
War](https://en.wikipedia.org/wiki/Core_War) Memory Array Redcode Simulator. It
supports the ICWS-94 standard draft and some additional extensions like read
and write limits and new features introduced by pMARS.

## Installation

Not yet available via RubyGems.org!

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

## Usage

### Commands

The following commands can be entered into the console window to operate RuMARS.

* battle, ba

Run the loaded warrior(s) in battle mode.

* break, br <address>

Toggle the breakpoint at the given address. You can use symbols and expressions to specify the address.

* create, cr

Create a new warrior.

* debug <level>

Set the verbosity of debug information. Levels 0 to 1 are supported.

* exit

Exit the RuMARS.

* focus, fo <pid>

Switch the focus to the loaded warrior with the given program ID.

* goto, go <address>

Set the current program counter to the given address. You can use symbols and expressions to specify the address.

* list, li <address>

Show the instruction at the given address in the core window. You can use symbols and expressions to specify the address.

* load, lo <file name>

Load the redcode file with the given file name.

* pcs

Show the program counters of the current program.

* peek, pe <address>

Print the instruction at the given address. You can use symbols and expressions to specify the address.

* poke, po <address> <instruction>

Write the given instruction to the specified address.

* restart, re

Restart all loaded warriors.

* run, ru [<cycles>]

Run the loaded warriors until the given cycle count is reached or only one is left. No execution trace will be recorded.

* save, sa <filename.red> [start address] [end address]

Save the whole core or the instructions within the specified address range to the given file.

* step, st

Execute one instruction for all loaded warriors. The execution trace of the instructions will be shown in the register window.

### Redcode IDE

![Redcode IDE](/screenshots/debug.png?raw=true "Redcode IDE")

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

