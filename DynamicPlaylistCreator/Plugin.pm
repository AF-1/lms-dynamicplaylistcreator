#
# Dynamic Playlist Creator
# (c) 2022 AF
# Licensed under the GPLv3 - see LICENSE file
#

package Plugins::DynamicPlaylistCreator::Plugin;

use strict;
use warnings;
use utf8;

use base qw(Slim::Plugin::Base);
use Slim::Schema;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use File::Basename qw(basename);
use File::Slurp qw(read_file);
use File::Spec::Functions qw(catdir catfile);
use HTML::Entities qw(encode_entities decode_entities);
use Time::Local qw(timelocal);
use XML::Simple qw(XMLin);

my $prefs = preferences('plugin.dynamicplaylistcreator');
my $log = Slim::Utils::Log->addLogCategory({
	'category' => 'plugin.dynamicplaylistcreator',
	'defaultLevel' => 'ERROR',
	'description' => 'PLUGIN_DYNAMICPLAYLISTCREATOR',
});
my $cache = Slim::Utils::Cache->new();

my $pluginVersion;
my $templates; # cached template definitions
my $playLists; # cached dynamic playlists created with DPLC
my $templateHandler; # Template Toolkit object, created on first use
my $unsafeChars = "&<>'\"";

my %largeFields = map {$_ => 50} qw(playlistname playlistgroups albumsearchtitle1 albumsearchtitle2 albumsearchtitle3 tracksearchtitle1 tracksearchtitle2 tracksearchtitle3 filepath1 filepath2 filepath3 clistartcmd1 clistartcmd2 clistartcmd3 clistartcmd4 clistopcmd1 clistopcmd2 clistopcmd3 clistopcmd4);
my %mediumFields = map {$_ => 35} qw(commentssearchstring1 commentssearchstring2 commentssearchstring3);
my %smallFields = map {$_ => 5} qw(nooftracks noofartists noofalbums noofgenres noofplaylists noofyears minlength maxlength minyear maxyear minartisttracks minalbumtracks mingenretracks minplaylisttracks minyeartracks minbitrate maxbitrate minsamplerate maxsamplerate minsamplesize maxsamplesize minbpm maxbpm skipcount maxskipcount minplaycount maxplaycount);
my %cachedListKeys;

sub initPlugin {
	my $class = shift;
	$class->SUPER::initPlugin(@_);
	$pluginVersion = Slim::Utils::PluginManager->dataForPlugin($class)->{'version'};

	initPrefs();
	if (main::WEBUI) {
		require Plugins::DynamicPlaylistCreator::Settings;
		Plugins::DynamicPlaylistCreator::Settings->new($class);
		_getTemplates();
	}

	Slim::Control::Request::subscribe(\&_setRefreshCBTimer, [['rescan'], ['done']]);
}

sub initPrefs {
	$prefs->init({
		customdirparentfolderpath => Slim::Utils::OSDetect::dirsFor('prefs'),
	});

	createCustomPlaylistFolder();

	$prefs->setValidate(sub {
		return if (!$_[1] || !(-d $_[1]) || (main::ISWINDOWS && !(-d Win32::GetANSIPathName($_[1]))) || !(-d Slim::Utils::Unicode::encode_locale($_[1])));
		return createCustomPlaylistFolder($_[1]);
	}, 'customdirparentfolderpath');

	# parameter types whose values come from the plugin caches
	%cachedListKeys = (
		'contributorlistcachedall' => 'dplc_contributorlist_all',
		'contributorlistcachedalbumartists' => 'dplc_contributorlist_albumartists',
		'contributorlistcachedcomposers' => 'dplc_contributorlist_composers',
		'genrelistcached' => 'dplc_genrelist',
		'contenttypelistcached' => 'dplc_contenttypes',
		'releasetypelistcached' => 'dplc_releasetypes',
		'worklistcached' => 'dplc_worklist',
	);
}

sub postinitPlugin {
	return unless Slim::Schema::hasLibrary() && !Slim::Music::Import->stillScanning;

	my $cachePluginVersion = $cache->get('dplc_pluginversion');
	main::DEBUGLOG && $log->is_debug && $log->debug('current plugin version = '.$pluginVersion.' -- cached plugin version = '.Data::Dump::dump($cachePluginVersion));

	# the work list cache only exists on LMS 9.0 and newer
	my @cacheKeys = values %cachedListKeys;
	@cacheKeys = grep {$_ ne 'dplc_worklist'} @cacheKeys if Slim::Utils::Versions->compareVersions($::VERSION, '9.0') < 0;
	refreshSQLCache() if !$cachePluginVersion || $cachePluginVersion ne $pluginVersion || grep {!$cache->get($_)} @cacheKeys;
}

sub createCustomPlaylistFolder {
	my $parentFolder = shift || $prefs->get('customdirparentfolderpath') || Slim::Utils::OSDetect::dirsFor('prefs');
	my $customPlaylistFolder = catdir($parentFolder, 'DynamicPlaylistCreator');
	if (!-d $customPlaylistFolder && !mkdir($customPlaylistFolder, 0755)) {
		$log->error("Could not create DynamicPlaylistCreator folder in parent folder '$parentFolder'! Please make sure that LMS has read/write permissions (755) for the parent folder: $!");
		return;
	}
	$prefs->set('customplaylistfolder', $customPlaylistFolder);
	return 1;
}

sub refreshDPLplaylists {
	my $client = shift;

	Slim::Utils::Timers::killTimers($client, \&refreshDPLplaylists);
	main::DEBUGLOG && $log->is_debug && $log->debug('Tell DPL to refresh list of dynamic playlists');
	$client->execute(['dynamicplaylist', 'refreshplaylists'])->source('PLUGIN_DYNAMICPLAYLISTCREATOR');
}



### web pages

sub webPages {
	my %pages = (
		"DynamicPlaylistCreator/list.html" => \&handleWebList,
		"DynamicPlaylistCreator/webpagemethods_edititem.html" => \&handleWebEditPlaylist,
		"DynamicPlaylistCreator/webpagemethods_newitemtypes.html" => \&handleWebNewPlaylistTypes,
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

	$playLists = readPlaylistValues();

	# tell DPL to refresh its list of dynamic playlists
	if (defined($client)) {
		Slim::Utils::Timers::setTimer($client, Time::HiRes::time() + 2, \&refreshDPLplaylists);
	}

	my @webPlaylists = sort {uc($a->{'name'}) cmp uc($b->{'name'})} map {
		{
			'id' => $_,
			'name' => _playlistDisplayName($_, $playLists->{$_}),
			'contextmenu' => $templates->{lc($playLists->{$_}->{'id'})}->{'contextmenu'} || 0,
			'nouserinput' => $playLists->{$_}->{'nouserinput'},
		}
	} keys %{$playLists};

	my $dir = $prefs->get('customplaylistfolder');
	if (!defined $dir || !-d $dir) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_CUSTOMDIR');
		$log->error("Could not create or access DynamicPlaylistCreator folder in parent folder '".$prefs->get('customdirparentfolderpath')."'! Please make sure that LMS has read/write permissions (755) for the parent folder.");
	}

	$params->{'nocustomdynamicplaylists'} = 1 if (scalar @webPlaylists == 0);
	$params->{'displayplaybtn'} = $prefs->get('displayplaybtn');
	$params->{'displayexportbtn'} = $prefs->get('displayexportbtn');
	$params->{'hidedplrefreshmsg'} = $prefs->get('hidedplrefreshmsg');
	$params->{'pluginDynamicPlaylistCreatorPlayLists'} = \@webPlaylists;
	main::DEBUGLOG && $log->is_debug && $log->debug('webPlaylists = '.Data::Dump::dump(\@webPlaylists));
	return Slim::Web::HTTP::filltemplatefile('plugins/DynamicPlaylistCreator/list.html', $params);
}

