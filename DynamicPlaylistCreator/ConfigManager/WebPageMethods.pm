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

package Plugins::DynamicPlaylistCreator::ConfigManager::WebPageMethods;

use strict;
use warnings;
use utf8;

use base qw(Slim::Utils::Accessor);
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use File::Spec::Functions qw(:ALL);
use XML::Simple;
use File::Basename;
use Data::Dumper;
use FindBin qw($Bin);
use HTML::Entities;
use Data::Dumper;

__PACKAGE__->mk_accessor(rw => qw(pluginVersion extension simpleExtension contentPluginHandler templatePluginHandler contentDirectoryHandler contentTemplateDirectoryHandler templateDirectoryHandler templateDataDirectoryHandler parameterHandler contentParser templateDirectories itemDirectories customItemDirectory webCallbacks webTemplates template templateExtension templateDataExtension));

my $utf8filenames = 1;
my $serverPrefs = preferences('server');
my $prefs = preferences('plugin.dynamicplaylistcreator');
my $log = logger('plugin.dynamicplaylistcreator');

my %largeFields = map {$_ => 50} qw(playlistname playlistgroups albumsearchtitle1 albumsearchtitle2 albumsearchtitle3);
my %mediumFields = map {$_ => 35} qw(includedcomment excludedcomment);
my %smallFields = map {$_ => 5} qw(nooftracks noofartists noofalbums noofgenres noofplaylists noofyears minlength maxlength minyear maxyear minartisttracks minalbumtracks mingenretracks minplaylisttracks minyeartracks minbitrate maxbitrate minsamplerate maxsamplerate minbpm maxbpm skipcount similaritypercent maxskipcount);

sub new {
	my ($class, $parameters) = @_;

	my $self = $class->SUPER::new($parameters);
	$self->pluginVersion($parameters->{'pluginVersion'});
	$self->extension($parameters->{'extension'});
	$self->simpleExtension($parameters->{'simpleExtension'});
	$self->contentPluginHandler($parameters->{'contentPluginHandler'});
	$self->templatePluginHandler($parameters->{'templatePluginHandler'});
	$self->contentDirectoryHandler($parameters->{'contentDirectoryHandler'});
	$self->contentTemplateDirectoryHandler($parameters->{'contentTemplateDirectoryHandler'});
	$self->templateDirectoryHandler($parameters->{'templateDirectoryHandler'});
	$self->templateDataDirectoryHandler($parameters->{'templateDataDirectoryHandler'});
	$self->parameterHandler($parameters->{'parameterHandler'});
	$self->contentParser($parameters->{'contentParser'});
	$self->templateDirectories($parameters->{'templateDirectories'});
	$self->itemDirectories($parameters->{'itemDirectories'});
	$self->customItemDirectory($parameters->{'customItemDirectory'});
	$self->webCallbacks($parameters->{'webCallbacks'});
	$self->webTemplates($parameters->{'webTemplates'});

	if (defined($parameters->{'utf8filenames'})) {
		$utf8filenames = $parameters->{'utf8filenames'};
	}

	$self->templateExtension($parameters->{'templateDirectoryHandler'}->extension);
	$self->templateDataExtension($parameters->{'templateDataDirectoryHandler'}->extension);

	return $self;
}

sub webList {
	my ($self, $client, $params, $items) = @_;
	$params->{'pluginWebPageMethodsItems'} = $items;
	return Slim::Web::HTTP::filltemplatefile($self->webTemplates->{'webList'}, $params);
}

sub webNewItemTypes {
	my ($self, $client, $params, $templates) = @_;

	my $structuredTemplates = $self->structureItemTypes($templates);
	$log->debug(Dumper($structuredTemplates));

	$params->{'pluginWebPageMethodsTemplates'} = \@{$structuredTemplates};
	$params->{'pluginWebPageMethodsPostUrl'} = $self->webTemplates->{'webNewItemParameters'};

	return Slim::Web::HTTP::filltemplatefile($self->webTemplates->{'webNewItemTypes'}, $params);
}

