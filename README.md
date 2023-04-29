# RuMARS

Modern computers have become so fast that programming languages have more and
more abstracted the CPU instructions into powerful high-level language
constructs. With that, programmers have lost the understanding how CPUs and
computers really work. This isn't usually a problem as long as your computer is
fast enough to do the job you need to have done. But if you need to write an
operating system or hypervisor, you must know how your CPU works.
Unfortunately, most computer science students no longer learn much about the
internals of their computers. This results in a shortage of good operating
system and hypervisor developers. RuMARS was developed to get more people
excited again about low-level programming and learning some basics of CPU
programming.

RuMARS is a new implementation of the [Core
War](https://en.wikipedia.org/wiki/Core_War) Memory Array Redcode Simulator
(MARS) that was first proposed by D. G. Jones and A. K. Dewdney in 1984. A MARS
is a virtual arena where 2 or more programmers can let their programs fight against
each other. The programs are written in an assembly dialect called
[Redcode](https://scrapper.github.io/rumars/redcode/index). Core War has
evolved since the orinal version. RuMARS supports the ICWS-94
standard draft and some additional extensions like read and write limits and
new features introduced by pMARS. RuMARS purposely adds new features so that
new strategies need to be developed to compete successfully against other
warriors. However, in the default configuration it is still compatible with
ICWS-94 compliant simulators.

For today's tournaments we recommend to use read and write limits and low
limits of processes to foster the creation of new strategies and more complex
warriors.

RuMARS is not just a virtual machine for Redcode programs but also an
integraded development environment to write and debug Redcode programs.

![Redcode IDE](/screenshots/debug.png?raw=true "Redcode IDE")

## Installation

Not yet available via RubyGems.org!

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

## Usage

See the [RuMARS Documentation](https://scrapper.github.io/rumars/)

## Battle View

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

