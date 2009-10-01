#
# Getopt::Awesome
#
# Author(s): Pablo Fischer (pfs@yahoo-inc.com)
# Created: 09/25/2009 11:43:15 AM
package Getopt::Awesome;

use strict;
use warnings;
use vars qw($no_usage $app_name $no_usage_exit);
use Getopt::Long qw(
    :config
    require_order
    gnu_compat
    no_ignore_case);
use Text::Wrap;
use Exporter 'import';
use Data::Dumper;

our @EXPORT_OK = qw(usage define_option define_options get_opt parse_opts %args);
our @EXPORT = qw(parse_opts);
our %EXPORT_TAGS = (
    'all' => [ @EXPORT_OK ],
    'common' => [ qw(define_option define_options get_opt) ],
);

=head1 NAME

Getopt::Awesome - Expands the Getopt *automatically* for modules.

=head1 DESCRIPTION

First of, this module was very inspired in the Getopt::Modular CPAN apckage,
however at the moment of creating this module the dependency chain of the
mentioned module was very large so I though would be a nice idea to copy
some concepts from it and the regular Getopt.

Now, this module is handy if you want to give "getopt options" to a module
like it could be a normal perl script (.pl) and don't want to be rewriting
all the options over and over everytime.

When user asks for help usage (-h or --help) he/she will also get all the
available options that were set via this module.

All options are prefixed by the package name in lowercase where namespace
separator (::) gets replaced by a dash (-), so --help will return:

--foo-bar-option   Description
--foo-bar-option2  Description 2

and so on..

See the SYNOPSYS section for examples.

NOTE 1: The use of short aliases is not supported for options defined
in modules, only for main (the .pl script).
NOTE 2: In your perl script (.pl) remember to call parse_opts otherwise the
values of the options you request might be undef, empty or have your
default values. ARGV is ONLY parsed when parse_opt is called.

=head1 SYNOPSYS

    package Your::Package;

    use Getopt::Awesome qw(:common);
    define_option('foo=s', 'Fooi bar');
    ...or...

    define_options(
        ('foo=s', 'Foo'),
        ('bar=s', 'Bar'));

    parse_opts();
    my $foo_val = get_opt('option_name', 'Default value');

=cut

my (%options, $parsed_args, $show_usage, %args);

=head1 FUNCTIONS

=head2 C<define_options> (array)

    use Getopt::Awesome;
    Getopt::Awesome qw(:common);

    define_options(
        ('option_name', 'Option description')
    );

It defines the given options for current package, please note the options
defined in the current caller package are not shared with other modules, this means
that 'foo' option from package 'Foo' will not exist or will have different value
from the 'foo' option of 'Bar' package.

Each array item should consist at least of 1 item with a max of 2. The first
parameter should be the option name while the second one (optional) is the
option description.

Some notes about the option name, the first item of every array:

B<*> It's a required parameter.
B<*> It accepts any of the C<Getopt::Long> option name styles (=s, !, =%s, etc).

=cut
sub define_options {
    my $new_options = shift;
    if (ref $new_options ne 'ARRAY') {
        die 'The options should be passed as an array';
    }
    my $current_package = _get_option_package();
    foreach my $opt (@$new_options) {
        my ($option_name, $option_description) = (@$opt);
        if (!$option_name) {
            die "Option name wasn't found";
        }
        if ($option_name =~ /\|/ && $current_package ne 'main') {
            die "Sorry but no aliases ($option_name) are suported for " .
                "modules except main";
        }
        $options{$current_package}{$option_name} = $option_description;
    }
}

=head2 C<define_option> (string, optional string)

    use Getopt::Awesome qw(:common);

    define_option('option_name', 'Description');

It calls the C<define_options> subroutine for adding the given option.

Please refer to the documentation of C<define_options> for a more complete
description about it, but basically some notes:

B<*> The option name is a required parameter
B<*> The option accepts any of te C<Getopt::Long> option name styles.

=cut
sub define_option {
    # Find the right option, we don't like namespaces or classes..
    my ($option_name, $option_description) = @_;
    define_options([[$option_name, $option_description]]);
}

=head2 C<get_opt> (string option name, string default value)

    use Getopt::Awesome qw(:common);

    my $val = get_opt('option_name', 'Some default opt');

It will return the value of the given option, if there's no option set then
undefined will be returned.

Please note that if the option is set to expect a list you will receive a list,
same for integer, strings, booleans, etc. Same as it happens with the 
Getopt::Long.