sub webEditItem {
	my ($self, $client, $params, $itemId, $itemHash, $templates) = @_;
	$log->debug('Start webEditItem');

	if (defined($itemId) && defined($itemHash->{$itemId})) {
		my $templateData = $self->loadTemplateValues($client, $itemId, $itemHash->{$itemId});
		if (defined($templateData)) {
			my $template = $templates->{lc($templateData->{'id'})};

			if (defined($template)) {
				my %currentParameterValues = ();
				my $templateDataParameters = $templateData->{'parameter'};
				my $dplTemplateVersion = $templateData->{'templateversion'} || 0;
				for my $p (@{$templateDataParameters}) {
					my $values = $p->{'value'};
					if (!defined($values)) {
						my $tmp = $p->{'content'};
						if (defined($tmp)) {
							my @tmpArray = ($tmp);
							$values = \@tmpArray;
						}
					}
					my %valuesHash = ();
					for my $v (@{$values}) {
						if (ref($v) ne 'HASH') {
							$valuesHash{$v} = $v;
						}
					}
					if (!%valuesHash) {
						$valuesHash{''} = '';
					}
					$currentParameterValues{$p->{'id'}} = \%valuesHash;
				}
				if (defined($template->{'parameter'})) {
					my $parameters = $template->{'parameter'};
					if (ref($parameters) ne 'ARRAY') {
						my @parameterArray = ();
						if (defined($parameters)) {
							push @parameterArray, $parameters;
						}
						$parameters = \@parameterArray;
					}
					my @parametersToSelect = ();
					for my $p (@{$parameters}) {
						if (defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
							if (!defined($currentParameterValues{$p->{'id'}})) {
								my $value = $p->{'value'};
								if (defined($value) || ref($value) ne 'HASH') {
									my %valuesHash = ();
									$valuesHash{$value} = $value;
									$currentParameterValues{$p->{'id'}} = \%valuesHash;
								}
							}

							# add the name of template on which the dynamic playlist is based
							if ($p->{'id'} eq 'playlistname') {
								$p->{'basetemplate'} = $template->{'name'};
								$p->{'templateversion'} = $template->{'templateversion'};
								$log->debug('new template version: '.Dumper($p->{'templateversion'}));
								$p->{'dpltemplateversion'} = $dplTemplateVersion;
								$log->debug('template version of dynamic playlist: '.Dumper($p->{'dpltemplateversion'}));
							}

							# add size for input element if specified
							if ($p->{'type'} eq 'text' || $p->{'type'} eq 'searchtext') {
								$p->{'elementsize'} = $largeFields{$p->{'id'}} if $largeFields{$p->{'id'}};
								$p->{'elementsize'} = $mediumFields{$p->{'id'}} if $mediumFields{$p->{'id'}};
								$p->{'elementsize'} = $smallFields{$p->{'id'}} if $smallFields{$p->{'id'}};
							}

							# use params unless required plugin is not enabled
							my $useParameter = 1;
							if (defined($p->{'requireplugins'})) {
								$useParameter = Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'});
							}
							if ($useParameter) {
								$self->parameterHandler->addValuesToTemplateParameter($p, $currentParameterValues{$p->{'id'}});
								push @parametersToSelect, $p;
							}
						}
					}
					$params->{'pluginWebPageMethodsEditItemParameters'} = \@parametersToSelect;
				}
				$params->{'pluginWebPageMethodsEditItemTemplate'} = lc($templateData->{'id'});
				$params->{'pluginWebPageMethodsEditItemFile'} = $itemId;
				$params->{'pluginWebPageMethodsEditItemFileUnescaped'} = unescape($itemId);
				return Slim::Web::HTTP::filltemplatefile($self->webTemplates->{'webEditItem'}, $params);
			}
		}
	}
	return $self->webCallbacks->webList($client, $params);
}