sub handleWebNewPlaylistTypes {
	my ($client, $params) = @_;

	_getTemplates();

	my @playlistCategories = ('tracks', 'artists', 'albums', 'genres', 'years', 'playlists');
	splice @playlistCategories, 3, 0, 'works' if (Slim::Utils::Versions->compareVersions($::VERSION, '9.0') >= 0);
	$params->{'playlistcategories'} = \@playlistCategories;
	$params->{'pluginWebPageMethodsTemplates'} = [values %{$templates}];
	$params->{'pluginWebPageMethodsPostUrl'} = 'plugins/DynamicPlaylistCreator/webpagemethods_newitemparameters.html';

	return Slim::Web::HTTP::filltemplatefile('plugins/DynamicPlaylistCreator/webpagemethods_newitemtypes.html', $params);
}

sub handleWebNewPlaylistParameters {
	my ($client, $params) = @_;

	my $templateId = $params->{'itemtemplate'};
	my $template = _getTemplates()->{$templateId};

	$params->{'pluginWebPageMethodsNewItemTemplate'} = $templateId;

	if (defined($template->{'parameter'})) {
		my @parametersToSelect = ();
		for my $p (@{_getUsableParameters($template)}) {
			push @parametersToSelect, buildParameterFormField($p);
		}
		_setCustomTagInfo($params);
		$params->{'pluginWebPageMethodsNewItemParameters'} = \@parametersToSelect;
		$params->{'templateName'} = $template->{'name'};
	}
	return Slim::Web::HTTP::filltemplatefile('plugins/DynamicPlaylistCreator/webpagemethods_newitemparameters.html', $params);
}

sub handleWebSaveNewPlaylist {
	my ($client, $params) = @_;
	main::DEBUGLOG && $log->is_debug && $log->debug('Start handleWebSaveNewPlaylist');

	my $templateId = $params->{'itemtemplate'};
	main::DEBUGLOG && $log->is_debug && $log->debug('templateId = '.Data::Dump::dump($templateId));
	$params->{'pluginWebPageMethodsError'} = undef;

	checkFilePaths($params); # add host and slashes to beginning of file paths if necessary

	my $template = _getTemplates()->{$templateId};
	(my $templateFile = $templateId) =~ s/\.sql\.xml$/.sql.template/;
	(my $fallbackFilename = $templateId) =~ s/\.sql\.xml$//;

	my $fileName = lc($params->{'itemparameter_playlistname'}) || lc($fallbackFilename);
	$fileName = lc(Slim::Utils::Text::ignoreCase($fileName, 1));
	$fileName =~ s/[\s]+/_/g;
	$fileName = unescape($fileName);
	my $dir = $prefs->get('customplaylistfolder');

	# if file name exists, append number
	if (-e catfile($dir, $fileName.'.sql') || -e catfile($dir, $fileName.'.customvalues.xml')) {
		my $i = 1;
		while (-e catfile($dir, $fileName.'_'.$i.'.sql') || -e catfile($dir, $fileName.'_'.$i.'.customvalues.xml')) {
			$i++;
		}
		$fileName .= '_'.$i;
	}

	my %templateParameters = ();
	for my $p (@{_getUsableParameters($template)}) {
		$templateParameters{$p->{'id'}} = getValueOfTemplateParameter($params, buildParameterFormField($p));
	}

	# add the name of template on which the dynamic playlist is based
	$templateParameters{'basetemplate'} = $template->{'name'};
	$templateParameters{'exacttitlesearch'} = $prefs->get('exacttitlesearch');

	$params->{'sqltextdplonly'} = fillTemplate($templateFile, \%templateParameters);
	_setNoUserInput($params, $templateId);

	if (_saveSimpleItem($params, catfile($dir, $fileName.'.customvalues.xml'), $templateId, catfile($dir, $fileName.'.sql'))) {
		$params->{'dplrefresh'} = 1;
	} else {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_SAVEFAILED');
	}
	return handleWebList($client, $params);
}

sub handleWebEditPlaylist {
	my ($client, $params) = @_;
	main::DEBUGLOG && $log->is_debug && $log->debug('Start handleWebEditPlaylist');

	$playLists = readPlaylistValues() if !defined($playLists);
	my $itemId = $params->{'item'};

	if (defined($itemId) && defined($playLists->{$itemId})) {
		my $templateData = _loadTemplateValues($itemId);
		if (defined($templateData)) {
			my $template = _getTemplates()->{lc($templateData->{'id'})};

			if (defined($template)) {
				my %currentParameterValues = ();
				my $dplTemplateVersion = $templateData->{'templateversion'} || 0;
				for my $p (@{$templateData->{'parameter'}}) {
					my $values = $p->{'value'};

					# unescape file paths here for web page
					if ($p->{'id'} =~ /filepath(\d+)$/ && defined($values)) {
						my $uri = $values->[0];
						$uri =~ s/_/%/g;
						$uri = Encode::decode('utf8', unescape($uri));
						main::DEBUGLOG && $log->is_debug && $log->debug('unescaped uri = '.$uri);
						$values = [$uri];
					}

					if (!defined($values)) {
						my $tmp = $p->{'content'};
						$values = [$tmp] if defined($tmp);
					}
					my %valuesHash = ();
					for my $v (@{$values}) {
						$valuesHash{$v} = $v if ref($v) ne 'HASH';
					}
					$valuesHash{''} = '' if !%valuesHash;
					$currentParameterValues{$p->{'id'}} = \%valuesHash;
				}

				my @parametersToSelect = ();
				for my $p (@{_getUsableParameters($template)}) {
					if (!defined($currentParameterValues{$p->{'id'}})) {
						my $value = $p->{'value'};
						if (defined($value) && ref($value) ne 'HASH') {
							$currentParameterValues{$p->{'id'}} = {$value => $value};
						}
					}

					my $field = buildParameterFormField($p, $currentParameterValues{$p->{'id'}});

					# add the name of template on which the dynamic playlist is based
					if ($p->{'id'} eq 'playlistname') {
						$field->{'basetemplate'} = $template->{'name'};
						$field->{'templateversion'} = $template->{'templateversion'};
						main::DEBUGLOG && $log->is_debug && $log->debug('new template version: '.Data::Dump::dump($field->{'templateversion'}));
						$field->{'dpltemplateversion'} = $dplTemplateVersion;
						main::DEBUGLOG && $log->is_debug && $log->debug('template version of dynamic playlist: '.Data::Dump::dump($field->{'dpltemplateversion'}));
					}

					push @parametersToSelect, $field;
				}
				$params->{'pluginWebPageMethodsEditItemParameters'} = \@parametersToSelect;
				_setCustomTagInfo($params);
				$params->{'pluginWebPageMethodsEditItemTemplate'} = lc($templateData->{'id'});
				$params->{'pluginWebPageMethodsEditItemFileUnescaped'} = unescape($itemId);
				return Slim::Web::HTTP::filltemplatefile('plugins/DynamicPlaylistCreator/webpagemethods_edititem.html', $params);
			}
		}
	}
	return handleWebList($client, $params);
}

