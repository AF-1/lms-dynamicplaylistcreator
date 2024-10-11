#
# Dynamic Playlist Creator
#
# (c) 2022 AF
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
use FindBin qw($Bin);

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
	'defaultLevel' => 'ERROR',
	'description' => 'PLUGIN_DYNAMICPLAYLISTCREATOR',
});
my $cache = Slim::Utils::Cache->new();

sub initPlugin {
	my $class = shift;
	$class->SUPER::initPlugin(@_);
	$pluginVersion = Slim::Utils::PluginManager->dataForPlugin($class)->{'version'};

	initPrefs();
	if (main::WEBUI) {
		require Plugins::DynamicPlaylistCreator::Settings;
		Plugins::DynamicPlaylistCreator::Settings->new($class);
	}

	Slim::Control::Request::subscribe(\&refreshSQLCache, [['rescan'], ['done']]);
}

sub initPrefs {
	$prefs->init({
		customdirparentfolderpath => Slim::Utils::OSDetect::dirsFor('prefs'),
	});

	createCustomPlaylistFolder();

	$prefs->setValidate(sub {
		return if (!$_[1] || !(-d $_[1]) || (main::ISWINDOWS && !(-d Win32::GetANSIPathName($_[1]))) || !(-d Slim::Utils::Unicode::encode_locale($_[1])));
		my $customPlaylistFolder = catdir($_[1], 'DynamicPlaylistCreator');
		eval {
			mkdir($customPlaylistFolder, 0755) unless (-d $customPlaylistFolder);
		} or do {
			$log->error("Could not create dynamic playlists folder in parent folder '$_[1]'! Please make sure that LMS has read/write permissions (755) for the parent folder.");
			return;
		};
		$prefs->set('customplaylistfolder', $customPlaylistFolder);
		return 1;
	}, 'customdirparentfolderpath');
}

sub postinitPlugin {
	my $class = shift;

	unless (!Slim::Schema::hasLibrary() || Slim::Music::Import->stillScanning) {
		my $cachePluginVersion = $cache->get('dplc_pluginversion');
		main::DEBUGLOG && $log->is_debug && $log->debug('current plugin version = '.$pluginVersion.' -- cached plugin version = '.Data::Dump::dump($cachePluginVersion));

		refreshSQLCache() if (!$cachePluginVersion || $cachePluginVersion ne $pluginVersion || !$cache->get('dplc_contributorlist_all') || !$cache->get('dplc_contributorlist_albumartists') || !$cache->get('dplc_contributorlist_composers') || !$cache->get('dplc_genrelist') || !$cache->get('dplc_contenttypes') || !$cache->get('dplc_releasetypes') || ((Slim::Utils::Versions->compareVersions($::VERSION, '9.0') >= 0) && !$cache->get('dplc_worklist')));
	}
}

sub initPlayLists {
	my $client = shift;
	my @pluginDirs = ();

	my $itemConfiguration = getConfigManager()->readItemConfiguration($client, 1);
	$playLists = $itemConfiguration->{'playlists'};

	# Refresh list of dynamic playlists in DPL
	if (defined($client)) {
		Slim::Utils::Timers::setTimer($client, Time::HiRes::time() + 2, \&refreshDPLplaylists);
	}
	main::DEBUGLOG && $log->is_debug && $log->debug('playlists = '.Data::Dump::dump($playLists));
}

sub getConfigManager {
	if (!defined($configManager)) {
		my %parameters = (
			'pluginVersion' => $pluginVersion,
			'addSqlErrorCallback' => undef
		);
		$configManager = Plugins::DynamicPlaylistCreator::ConfigManager::Main->new(\%parameters);
	}
	return $configManager;
}

sub refreshDPLplaylists {
	my $client = shift;

	Slim::Utils::Timers::killTimers($client, \&refreshDPLplaylists);
	main::DEBUGLOG && $log->is_debug && $log->debug('Tell DPL to refresh list of dynamic playlists');
	my $request = $client->execute(['dynamicplaylist', 'refreshplaylists']);
	$request->source('PLUGIN_DYNAMICPLAYLISTCREATOR');
}

### web pages

