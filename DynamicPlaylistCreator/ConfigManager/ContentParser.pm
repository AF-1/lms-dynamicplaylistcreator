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

package Plugins::DynamicPlaylistCreator::ConfigManager::ContentParser;

use strict;
use warnings;
use utf8;

use base qw(Slim::Utils::Accessor);
use Slim::Buttons::Home;
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use HTML::Entities;
use Data::Dumper;

use Plugins::DynamicPlaylistCreator::ConfigManager::BaseParser;
our @ISA = qw(Plugins::DynamicPlaylistCreator::ConfigManager::BaseParser);

my $log = logger('plugin.dynamicplaylistcreator');

sub new {
	my ($class, $parameters) = @_;

	$parameters->{'contentType'} = 'playlist';
	my $self = $class->SUPER::new($parameters);
	return $self;
}

sub parse {
	my ($self, $client, $item, $content, $items, $globalcontext, $localcontext) = @_;
	return $self->parseContent($client, $item, $content, $items, $globalcontext, $localcontext);
}

sub parseContentImplementation {
	my ($self, $client, $item, $content, $items, $globalcontext, $localcontext) = @_;

	my $errorMsg = undef;
	if ($content) {
		decode_entities($content);

		my @playlistDataArray = split(/[\n\r]+/, $content);
		my $name = undef;
		my $statement = '';
		my $fulltext = '';
		my $dplTargetVersion = 0;

		for my $line (@playlistDataArray) {
			# Add linefeed to make sure playlist looks ok when editing
			$line .= "\n";
			if ($name && $line !~ /^\s*--\s*PlaylistGroups\s*[:=]\s*/) {
				$fulltext .= $line;
			}
			chomp $line;

			$line =~ s/^\s*--\s*PlaylistName\s*[:=]\s*//io;

			# parse dplTargetVersion from adv/sqlite def
			my $dplVersion = parseDPLtargetVersion($line);
			if ($dplVersion) {
				$dplTargetVersion = int($dplVersion);
			}

			# skip and strip comments & empty lines
			$line =~ s/\s*--.*?$//o;
			$line =~ s/^\s*//o;

			next if $line =~ /^--/;
			next if $line =~ /^\s*$/;

			if (!$name) {
				$name = $line;
			} else {
				$line =~ s/\s+$//;
				if ($statement) {
					if ($statement =~ /;$/) {
						$statement .= "\n";
					} else {
						$statement .= " ";
					}
				}
				$statement .= $line;
			}
		}

		if ($name && $statement) {
			my $playlistid = $item;
			my $file = $item;

			my %playlist = (
				'id' => $playlistid,
				'file' => $file,
				'name' => $name,
				'sql' => Slim::Utils::Unicode::utf8decode($statement, 'utf8'),
				'fulltext' => Slim::Utils::Unicode::utf8decode($fulltext, 'utf8')
			);

			if (defined($localcontext) && defined($localcontext->{'simple'})) {
				$playlist{'simple'} = 1;
			} else {
				$playlist{'dpltargetversion'} = $dplTargetVersion if $dplTargetVersion;
			}

			if (defined($localcontext) && defined($localcontext->{'dpltargetversion'})) {
				$playlist{'dpltargetversion'} = $localcontext->{'dpltargetversion'};
			}

			#$log->debug('playlist = '.Dumper(\%playlist));
			return \%playlist;
		}

	} else {
		if ($@) {
			$errorMsg = "Incorrect information in playlist data: $@";
			$log->warn("Unable to read playlist configuration: $@");
		} else {
			$errorMsg = "Incorrect information in playlist data";
			$log->warn("Unable to to read playlist configuration");
		}
	}
	return undef;
}

sub parseDPLtargetVersion {
	my $line = shift;
	if ($line =~ /^\s*--\s*dplTargetVersion\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*dplTargetVersion\s*[:=]\s*([^:]+)\s*(.*)$/;
		my $dplversion = $1;
		$dplversion =~ s/\s+$//;
		$dplversion =~ s/^\s+//;
		if ($dplversion) {
			return $dplversion;
		} else {
			$log->debug("No value or error in dplversion: $line");
			return undef;
		}
	}
	return undef;
}

*escape = \&URI::Escape::uri_escape_utf8;

1;
