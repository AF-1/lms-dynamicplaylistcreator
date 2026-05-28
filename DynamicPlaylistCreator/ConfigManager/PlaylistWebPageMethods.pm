#
# Dynamic Playlist Creator
# (c) 2022 AF
# Licensed under the GPLv3 - see LICENSE file
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