sub webNewItemParameters {
	my ($self, $client, $params, $templateId, $templates) = @_;

	$params->{'pluginWebPageMethodsNewItemTemplate'} = $templateId;
	my $template = $templates->{$templateId};

	if (defined($template->{'parameter'})) {
		my $parameters = $template->{'parameter'};
		if (ref($parameters) ne 'ARRAY') {
			my @parameterArray = ();
			if (defined($parameters)) {
				push @parameterArray, $parameters;
			}
			$parameters = \@parameterArray;
		}
		my @parametersToSelect = ();
		for my $p (@{$parameters}) {
			if (defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
				# add size for input element if specified
				if ($p->{'type'} eq 'text' || $p->{'type'} eq 'searchtext') {
					$p->{'elementsize'} = $largeFields{$p->{'id'}} if $largeFields{$p->{'id'}};
					$p->{'elementsize'} = $mediumFields{$p->{'id'}} if $mediumFields{$p->{'id'}};
					$p->{'elementsize'} = $smallFields{$p->{'id'}} if $smallFields{$p->{'id'}};
				}

				# add param unless required plugin is not enabled
				my $useParameter = 1;
				if (defined($p->{'requireplugins'})) {
					$useParameter = Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'});
				}
				if ($useParameter) {
					$self->parameterHandler->addValuesToTemplateParameter($p);
					push @parametersToSelect, $p;
				}
			}
		}

		$params->{'pluginWebPageMethodsNewItemParameters'} = \@parametersToSelect;
		$params->{'templateName'} = $template->{'name'};
	}
	return Slim::Web::HTTP::filltemplatefile($self->webTemplates->{'webNewItemParameters'}, $params);
}

