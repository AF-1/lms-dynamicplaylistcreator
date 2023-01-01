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

package Plugins::DynamicPlaylistCreator::ConfigManager::BaseParser;

use strict;
use warnings;
use utf8;

use base qw(Slim::Utils::Accessor);
use Slim::Utils::Prefs;
use Slim::Utils::Misc;
use Slim::Utils::Log;
use Slim::Utils::Strings qw(string);
use File::Spec::Functions qw(:ALL);
use XML::Simple;
use Data::Dumper;
use HTML::Entities;
use Cache::Cache qw($EXPIRES_NEVER);

__PACKAGE__->mk_accessor(rw => qw(pluginVersion contentType templateHandler cache cacheName cachePrefix cacheItems));

my $utf8filenames = 1;
my $serverPrefs = preferences('server');

my $log = logger('plugin.dynamicplaylistcreator');

sub new {
	my ($class, $parameters) = @_;

	my $self = $class->SUPER::new($parameters);
	$self->pluginVersion($parameters->{'pluginVersion'});
	$self->contentType($parameters->{'contentType'});
	$self->cacheName($parameters->{'cacheName'});
	$self->cachePrefix($parameters->{'cachePrefix'});
	my $cacheVersion = $parameters->{'pluginVersion'};
	$cacheVersion =~ s/^.*\.([^\.]+)$/$1/;
	if (defined($self->cacheName)) {
		$self->cache(Slim::Utils::Cache->new($self->cacheName, $cacheVersion));
	}
	if (defined($parameters->{'utf8filenames'})) {
		$utf8filenames = $parameters->{'utf8filenames'};
	}

	return $self;
}

sub readFromCache {
	my $self = shift;

	if (defined($self->cacheName) && defined($self->cache)) {
		$self->cacheItems($self->cache->get($self->cachePrefix));
		if (!defined($self->cacheItems)) {
			my %noItems = ();
			my %empty = (
				'items' => \%noItems,
				'timestamp' => undef,
			);
			$self->cacheItems(\%empty);
		}
	}
}

sub writeToCache {
	my $self = shift;

	if (defined($self->cacheName) && defined($self->cache) && defined($self->cacheItems)) {
		$self->cacheItems->{'timestamp'} = time();
		$self->cache->set($self->cachePrefix, $self->cacheItems, $EXPIRES_NEVER);
	}
}

sub parseContent {
	my ($self, $client, $item, $content, $items, $globalcontext, $localcontext) = @_;

	my $errorMsg = undef;
		if ($content) {
		my $result = eval { $self->parseContentImplementation($client, $item, $content, $items, $globalcontext, $localcontext) };
		if (!$@ && defined($result)) {
			my $timestamp = undef;
			if (defined($localcontext->{'timestamp'})) {
				$timestamp = $localcontext->{'timestamp'};
			}
			if (!defined($items->{$item}) || !defined($timestamp) || !defined($items->{$item}->{'timestamp'}) || $items->{$item}->{'timestamp'}<=$timestamp) {
				$log->debug("Storing parsed result for $item");
				$items->{$item} = $result;
			} else {
				$log->debug("Skipping $item, newer entry already loaded");
			}
		} else {
			$log->debug("Skipping $item: $@");
			$errorMsg = "$@";
		}
		# Release content
		undef $content;
	} else {
		if ($@) {
			$errorMsg = "Incorrect information in data: $@";
			$log->warn("Unable to read configuration: $@");
		} else {
			$errorMsg = 'Incorrect information in data';
			$log->warn('Unable to to read configuration');
		}
	}
	return $errorMsg;
}

