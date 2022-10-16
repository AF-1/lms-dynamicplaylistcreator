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

package Plugins::DynamicPlaylistCreator::ConfigManager::DirectoryLoader;

use strict;
use warnings;
use utf8;

use base qw(Slim::Utils::Accessor);
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use File::Spec::Functions qw(:ALL);
use File::Basename;
use File::Slurp;
use FindBin qw($Bin);
use Cache::Cache qw($EXPIRES_NEVER);
use Data::Dumper;

__PACKAGE__->mk_accessor(rw => qw(pluginVersion extension includeExtensionInIdentifier identifierExtension parser cacheName cache cacheItems));

my $log = logger('plugin.dynamicplaylistcreator');

sub new {
	my ($class, $parameters) = @_;

	my $self = $class->SUPER::new();
	$self->extension($parameters->{'extension'});
	$self->identifierExtension($parameters->{'identifierExtension'});
	$self->includeExtensionInIdentifier($parameters->{'includeExtensionInIdentifier'});
	$self->parser($parameters->{'parser'});
	$self->cacheName($parameters->{'cacheName'});
	my $cacheVersion = $parameters->{'pluginVersion'};
	$cacheVersion =~ s/^.*\.([^\.]+)$/$1/;
	if (defined($self->cacheName)) {
		$self->cache(Slim::Utils::Cache->new($self->cacheName, $cacheVersion));
	}

	return $self;
}

sub readFromCache {
	my $self = shift;

	if (defined($self->cacheName) && defined($self->cache)) {
		$self->cacheItems($self->cache->get($self->cacheName));
		if (!defined($self->cacheItems)) {
			my %noItems = ();
			my %empty = (
				'items' => \%noItems,
				'timestamp' => undef,
			);
			$self->cacheItems(\%empty);
		}
	}
	if (defined($self->parser)) {
		$self->parser->readFromCache();
	}
}

sub writeToCache {
	my $self = shift;

	if (defined($self->cacheName) && defined($self->cache) && defined($self->cacheItems)) {
		$self->cacheItems->{'timestamp'} = time();
		$self->cache->set($self->cacheName, $self->cacheItems, $EXPIRES_NEVER);
	}
	if (defined($self->parser)) {
		$self->parser->writeToCache();
	}
}

sub readFromDir {
	my ($self, $client, $dir, $items, $globalcontext) = @_;

	$log->debug("Loading configuration from: $dir");
	$self->readFromCache();
	my @dircontents = Slim::Utils::Misc::readDirectory($dir, $self->extension, 'dorecursive');

	my $extensionRegexp = "\\.".$self->extension."\$";
	for my $item (@dircontents) {
		next unless $item =~ /$extensionRegexp/;
		next if -d catdir($dir, $item);

		my $path = $item;
		$item = basename($item);

		my $extension = $self->extension;
		$extension =~ s/\./\\./;
		$extension = ".".$extension."\$";
		if (!defined($self->includeExtensionInIdentifier) || !$self->includeExtensionInIdentifier) {
			$item =~ s/$extension//;
		}

		my $timestamp = (stat ($path))[9];

		# read_file from File::Slurp
		my $content = undef;
		if (defined($self->cacheItems) && defined($self->cacheItems->{'items'}->{$path}) && defined($timestamp) && $self->cacheItems->{'items'}->{$path}->{'timestamp'}>=$timestamp) {
			#$log->debug("Reading $item from cache");
			$content = $self->cacheItems->{'items'}->{$path}->{'data'};
		} else {
			$content = eval { read_file($path) };
			if ($content) {
				my $encoding = Slim::Utils::Unicode::encodingFromString($content);
				if ($encoding ne 'utf8') {
					$content = Slim::Utils::Unicode::latin1toUTF8($content);
					$content = Slim::Utils::Unicode::utf8on($content);
					$log->debug("Loading $item and converting from latin1");
				} else {
					$content = Slim::Utils::Unicode::utf8decode($content, 'utf8');
					$log->debug("Loading $item without conversion with encoding ".$encoding);
				}
			}
		}
		if ($content) {
			if (defined($self->cacheItems) && defined($timestamp)) {
				my %entry = (
					'data' => $content,
					'timestamp' => $timestamp
				);
				delete $self->cacheItems->{'items'}->{$path};
				$self->cacheItems->{'items'}->{$path} = \%entry;
			}
			if (defined($self->parser)) {
				my %localcontext = ();
				if (defined($timestamp)) {
					$localcontext{'timestamp'} = $timestamp;
				}
				$localcontext{'cacheNamePrefix'} = $dir.$self->extension;
				$log->debug("Parsing file: $path");
				my $errorMsg = $self->parser->parse($client, $item, $content, $items, $globalcontext, \%localcontext);
				if ($errorMsg) {
					$log->warn("Unable to open file: $path\n$errorMsg");
				}
			}
		} else {
			if ($@) {
				$log->warn("Unable to open file: $path\nBecause of: $@");
			} else {
				$log->warn("Unable to open file: $path");
			}
		}
	}
	$self->writeToCache();
}

sub readDataFromDir {
	my ($self, $dir, $itemId) = @_;

	my $file = $itemId;
	if ($self->includeExtensionInIdentifier) {
		my $regExp = "\.".$self->identifierExtension."\$";
		$regExp =~ s/\./\\./g;
		$file =~ s/$regExp//;
		$file .= ".".$self->extension;
	} else {
		$file .= ".".$self->extension;
	}

	$log->debug("Loading item data from: $dir/$file");

	my $path = catfile($dir, $file);

	return unless -f $path;

	my $timestamp = (stat ($path))[9];
	if (defined($self->cacheItems) && defined($self->cacheItems->{'items'}->{$path}) && defined($timestamp) && $self->cacheItems->{'items'}->{$path}->{'timestamp'}>=$timestamp) {
		#$log->debug("Reading $item from cache");
		return $self->cacheItems->{'items'}->{$path}->{'data'};
	}

	my $content = eval { read_file($path) };
	if ($@) {
		$log->warn("Failed to load item data because: $@");
	}
	if (defined($content)) {
		my $encoding = Slim::Utils::Unicode::encodingFromString($content);
		if ($encoding ne 'utf8') {
			$content = Slim::Utils::Unicode::latin1toUTF8($content);
			$content = Slim::Utils::Unicode::utf8on($content);
			$log->debug("Loading $itemId and converting from latin1 to $encoding");
		} else {
			$content = Slim::Utils::Unicode::utf8decode($content, 'utf8');
			$log->debug("Loading $itemId without conversion with encoding ".$encoding);
		}
		if (defined($timestamp) && defined($self->cacheItems)) {
			my %entry = (
				'data' => $content,
				'timestamp' => $timestamp,
			);
			$self->cacheItems->{'items'}->{$path} = \%entry;
		}
		$log->debug("Loading of item data succeeded");
	}
	return $content;
}

1;