sub webNewItem {
	my ($self, $client, $params, $templateId, $templates) = @_;
	$log->debug('Start webNewItem');

	my $templateFile = $templateId;
	my $itemFile = $templateFile;

	my $regex1 = "\\.".$self->templateExtension."\$";
	my $regex2 = ".".$self->templateDataExtension;
	$templateFile =~ s/$regex1/$regex2/;

	$itemFile =~ s/$regex1//;

	my $fileName = lc($params->{'itemparameter_playlistname'});
	my $templateFileName = basename($itemFile);

	$fileName = lc($templateFileName) if !$fileName;
	$fileName =~ s/[\$#@~!&*()\[\];.,:?^`'"\\\/]+//g;
	$fileName =~ s/^[ \t\s]+|[ \t\s]+$//g;
	$fileName =~ s/[\s]+/_/g;

	my $template = $templates->{$templateId};

	if (-e catfile($self->customItemDirectory, unescape($itemFile).".".$self->extension) || -e catfile($self->customItemDirectory, unescape($itemFile).".".$self->simpleExtension)) {
		my $i = 1;
		while(-e catfile($self->customItemDirectory, unescape($itemFile).$i.".".$self->extension) || -e catfile($self->customItemDirectory, unescape($itemFile).$i.".".$self->simpleExtension)) {
			$i = $i + 1;
		}
		$itemFile .= $i;
	}
	my %templateParameters = ();
	if (defined($template->{'parameter'})) {
		my $parameters = $template->{'parameter'};
		for my $p (@{$parameters}) {
			if (defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
				my $useParameter = 1;
				if (defined($p->{'requireplugins'})) {
					$useParameter = Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'});
				}
				if ($useParameter) {
					$self->parameterHandler->addValuesToTemplateParameter($p);
					my $value = $self->parameterHandler->getValueOfTemplateParameter($params, $p);
					$templateParameters{$p->{'id'}} = $value;
				}
			}
		}
	}

	# add the name of template on which the dynamic playlist is based
	$templateParameters{'basetemplate'} = $template->{'name'};

	my $templateFileData = $templateFile;
	my $doParsing = 1;
	my $itemData = undef;

	if ($doParsing) {
		$itemData = $self->fillTemplate($templateFileData, \%templateParameters);
	} else {
		$itemData = $templateFileData;
	}

	$itemData = encode_entities($itemData, "&<>\'\"");
	$params->{'sqltextdplonly'} = $itemData;

	$itemFile .= ".".$self->simpleExtension;

	for my $p (keys %{$params}) {
		my $regexp = '^'.$self->parameterHandler->parameterPrefix.'_';
		if ($p =~ /$regexp/) {
			$templateParameters{$p} = $params->{$p};
		}
	}
	$params->{'pluginWebPageMethodsNewItemParameters'} = \%templateParameters;
	$params->{'pluginWebPageMethodsNewItemTemplate'} = $templateId;
	$params->{'pluginWebPageMethodsEditItemFile'} = $itemFile;
	$params->{'pluginWebPageMethodsEditItemFileUnescaped'} = unescape($fileName);
	return Slim::Web::HTTP::filltemplatefile($self->webTemplates->{'webNewItem'}, $params);
}

sub webDeleteItem {
	my ($self, $client, $params, $itemId, $items) = @_;

	my $dir = $self->customItemDirectory;

	# delete XML file
	my $xmlFile = unescape($itemId).".".$self->simpleExtension;
	my $xmlUrl = catfile($dir, $xmlFile);

	if (defined($dir) && -d $dir && $xmlFile && -e $xmlUrl) {
		unlink($xmlUrl) or do {
			warn "Unable to delete file: ".$xmlUrl.": $!";
		}
	}

	# delete SQLite file
	my $sqlFile = unescape($itemId).".".$self->extension;
	my $sqlFileUrl = catfile($dir, $sqlFile);

	if (defined($dir) && -d $dir && $sqlFile && -e $sqlFileUrl) {
		unlink($sqlFileUrl) or do {
			warn "Unable to delete dpl sql file: ".$sqlFileUrl.": $!";
		}
	}

	$params->{'dplrefresh'} = 1;
	return $self->webCallbacks->webList($client, $params);
}

sub webPlayItem {
	my ($self, $client, $params, $itemId, $items) = @_;
	return $self->webCallbacks->webList($client, $params);
}

sub webSaveItem {
	my ($self, $client, $params, $templateId, $templates) = @_;
	$log->debug('Start webSaveItem');

	my $templateFile = $templateId;
	my $regex1 = "\\.".$self->templateExtension."\$";
	my $regex2 = ".".$self->templateDataExtension;
	$templateFile =~ s/$regex1/$regex2/;

	my $regex3 = "\\.".$self->simpleExtension."\$";
	my $itemFile = $params->{'file'};
	$itemFile =~ s/$regex3//;

	my $template = $templates->{$templateId};

	## build sql statement
	my %templateParameters = ();
	if (defined($template->{'parameter'})) {
		my $parameters = $template->{'parameter'};

		if (ref($parameters) ne 'ARRAY') {
			my @parameterArray = ();
			if (defined($parameters)) {
				push @parameterArray, $parameters;
			}
			$parameters = \@parameterArray;
		}
		for my $p (@{$parameters}) {
			if (defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
				my $useParameter = 1;
				if (defined($p->{'requireplugins'})) {
					$useParameter = Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'});
				}
				if ($useParameter) {
					if ($self->parameterHandler->parameterIsSpecified($params, $p)) {
						$self->parameterHandler->addValuesToTemplateParameter($p);
					}
					my $value = $self->parameterHandler->getValueOfTemplateParameter($params, $p);
					$templateParameters{$p->{'id'}} = $value;
				}
			}
		}
	}

	$log->debug('templateParameters = '.Dumper(\%templateParameters));

	# add the name of template on which the dynamic playlist is based
	$templateParameters{'basetemplate'} = $template->{'name'};
	$templateParameters{'exacttitlesearch'} = $prefs->get('exacttitlesearch');

	my $templateFileData = $templateFile;
	my $itemData = $self->fillTemplate($templateFileData, \%templateParameters);
	$params->{'sqltextdplonly'} = $itemData;

	$params->{'pluginWebPageMethodsError'} = undef;
	if (!$params->{'itemparameter_playlistname'}) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_DPLNAME');
	}

	if (!$params->{'file'}) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_FILENAME');
	}


	# check if dpl requires user input
	my $isPreselectionTemplate = $templateId;
	$isPreselectionTemplate =~ s/\.sql\.xml//g;
	$params->{'nouserinput'} = 1 if !$params->{'itemparameter_request1fromuser'} && !$params->{'itemparameter_request2fromuser'} && !$params->{'itemparameter_datasource'} && $isPreselectionTemplate !~ m/.*_preselection.*$/;

	my $dir = $self->customItemDirectory;
	if (!defined $dir || !-d $dir) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_CUSTOMDIR');
	}
	my $file = unescape($params->{'file'});
	my $url = catfile($dir, $file);
	my $customUrl = catfile($dir, $file.".".$self->extension);
	if (!$self->saveSimpleItem($client, $params, $url, $templateId, $templates, $customUrl)) {
		$log->debug('saveSimpleItem FAILED - return to edit mode');
		return Slim::Web::HTTP::filltemplatefile($self->webTemplates->{'webEditItem'}, $params);
	} else {
		$log->debug('saveSimpleItem succeeded');
		$params->{'dplrefresh'} = 1;
		return $self->webCallbacks->webList($client, $params);
	}
}