sub handleWebSavePlaylist {
	my ($client, $params) = @_;
	main::DEBUGLOG && $log->is_debug && $log->debug('Start handleWebSavePlaylist');

	my $templateId = $params->{'itemtemplate'};
	my $template = _getTemplates()->{$templateId};

	checkFilePaths($params); # add host and slashes to beginning of file paths if necessary

	## build sql statement
	my %templateParameters = ();
	for my $p (@{_getUsableParameters($template)}) {
		$p = buildParameterFormField($p) if parameterIsSpecified($params, $p);
		$templateParameters{$p->{'id'}} = getValueOfTemplateParameter($params, $p);
	}
	main::DEBUGLOG && $log->is_debug && $log->debug('templateParameters = '.Data::Dump::dump(\%templateParameters));

	# add the name of template on which the dynamic playlist is based
	$templateParameters{'basetemplate'} = $template->{'name'};
	$templateParameters{'exacttitlesearch'} = $prefs->get('exacttitlesearch');

	(my $templateFile = $templateId) =~ s/\.sql\.xml$/.sql.template/;
	$params->{'sqltextdplonly'} = fillTemplate($templateFile, \%templateParameters);

	$params->{'pluginWebPageMethodsError'} = undef;
	if (!$params->{'itemparameter_playlistname'}) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_DPLNAME');
	}

	_setNoUserInput($params, $templateId);

	my $dir = $prefs->get('customplaylistfolder');
	if (!defined $dir || !-d $dir) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_CUSTOMDIR');
	}
	my $file = unescape($params->{'file'});

	if (_saveSimpleItem($params, catfile($dir, $file.'.customvalues.xml'), $templateId, catfile($dir, $file.'.sql'))) {
		main::DEBUGLOG && $log->is_debug && $log->debug('saveSimpleItem succeeded');
		$params->{'dplrefresh'} = 1;
		return handleWebList($client, $params);
	}
	main::DEBUGLOG && $log->is_debug && $log->debug('saveSimpleItem FAILED - return to edit mode');
	return Slim::Web::HTTP::filltemplatefile('plugins/DynamicPlaylistCreator/webpagemethods_edititem.html', $params);
}

sub handleWebRemovePlaylist {
	my ($client, $params) = @_;

	_deleteItemFiles($params->{'item'});
	$params->{'dplrefresh'} = 1;
	return handleWebList($client, $params);
}

sub handleWebStartPlaylist {
	my ($client, $params) = @_;
	my $dpl = $params->{'item'};
	return unless $client && $dpl;
	main::DEBUGLOG && $log->is_debug && $log->debug('Tell DPL to play dynamic playlist "'.$dpl.'"');
	$client->execute(['dynamicplaylist', 'playlist', 'play', 'dplccustom_'.$dpl])->source('PLUGIN_DYNAMICPLAYLISTCREATOR');
	return handleWebList($client, $params);
}

sub handleWebExportPlaylist {
	my ($client, $params) = @_;
	my $itemId = $params->{'item'};

	my $data = _readDataFile($itemId.'.sql');
	main::DEBUGLOG && $log->is_debug && $log->debug('itemId = '.$itemId.' -- data = '.Data::Dump::dump($data));

	# get DPL folder for custom dpls
	my $dplCustomFolder = preferences('plugin.dynamicplaylists4')->get('customplaylistfolder');
	if (!defined $dplCustomFolder || !-d $dplCustomFolder) {
		$log->error('Could not find Dynamic Playlists folder called "DPL-custom-lists" for custom dynamic playlists. Make sure it exists and LMS has read/write permissions (755) for the folder');
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_DPLCUSTOMDIR');
		return handleWebList($client, $params);
	}

	my $url = catfile($dplCustomFolder, $itemId).'.sql';
	main::DEBUGLOG && $log->is_debug && $log->debug('url = '.Data::Dump::dump($url));
	if (-e $url) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_DPLFILENAMEALREADYEXISTS');
		return handleWebList($client, $params);
	}

	open(my $fh, '>:encoding(UTF-8)', $url) or do {
		$params->{'pluginWebPageMethodsError'} = "Error saving $url: ".$!;
		return handleWebList($client, $params);
	};

	main::DEBUGLOG && $log->is_debug && $log->debug("Writing to file: $url");
	print $fh $data;
	main::DEBUGLOG && $log->is_debug && $log->debug('Writing to file succeeded');
	close $fh;

	# exported dynamic playlists are no longer managed by DPLC
	return handleWebRemovePlaylist($client, $params);
}



### templates (read-only, loaded once via initPlugin/_getTemplates)

sub readTemplateConfiguration {
	my %result = ();

	for my $pluginDir (Slim::Utils::OSDetect::dirsFor('Plugins')) {
		my $templateDir = catdir($pluginDir, 'DynamicPlaylistCreator', 'Templates');
		main::DEBUGLOG && $log->is_debug && $log->debug('Checking for dir: '.$templateDir);
		next unless -d $templateDir;
		_readConfigFiles($templateDir, 'sql.xml', 1, sub {
			my ($item, $content) = @_;
			eval { _parseTemplate($item, $content, \%result) };
			return $@;
		});
	}
	return \%result;
}

### dynamic playlist values (rebuilt on every list.html view)

# returns the full saved values (same shape _loadTemplateValues returns) of every dynamic
# playlist, keyed by file name; skips playlists whose template no longer exists
sub readPlaylistValues {
	_getTemplates();
	my %result = ();
	my $dir = $prefs->get('customplaylistfolder');
	main::DEBUGLOG && $log->is_debug && $log->debug("Searching for item configuration in: $dir");

	if (!defined $dir || !-d $dir) {
		main::DEBUGLOG && $log->is_debug && $log->debug('Skipping custom configuration scan - directory is undefined');
	} else {
		_readConfigFiles($dir, 'customvalues.xml', 0, sub {
			my ($item, $content) = @_;
			return _parsePlaylistValues($item, $content, \%result);
		});
	}
	return \%result;
}

