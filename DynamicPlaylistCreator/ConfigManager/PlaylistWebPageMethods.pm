#
# Dynamic Playlist Creator
#
# (c) 2022 AF-1
#
# Some code based on the SQLPlayList plugin (c) 2006 Erland Isaksson
#
# GPLv3 license
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#

package Plugins::DynamicPlaylistCreator::ConfigManager::PlaylistWebPageMethods;

use strict;
use Plugins::DynamicPlaylistCreator::ConfigManager::WebPageMethods;
our @ISA = qw(Plugins::DynamicPlaylistCreator::ConfigManager::WebPageMethods);

use Slim::Utils::Strings qw(string);

sub new {
	my $class = shift;
	my $parameters = shift;

	my $self = $class->SUPER::new($parameters);
	return $self;
}

1;
