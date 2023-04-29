# Metadata

It is possible to include certain information about your warrior within special
metadata comments. These comments are recognised by the parser and included in
the parsed output (though they are excluded when the parsed warrior is loaded
into the core).

The following metadata comments are recognised by the redcode parser

## ;redcode-94

Indicates that this warrior was written using [ICWS'94](./#standards) standard
compliant redcode.

Earlier standards of Corewar did not have a standard way to declare the version
of redcode used.  The RuMARS parser supports `;redcode` and `;redcode-94`
comments.

## ;name

Allows the author to give a name to their warrior, for example `;name imp`.

The RuMARS parser will insert a default name comment of `;name Player <N>` if
no name comment is found in the source redcode.

## ;author

Specifies the name of the warrior's author (i.e. you).