sub _getTemplates {
	$templates = readTemplateConfiguration() if !defined($templates);
	return $templates;
}

# calls the callback for every file with the given extension (incl. subfolders); a true return value of the callback is logged as error
sub _readConfigFiles {
	my ($dir, $extension, $keepExtension, $parseCallback) = @_;

	main::DEBUGLOG && $log->is_debug && $log->debug("Loading configuration from: $dir");
	for my $path (Slim::Utils::Misc::readDirectory($dir, $extension, 'dorecursive')) {
		next unless $path =~ /\Q.$extension\E$/;
		next if -d $path;

		my $item = basename($path);
		$item =~ s/\Q.$extension\E$// if !$keepExtension;

		# read_file from File::Slurp
		my $content = eval { read_file($path) };
		$content = _decodeContent($content, $item) if $content;

		if ($content) {
			my $errorMsg = $parseCallback->($item, $content);
			$log->error("Unable to parse file: $path\n$errorMsg") if $errorMsg;
		} else {
			$log->error("Unable to open file: $path".($@ ? "\nBecause of: $@" : ''));
		}
	}
}

sub _decodeContent {
	my ($content, $name) = @_;

	my $encoding = Slim::Utils::Unicode::encodingFromString($content);
	if ($encoding ne 'utf8') {
		main::DEBUGLOG && $log->is_debug && $log->debug("Loading $name and converting from $encoding to utf8");
		$content = Slim::Utils::Unicode::latin1toUTF8($content);
		return Slim::Utils::Unicode::utf8on($content);
	}
	main::DEBUGLOG && $log->is_debug && $log->debug("Loading $name without conversion with encoding ".$encoding);
	return Slim::Utils::Unicode::utf8decode($content, 'utf8');
}

# reads a file from the folder for custom dynamic playlists
sub _readDataFile {
	my $fileName = shift;

	my $dir = $prefs->get('customplaylistfolder');
	return unless defined($dir) && -d $dir;

	my $path = catfile($dir, $fileName);
	main::DEBUGLOG && $log->is_debug && $log->debug("Loading item data from: $path");
	return unless -f $path;

	my $content = eval { read_file($path) };
	$log->error("Failed to load item data because: $@") if $@;
	return defined($content) ? _decodeContent($content, $fileName) : undef;
}

sub _loadTemplateValues {
	my $itemId = shift;

	my $content = _readDataFile($itemId.'.customvalues.xml');
	return if !defined($content);

	my $xml = eval { XMLin($content, forcearray => ['parameter', 'value'], keyattr => []) };
	if ($@) {
		$log->error("Failed to parse configuration because: $@");
		return;
	}
	return $xml->{'template'};
}

# parses a template definition file (*.sql.xml) and adds it to $result
sub _parseTemplate {
	my ($item, $content, $result) = @_;

	main::DEBUGLOG && $log->is_debug && $log->debug('XMLin part');
	my $xml = eval { XMLin($content, forcearray => ['item'], keyattr => []) };
	if ($@) {
		$log->warn("Failed to parse configuration ($item) because: $@");
		return;
	}

	# enable/disable complete(!) template, not just individual params
	my $include = 1;
	if (defined($xml->{'requireplugins'})) {
		$include = Slim::Utils::PluginManager->isEnabled('Plugins::'.$xml->{'requireplugins'}) ? 1 : 0;
	}
	if ($include && defined($xml->{'minpluginversion'})) {
		$include = (Slim::Utils::Versions->compareVersions($pluginVersion, $xml->{'minpluginversion'}) >= 0) ? 1 : 0;
	}
	return if !$include || !defined($xml->{'template'});

	$xml->{'template'}->{'id'} = escape($item);
	$result->{$item} = $xml->{'template'};
}

# parses one saved playlist's full values (same shape _loadTemplateValues returns) into $result. Values are raw/unescaped. See _playlistDisplayName for safe display.
sub _parsePlaylistValues {
	my ($item, $content, $result) = @_;

	my $valuesXml = eval { XMLin($content, forcearray => ['parameter', 'value'], keyattr => []) };
	if ($@) {
		$log->warn("Failed to parse playlist configuration ($item) because: $@");
		return "$@";
	}

	my $templateId = lc($valuesXml->{'template'}->{'id'});
	if (!defined($templates->{$templateId})) {
		main::DEBUGLOG && $log->is_debug && $log->debug("Template $templateId not found");
		return;
	}

	$result->{$item} = $valuesXml->{'template'};
	return;
}

# derives a safe display name for list.html from a playlist's parsed values, falling back to the file name itself if no playlist name was saved.
sub _playlistDisplayName {
	my ($item, $templateData) = @_;

	for my $p (@{$templateData->{'parameter'} || []}) {
		next unless $p->{'id'} eq 'playlistname';
		# an empty <value></value> element parses to a hashref, not a string; skip it
		my ($v) = grep { ref($_) ne 'HASH' } @{$p->{'value'} || []};
		return encode_entities($v, '&<>') if defined($v) && $v ne '';
		last;
	}
	return encode_entities($item, '&<>');
}



### editing, saving and deleting dynamic playlists

# returns the template parameters that are usable with the current plugins and LMS version
sub _getUsableParameters {
	my $template = shift;

	my $parameters = $template->{'parameter'};
	return [] if !defined($parameters);
	$parameters = [$parameters] if ref($parameters) ne 'ARRAY';

	my @usable = ();
	for my $p (@{$parameters}) {
		next unless defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'});
		next if defined($p->{'requireplugins'}) && !Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'});
		if (defined($p->{'minlmsversion'}) && Slim::Utils::Versions->compareVersions($::VERSION, $p->{'minlmsversion'}) == -1) {
			main::DEBUGLOG && $log->is_debug && $log->debug('LMS version = '.$::VERSION.' -- min. LMS version for param "'.$p->{'id'}.'" = '.$p->{'minlmsversion'});
			next;
		}
		push @usable, $p;
	}
	return \@usable;
}

