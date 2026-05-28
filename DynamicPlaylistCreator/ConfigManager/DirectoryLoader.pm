#
# Dynamic Playlist Creator
# (c) 2022 AF
# Licensed under the GPLv3 - see LICENSE file
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

__PACKAGE__->mk_accessor(rw => qw(pluginVersion extension includeExtensionInIdentifier identifierExtension parser));

my $log = logger('plugin.dynamicplaylistcreator');

sub new {
	my ($class, $parameters) = @_;

	my $self = $class->SUPER::new();
	$self->extension($parameters->{'extension'});
	$self->identifierExtension($parameters->{'identifierExtension'});
	$self->includeExtensionInIdentifier($parameters->{'includeExtensionInIdentifier'});
	$self->parser($parameters->{'parser'});

	return $self;
}

sub readFromDir {
	my ($self, $client, $dir, $items, $globalcontext) = @_;

	main::DEBUGLOG && $log->is_debug && $log->debug("Loading configuration from: $dir");
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

		# read_file from File::Slurp
		my $content = eval { read_file($path) };
		if ($content) {
			my $encoding = Slim::Utils::Unicode::encodingFromString($content);
			if ($encoding ne 'utf8') {
				$content = Slim::Utils::Unicode::latin1toUTF8($content);
				$content = Slim::Utils::Unicode::utf8on($content);
				main::DEBUGLOG && $log->is_debug && $log->debug("Loading $item and converting from latin1");
			} else {
				$content = Slim::Utils::Unicode::utf8decode($content, 'utf8');
				main::DEBUGLOG && $log->is_debug && $log->debug("Loading $item without conversion with encoding ".$encoding);
			}
		}

		if ($content) {
			if (defined($self->parser)) {
				my %localcontext = ();
				main::DEBUGLOG && $log->is_debug && $log->debug("Parsing file: $path");
				my $errorMsg = $self->parser->parse($client, $item, $content, $items, $globalcontext, \%localcontext);
				if ($errorMsg) {
					$log->error("Unable to open file: $path\n$errorMsg");
				}
			} else {
				main::DEBUGLOG && $log->is_debug && $log->debug('No parser defined');
			}
		} else {
			if ($@) {
				$log->error("Unable to open file: $path\nBecause of: $@");
			} else {
				$log->error("Unable to open file: $path");
			}
		}
	}
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

	main::DEBUGLOG && $log->is_debug && $log->debug("Loading item data from: $dir/$file");

	my $path = catfile($dir, $file);

	return unless -f $path;

	my $content = eval { read_file($path) };
	if ($@) {
		$log->error("Failed to load item data because: $@");
	}
	if (defined($content)) {
		my $encoding = Slim::Utils::Unicode::encodingFromString($content);
		if ($encoding ne 'utf8') {
			$content = Slim::Utils::Unicode::latin1toUTF8($content);
			$content = Slim::Utils::Unicode::utf8on($content);
			main::DEBUGLOG && $log->is_debug && $log->debug("Loading $itemId and converting from latin1 to $encoding");
		} else {
			$content = Slim::Utils::Unicode::utf8decode($content, 'utf8');
			main::DEBUGLOG && $log->is_debug && $log->debug("Loading $itemId without conversion with encoding ".$encoding);
		}
	}
	return $content;
}

1;
