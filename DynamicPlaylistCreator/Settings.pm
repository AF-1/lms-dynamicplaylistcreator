#
# Dynamic Playlist Creator
# (c) 2022 AF
# Licensed under the GPLv3 - see LICENSE file
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
	return ($prefs, qw(customdirparentfolderpath displayplaybtn displayexportbtn hidedplrefreshmsg exacttitlesearch));
}

sub handler {
	my ($class, $client, $paramRef) = @_;
	my $result = undef;
	my $callHandler = 1;
	if ($paramRef->{'saveSettings'}) {
		$result = $class->SUPER::handler($client, $paramRef);
		Plugins::DynamicPlaylistCreator::Plugin::getConfigManager()->initWebPageMethods();
		$callHandler = 0;
	}
	if ($paramRef->{'refreshcachesnow'}) {
		if ($callHandler) {
			$result = $class->SUPER::handler($client, $paramRef);
		}
		Plugins::DynamicPlaylistCreator::Plugin::refreshSQLCache();
	} elsif ($callHandler) {
		$result = $class->SUPER::handler($client, $paramRef);
	}
	return $result;
}

1;