sub webSaveNewItem {
	my ($self, $client, $params, $templateId, $templates) = @_;
	$log->debug('Start webSaveNewItem');

	$params->{'pluginWebPageMethodsError'} = undef;

	if (!$params->{'file'}) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_FILENAME');
	}

	my $dir = $self->customItemDirectory;
	if (!defined $dir || !-d $dir) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_CUSTOMDIR');
	}
	my $file = unescape($params->{'file'}).".".$self->simpleExtension;
	my $customFile = $file;
	my $regexp1 = ".".$self->simpleExtension."\$";
	$regexp1 =~ s/\./\\./;
	my $regexp2 = ".".$self->extension;
	$customFile =~ s/$regexp1/$regexp2/;
	my $url = catfile($dir, $file);
	my $customUrl = catfile($dir, $customFile);

	# check if dpl requires user input
	my $isPreselectionTemplate = $templateId;
	$isPreselectionTemplate =~ s/\.sql\.xml//g;
	$params->{'nouserinput'} = 1 if !$params->{'itemparameter_request1fromuser'} && !$params->{'itemparameter_request2fromuser'} && !$params->{'itemparameter_datasource'} && $isPreselectionTemplate !~ m/.*_preselection.*$/;

	if (!defined($params->{'pluginWebPageMethodsError'}) && -e $url && !$params->{'overwrite'}) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_ITEM_EXISTS');
	}
	if (!defined($params->{'pluginWebPageMethodsError'}) && -e $customUrl && !$params->{'overwrite'}) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_CUSTOMIZEDITEM_EXISTS');
	}

	if (!$self->saveSimpleItem($client, $params, $url, $templateId, $templates, $customUrl)) {
		return Slim::Web::HTTP::filltemplatefile($self->webTemplates->{'webNewItem'}, $params);
	} else {
		$params->{'dplrefresh'} = 1;
		return $self->webCallbacks->webList($client, $params);
	}
}

