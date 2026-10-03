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
use Slim::Utils::Prefs;

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_DYNAMICPLAYLISTCREATOR');
}

sub page {
	return 'plugins/DynamicPlaylistCreator/settings/settings.html';
}

sub prefs {
	return (preferences('plugin.dynamicplaylistcreator'), qw(customdirparentfolderpath displayplaybtn displayexportbtn hidedplrefreshmsg exacttitlesearch));
}

1;