# builds a fresh per-request form field from a read-only parameter definition plus its current value(s), if any. Never writes to $p itself.
sub buildParameterFormField {
	my ($p, $currentValues) = @_;
	my %field = %$p;

	if ($field{'type'} eq 'text' || $field{'type'} eq 'number' || $field{'type'} eq 'searchtext' || $field{'type'} eq 'searchurl') {
		$field{'elementsize'} = $largeFields{$field{'id'}} if $largeFields{$field{'id'}};
		$field{'elementsize'} = $mediumFields{$field{'id'}} if $mediumFields{$field{'id'}};
		$field{'elementsize'} = $smallFields{$field{'id'}} if $smallFields{$field{'id'}};
	}
	$field{'elementsize'} = 50 if $field{'type'} eq 'multivaltext';

	if ($field{'type'} =~ /^sql/) {
		my $listValues = getSQLTemplateData($field{'data'});
		unshift @{$listValues}, _emptyListValue() if ($field{'type'} =~ /optional/);
		$field{'values'} = $listValues;
	} elsif ($field{'type'} =~ /function/) {
		my $listValues = getFunctionTemplateData($field{'data'});
		unshift @{$listValues}, _emptyListValue() if ($field{'type'} =~ /optional.*list$/);
		if ($field{'value'}) {
			for my $v (@{$listValues}) {
				$v->{'selected'} = 1;
			}
		}
		$field{'values'} = $listValues;
	} elsif ($field{'type'} =~ /virtuallibraries/) {
		my $listValues = getVirtualLibraries();
		unshift @{$listValues}, _emptyListValue();
		if ($field{'value'}) {
			for my $v (@{$listValues}) {
				$v->{'selected'} = 1;
			}
		}
		$field{'values'} = $listValues;
	} elsif ($cachedListKeys{$field{'type'}}) {
		$field{'values'} = $cache->get($cachedListKeys{$field{'type'}}) || [];
	} elsif ($field{'type'} =~ /list$/ || $field{'type'} =~ /checkboxes$/) {
		my @listValues = ();
		for my $value (split(/,/, $field{'data'})) {
			my @idName = split(/=/, $value);
			push @listValues, {
				'id' => $idName[0],
				'name' => $idName[1],
				'value' => scalar(@idName) > 2 ? $idName[2] : $idName[0],
			};
		}
		unshift @listValues, _emptyListValue() if ($field{'type'} =~ /optional.*list$/);
		$field{'values'} = \@listValues;
	}

	if (defined($currentValues)) {
		if ($field{'type'} =~ /^sql/ || $field{'type'} =~ /function/ || $field{'type'} =~ /list$/ || $field{'type'} =~ /checkboxes$/ || $field{'type'} =~ /listcached/) {
			for my $v (@{$field{'values'}}) {
				if (($field{'id'} eq 'includedratings' || $field{'id'} eq 'exactrating') && defined($currentValues->{$v->{'value'}})) {
					$v->{'selected'} = 1;
				} elsif ($currentValues->{$v->{'value'}}) {
					$v->{'selected'} = 1;
				} else {
					$v->{'selected'} = undef;
				}
			}
		} else {
			for my $v (keys %{$currentValues}) {
				$field{'value'} = $v;
			}
		}
	}
	return \%field;
}

# the number of custom tags is needed by the web page if CustomTagImporter is enabled
sub _setCustomTagInfo {
	my $params = shift;

	$params->{'CTIenabled'} = Slim::Utils::PluginManager->isEnabled('Plugins::CustomTagImporter::Plugin');
	if ($params->{'CTIenabled'}) {
		my $sth = Slim::Schema->dbh->prepare("select count(distinct attr) from customtagimporter_track_attributes where customtagimporter_track_attributes.type='customtag'");
		$sth->execute();
		($params->{'customtagcount'}) = $sth->fetchrow_array;
		$sth->finish();
	}
}

# check if dpl requires user input
sub _setNoUserInput {
	my ($params, $templateId) = @_;

	$params->{'nouserinput'} = 1 if !$params->{'itemparameter_request1fromuser'} && !$params->{'itemparameter_request2fromuser'} && !$params->{'itemparameter_requestcustomtag'} && $templateId !~ /_preselection/;
}

# writes the values file ($url) and the sql file ($customUrl) of a dynamic playlist; returns 1 on success, sets an error message otherwise
sub _saveSimpleItem {
	my ($params, $url, $templateId, $customUrl) = @_;
	main::DEBUGLOG && $log->is_debug && $log->debug('Start saveSimpleItem');

	my $template = _getTemplates()->{$templateId};

	if (!$params->{'pluginWebPageMethodsError'}) {
		my $data = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<dynamicplaylistcreator>\n\t<template>\n\t\t<id>".encode_entities($templateId, $unsafeChars).'</id>';
		# include template version
		$data .= "\n\t\t<templateversion>".$template->{'templateversion'}.'</templateversion>' if $template->{'templateversion'};
		# record if dpl requires user input
		$data .= "\n\t\t<nouserinput>".$params->{'nouserinput'}.'</nouserinput>' if $params->{'nouserinput'};

		for my $p (@{_getUsableParameters($template)}) {
			$p = buildParameterFormField($p) if parameterIsSpecified($params, $p);
			my $attributes = '';
			$attributes .= ' quotevalue="1"' if $p->{'quotevalue'};
			$attributes .= ' rawvalue="1"' if $p->{'rawvalue'};
			$data .= "\n\t\t<parameter type=\"text\" id=\"".$p->{'id'}.'"'.$attributes.'>'.getXMLValueOfTemplateParameter($params, $p).'</parameter>';
		}
		$data .= "\n\t</template>\n</dynamicplaylistcreator>\n";

		# write simple file
		_writeFile($params, $url, $data);

		# write adv file
		if (!$params->{'pluginWebPageMethodsError'}) {
			my $sqlData = Slim::Utils::Unicode::utf8decode_locale($params->{'sqltextdplonly'});
			$sqlData =~ s/\r+\n/\n/g; # Remove any extra \r character, will create duplicate linefeeds on Windows if not removed
			_writeFile($params, $customUrl, $sqlData);
		}
	}

	if ($params->{'pluginWebPageMethodsError'}) {
		# restore the values entered by the user for the edit page
		my @parametersToSelect = ();
		for my $p (@{_getUsableParameters($template)}) {
			my $field = buildParameterFormField($p);
			my $value = getXMLValueOfTemplateParameter($params, $field);
			if (defined($value) && $value ne '') {
				my $xmlValue = eval { XMLin('<data>'.$value.'</data>', forcearray => ['value'], keyattr => []) };
				if (defined($xmlValue)) {
					my %valuesHash = ();
					for my $v (@{$xmlValue->{'value'}}) {
						$valuesHash{$v} = $v if ref($v) ne 'HASH';
					}
					$valuesHash{''} = '' if !%valuesHash;
					$field = buildParameterFormField($p, \%valuesHash);
				}
			}
			push @parametersToSelect, $field;
		}
		$params->{'pluginWebPageMethodsEditItemParameters'} = \@parametersToSelect;
		$params->{'pluginWebPageMethodsEditItemTemplate'} = $templateId;
		$params->{'pluginWebPageMethodsEditItemFileUnescaped'} = unescape($params->{'file'});
		return;
	}
	return 1;
}

sub _writeFile {
	my ($params, $path, $data) = @_;

	main::DEBUGLOG && $log->is_debug && $log->debug("Opening configuration file: $path");
	open(my $fh, '>:encoding(UTF-8)', $path) or do {
		$params->{'pluginWebPageMethodsError'} = "Error saving $path: ".$!;
		$log->error("Error saving $path: ".$!);
		return;
	};

	main::DEBUGLOG && $log->is_debug && $log->debug("Writing to file: $path");
	print $fh $data;
	main::DEBUGLOG && $log->is_debug && $log->debug('Writing to file succeeded');
	close $fh;
}