sub saveSimpleItem {
	my ($self, $client, $params, $url, $templateId, $templates, $customUrl) = @_;
	my $fh;
	$log->debug('Start saveSimpleItem');
	my $regexp = $self->simpleExtension;
	$regexp =~ s/\./\\./;
	$regexp = ".*".$regexp."\$";
	if (!($url =~ /$regexp/)) {
		$url .= ".".$self->simpleExtension;
	}

	if (!($params->{'pluginWebPageMethodsError'})) {
		$log->debug("Opening configuration file: $url");
		open($fh, ">:encoding(UTF-8)", $url) or do {
			$params->{'pluginWebPageMethodsError'} = "Error saving $url:".$!;
		};
	}

	# write simple file
	if (!($params->{'pluginWebPageMethodsError'})) {
		my $template = $templates->{$templateId};
		my %templateParameters = ();
		my $data = "";
		$data .= "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<dynamicplaylistcreator>\n\t<template>\n\t\t<id>".$templateId."</id>";
		# include template version
		$data .= "\n\t\t<templateversion>".$template->{'templateversion'}."</templateversion>" if $template->{'templateversion'};
		# record if dpl requires user input
		$data .= "\n\t\t<nouserinput>".$params->{'nouserinput'}."</nouserinput>" if $params->{'nouserinput'};

		if (defined($template->{'parameter'})) {
			my $parameters = $template->{'parameter'};
			if (ref($parameters) ne 'ARRAY') {
				my @parameterArray = ();
				if (defined($parameters)) {
					push @parameterArray, $parameters;
				}
				$parameters = \@parameterArray;
			}
			for my $p (@{$parameters}) {
				if (defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
					my $useParameter = 1;
					if (defined($p->{'requireplugins'})) {
						$useParameter = Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'});
					}
					if ($useParameter) {
						if ($self->parameterHandler->parameterIsSpecified($params, $p)) {
							$self->parameterHandler->addValuesToTemplateParameter($p);
						}
						my $value = $self->parameterHandler->getXMLValueOfTemplateParameter($params, $p);
						my $rawValue = '';
						if (defined($p->{'rawvalue'}) && $p->{'rawvalue'}) {
							$rawValue = " rawvalue=\"1\"";
						}
						if ($p->{'quotevalue'}) {
							$data .= "\n\t\t<parameter type=\"text\" id=\"".$p->{'id'}."\" quotevalue=\"1\"$rawValue>";
						} else {
							$data .= "\n\t\t<parameter type=\"text\" id=\"".$p->{'id'}."\"$rawValue>";
						}
						$data .= $value.'</parameter>';
					}
				}
			}
		}
		$data .= "\n\t</template>\n</dynamicplaylistcreator>\n";
		my $encoding = Slim::Utils::Unicode::encodingFromString($data);
		if ($encoding eq 'utf8') {
			$data = Slim::Utils::Unicode::utf8toLatin1($data);
		}

		$log->debug("Writing to file: $url");
		print $fh $data;
		$log->debug('Writing to file succeeded');
		close $fh;
	}

	# write adv file
	if (!($params->{'pluginWebPageMethodsError'})) {
		$self->saveItem($client, $params, $customUrl, 1);
	}

	if ($params->{'pluginWebPageMethodsError'}) {
		my $template = $templates->{$templateId};
		if (defined($template->{'parameter'})) {
			my @templateDataParameters = ();
			my $parameters = $template->{'parameter'};
			if (ref($parameters) ne 'ARRAY') {
				my @parameterArray = ();
				if (defined($parameters)) {
					push @parameterArray, $parameters;
				}
				$parameters = \@parameterArray;
			}
			for my $p (@{$parameters}) {
				my $useParameter = 1;
				if (defined($p->{'requireplugins'})) {
					$useParameter = Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'});
				}
				if ($useParameter) {
					$self->parameterHandler->addValuesToTemplateParameter($p);
					my $value = $self->parameterHandler->getXMLValueOfTemplateParameter($params, $p);
					if (defined($value) && $value ne '') {
						my $valueData = '<data>'.$value.'</data>';
						my $xmlValue = eval { XMLin($valueData, forcearray => ['value'], keyattr => []) };
						if (defined($xmlValue)) {
							$xmlValue->{'id'} = $p->{'id'};
							push @templateDataParameters, $xmlValue;
						}
					}
				}
			}
			my %currentParameterValues = ();
			for my $p (@templateDataParameters) {
				my $values = $p->{'value'};
				my %valuesHash = ();
				for my $v (@{$values}) {
					if (ref($v) ne 'HASH') {
						$valuesHash{$v} = $v;
					}
				}
				if (!%valuesHash) {
					$valuesHash{''} = '';
				}
				$currentParameterValues{$p->{'id'}} = \%valuesHash;
			}

			my @parametersToSelect = ();
			for my $p (@{$parameters}) {
				if (defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
					my $useParameter = 1;
					if (defined($p->{'requireplugins'})) {
						$useParameter = Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'});
					}
					if ($useParameter) {
						$self->parameterHandler->setValueOfTemplateParameter($p, $currentParameterValues{$p->{'id'}});
						push @parametersToSelect, $p;
					}
				}
			}
			my %templateParameters = ();
			for my $p (keys %{$params}) {
				my $regexp = '^'.$self->parameterHandler->parameterPrefix.'_';
				if ($p =~ /$regexp/) {
					$templateParameters{$p} = $params->{$p};
				}
			}

			$params->{'pluginWebPageMethodsEditItemParameters'} = \@parametersToSelect;
			$params->{'pluginWebPageMethodsNewItemParameters'} =\%templateParameters;
		}
		$params->{'pluginWebPageMethodsNewItemTemplate'} = $templateId;
		$params->{'pluginWebPageMethodsEditItemTemplate'} = $templateId;
		$params->{'pluginWebPageMethodsEditItemFile'} = $params->{'file'};
		$params->{'pluginWebPageMethodsEditItemFileUnescaped'} = unescape($params->{'pluginWebPageMethodsEditItemFile'});
		return undef;
	} else {
		return 1;
	}
}

