#
# Foo::ChildFoo
#
# Created: 10/07/2009 09:07:46 AM
package Foo::ChildFoo;

use strict;
use warnings;
use base qw(Foo);
use Getopt::Awesome qw(:common);

define_option('example=s', 'An example from first child');

sub test {
    print get_opt('example') . "\n";
}

1;