sub webPages {
	my %pages = (
		"DynamicPlaylistCreator/list.html" => \&handleWebList,
		"DynamicPlaylistCreator/webpagemethods_edititem.html" => \&handleWebEditPlaylist,
		"DynamicPlaylistCreator/webpagemethods_newitemtypes.html" => \&handleWebNewPlaylistTypes,
		"DynamicPlaylistCreator/webpagemethods_deleteitemtype.html" => \&handleWebDeletePlaylistType,
		"DynamicPlaylistCreator/webpagemethods_newitemparameters.html" => \&handleWebNewPlaylistParameters,
		"DynamicPlaylistCreator/webpagemethods_savenewitem.html" => \&handleWebSaveNewPlaylist,
		"DynamicPlaylistCreator/webpagemethods_saveitem.html" => \&handleWebSavePlaylist,
		"DynamicPlaylistCreator/webpagemethods_removeitem.html" => \&handleWebRemovePlaylist,
		"DynamicPlaylistCreator/webpagemethods_playitem.html" => \&handleWebStartPlaylist,
		"DynamicPlaylistCreator/webpagemethods_exportitem.html" => \&handleWebExportPlaylist,
	);
	for my $page (keys %pages) {
		Slim::Web::Pages->addPageFunction($page, $pages{$page});
	}

	Slim::Web::Pages->addPageLinks("plugins", {'PLUGIN_DYNAMICPLAYLISTCREATOR' => 'plugins/DynamicPlaylistCreator/list.html'});
}

sub handleWebList {
	my ($client, $params) = @_;

	initPlayLists($client);

	my @webPlaylists = ();
	for my $key (keys %{$playLists}) {
		push @webPlaylists, $playLists->{$key};
	}
	@webPlaylists = sort {uc($a->{'name'}) cmp uc($b->{'name'})} @webPlaylists;

	my $dir = $prefs->get('customplaylistfolder');
	if (!defined $dir || !-d $dir) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_CUSTOMDIR');
		my $customPlaylistFolder_parentfolderpath = $prefs->get('customdirparentfolderpath');
		$log->error("Could not create or access DynamicPlaylistCreator folder in parent folder '$customPlaylistFolder_parentfolderpath'! Please make sure that LMS has read/write permissions (755) for the parent folder.");
	}

	$params->{'nocustomdynamicplaylists'} = 1 if (scalar @webPlaylists == 0);
	$params->{'displayplaybtn'} = $prefs->get('displayplaybtn');
	$params->{'displayexportbtn'} = $prefs->get('displayexportbtn');
	$params->{'hidedplrefreshmsg'} = $prefs->get('hidedplrefreshmsg');
	$params->{'pluginDynamicPlaylistCreatorPlayLists'} = \@webPlaylists;
	main::DEBUGLOG && $log->is_debug && $log->debug('webPlaylists = '.Data::Dump::dump(\@webPlaylists));
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

sub handleWebSaveNewPlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webSaveNewItem($client, $params);
}

sub handleWebSavePlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webSaveItem($client, $params);
}

sub handleWebRemovePlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webRemoveItem($client, $params);
}

sub handleWebStartPlaylist {
	my ($client, $params) = @_;
	my $dpl = $params->{'item'};
	return unless $client && $dpl;
	main::DEBUGLOG && $log->is_debug && $log->debug('Tell DPL to play dynamic playlist "'.$dpl.'"');
	my $request = $client->execute(['dynamicplaylist', 'playlist', 'play', 'dplccustom_'.$dpl]);
	$request->source('PLUGIN_DYNAMICPLAYLISTCREATOR');
	return getConfigManager()->webPlayItem($client, $params);
}

sub handleWebExportPlaylist {
	my ($client, $params) = @_;
	return getConfigManager()->webExportItem($client, $params);
}

sub createCustomPlaylistFolder {
	my $customPlaylistFolder_parentfolderpath = $prefs->get('customdirparentfolderpath') || Slim::Utils::OSDetect::dirsFor('prefs');
	my $customPlaylistFolder = catdir($customPlaylistFolder_parentfolderpath, 'DynamicPlaylistCreator');
	eval {
		mkdir($customPlaylistFolder, 0755) unless (-d $customPlaylistFolder);
	} or do {
		$log->error("Could not create DynamicPlaylistCreator folder in parent folder '$customPlaylistFolder_parentfolderpath'! Please make sure that LMS has read/write permissions (755) for the parent folder.");
		return;
	};
	$prefs->set('customplaylistfolder', $customPlaylistFolder);
}