sub saveItem {
	my ($self, $client, $params, $url, $dplonly) = @_;
	my $fh;
	$log->debug('Start saveItem');

	my $regexp = ".".$self->extension."\$";
	$regexp =~ s/\./\\./;
	if (!($url =~ /$regexp/)) {
		$url .= ".".$self->extension;
	}
	my $data = undef;

	$data = $dplonly ? Slim::Utils::Unicode::utf8decode_locale($params->{'sqltextdplonly'}) : Slim::Utils::Unicode::utf8decode_locale($params->{'text'});
	$data =~ s/\r+\n/\n/g; # Remove any extra \r character, will create duplicate linefeeds on Windows if not removed

	if (!($params->{'pluginWebPageMethodsError'})) {
		$log->debug("Opening configuration file: $url");
		open($fh, ">:encoding(UTF-8)", $url) or do {
			$params->{'pluginWebPageMethodsError'} = "Error saving $url: ".$!;
		};
	}
	if (!($params->{'pluginWebPageMethodsError'})) {

		$log->debug("Writing to file: $url");
		my $encoding = Slim::Utils::Unicode::encodingFromString($data);
		if ($encoding eq 'utf8') {
			$data = Slim::Utils::Unicode::utf8toLatin1($data);
		}
		print $fh $data;
		$log->debug('Writing to file succeeded');
		close $fh;
	}

	if ($params->{'pluginWebPageMethodsError'}) {
		$params->{'pluginWebPageMethodsEditItemFile'} = $params->{'file'};
		$params->{'pluginWebPageMethodsEditItemData'} = encode_entities($params->{'text'});
		$params->{'pluginWebPageMethodsEditItemFileUnescaped'} = unescape($params->{'pluginWebPageMethodsEditItemFile'});
		return undef;
	} else {
		return 1;
	}
}

