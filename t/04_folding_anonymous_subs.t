use strict;
use warnings;
use lib 't';

use Test::More;
use VimFolds;

my @quote_words = qw(q qq qx qw qr);
my @quote_chars = (
    '/',
    '.',
    '#',
    '()',
    '[]',
    '{}',
    '<>',
);

plan tests => 16 + (@quote_chars * @quote_words);

my $no_anon_folds = VimFolds->new(
    language      => 'perl',
    script_before => 'let perl_fold=1 | let perl_nofold_packages=1'
);

my $anon_folds = VimFolds->new(
    language      => 'perl',
    script_before => 'let perl_fold=1 | let perl_nofold_packages=1 | let perl_fold_anonymous_subs=1'
);

$no_anon_folds->folds_match(<<'END_PERL');
use strict;
use warnings;

my $anon_sub = sub {
    print "one\n";
    print "two\n";
    print "three\n";
};
END_PERL

$anon_folds->folds_match(<<'END_PERL');
use strict;
use warnings;

my $anon_sub = sub { # {{{
    print "one\n";
    print "two\n";
    print "three\n";
}; # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL');
use strict;
use warnings;

my %HASH = (
    super => 1,
    'sub' => 2,
);

sub something { # {{{
    my ( $self, $child ) = @_;

    # hello
    unless(ref $child) {
        $child = $child->new;
    }

    $self->current_node->append_child($child);
} # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL');
has parser_rules => (
    is      => 'ro',
    default => sub { [] },
);

sub _append_child { # {{{
    my ( $self, $child, %params ) = @_;

    unless(ref $child) {
        $child = $child->new(
            %params,
            parent => $self->current_node,
        );
    }

    $self->current_node->append_child($child);
    return $child;
} }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL');
my $sub = sub :Attribute { # {{{
    say 'foo';
    say 'bar';
    say 'baz';
}; # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL');
my $sub = sub () { # {{{
    say 'foo';
    say 'bar';
    say 'baz';
}; # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL');
my $sub = sub { # {{{
    my $string = 'foo } bar';
    say 'more stuff';
}; # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL');
my $sub = sub { # {{{
    my $string = "foo } bar";
    say 'more stuff';
}; # }}}
END_PERL

foreach my $word (@quote_words) {
    foreach my $char_pair (@quote_chars) {
        my $open_char  = substr($char_pair, 0, 1);
        my $close_char = length($char_pair) > 1
            ? substr($char_pair, 1, 1)
            : $open_char;
        my $char = $close_char eq '}' ? '\}' : '}';

        my $code = <<"END_PERL";
my \$sub = sub { # {{{
    my \$string = ${word}${open_char}foo $char bar${close_char};
    say 'more stuff';
}; # }}}
END_PERL

        $anon_folds->folds_match($code, "Testing ${word}${open_char}...${close_char} with embedded }");
    }
}

# I know this is not valid Perl, but VimFolds
# will strip the comments.  Besides, I needed a
# way to tell VimFolds where the folds begin/end.
$anon_folds->folds_match(<<'END_PERL');
my $sub = sub () { # {{{
    my $perl = <<'END_PERL2'; # {{{
sub {
    say 'hello'
}
END_PERL2 # }}}
}; # }}}
END_PERL

TODO: {
    local $TODO = q{Next-line subs don't fold properly yet'};

    $anon_folds->folds_match(<<'END_PERL', 'test opening sub brace on next line');
my $sub = sub ()
{ # {{{
    say 'foo';
    say 'bar';
    say 'baz';
}; # }}}
END_PERL
}

$anon_folds->folds_match(<<'END_PERL', 'test folds with print { $fh } ... (anonymous ON)');
use strict;
use warnings;

sub foo { # {{{
    my ( $self, @params ) = @_;

    open my $fh, '> ', 'log.txt' or die $!;
    print { $fh } "warning!\n";
    close $fh;
} # }}}
END_PERL

$no_anon_folds->folds_match(<<'END_PERL', 'test folds with print { $fh } ... (anonymous OFF)');
use strict;
use warnings;

sub foo { # {{{
    my ( $self, @params ) = @_;

    open my $fh, '> ', 'log.txt' or die $!;
    print { $fh } "warning!\n";
    close $fh;
} # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL', 'Test folding with an anonymous sub nested in a regular one');
use strict;
use warnings;
use feature qw(say);

sub my_sub { # {{{
    say 'hi';

    return sub { # {{{
        say 'hello';
    }; # }}}
}; # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL', 'Test folding with @{...} nested in a regular sub');
sub my_sub { # {{{
    my @entries = @{ $ref };
}; # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL', 'Test folding with %{...} nested in a regular sub');
sub my_sub { # {{{
    my %entries = %{ $ref };
}; # }}}
END_PERL

$anon_folds->folds_match(<<'END_PERL', 'Test BEGIN block folding');
package Moose;
BEGIN { # {{{
  $Moose::AUTHORITY = 'cpan:STEVAN';
} # }}}

say 'hello';
END_PERL
