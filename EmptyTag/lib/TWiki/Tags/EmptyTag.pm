# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the Foswiki root.
#
# '$Rev$'

=pod

---+ package EmptyTag

This is an empty Foswiki tag. It is a fully defined tag, but is
disabled by default in a Foswiki installation. Use it as a template
for your own tags; see %SYSTEMWEB%.Macros for details.

=cut

# Always use strict to enforce variable scoping
use strict;

# Must be in Foswiki package
package TWiki;

use vars qw($tagname);

#
# By default, the tag will be the name of the module with "Tag.pm" stripped off.
# So, for example, EmptyTag.pm would have a default tag of 'Empty'
# If you want to user a different tag, uncomment and define $tagname to that
# ((and name the function the same!)
#
#$tagname='EMPTY';

sub Empty {
    return "";
}

return 1;