sub parseTemplateContent {
	my ($self, $client, $item, $content, $items, $templates, $globalcontext, $localcontext) = @_;

	my $cacheName = $item;
	if (defined($localcontext->{'cacheNamePrefix'})) {
		$cacheName = $localcontext->{'cacheNamePrefix'}.$cacheName;
	}

	my $errorMsg = undef;
	if ($content) {
		my $timestamp = undef;
		if (defined($localcontext->{'timestamp'})) {
			$timestamp = $localcontext->{'timestamp'};
		}
		my $valuesXml = undef;
		if (defined($timestamp) && defined($self->cacheItems) && defined($self->cacheItems->{'items'}->{'values_'.$cacheName}) && $self->cacheItems->{'items'}->{'values_'.$cacheName}->{'timestamp'}>=$timestamp) {
			$valuesXml = $self->cacheItems->{'items'}->{'values_'.$cacheName}->{'data'};
		} else {
			$valuesXml = eval { XMLin($content, forcearray => ["parameter", "value"], keyattr => []) };
			if (defined($timestamp) && defined($self->cacheItems)) {
				my %entry = (
					'data' => $valuesXml,
					'timestamp' => $timestamp,
				);
				delete $self->cacheItems->{'items'}->{'values_'.$cacheName};
				$self->cacheItems->{'items'}->{'values_'.$cacheName} = \%entry;
			}
		}

		if ($@) {
			$errorMsg = "$@";
			$log->warn("Failed to parse ".$self->contentType." configuration ($item) because: $@");
		} else {
			my $templateId = lc($valuesXml->{'template'}->{'id'});
			my $template = $templates->{$templateId};
			if (!defined($template)) {
				$log->debug("Template $templateId not found");
				undef $content;
				return undef;
			}
			if (defined($template->{'timestamp'}) && defined($timestamp) && $template->{'timestamp'}>$timestamp) {
				$timestamp = $template->{'timestamp'};
				$localcontext->{'timestamp'} = $timestamp;
			}
			my $itemData = undef;
			if (defined($timestamp) && defined($self->cacheItems) && defined($self->cacheItems->{'items'}->{'templatecontent_'.$cacheName}) && $self->cacheItems->{'items'}->{'templatecontent_'.$cacheName}->{'timestamp'}>=$timestamp) {
				$itemData = $self->cacheItems->{'items'}->{'templatecontent_'.$cacheName}->{'data'};

			} else {
				my %templateParameters = ();
				my $parameters = $valuesXml->{'template'}->{'parameter'};

				for my $p (@{$parameters}) {
					my $values = $p->{'value'};
					if (!defined($values)) {
						my $tmp = $p->{'content'};
						if (defined($tmp)) {
							my @tmpArray = ($tmp);
							$values = \@tmpArray;
						}
					}
					my $value = '';
					for my $v (@{$values}) {
						if (ref($v) ne 'HASH') {
							if ($value ne '') {
								$value .= ',';
							}
							if (!defined($p->{'rawvalue'}) || !$p->{'rawvalue'}) {
								$v =~ s/\'/\'\'/g;
							}
							if ($p->{'quotevalue'}) {
								$value .= "'".encode_entities($v, "&<>")."'";
							} else {
								$value .= encode_entities($v, "&<>");
							}
						}
					}
					$templateParameters{$p->{'id'}} = $value;
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
					for my $p (@{$parameters}) {
						if (defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
							if (!defined($templateParameters{$p->{'id'}})) {
								my $value = $p->{'value'};
								if (!defined($value) || ref($value) eq 'HASH') {
									my $tmp = $p->{'content'};
									if (defined($tmp)) {
										my @tmpArray = ($tmp);
										$value = \@tmpArray;
									} else {
										$value = '';
									}
								}
								$templateParameters{$p->{'id'}} = $value;
							}
							if (defined($p->{'requireplugins'})) {
								if (!(Slim::Utils::PluginManager->isEnabled('Plugins::'.$p->{'requireplugins'}))) {
									$templateParameters{$p->{'id'}} = undef;
								}
							}
							if (defined($templateParameters{$p->{'id'}})) {
								if (Slim::Utils::Unicode::encodingFromString($templateParameters{$p->{'id'}}) ne 'utf8') {
									$templateParameters{$p->{'id'}} = Slim::Utils::Unicode::latin1toUTF8($templateParameters{$p->{'id'}});
								}
							}
						}
					}
				}

				# record in localcontext if user input required
				$localcontext->{'nouserinput'} = $templateParameters{'nouserinput'};

				my $templateData = $self->loadTemplate($client, $template, \%templateParameters);
				if (!defined($templateData)) {
					$log->debug("Ignoring $item due to loadTemplate");
					undef $content;
					return undef;
				}
				my $templateFileData = $templateData->{'data'};

				my $doParsing = 1;
				if (!defined($templateData->{'parse'})) {
					$doParsing = 0;
				}

				if ($doParsing) {
					$itemData = $self->fillTemplate($templateFileData, \%templateParameters);
				} else {
					$itemData = $templateFileData;
				}

				if (defined($timestamp) && defined($self->cacheItems)) {
					my %entry = (
						'data' => $itemData,
						'timestamp' => $timestamp,
					);
					delete $self->cacheItems->{'items'}->{'templatecontent_'.$cacheName};
					$self->cacheItems->{'items'}->{'templatecontent_'.$cacheName} = \%entry;
				}
			}

			my $result = eval {$self->parseContentImplementation($client, $item, $itemData, $items, $globalcontext, $localcontext) };
			if (!$@ && defined($result)) {
			my $timestamp = undef;
				if (defined($localcontext->{'timestamp'})) {
					$timestamp = $localcontext->{'timestamp'};
				}
				if (!defined($items->{$item}) || !defined($timestamp) || !defined($items->{$item}->{'timestamp'}) || $items->{$item}->{'timestamp'} <= $timestamp) {
					$log->debug("Storing parsed result for $item");
					$items->{$item} = $result;
				} else {
					$log->debug("Skipping $item, newer entry already loaded");
				}
			} else {
				$log->debug("Skipping $item: $@");
				$errorMsg = "$@";
			}

			# Release content
			undef $itemData;
			undef $content;
		}
	} else {
		$errorMsg = "Incorrect information in data";
		$log->warn("Unable to to read configuration");
	}
	return $errorMsg;
}