=cut
sub get_opt {
    my ($option_name, $default_value) = @_;
    return $default_value unless $option_name;
    my $current_package = _get_option_package();
    if ($current_package ne 'main') {
        $current_package = lc $current_package;
        $current_package =~ s/::/-/g;
        $option_name = $current_package . '-' . $option_name;
    }
    if (defined $args{$option_name}) {
        return $args{$option_name};
    } else {
        if (defined $default_value) {
            return $default_value;
        }
    }
    return '';
}

=head2 C<parse_opts>

This subroutine should never be called directly unless you want to re-parse the
arguments or that your module is not getting called from a perl script (.pl).

In case you want to call it:

    use Getopt::Awesome qw(:common);

    parse_opts();

=cut
sub parse_opts {
    my %all_options = _build_all_options();
    if (!defined $no_usage) {
        $all_options{'h|help'} = 1;
    }
    my $res = GetOptions(
        \%args,
        keys %all_options);
    if ($args{'h'} ||
        (!defined $no_usage && !%args)) {
        usage();
        if (!defined $no_usage_exit) {
            exit(1);
        }
    }
}

=head2 C<usage>

Based on all the current options it will returns a nice and helpful
'guide' to use the current options.

Although the usage gets called directly if a -h or --help is passed
and also if no_usage is set you can call it directly:

    use Getopt::Awesome qw(:all);

    usage();

=cut
sub usage {
    my (%main_options, %other_options);
    if ($app_name) {
        print "$app_name\n";
    }
    if (scalar %options ge 1) {
        print "Options:\n";
    }
    $Text::Wrap::columns = 80;
    my @packages = keys %options;
    my ($main_pos) = grep($packages[$_] eq 'main', 0 .. $#packages);
    # Lets make sure that main options are showed first
    if ($main_pos) {
        splice(@packages, $main_pos, 1);
        unshift(@packages, 'main');
    }
    foreach my $package (@packages) {
        my $package_option_prefix = lc $package;
        $package_option_prefix =~ s/::/-/g;
        if ($package ne 'main') {
            print "\nOptions from: $package\n";
            print "Prepend --$package_option_prefix to use them\n";
        }
        foreach my $opt (keys %{$options{$package}}) {
            my ($option_name, $option_type) = split('=', $opt);
            # Perhaps option is a + or a !?
            if (substr($option_name, -1, 1) eq '!') {
                $option_type = '!';
                $option_name =~ s/!//;
            } elsif(substr($option_name, -1, 1) eq '+') {
                $option_type = '+';
                $option_name =~ s/\+//;
            }
            if (!defined $option_type) {
                $option_type = '';
            }
            $option_name=~ s/[\!,\+]//g;
            my @aliases = split('\|', $option_name);
            foreach (@aliases) {
                my $dash = length $_ eq 1 ? '-' : '--';
                if ($package eq 'main')
                    $_ = "$dash$_";
                } else {
                    $_ = "-$_";
                }
            }
            my $description = $options{$package}{$opt};
            printf "  %-35s", join(', ', @aliases);
            printf "%-10s", $description;
            print "\n";
        }
    }
}

=head2 C<_build_all_options>

Should _never_ be called. It will parse all the options we have right now from
main and other modules and prepare a hash that C<GetOpt::Long->GetOptions> will
use to parse the arguments.
=cut
sub _build_all_options {
    my %get_options;
    foreach my $package (keys %options) {
        foreach my $opt (keys %{$options{$package}}) {
            my $option_name = $opt;
            if ($package ne 'main') {
                $option_name = lc $package;
                $option_name =~ s/::/-/g;
                $option_name = $option_name . '-' . $opt;
            }
            $get_options{$option_name} = 1;
        }
    }
    return %get_options;
}

=head2 C<_get_option_package>

Returns the right option package where the options are going to be stored.

=cut
sub _get_option_package {
    # Look for the real package, it shouldn't be this package
    my ($caller_package, $tries, $max_tries) = ('', 0, 10);
    while($tries ne $max_tries) {
        ($caller_package) = caller($tries);
        if ($caller_package eq __PACKAGE__) {
            $tries += 1;
        } else {
            last;
        }
    }
    if ($caller_package eq __PACKAGE__) {
        return 'main';
    }
    if (!$caller_package) {
        return 'main';
    }
    return $caller_package;
}

1;