sub webExportItem {
	my ($self, $client, $params, $itemId, $items) = @_;
	my $data = $self->loadItemDataFromAnyDir($itemId);
	$log->debug('itemId = '.$itemId.' -- data = '.Dumper($data));

	# get DPL folder for custom dpls
	my $dpl_customPLfolder = preferences('plugin.dynamicplaylists4')->get('customplaylistfolder');
	if (!defined $dpl_customPLfolder || !-d $dpl_customPLfolder) {
		$log->error(string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_CUSTOMDIR'));
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_MISSING_DPLCUSTOMDIR');
		return $self->webCallbacks->webList($client, $params);
	}

	my $url = catfile($dpl_customPLfolder, $itemId).'.sql';
	$log->debug('url = '.Dumper($url));
	if (-e $url) {
		$params->{'pluginWebPageMethodsError'} = string('PLUGIN_DYNAMICPLAYLISTCREATOR_ERROR_DPLFILENAMEALREADYEXISTS');
		return $self->webCallbacks->webList($client, $params);
	}

	my $fh;
	open($fh, ">:encoding(UTF-8)", $url) or do {
		$params->{'pluginWebPageMethodsError'} = "Error saving $url: ".$!;
		return $self->webCallbacks->webList($client, $params);
	};

	if (!($params->{'pluginWebPageMethodsError'})) {
		$log->debug("Writing to file: $url");
		my $encoding = Slim::Utils::Unicode::encodingFromString($data);
		if ($encoding eq 'utf8') {
			$data = Slim::Utils::Unicode::utf8toLatin1($data);
		}
		print $fh $data;
		$log->debug('Writing to file succeeded');
		close $fh;

		webDeleteItem($self, $client, $params, $itemId, $items);
	}
}

sub structureItemTypes {
	my ($self, $templates) = @_;
	my @templatesArray = ();

	for my $key (keys %{$templates}) {
		push @templatesArray, $templates->{$key};
	}
	return \@templatesArray;
}

sub loadItemDataFromAnyDir {
	my ($self, $itemId) = @_;
	my $data = undef;

	my $directories = $self->itemDirectories;
	for my $dir (@{$directories}) {
		$data = $self->contentDirectoryHandler->readDataFromDir($dir, $itemId);
		if (defined($data)) {
			last;
		}
	}
	return $data;
}

sub loadTemplateFromAnyDir {
	my ($self, $templateId) = @_;
	my $data = undef;

	my $directories = $self->templateDirectories;
	for my $dir (@{$directories}) {
		$data = $self->templateDirectoryHandler->readDataFromDir($dir, $templateId);
		if (defined($data)) {
			last;
		}
	}
	return $data;
}

sub loadTemplateDataFromAnyDir {
	my ($self, $templateId) = @_;
	my $data = undef;

	my $directories = $self->templateDirectories;
	for my $dir (@{$directories}) {
		$data = $self->templateDataDirectoryHandler->readDataFromDir($dir, $templateId);
		if (defined($data)) {
			last;
		}
	}
	return $data;
}

sub loadTemplateValues {
	my ($self, $client, $itemId, $item) = @_;
	my $templateData = undef;

	my $itemDirectories = $self->itemDirectories;
	for my $dir (@{$itemDirectories}) {
		my $content = $self->contentTemplateDirectoryHandler->readDataFromDir($dir, $itemId);
		if (defined($content)) {
			my $xml = eval { XMLin($content, forcearray => ["parameter", "value"], keyattr => []) };
			if ($@) {
				$log->error("Failed to parse configuration because: $@");
			} else {
				$templateData = $xml->{'template'};
			}
		}
		if (defined($templateData)) {
			last;
		}
	}
	return $templateData;
}

sub getTemplate {
	my $self = shift;
	if (!defined($self->template)) {
		$self->template(Template->new({
			INCLUDE_PATH => $self->templateDirectories,
			COMPILE_DIR => catdir($serverPrefs->get('cachedir'), 'templates'),
			FILTERS => {
				'string' => \&Slim::Utils::Strings::string,
				'getstring' => \&Slim::Utils::Strings::getString,
				'resolvestring' => \&Slim::Utils::Strings::resolveString,
				'nbsp' => \&nonBreaking,
				'uri' => \&URI::Escape::uri_escape_utf8,
				'unuri' => \&URI::Escape::uri_unescape,
				'utf8decode' => \&Slim::Utils::Unicode::utf8decode,
				'utf8encode' => \&Slim::Utils::Unicode::utf8encode,
				'utf8on' => \&Slim::Utils::Unicode::utf8on,
				'utf8off' => \&Slim::Utils::Unicode::utf8off,
				'fileurl' => \&fileURLFromPath,
			},
			EVAL_PERL => 1,
		}));
	}
	return $self->template;
}

sub fileURLFromPath {
	my $path = shift;
	if ($utf8filenames) {
		$path = Slim::Utils::Unicode::utf8off($path);
	} else {
		$path = Slim::Utils::Unicode::utf8on($path);
	}
	$path = decode_entities($path);
	$path =~ s/\'\'/\'/g;
	$path = Slim::Utils::Misc::fileURLFromPath($path);
	$path = Slim::Utils::Unicode::utf8on($path);
	$path =~ s/%/\\%/g;
	$path =~ s/\'/\'\'/g;
	$path = encode_entities($path, "&<>\'\"");
	return $path;
}

sub fillTemplate {
	my ($self, $filename, $params) = @_;

	my $output = '';
	$params->{'LOCALE'} = 'utf-8';
	my $template = $self->getTemplate();
	if (!$template->process($filename, $params, \$output)) {
		$log->error("ERROR parsing template: ".$template->error());
	}
	return $output;
}

*escape = \&URI::Escape::uri_escape_utf8;

sub unescape {
	my ($in, $isParam) = @_;
	return if !$in;
	$in =~ s/\+/ /g if $isParam;
	$in =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	return $in;
}

1;
