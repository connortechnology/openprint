# ==========================================================================
#
# ZoneMinder Zone Module
# Copyright (C) 2020 ZoneMinder LLC
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# ==========================================================================

package openprint::Model;

use strict;
use warnings;

require openprint::Object;
require openprint::Manufacturer;

use parent qw(openprint::Object);

use vars qw/ $table $primary_key %fields $serial %defaults $debug %transforms/;
$table = 'models';
$serial = $primary_key = 'id';
%fields = map { $_ => $_ } qw(
  id
  name
  manufacturer_id
  );

%defaults = (
  name                => '',
);

%transforms = (
		name	=> [ 's/^\s+//', 's/\s+$//', 's/\s\s+/ /g' ],
);

sub save {
  my $self = shift;

  my $manufacturer = $self->Manufacturer();

  if ($manufacturer->name() and !$self->manufacturer_id()) {
    if ($manufacturer->save()) {
      $$self{manufacturer_id} = $manufacturer->id();
    }
  }

  my $error = $self->SUPER::save( );
  return $error;
} # end sub save

sub Manufacturer {
  my $self = shift;
  $$self{Manufacturer} = shift if @_;
  if (!$$self{Manufacturer}) {
    $$self{Manufacturer} = new openprint::Manufacturer($$self{manufacturer_id});
  }
  return $$self{Manufacturer};
}

1;
__END__
