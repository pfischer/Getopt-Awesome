#
# ImportAllFoos
#
# Created: 10/07/2009 09:18:20 AM
package ImportAllFoos;

use strict;
use warnings;

use Foo;
use Foo::ChildFoo;
use Foo::ChildFoo::GrandchildFoo;
use Getopt::Awesome qw(:common);

sub test_this_foo {
    print "Calling ChildFoo::test:\n";
    Foo::ChildFoo->test;
    print "Gettings the example value of ChildFoo frm ImportAllFoos:\n";
    print get_opt('Foo::ChildFoo::example') . "\n";
    print "Now setting the value from ImportallFoos:\n";
    set_opt('Foo::ChildFoo::example', 'new value');
    print "Getting the value we just set...\n";
    print get_opt('Foo::ChildFoo::example') . "\n";
}
1;



