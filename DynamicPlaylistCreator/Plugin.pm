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

package Plugins::DynamicPlaylistCreator::Plugin;

use strict;
use warnings;
use utf8;

use base qw(Slim::Plugin::Base);
use Slim::Schema;
use Slim::Utils::Prefs;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use File::Spec::Functions qw(:ALL);
use Data::Dumper;
use FindBin qw($Bin);

use Plugins::DynamicPlaylistCreator::Settings;
use Plugins::DynamicPlaylistCreator::ConfigManager::Main;

my $playLists = undef;
my $playListTypes = undef;
my $sqlerrors = '';
my $configManager = undef;
my $pluginVersion = undef;

my $prefs = preferences('plugin.dynamicplaylistcreator');
my $serverPrefs = preferences('server');
my $log = Slim::Utils::Log->addLogCategory({
	'category' => 'plugin.dynamicplaylistcreator',
	'defaultLevel' => 'WARN',
	'description' => 'PLUGIN_DYNAMICPLAYLISTCREATOR',
});

sub initPlugin {
	my $class = shift;
	$class->SUPER::initPlugin(@_);
	$pluginVersion = Slim::Utils::PluginManager->dataForPlugin($class)->{'version'};

	initPrefs();
	if (!$::noweb) {
		Plugins::DynamicPlaylistCreator::Settings->new($class);
	}
}

sub initPrefs {
	$prefs->init({
		customdirparentfolderpath => $serverPrefs->get('playlistdir'),
	});

	createCustomPlaylistFolder();

	$prefs->setValidate(sub {
		return if (!$_[1] || !(-d $_[1]) || (main::ISWINDOWS && !(-d Win32::GetANSIPathName($_[1]))) || !(-d Slim::Utils::Unicode::encode_locale($_[1])));
		my $customPlaylistFolder = catdir($_[1], 'DynamicPlaylistCreator');
		eval {
			mkdir($customPlaylistFolder, 0755) unless (-d $customPlaylistFolder);
			chdir($customPlaylistFolder);
		} or do {
			$log->warn("Could not create or access dynamic playlists folder in parent folder '$_[1]'!");
			return;
		};
		$prefs->set('customplaylistfolder', $customPlaylistFolder);
		return 1;
	}, 'customdirparentfolderpath');
}

sub initPlayLists {
	my $client = shift;
	my @pluginDirs = ();

	my $itemConfiguration = getConfigManager()->readItemConfiguration($client, 1);
	$playLists = $itemConfiguration->{'playlists'};

	# Refresh list of playlists in DPL3
	if (defined($client)) {
		$log->debug(('Tell DPL3 to refresh list of dynamic playlists'));
		my $request = $client->execute(['dynamicplaylist', 'refreshplaylists']);
		$request->source('PLUGIN_DYNAMICPLAYLISTCREATOR');
	}
	$log->debug('playlists = '.Dumper($playLists));
}

sub getConfigManager {
	if (!defined($configManager)) {
		my %parameters = (
			'pluginVersion' => $pluginVersion,
			'addSqlErrorCallback' => undef,
		);
		$configManager = Plugins::DynamicPlaylistCreator::ConfigManager::Main->new(\%parameters);
	}
	return $configManager;
}


### web pages

sub webPages {
	my %pages = (
		"DynamicPlaylistCreator/list.html" => \&handleWebList,
		"DynamicPlaylistCreator/webpagemethods_edititem.html" => \&handleWebEditPlaylist,
		"DynamicPlaylistCreator/webpagemethods_newitemtypes.html" => \&handleWebNewPlaylistTypes,
		"DynamicPlaylistCreator/webpagemethods_deleteitemtype.html" => \&handleWebDeletePlaylistType,
		"DynamicPlaylistCreator/webpagemethods_newitemparameters.html" => \&handleWebNewPlaylistParameters,
		"DynamicPlaylistCreator/webpagemethods_newitem.html" => \&handleWebNewPlaylist,
		"DynamicPlaylistCreator/webpagemethods_savenewsimpleitem.html" => \&handleWebSaveNewSimplePlaylist,
		"DynamicPlaylistCreator/webpagemethods_savesimpleitem.html" => \&handleWebSaveSimplePlaylist,
		"DynamicPlaylistCreator/webpagemethods_saveitem.html" => \&handleWebSavePlaylist,
		"DynamicPlaylistCreator/webpagemethods_savenewitem.html" => \&handleWebSaveNewPlaylist,
		"DynamicPlaylistCreator/webpagemethods_removeitem.html" => \&handleWebRemovePlaylist,
	);
	for my $page (keys %pages) {
		Slim::Web::Pages->addPageFunction($page, $pages{$page});
	}

	Slim::Web::Pages->addPageLinks("plugins", {'PLUGIN_DYNAMICPLAYLISTCREATOR' => 'plugins/DynamicPlaylistCreator/list.html'});
}