sub _deleteItemFiles {
	my $itemId = shift;

	my $dir = $prefs->get('customplaylistfolder');
	return unless defined($dir) && -d $dir;

	# delete values file and SQLite file
	for my $extension ('customvalues.xml', 'sql') {
		my $file = catfile($dir, unescape($itemId).'.'.$extension);
		next unless -e $file;
		unlink($file) or do {
			$log->warn("Unable to delete file: $file: $!");
		};
	}
}

sub checkFilePaths {
	my $params = shift;

	my $prefix = 'file:///';
	for my $i (1..3) {
		my $key = 'itemparameter_filepath'.$i;
		last if !$params->{$key};
		next if Slim::Music::Info::isURL($params->{$key});
		if ($params->{$key.'_searchtype'} =~ /STARTS/ && index($params->{$key}, $prefix) != 0) {
			main::DEBUGLOG && $log->is_debug && $log->debug('incorrect or missing file path '.$i.' prefix');
			$params->{$key} = setFilePathPrefix($params->{$key}, $prefix);
		}
	}
}

sub setFilePathPrefix {
	my ($path, $prefix) = @_;

	if (index($path, $prefix) != 0) {
		main::DEBUGLOG && $log->is_debug && $log->debug('NO correct prefix');
		$path = $prefix.$path;
	}
	my $dirSep = File::Spec->canonpath('/');
	$path =~ s<(?:\Q$dirSep\E){4,}><$dirSep$dirSep$dirSep>;
	return $path;
}



### template parameter handling

sub quoteValue {
	my $value = shift;
	$value =~ s/\'/\'\'/g;
	return $value;
}

sub _emptyListValue {
	return {'id' => '', 'name' => '', 'value' => ''};
}

# returns the selected values of a multiple list or checkboxes parameter
sub _getSelectedValues {
	my ($params, $parameter) = @_;

	my $paramName = 'itemparameter_'.$parameter->{'id'};
	if ($parameter->{'type'} =~ /multiplelist$/ || $parameter->{'type'} eq 'contributorlistcachedall' || $parameter->{'type'} eq 'contributorlistcachedalbumartists' || $parameter->{'type'} eq 'contributorlistcachedcomposers' || $parameter->{'type'} eq 'worklistcached') {
		return getMultipleListQueryParameter($params, $paramName);
	}
	return getCheckBoxesQueryParameter($params, $paramName);
}

sub parameterIsSpecified {
	my ($params, $parameter) = @_;

	if ($parameter->{'type'} =~ /multiplelist$/ || $parameter->{'type'} =~ /checkboxes$/ || $parameter->{'type'} =~ /listcached/) {
		return 1 if scalar(keys %{_getSelectedValues($params, $parameter)}) > 0;
	} elsif ($parameter->{'type'} =~ /singlelist$/) {
		return 1 if defined($params->{'itemparameter_'.$parameter->{'id'}});
	} else {
		return 1 if $params->{'itemparameter_'.$parameter->{'id'}};
	}
	return 0;
}

sub getValueOfTemplateParameter {
	my ($params, $parameter) = @_;

	my $result = '';
	if ($parameter->{'type'} =~ /multiplelist$/ || $parameter->{'type'} =~ /checkboxes$/ || $parameter->{'type'} =~ /listcached/) {
		my $selectedValues = _getSelectedValues($params, $parameter);
		main::DEBUGLOG && $log->is_debug && $log->debug('Got '.scalar(keys %{$selectedValues}).' values for '.$parameter->{'id'});
		for my $item (@{$parameter->{'values'}}) {
			if (defined($selectedValues->{$item->{'id'}})) {
				$result .= ',' if $result ne '';

				my $thisvalue = $item->{'value'};
				# if param = includeddecades, add years to decades
				if ($parameter->{'id'} eq 'includeddecades') {
					my $decadeYears = $thisvalue;
					unless ($thisvalue == 0) {
						for (1..9) {
							$decadeYears .= ','.($thisvalue + $_);
						}
					}
					$thisvalue = $decadeYears;
				}

				$thisvalue = quoteValue($thisvalue) if !$parameter->{'rawvalue'};
				$result .= $parameter->{'quotevalue'} ? "'".encode_entities($thisvalue, $unsafeChars)."'" : encode_entities($thisvalue, $unsafeChars);
				main::DEBUGLOG && $log->is_debug && $log->debug('Got '.$parameter->{'id'}." = $thisvalue");
			}
		}
	} elsif ($parameter->{'type'} =~ /singlelist$/) {
		my $selectedValue = Slim::Utils::Unicode::utf8decode_locale($params->{'itemparameter_'.$parameter->{'id'}});
		for my $item (@{$parameter->{'values'}}) {
			if ($selectedValue && $selectedValue eq $item->{'id'}) {
				my $thisvalue = $item->{'value'};
				$thisvalue = quoteValue($thisvalue) if !$parameter->{'rawvalue'};
				$result = $parameter->{'quotevalue'} ? "'".encode_entities($thisvalue, $unsafeChars)."'" : encode_entities($thisvalue, $unsafeChars);
				main::DEBUGLOG && $log->is_debug && $log->debug('Got '.$parameter->{'id'}." = $thisvalue");
				last;
			}
		}
	} elsif ($parameter->{'type'} eq 'multivaltext') {
		if ($params->{'itemparameter_'.$parameter->{'id'}}) {
			my $thisvalue = Slim::Utils::Unicode::utf8decode_locale($params->{'itemparameter_'.$parameter->{'id'}});
			main::INFOLOG && $log->is_info && $log->info('thisvalue = '.Data::Dump::dump($thisvalue));

			my $quotedTextVal;
			foreach my $thisParamVal (split(/;/, $thisvalue)) {
				$thisParamVal = quoteValue($thisParamVal) if !$parameter->{'rawvalue'};
				if ($parameter->{'quotevalue'}) {
					$quotedTextVal .= ($quotedTextVal ? ',' : '')."'".encode_entities(trimLeadTail($thisParamVal), $unsafeChars)."'";
				} else {
					$quotedTextVal .= ($quotedTextVal ? ',' : '').encode_entities(trimLeadTail($thisParamVal), $unsafeChars);
				}
			}
			main::INFOLOG && $log->is_info && $log->info('Got '.$parameter->{'id'}.' = '.Data::Dump::dump($quotedTextVal));
			$result = $quotedTextVal;
		}
	} else {
		if ($params->{'itemparameter_'.$parameter->{'id'}}) {
			my $thisvalue = Slim::Utils::Unicode::utf8decode_locale($params->{'itemparameter_'.$parameter->{'id'}});
			$thisvalue = quoteValue($thisvalue) if !$parameter->{'rawvalue'};

			$thisvalue = handleSearchText($thisvalue, $parameter->{'id'} =~ /commentssearchstring/ ? 1 : 0) if $parameter->{'type'} eq 'searchtext';
			$thisvalue = handleSearchURL($thisvalue) if $parameter->{'type'} eq 'searchurl';

			# filestamp: date -> epoch time
			if ($parameter->{'type'} eq 'text' && $parameter->{'id'} =~ /filetimestamp$/) {
				my ($days, $months, $years) = split(m@/@, $thisvalue);
				$thisvalue = timelocal(0, 0, 0, $days, $months - 1, $years);
			}

			return $parameter->{'quotevalue'} ? "'".encode_entities($thisvalue, $unsafeChars)."'" : encode_entities($thisvalue, $unsafeChars);
		} elsif ($parameter->{'type'} =~ /checkbox$/) {
			$result = '0';
		}
		main::DEBUGLOG && $log->is_debug && $log->debug('Got '.$parameter->{'id'}." = $result");
	}
	return $result;
}