sub getTemplate {
	my $self = shift;
	if (!defined($self->templateHandler)) {
		$self->templateHandler(Template->new({
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
				'fileurl' => \&templateFileURLFromPath,
			},
			EVAL_PERL => 1,
		}));
	}
	return $self->templateHandler;
}

sub templateFileURLFromPath {
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
		$log->warn("ERROR parsing template: ".$template->error());
	}
	return $output;
}

sub isEnabled {
	my $self = shift;
	my $client = shift;
	my $xml = shift;

	my $include = 1;
	if (defined($xml->{'requireplugins'}) && $include) {
		$include = 0;
		if (!defined($xml->{'requireplugins'}) || Slim::Utils::PluginManager->isEnabled('Plugins::'.$xml->{'requireplugins'})) {
			$include = 1;
		}
	}
	if ($include && defined($xml->{'minpluginversion'}) && $xml->{'minpluginversion'} =~ /(\d+)\.(\d+).*/) {
		my $downloadMajor = $1;
		my $downloadMinor = $2;
		if ($self->pluginVersion =~ /(\d+)\.(\d+).*/) {
			my $pluginMajor = $1;
			my $pluginMinor = $2;
			if ($pluginMajor == $downloadMajor && $pluginMinor >= $downloadMinor) {
				$include = 1;
			} else {
				$include = 0;
			}
		}
	}
	return $include;
}

sub parseContentImplementation {
	my ($self, $client, $item, $content, $items, $globalcontext, $localcontext) = @_;

	my $timestamp = undef;
	if (defined($localcontext->{'timestamp'})) {
		$timestamp = $localcontext->{'timestamp'};
	}
	my $cacheName = $item;
	if (defined($localcontext->{'cacheNamePrefix'})) {
		$cacheName = $localcontext->{'cacheNamePrefix'}.$cacheName;
	}

	my $xml = undef;
	if (defined($timestamp) && defined($self->cacheItems) && defined($self->cacheItems->{'items'}->{'content_'.$cacheName}) && $self->cacheItems->{'items'}->{'content_'.$cacheName}->{'timestamp'}>=$timestamp) {
		$xml = $self->cacheItems->{'items'}->{'content_'.$cacheName}->{'data'};
	} else {
		$log->debug('XMLin part');
		$xml = eval { XMLin($content, forcearray => ["item"], keyattr => []) };
	}

	if ($@) {
		$log->warn("Failed to parse configuration ($item) because: $@");
	} else {
		if (defined($timestamp) && defined($self->cacheItems)) {
			my %entry = (
				'data' => $xml,
				'timestamp' => $timestamp,
			);
			delete $self->cacheItems->{'items'}->{'content_'.$cacheName};
			$self->cacheItems->{'items'}->{'content_'.$cacheName} = \%entry;
		}

		my $include = $self->isEnabled($client, $xml);
		if (defined($xml->{$self->contentType})) {
			$xml->{$self->contentType}->{'id'} = escape($item);
			if (defined($timestamp)) {
				$xml->{$self->contentType}->{'timestamp'} = $timestamp;
			}
		}

		return $xml->{$self->contentType} if $include;
	}
	return undef;
}

*escape = \&URI::Escape::uri_escape_utf8;

sub unescape {
	my ($in, $isParam) = @_;
	$in =~ s/\+/ /g if $isParam;
	$in =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	return $in;
}

1;
