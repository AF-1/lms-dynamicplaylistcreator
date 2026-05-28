#
# Dynamic Playlist Creator
# (c) 2022 AF
# Licensed under the GPLv3 - see LICENSE file
#

package Plugins::DynamicPlaylistCreator::ConfigManager::TemplateParser;

use strict;
use warnings;
use utf8;

use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);

use Plugins::DynamicPlaylistCreator::ConfigManager::BaseParser;
our @ISA = qw(Plugins::DynamicPlaylistCreator::ConfigManager::BaseParser);

my $log = logger('plugin.dynamicplaylistcreator');

sub new {
	my ($class, $parameters) = @_;

	$parameters->{'contentType'} = 'template';
	my $self = $class->SUPER::new($parameters);

	return $self;
}

sub parse {
	my ($self, $client, $item, $content, $items, $globalcontext, $localcontext) = @_;

	return $self->parseContent($client, $item, $content, $items, $globalcontext, $localcontext);
}

1;
