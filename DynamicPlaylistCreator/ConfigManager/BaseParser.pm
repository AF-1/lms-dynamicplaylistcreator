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
use HTML::Entities;

__PACKAGE__->mk_accessor(rw => qw(pluginVersion contentType templateHandler));

my $utf8filenames = 1;
my $serverPrefs = preferences('server');

my $log = logger('plugin.dynamicplaylistcreator');

sub new {
	my ($class, $parameters) = @_;

	my $self = $class->SUPER::new($parameters);
	$self->pluginVersion($parameters->{'pluginVersion'});
	$self->contentType($parameters->{'contentType'});
	if (defined($parameters->{'utf8filenames'})) {
		$utf8filenames = $parameters->{'utf8filenames'};
	}

	return $self;
}

sub parseContent {
	my ($self, $client, $item, $content, $items, $globalcontext, $localcontext) = @_;
	my $errorMsg = undef;
	if ($content) {
		my $result = eval { $self->parseContentImplementation($client, $item, $content, $items, $globalcontext, $localcontext) };

		if (!$@ && defined($result)) {
			$items->{$item} = $result;
		} else {
			main::DEBUGLOG && $log->is_debug && $log->debug("Skipping $item: $@");
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

	my $errorMsg = undef;
	if ($content) {
		my $valuesXml = eval { XMLin($content, forcearray => ["parameter", "value"], keyattr => []) };
		if ($@) {
			$errorMsg = "$@";
			$log->warn("Failed to parse ".$self->contentType." configuration ($item) because: $@");
		} else {
			my $templateId = lc($valuesXml->{'template'}->{'id'});
			my $template = $templates->{$templateId};
			if (!defined($template)) {
				main::DEBUGLOG && $log->is_debug && $log->debug("Template $templateId not found");
				undef $content;
				return undef;
			}

			my %templateParameters = ();

			# check if dpl is context menu list
			my $isContextMenuList = $template->{'contextmenu'};
			$templateParameters{'contextmenu'} = $isContextMenuList;

			# params
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
						if (defined($p->{'minlmsversion'}) && (versionToInt($::VERSION) < versionToInt($p->{'minlmsversion'}))) {
								main::DEBUGLOG && $log->is_debug && $log->debug('LMS version = '.$::VERSION.' -- min. LMS version for param "'.$p->{'id'}.'" = '.$p->{'minlmsversion'});
								$templateParameters{$p->{'id'}} = undef;
						}
						if (defined($templateParameters{$p->{'id'}})) {
							if (Slim::Utils::Unicode::encodingFromString($templateParameters{$p->{'id'}}) ne 'utf8') {
								$templateParameters{$p->{'id'}} = Slim::Utils::Unicode::latin1toUTF8($templateParameters{$p->{'id'}});
							}
						}
					}
				}

				# store selected params in localcontext
				$localcontext->{'nouserinput'} = $valuesXml->{'template'}->{'nouserinput'};
				$localcontext->{'contextmenu'} = $templateParameters{'contextmenu'} || 0;
				$localcontext->{'playlistname'} = $templateParameters{'playlistname'};
			}

			my $playlistid = $item;
			my $file = $item;

			my %playlist = (
				'id' => $playlistid,
				'file' => $file,
				'name' => $localcontext->{'playlistname'},
				'contextmenu' => $localcontext->{'contextmenu'},
				'nouserinput' => $localcontext->{'nouserinput'}
			);

			$items->{$item} = \%playlist;

			# Release content
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
		$log->error("ERROR parsing template: ".$template->error());
	}
	return $output;
}

sub isEnabled {
	my $self = shift;
	my $client = shift;
	my $xml = shift;

	# enable/disable complete(!) template, not just individual params
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

	main::DEBUGLOG && $log->is_debug && $log->debug('XMLin part');
	my $xml = eval { XMLin($content, forcearray => ["item"], keyattr => []) };

	if ($@) {
		$log->warn("Failed to parse configuration ($item) because: $@");
	} else {
		my $include = $self->isEnabled($client, $xml);
		if (defined($xml->{$self->contentType})) {
			$xml->{$self->contentType}->{'id'} = escape($item);
		}
		return $xml->{$self->contentType} if $include;
	}
	return undef;
}

sub versionToInt {
	my $versionString = shift;
	my @parts = split /\./, $versionString;
	my $formatted = 0;
	foreach my $p (@parts) {
		$formatted *= 100;
		$formatted += int($p);
	}
	return $formatted;
}

*escape = \&URI::Escape::uri_escape_utf8;
*unescape = \&URI::Escape::uri_unescape;

1;