sub getVirtualLibraries {
	my (@items, @hiddenVLs);
	my $libraries = Slim::Music::VirtualLibraries->getLibraries();
	main::DEBUGLOG && $log->is_debug && $log->debug('ALL virtual libraries: '.Data::Dump::dump($libraries));

	while (my ($key, $values) = each %{$libraries}) {
		my $count = Slim::Music::VirtualLibraries->getTrackCount($key);
		my $name = $values->{'name'};
		my $displayName = Slim::Utils::Unicode::utf8decode($name, 'utf8').' ('.Slim::Utils::Misc::delimitThousands($count).($count == 1 ? ' track' : ' tracks').')';
		main::DEBUGLOG && $log->is_debug && $log->debug("VL: ".$displayName);
		my $persistentVLID = $values->{'id'};

		push @items, {
			name => $displayName,
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

sub refreshSQLCache {
	main::DEBUGLOG && $log->is_debug && $log->debug('Deleting old caches and creating new ones');
	$cache->remove('dplc_pluginversion');
	$cache->remove('dplc_contributorlist_all');
	$cache->remove('dplc_contributorlist_albumartists');
	$cache->remove('dplc_contributorlist_composers');
	$cache->remove('dplc_genrelist');
	$cache->remove('dplc_contenttypes');
	$cache->remove('dplc_releasetypes');
	$cache->remove('dplc_worklist');

	my $contributorSQL_all = "select contributors.id,contributors.name,contributors.namesearch from tracks,contributor_track,contributors where tracks.id=contributor_track.track and contributor_track.contributor=contributors.id and contributor_track.role in (1,5,6) group by contributors.id order by contributors.namesort asc";
	my $contributorSQL_albumartists = "select contributors.id,contributors.name,contributors.namesearch from tracks,contributor_track,contributors where tracks.id=contributor_track.track and contributor_track.contributor=contributors.id and contributor_track.role in (1,5) group by contributors.id order by contributors.namesort asc";
	my $contributorSQL_composers = "select contributors.id,contributors.name,contributors.namesearch from tracks,contributor_track,contributors where tracks.id=contributor_track.track and contributor_track.contributor=contributors.id and contributor_track.role = 2 group by contributors.id order by contributors.namesort asc";
	my $genreSQL = "select genres.id,genres.name,genres.namesearch from genres order by namesort asc";
	my $contentTypesSQL = "select distinct tracks.content_type,tracks.content_type,tracks.content_type from tracks where tracks.content_type is not null and tracks.content_type != 'cpl' and tracks.content_type != 'src' and tracks.content_type != 'ssp' and tracks.content_type != 'dir' order by tracks.content_type asc";
	my $releaseTypesSQL = "select distinct albums.release_type,albums.release_type,albums.release_type from albums order by albums.release_type asc";
	my $workSQL = "select works.id,works.title,works.titlesearch from works join tracks on works.id = tracks.work where tracks.work is not null group by works.id order by works.titlesort asc";

	my $contributorList_all = Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler::getSQLTemplateData(undef, $contributorSQL_all);
	$cache->set('dplc_contributorlist_all', $contributorList_all, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('contributorList_all count = '.scalar(@{$contributorList_all}));

	my $contributorList_albumartists = Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler::getSQLTemplateData(undef, $contributorSQL_albumartists);
	$cache->set('dplc_contributorlist_albumartists', $contributorList_albumartists, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('contributorList_albumartists count = '.scalar(@{$contributorList_albumartists}));

	my $contributorList_composers = Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler::getSQLTemplateData(undef, $contributorSQL_composers);
	$cache->set('dplc_contributorlist_composers', $contributorList_composers, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('contributorList_composers count = '.scalar(@{$contributorList_composers}));

	my $genreList = Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler::getSQLTemplateData(undef, $genreSQL);
	$cache->set('dplc_genrelist', $genreList, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('genreList count = '.scalar(@{$genreList}));

	my $contentTypesList = Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler::getSQLTemplateData(undef, $contentTypesSQL);
	$cache->set('dplc_contenttypes', $contentTypesList, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('contentTypesList count = '.scalar(@{$contentTypesList}));

	my $releaseTypesList = Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler::getSQLTemplateData(undef, $releaseTypesSQL);
	foreach my $releaseType (@{$releaseTypesList}) {
		$releaseType->{'name'} = _releaseTypeName($releaseType->{'name'});
	}
	$cache->set('dplc_releasetypes', $releaseTypesList, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('releaseTypesList count = '.scalar(@{$releaseTypesList}));

	if (Slim::Utils::Versions->compareVersions($::VERSION, '9.0') >= 0) {
		my $workList = Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler::getSQLTemplateData(undef, $workSQL);
		$cache->set('dplc_worklist', $workList, 'never');
		main::DEBUGLOG && $log->is_debug && $log->debug('workList count = '.scalar(@{$workList}));
	}

	$cache->set('dplc_pluginversion', $pluginVersion);
}

sub _releaseTypeName {
	my $releaseType = shift;

	my $nameToken = uc($releaseType);
	$nameToken =~ s/[^a-z_0-9]/_/ig;
	my $name;
	foreach ('RELEASE_TYPE_' . $nameToken, 'RELEASE_TYPE_CUSTOM_' . $nameToken, $nameToken) {
		$name = string($_) if Slim::Utils::Strings::stringExists($_);
		last if $name;
	}
	return $name || $releaseType;
}

1;