sub getXMLValueOfTemplateParameter {
	my ($params, $parameter) = @_;

	my $result = '';
	if ($parameter->{'type'} =~ /multiplelist$/ || $parameter->{'type'} =~ /checkboxes$/ || $parameter->{'type'} =~ /listcached/) {
		my $selectedValues = _getSelectedValues($params, $parameter);
		main::DEBUGLOG && $log->is_debug && $log->debug('Got '.scalar(keys %{$selectedValues}).' values for '.$parameter->{'id'}.' to convert to XML');
		for my $item (@{$parameter->{'values'}}) {
			if (defined($selectedValues->{$item->{'id'}})) {
				$result .= '<value>'.encode_entities($item->{'value'}, $unsafeChars).'</value>';
				main::DEBUGLOG && $log->is_debug && $log->debug('Got '.$parameter->{'id'}.' = '.$item->{'value'});
			}
		}
	} elsif ($parameter->{'type'} =~ /singlelist$/) {
		my $selectedValue = Slim::Utils::Unicode::utf8decode_locale($params->{'itemparameter_'.$parameter->{'id'}});
		for my $item (@{$parameter->{'values'}}) {
			if ($selectedValue && $selectedValue eq $item->{'id'}) {
				$result .= '<value>'.encode_entities($item->{'value'}, $unsafeChars).'</value>';
				main::DEBUGLOG && $log->is_debug && $log->debug('Got '.$parameter->{'id'}.' = '.$item->{'value'});
				last;
			}
		}
	} else {
		if (defined($params->{'itemparameter_'.$parameter->{'id'}}) && $params->{'itemparameter_'.$parameter->{'id'}} ne '') {
			my $value = Slim::Utils::Unicode::utf8decode_locale($params->{'itemparameter_'.$parameter->{'id'}});
			$value = handleSearchText($value, $parameter->{'id'} =~ /commentssearchstring/ ? 1 : 0) if $parameter->{'type'} eq 'searchtext';
			$value = handleSearchURL($value) if $parameter->{'type'} eq 'searchurl';
			$result = '<value>'.encode_entities($value, "%_&<>'\"").'</value>';
			main::DEBUGLOG && $log->is_debug && $log->debug('Got '.$parameter->{'id'}." = $value");
		} else {
			$result = '<value>0</value>' if $parameter->{'type'} =~ /checkbox$/;
			main::DEBUGLOG && $log->is_debug && $log->debug('Got '.$parameter->{'id'}." = $result");
		}
	}
	return $result;
}

sub getMultipleListQueryParameter {
	my ($params, $parameter) = @_;

	my $query = $params->{url_query};
	my %result = ();
	if ($query) {
		foreach my $param (split /\&/, $query) {
			if ($param =~ /^([^=]+)=(.*)$/) {
				my $name = unescape($1);
				my $value = unescape($2);
				if ($name eq $parameter) {
					# We need to turn perl's internal representation of the unescaped
					# UTF-8 string into a "real" UTF-8 string with the appropriate magic set.
					if ($value ne '*' && $value ne '') {
						$value = Slim::Utils::Unicode::utf8on($value);
						$value = Slim::Utils::Unicode::utf8encode_locale($value);
					}
					$result{$value} = 1;
				}
			}
		}
	}
	return \%result;
}

sub getCheckBoxesQueryParameter {
	my ($params, $parameter) = @_;

	my %result = ();
	foreach my $key (keys %{$params}) {
		if ($key =~ /^\Q$parameter\E_(.*)/) {
			my $id = unescape($1);
			if ($id ne '*' && $id ne '') {
				$id = Slim::Utils::Unicode::utf8on($id);
				$id = Slim::Utils::Unicode::utf8encode_locale($id);
			}
			$result{$id} = 1;
		}
	}
	return \%result;
}

sub getSQLTemplateData {
	my $sqlstatements = shift;

	my @result = ();
	my $dbh = Slim::Schema->dbh;

	for my $sql (split(/[;]/, $sqlstatements)) {
		main::DEBUGLOG && $log->is_debug && $log->debug('sql = '.Data::Dump::dump($sql));
		$sql =~ s/^\s+//g;
		$sql =~ s/\s+$//g;
		next if !$sql;
		eval {
			my $sth = $dbh->prepare($sql);
			main::DEBUGLOG && $log->is_debug && $log->debug('Executing: '.Data::Dump::dump($sql));
			$sth->execute() or do {
				$log->error('Error executing: '.Data::Dump::dump($sql));
				$sql = undef;
			};

			if ($sql && $sql =~ /^SELECT/i) {
				main::DEBUGLOG && $log->is_debug && $log->debug('Executing and collecting: '.Data::Dump::dump($sql));
				my ($id, $name, $value);
				$sth->bind_col(1, \$id);
				$sth->bind_col(2, \$name);
				$sth->bind_col(3, \$value);

				while ($sth->fetch()) {
					push @result, {
						'id' => Slim::Utils::Unicode::utf8decode($id, 'utf8'),
						'name' => Slim::Utils::Unicode::utf8decode($name, 'utf8'),
						'value' => Slim::Utils::Unicode::utf8decode($value, 'utf8'),
					};
				}
			}
			$sth->finish();
		};
		if ($@) {
			$log->warn('Database error running '.(defined($sql) ? $sql : 'sql statement').": $@");
		}
	}
	return \@result;
}

sub getFunctionTemplateData {
	my $data = shift;

	my @params = split(/\,/, $data);
	my @result = ();
	if (scalar(@params) == 2) {
		my ($object, $function) = @params;
		if (UNIVERSAL::can($object, $function)) {
			main::DEBUGLOG && $log->is_debug && $log->debug("Getting values for: $function");
			no strict 'refs';
			my $items = eval { &{$object.'::'.$function}() };
			if ($@) {
				$log->warn("Function call error: $@");
			}
			use strict 'refs';
			@result = @{$items} if defined($items);
		}
	} else {
		$log->warn("Error getting values for: $data, incorrect number of parameters ".scalar(@params));
	}
	return \@result;
}

