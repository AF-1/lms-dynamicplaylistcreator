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

package Plugins::DynamicPlaylistCreator::ConfigManager::Main;

use strict;
use warnings;
use utf8;

use base qw(Slim::Utils::Accessor);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Plugins::DynamicPlaylistCreator::ConfigManager::TemplateParser;
use Plugins::DynamicPlaylistCreator::ConfigManager::TemplateContentParser;
use Plugins::DynamicPlaylistCreator::ConfigManager::DirectoryLoader;
use Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler;
use Plugins::DynamicPlaylistCreator::ConfigManager::PlaylistWebPageMethods;
use FindBin qw($Bin);
use File::Spec::Functions qw(:ALL);

__PACKAGE__->mk_accessor(rw => qw(pluginVersion contentDirectoryHandler templateContentDirectoryHandler templateDirectoryHandler templateDataDirectoryHandler contentPluginHandler templatePluginHandler parameterHandler templateParser contentParser templateContentParser webPageMethods addSqlErrorCallback templates items));

my $log = logger('plugin.dynamicplaylistcreator');
my $prefs = preferences('plugin.dynamicplaylistcreator');

sub new {
	my ($class, $parameters) = @_;
	my $self = $class->SUPER::new();

	$self->pluginVersion($parameters->{'pluginVersion'});
	$self->addSqlErrorCallback($parameters->{'addSqlErrorCallback'});
	$self->init();

	return $self;
}

sub init {
	my $self = shift;
	$self->templateParser(Plugins::DynamicPlaylistCreator::ConfigManager::TemplateParser->new());

	my %parameters = (
		'criticalErrorCallback' => $self->addSqlErrorCallback,
		'parameterPrefix' => 'itemparameter'
	);
	$self->parameterHandler(Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler->new(\%parameters));

	my %directoryHandlerParameters = (
		'pluginVersion' => $self->pluginVersion,
	);

	$directoryHandlerParameters{'extension'} = "sql.xml";
	$directoryHandlerParameters{'identifierExtension'} = "sql.xml";
	$directoryHandlerParameters{'parser'} = $self->templateParser;
	$directoryHandlerParameters{'includeExtensionInIdentifier'} = 1;
	$self->templateDirectoryHandler(Plugins::DynamicPlaylistCreator::ConfigManager::DirectoryLoader->new(\%directoryHandlerParameters));

	$directoryHandlerParameters{'extension'} = "sql.template";
	$directoryHandlerParameters{'identifierExtension'} = "sql.xml";
	$directoryHandlerParameters{'parser'} = $self->contentParser;
	$directoryHandlerParameters{'includeExtensionInIdentifier'} = 1;
	$self->templateDataDirectoryHandler(Plugins::DynamicPlaylistCreator::ConfigManager::DirectoryLoader->new(\%directoryHandlerParameters));

	$self->templateContentParser(Plugins::DynamicPlaylistCreator::ConfigManager::TemplateContentParser->new());

	$directoryHandlerParameters{'extension'} = "customvalues.xml";
	$directoryHandlerParameters{'parser'} = $self->templateContentParser;
	$directoryHandlerParameters{'includeExtensionInIdentifier'} = undef;
	$self->templateContentDirectoryHandler(Plugins::DynamicPlaylistCreator::ConfigManager::DirectoryLoader->new(\%directoryHandlerParameters));

	$self->initWebPageMethods();
}

sub initWebPageMethods {
	my $self = shift;

	my %webTemplates = (
		'webList' => 'plugins/DynamicPlaylistCreator/list.html',
		'webEditItem' => 'plugins/DynamicPlaylistCreator/webpagemethods_edititem.html',
		'webNewItemParameters' => 'plugins/DynamicPlaylistCreator/webpagemethods_newitemparameters.html',
		'webNewItemTypes' => 'plugins/DynamicPlaylistCreator/webpagemethods_newitemtypes.html',
	);

	my @itemDirectories = ();
	my @templateDirectories = ();
	my $dir = $prefs->get("customplaylistfolder");
	if (defined $dir && -d $dir) {
		push @itemDirectories, $dir
	}

	my @pluginDirs = Slim::Utils::OSDetect::dirsFor('Plugins');
	for my $plugindir (@pluginDirs) {
		if (-d catdir($plugindir, "DynamicPlaylistCreator", "Templates")) {
			push @templateDirectories, catdir($plugindir, "DynamicPlaylistCreator", "Templates");
			my @subDirs = ('Songs', 'Artists', 'Albums', 'Genres', 'Years', 'Playlists');
			splice @subDirs, 3, 0, 'Works' if (Slim::Utils::Versions->compareVersions($::VERSION, '9.0') >= 0);
			foreach (@subDirs) {
				push @templateDirectories, catdir($plugindir, "DynamicPlaylistCreator", "Templates", $_);
			}
			main::DEBUGLOG && $log->is_debug && $log->debug('templateDirectories = '.Data::Dump::dump(\@templateDirectories));
		}
	}
	my %webPageMethodsParameters = (
		'pluginVersion' => $self->pluginVersion,
		'extension' => 'sql',
		'simpleExtension' => 'customvalues.xml',
		'contentPluginHandler' => $self->contentPluginHandler,
		'templatePluginHandler' => $self->templatePluginHandler,
		'contentDirectoryHandler' => $self->contentDirectoryHandler,
		'contentTemplateDirectoryHandler' => $self->templateContentDirectoryHandler,
		'templateDirectoryHandler' => $self->templateDirectoryHandler,
		'templateDataDirectoryHandler' => $self->templateDataDirectoryHandler,
		'parameterHandler' => $self->parameterHandler,
		'contentParser' => $self->contentParser,
		'templateDirectories' => \@templateDirectories,
		'itemDirectories' => \@itemDirectories,
		'customItemDirectory' => $prefs->get('customplaylistfolder'),
		'webCallbacks' => $self,
		'webTemplates' => \%webTemplates,
	);
	$self->webPageMethods(Plugins::DynamicPlaylistCreator::ConfigManager::PlaylistWebPageMethods->new(\%webPageMethodsParameters));
}

