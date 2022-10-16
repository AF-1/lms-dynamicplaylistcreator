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

package Plugins::DynamicPlaylistCreator::Settings;

use strict;
use warnings;
use utf8;

use base qw(Slim::Web::Settings);

use File::Basename;
use File::Next;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Misc;
use Slim::Utils::Strings;

my $log = logger('plugin.dynamicplaylistcreator');
my $prefs = preferences('plugin.dynamicplaylistcreator');

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_DYNAMICPLAYLISTCREATOR');
}

sub page {
	return 'plugins/DynamicPlaylistCreator/settings/settings.html';
}

sub prefs {
	return ($prefs, qw(customdirparentfolderpath disableconflictcheck));
}

sub handler {
	my ($class, $client, $paramRef) = @_;

	my $result = $class->SUPER::handler($client, $paramRef);
	if ($paramRef->{'saveSettings'}) {
		Plugins::DynamicPlaylistCreator::Plugin::getConfigManager()->initWebPageMethods();
	}
	return $result;
}

1;