sub handleSearchURL {
	my $url = shift;
	$url =~ s/^\s*//;
	$url =~ s/\s+$//;

	my $uri = URI::Escape::uri_escape_utf8($url);

	# don't escape backslashes
	$uri =~ s$%(?:2F|5C)$/$ig;

	# don't escape colons (important for file: and Windows)
	$uri =~ s$%(?:3A|_3A)$:$ig;

	# replace the % in the URI escaped string with a single character placeholder
	$uri =~ s/%/_/g;

	return $uri;
}

sub handleSearchText {
	my ($searchString, $skipExact) = @_;
	$searchString =~ s/^\s*//;
	$searchString =~ s/\s+$//;
	$searchString =~ s/%/\\%/g;
	$searchString =~ s/_/\\_/g;
	$searchString = Slim::Utils::Unicode::utf8decode_locale($searchString);

	if (!$prefs->get('exacttitlesearch') && !$skipExact) {
		main::DEBUGLOG && $log->is_debug && $log->debug('Not using exact title search');
		$searchString = Slim::Utils::Text::ignoreCase($searchString, 1);
	}
	return $searchString;
}

sub trimLeadTail {
	my ($str) = @_;
	$str =~ s{^\s+}{};
	$str =~ s{\s+$}{};
	return $str;
}



### Template Toolkit (sql templates)

sub _getTemplateHandler {
	if (!defined($templateHandler)) {
		my @subDirs = ('Songs', 'Artists', 'Albums', 'Genres', 'Years', 'Playlists');
		splice @subDirs, 3, 0, 'Works' if (Slim::Utils::Versions->compareVersions($::VERSION, '9.0') >= 0);

		my @includePath = ();
		for my $pluginDir (Slim::Utils::OSDetect::dirsFor('Plugins')) {
			my $templateDir = catdir($pluginDir, 'DynamicPlaylistCreator', 'Templates');
			next unless -d $templateDir;
			push @includePath, $templateDir, map { catdir($templateDir, $_) } @subDirs;
		}
		main::DEBUGLOG && $log->is_debug && $log->debug('templateDirectories = '.Data::Dump::dump(\@includePath));

		$templateHandler = Template->new({
			INCLUDE_PATH => \@includePath,
			COMPILE_DIR => catdir(preferences('server')->get('cachedir'), 'templates'),
			FILTERS => {
				'string' => \&Slim::Utils::Strings::string,
				'getstring' => \&Slim::Utils::Strings::getString,
				'resolvestring' => \&Slim::Utils::Strings::resolveString,
				'uri' => \&URI::Escape::uri_escape_utf8,
				'unuri' => \&URI::Escape::uri_unescape,
				'utf8decode' => \&Slim::Utils::Unicode::utf8decode,
				'utf8encode' => \&Slim::Utils::Unicode::utf8encode,
				'utf8on' => \&Slim::Utils::Unicode::utf8on,
				'utf8off' => \&Slim::Utils::Unicode::utf8off,
				'fileurluri' => \&fileURLFromPathUri,
			},
			EVAL_PERL => 1,
		});
	}
	return $templateHandler;
}

sub fillTemplate {
	my ($filename, $params) = @_;

	my $output = '';
	$params->{'LOCALE'} = 'utf-8';
	my $template = _getTemplateHandler();
	if (!$template->process($filename, $params, \$output)) {
		$log->error('ERROR parsing template: '.$template->error());
	}
	return $output;
}

sub fileURLFromPathUri {
	my $path = shift;

	# percent-encode using the same character set tracks.url itself uses (matches
	# URI::file, not the much more aggressive default of uri_escape_utf8)
	my $uri = URI::Escape::uri_escape_utf8($path, "^!\$&'()*+,\-.0-9:=\@A-Za-z_~/");

	# SQL string literal: double any embedded single quote
	$uri =~ s/'/''/g;

	# SQL LIKE: escape wildcard-significant characters for ESCAPE '\'
	$uri =~ s/([%_])/\\$1/g;

	return $uri;
}



### caches for lists of artists, genres, composers etc.

sub getVirtualLibraries {
	my @items;
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

	my $contributorList_all = getSQLTemplateData($contributorSQL_all);
	$cache->set('dplc_contributorlist_all', $contributorList_all, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('contributorList_all count = '.scalar(@{$contributorList_all}));

	my $contributorList_albumartists = getSQLTemplateData($contributorSQL_albumartists);
	$cache->set('dplc_contributorlist_albumartists', $contributorList_albumartists, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('contributorList_albumartists count = '.scalar(@{$contributorList_albumartists}));

	my $contributorList_composers = getSQLTemplateData($contributorSQL_composers);
	$cache->set('dplc_contributorlist_composers', $contributorList_composers, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('contributorList_composers count = '.scalar(@{$contributorList_composers}));

	my $genreList = getSQLTemplateData($genreSQL);
	$cache->set('dplc_genrelist', $genreList, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('genreList count = '.scalar(@{$genreList}));

	my $contentTypesList = getSQLTemplateData($contentTypesSQL);
	$cache->set('dplc_contenttypes', $contentTypesList, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('contentTypesList count = '.scalar(@{$contentTypesList}));

	my $releaseTypesList = getSQLTemplateData($releaseTypesSQL);
	foreach my $releaseType (@{$releaseTypesList}) {
		$releaseType->{'name'} = _releaseTypeName($releaseType->{'name'});
	}
	$cache->set('dplc_releasetypes', $releaseTypesList, 'never');
	main::DEBUGLOG && $log->is_debug && $log->debug('releaseTypesList count = '.scalar(@{$releaseTypesList}));

	if (Slim::Utils::Versions->compareVersions($::VERSION, '9.0') >= 0) {
		my $workList = getSQLTemplateData($workSQL);
		$cache->set('dplc_worklist', $workList, 'never');
		main::DEBUGLOG && $log->is_debug && $log->debug('workList count = '.scalar(@{$workList}));
	}

	$cache->set('dplc_pluginversion', $pluginVersion, 'never');
}

sub _setRefreshCBTimer {
	main::DEBUGLOG && $log->is_debug && $log->debug('Killing existing timers for post-scan refresh to prevent multiple calls');
	Slim::Utils::Timers::killOneTimer(undef, \&delayedPostScanRefresh);
	main::DEBUGLOG && $log->is_debug && $log->debug('Scheduling a delayed post-scan refresh');
	Slim::Utils::Timers::setTimer(undef, time() + 5, \&delayedPostScanRefresh);
}

sub delayedPostScanRefresh {
	if (Slim::Music::Import->stillScanning) {
		main::DEBUGLOG && $log->is_debug && $log->debug('Scan in progress. Waiting for current scan to finish.');
		_setRefreshCBTimer();
	} else {
		main::DEBUGLOG && $log->is_debug && $log->debug('Starting post-scan SQL cache refresh.');
		refreshSQLCache();
	}
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

*escape = \&URI::Escape::uri_escape_utf8;
*unescape = \&URI::Escape::uri_unescape;

1;