sub handleWebList {
	my ($client, $params) = @_;
	my $playlist = undef;

	clearCache();
	initPlayLists($client);

	my @webPlaylists = ();
	for my $key (keys %{$playLists}) {
		$playLists->{$key}->{'name'} = $playLists->{$key}->{'name'}.'&nbsp;&nbsp;[customized SQLite]' if !$playLists->{$key}->{'simple'};
		push @webPlaylists, $playLists->{$key};
	}
	@webPlaylists = sort {uc($a->{'name'}) cmp uc($b->{'name'})} @webPlaylists;

	$params->{'nocustomdynamicplaylists'} = 1 if (scalar @webPlaylists == 0);
	$params->{'pluginDynamicPlaylistCreatorPlayLists'} = \@webPlaylists;

	return Slim::Web::HTTP::filltemplatefile('plugins/DynamicPlaylistCreator/list.html', $params);
}

sub handleWebEditPlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webEditItem($client, $params);
}

sub handleWebNewPlaylistTypes {
	my ($client, $params) = @_;
	return getConfigManager()->webNewItemTypes($client, $params);
}

sub handleWebNewPlaylistParameters {
	my ($client, $params) = @_;
	return getConfigManager()->webNewItemParameters($client, $params);
}

sub handleWebNewPlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webNewItem($client, $params);
}

sub handleWebSaveSimplePlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webSaveSimpleItem($client, $params);
}

sub handleWebRemovePlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webRemoveItem($client, $params);
}

sub handleWebSaveNewSimplePlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webSaveNewSimpleItem($client, $params);
}

sub handleWebSaveNewPlaylist {
	my ($client, $params) = @_;
	if (!defined($params->{'pluginWebPageMethodsError'})) {
		return getConfigManager()->webSaveNewItem($client, $params);
	} else {
		return Slim::Web::HTTP::filltemplatefile('plugins/DynamicPlaylistCreator/webpagemethods_newitem.html', $params);
	}
}

sub handleWebSavePlaylist {
	my ($client, $params) = @_;
	if (!defined($params->{'pluginWebPageMethodsError'})) {
		return getConfigManager()->webSaveItem($client, $params);
	} else {
		return Slim::Web::HTTP::filltemplatefile('plugins/DynamicPlaylistCreator/webpagemethods_edititem.html', $params);
	}
}



sub createCustomPlaylistFolder {
	my $customPlaylistFolder_parentfolderpath = $prefs->get('customdirparentfolderpath') || $serverPrefs->get('playlistdir');
	my $customPlaylistFolder = catdir($customPlaylistFolder_parentfolderpath, 'DynamicPlaylistCreator');
	eval {
		mkdir($customPlaylistFolder, 0755) unless (-d $customPlaylistFolder);
		chdir($customPlaylistFolder);
	} or do {
		$log->error("Could not create or access DynamicPlaylistCreator folder in parent folder '$customPlaylistFolder_parentfolderpath'!");
		return;
	};
	$prefs->set('customplaylistfolder', $customPlaylistFolder);
}

sub getVirtualLibraries {
	my (@items, @hiddenVLs);
	my $libraries = Slim::Music::VirtualLibraries->getLibraries();
	$log->debug('ALL virtual libraries: '.Dumper($libraries));

	while (my ($key, $values) = each %{$libraries}) {
		my $count = Slim::Utils::Misc::delimitThousands(Slim::Music::VirtualLibraries->getTrackCount($key)) + 0;
		my $name = $values->{'name'};
		my $persistentVLID = $values->{'id'};
		$log->debug('VL: '.$name.' ('.$count.')');

		push @items, {
			name => Slim::Utils::Unicode::utf8decode($name, 'utf8').' ('.$count.($count == 1 ? ' track)' : ' tracks)'),
			sortName => Slim::Utils::Unicode::utf8decode($name, 'utf8'),
			value => $persistentVLID,
			id => $persistentVLID,
		};
	}
	if (scalar @items == 0) {
		push @items, {
			name => 'No virtual libraries found',
			value => '',
			id => '',
		};
	}

	if (scalar @items > 1) {
		@items = sort {lc($a->{sortName}) cmp lc($b->{sortName})} @items;
	}
	return \@items;
}

sub clearCache {
	my $cacheVersion = $pluginVersion;
	$cacheVersion =~ s/^.*\.([^\.]+)$/$1/;
	my $cache = Slim::Utils::Cache->new("PluginCache/DynamicPlaylistCreator", $cacheVersion);
	$cache->clear();
}

*escape = \&URI::Escape::uri_escape_utf8;

sub unescape {
	my ($in, $isParam) = @_;
	$in =~ s/\+/ /g if $isParam;
	$in =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	return $in;
}

1;