sub readTemplateConfiguration {
	my ($self, $client) = @_;

	my %templates = ();
	my %globalcontext = ();
	my @pluginDirs = Slim::Utils::OSDetect::dirsFor('Plugins');
	for my $plugindir (@pluginDirs) {
		main::DEBUGLOG && $log->is_debug && $log->debug("Checking for dir: ".catdir($plugindir, "DynamicPlaylistCreator", "Templates"));
		next unless -d catdir($plugindir, "DynamicPlaylistCreator", "Templates");
		$self->templateDirectoryHandler()->readFromDir($client, catdir($plugindir, "DynamicPlaylistCreator", "Templates"), \%templates, \%globalcontext);
	}
	return \%templates;
}

sub readItemConfiguration {
	my ($self, $client, $storeInCache) = @_;

	my $dir = $prefs->get("customplaylistfolder");
	main::DEBUGLOG && $log->is_debug && $log->debug("Searching for item configuration in: $dir");

	my %customItems = ();
	my %globalcontext = ();
	$self->templates($self->readTemplateConfiguration());

	$globalcontext{'templates'} = $self->templates;

	main::DEBUGLOG && $log->is_debug && $log->debug("Checking for dir: $dir");
	if (!defined $dir || !-d $dir) {
		main::DEBUGLOG && $log->is_debug && $log->debug("Skipping custom configuration scan - directory is undefined");
	} else {
		$self->templateContentDirectoryHandler()->readFromDir($client, $dir, \%customItems, \%globalcontext);
	}

	my %localItems = ();
	for my $itemId (keys %customItems) {
		my $item = $customItems{$itemId};
		$localItems{$item->{'id'}} = $item;
	}

	for my $key (keys %localItems) {
		postProcessItem($localItems{$key});
	}

	if ($storeInCache) {
		$self->items(\%localItems);
	}
	my %result = (
		'playlists' => \%localItems,
		'templates' => $self->templates
	);
	return \%result;
}

sub postProcessItem {
	my $item = shift;
	if (defined($item->{'name'})) {
		$item->{'name'} =~ s/\'\'/\'/g;
	}
}

sub webList {
	my ($self, $client, $params) = @_;
	return Plugins::DynamicPlaylistCreator::Plugin::handleWebList($client, $params);
}

sub webEditItem {
	my ($self, $client, $params) = @_;

	if (!defined($self->items)) {
		my $itemConfiguration = $self->readItemConfiguration($client);
		$self->items($itemConfiguration->{'playlists'});
	}
	if (!defined($self->templates)) {
		$self->templates($self->readTemplateConfiguration($client));
	}

	return $self->webPageMethods->webEditItem($client, $params, $params->{'item'}, $self->items, $self->templates);
}

sub webNewItemTypes {
	my ($self, $client, $params) = @_;
	$self->templates($self->readTemplateConfiguration($client));
	return $self->webPageMethods->webNewItemTypes($client, $params, $self->templates);
}

sub webNewItemParameters {
	my ($self, $client, $params) = @_;
	if (!defined($self->templates) || !defined($self->templates->{$params->{'itemtemplate'}})) {
		$self->templates($self->readTemplateConfiguration($client));
	}
	return $self->webPageMethods->webNewItemParameters($client, $params, $params->{'itemtemplate'}, $self->templates);
}

sub webSaveNewItem {
	my ($self, $client, $params) = @_;
	if (!defined($self->templates)) {
		$self->templates($self->readTemplateConfiguration($client));
	}
	$params->{'items'} = $self->items;

	return $self->webPageMethods->webSaveNewItem($client, $params, $params->{'itemtemplate'}, $self->templates);
}

sub webSaveItem {
	my ($self, $client, $params) = @_;
	if (!defined($self->templates)) {
		$self->templates($self->readTemplateConfiguration($client));
	}
	$params->{'items'} = $self->items;

	return $self->webPageMethods->webSaveItem($client, $params, $params->{'itemtemplate'}, $self->templates);
}

sub webRemoveItem {
	my ($self, $client, $params) = @_;
	if (!defined($self->items)) {
		my $itemConfiguration = $self->readItemConfiguration($client);
		$self->items($itemConfiguration->{'playlists'});
	}
	return $self->webPageMethods->webDeleteItem($client, $params, $params->{'item'}, $self->items);
}

sub webPlayItem {
	my ($self, $client, $params) = @_;
	if (!defined($self->items)) {
		my $itemConfiguration = $self->readItemConfiguration($client);
		$self->items($itemConfiguration->{'playlists'});
	}
	return $self->webPageMethods->webPlayItem($client, $params, $params->{'item'}, $self->items);
}

sub webExportItem {
	my ($self, $client, $params) = @_;
	if (!defined($self->items)) {
		my $itemConfiguration = $self->readItemConfiguration($client);
		$self->items($itemConfiguration->{'playlists'});
	}
	return $self->webPageMethods->webExportItem($client, $params, $params->{'item'}, $self->items);
}

1;
