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
		my @groups = ();
		my %parameters = ();
		my %options = ();
		my $menuListType = '';
		my $playlistCategory = '';
		my $playlistTrackOrder = '';
		my $playlistLimitOption = '';
		my $scope = '';
		my $playlistVLnames = ();
		my $playlistVLids = ();
		my %startactions = ();
		my %stopactions = ();
		for my $line (@playlistDataArray) {
			# Add linefeed to make sure playlist looks ok when editing
			$line .= "\n";
			if ($name && $line !~ /^\s*--\s*PlaylistGroups\s*[:=]\s*/) {
				$fulltext .= $line;
			}
			chomp $line;

			$line =~ s/^\s*--\s*PlaylistName\s*[:=]\s*//io;

			my $parameter = $self->parseParameter($line);
			my $action = $self->parseAction($line);
			my $option = $self->parseOption($line);
			my $listType = parseMenuListType($line);
			my $category = parseCategory($line);
			my $trackOrder = parseTrackOrder($line);
			my $limitOption = parseLimitOption($line);
			my $PLscope = parseScope($line);
			my $VLnameItem = parseVirtualLibraryName($line);
			my $VLidItem = parseVirtualLibraryID($line);
			if ($line =~ /^\s*--\s*PlaylistGroups\s*[:=]\s*/) {
				$line =~ s/^\s*--\s*PlaylistGroups\s*[:=]\s*//io;
				if ($line) {
					my @stringGroups = split(/\,/, $line);
					foreach my $group (@stringGroups) {
						# Remove all white spaces
						$group =~ s/^\s+//;
						$group =~ s/\s+$//;
						my @subGroups = split(/\//, $group);
						push @groups, \@subGroups;
					}
				}
				$line = "";
			}
			if ($parameter) {
				$parameters{$parameter->{'id'}} = $parameter;
			}
			if ($option) {
				$options{$option->{'id'}} = $option;
			}
			if ($action) {
				if ($action->{'execute'} eq 'Start') {
					$startactions{$action->{'id'}} = $action;
				} elsif ($action->{'execute'} eq 'Stop') {
					$stopactions{$action->{'id'}} = $action;
				}
			}
			if ($listType) {
				$menuListType = $listType;
			}
			if ($category) {
				$playlistCategory = $category;
			}
			if ($trackOrder) {
				$playlistTrackOrder = $trackOrder;
			}
			if ($limitOption) {
				$playlistLimitOption = $limitOption;
			}
			if ($PLscope) {
				$scope = $PLscope;
			}
			if (keys %{$VLnameItem}) {
				$$playlistVLnames{$VLnameItem->{'number'}} = $VLnameItem->{'name'};
			}
			if (keys %{$VLidItem}) {
				$$playlistVLids{$VLidItem->{'number'}} = $VLidItem->{'id'};
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
			}
			if (scalar(@groups)>0) {
				$playlist{'groups'} = \@groups;
			}
			if (%parameters) {
				$playlist{'parameters'} = \%parameters;
				my $playLists = $items;
				foreach my $p (keys %parameters) {
					if (defined($playLists)
						&& defined($playLists->{$playlistid})
						&& defined($playLists->{$playlistid}->{'parameters'})
						&& defined($playLists->{$playlistid}->{'parameters'}->{$p})
						&& $playLists->{$playlistid}->{'parameters'}->{$p}->{'name'} eq $parameters{$p}->{'name'}
						&& defined($playLists->{$playlistid}->{'parameters'}->{$p}->{'value'})) {

						$log->debug("Use already existing value PlaylistParameter$p = ".$playLists->{$playlistid}->{'parameters'}->{$p}->{'value'});
						$parameters{$p}->{'value'} = $playLists->{$playlistid}->{'parameters'}->{$p}->{'value'};
					}
				}
			}
			if (defined $menuListType && $menuListType ne '') {
				$playlist{'menulisttype'} = $menuListType;
			}
			if (defined $playlistCategory && $playlistCategory ne '') {
				$playlist{'playlistcategory'} = $playlistCategory;
			}
			if (defined $playlistTrackOrder && $playlistTrackOrder ne '') {
				$playlist{'playlisttrackorder'} = $playlistTrackOrder;
			}
			if (defined $playlistLimitOption && $playlistLimitOption ne '') {
				$playlist{'playlistlimitoption'} = $playlistLimitOption;
			}
			if (defined $scope && $scope ne '') {
				$playlist{'scope'} = $scope;
			}
			if (keys %{$playlistVLnames}) {
				$playlist{'playlistvirtuallibrarynames'} = $playlistVLnames;
			}
			if (keys %{$playlistVLids}) {
				$playlist{'playlistvirtuallibraryids'} = $playlistVLids;
			}
			if (%options) {
				$playlist{'options'} = \%options;
			}
			if (%startactions) {
				my @actionArray = ();
				for my $key (keys %startactions) {
					my $a = $startactions{$key};
					push @actionArray, $a;
				}
				$playlist{'startactions'} = \@actionArray;
			}
			if (%stopactions) {
				my @actionArray = ();
				for my $key (keys %stopactions) {
					my $a = $stopactions{$key};
					push @actionArray, $a;
				}
				$playlist{'stopactions'} = \@actionArray;
			}
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

sub parseParameter {
	my ($self, $line) = @_;

	if ($line =~ /^\s*--\s*PlaylistParameter\s*\d\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*PlaylistParameter\s*(\d)\s*[:=]\s*([^:]+):\s*([^:]*):\s*(.*)$/;
		my $parameterId = $1;
		my $parameterType = $2;
		my $parameterName = $3;
		my $parameterDefinition = $4;

		$parameterType =~ s/^\s+//;
		$parameterType =~ s/\s+$//;

		$parameterName =~ s/^\s+//;
		$parameterName =~ s/\s+$//;

		$parameterDefinition =~ s/^\s+//;
		$parameterDefinition =~ s/\s+$//;

		if ($parameterId && $parameterName && $parameterType) {
			my %parameter = (
				'id' => $parameterId,
				'type' => $parameterType,
				'name' => $parameterName,
				'definition' => $parameterDefinition
			);
			return \%parameter;
		} else {
			$log->warn("Error in parameter: $line");
			$log->warn("Parameter values: ID = $parameterId, Type = $parameterType, Name = $parameterName, Definition = $parameterDefinition");
			return undef;
		}
	}
	return undef;
}

sub parseAction {
	my ($self, $line, $actionType) = @_;

	if ($line =~ /^\s*--\s*Playlist(Start|Stop)Action\s*\d\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*Playlist(Start|Stop)Action\s*(\d)\s*[:=]\s*([^:]+):\s*(.*)$/;
		my $executeTime = $1;
		my $actionId = $2;
		my $actionType = $3;
		my $actionDefinition = $4;

		$actionType =~ s/^\s+//;
		$actionType =~ s/\s+$//;

		$actionDefinition =~ s/^\s+//;
		$actionDefinition =~ s/\s+$//;

		if ($actionId && $actionType && $actionDefinition) {
			my %action = (
				'id' => $actionId,
				'execute' => $executeTime,
				'type' => $actionType,
				'data' => $actionDefinition
			);
			return \%action;
		} else {
			$log->warn("Error in action: $line");
			$log->warn("Action values: ID = $actionId, Type = $actionType, Definition = $actionDefinition");
			return undef;
		}
	}
	return undef;
}

sub parseOption {
	my ($self, $line) = @_;
	if ($line =~ /^\s*--\s*PlaylistOption\s*[^:=]+\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*PlaylistOption\s*([^:=]+)\s*[:=]\s*(.+)\s*$/;
		my $optionId = $1;
		my $optionValue = $2;

		$optionId =~ s/\s+$//;

		$optionValue =~ s/^\s+//;
		$optionValue =~ s/\s+$//;

		if ($optionId && $optionValue) {
			my %option = (
				'id' => $optionId,
				'value' => $optionValue
			);
			return \%option;
		} else {
			$log->warn("Error in option: $line");
			$log->warn("Option values: ID = $optionId, Value = $optionValue");
			return undef;
		}
	}
	return undef;
}

sub parseMenuListType {
	my $line = shift;
	if ($line =~ /^\s*--\s*PlaylistMenuListType\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*PlaylistMenuListType\s*[:=]\s*([^:]+)\s*(.*)$/;
		my $MenuListType = $1;
		$MenuListType =~ s/\s+$//;
		$MenuListType =~ s/^\s+//;

		if ($MenuListType) {
			return $MenuListType;
		} else {
			$log->debug("No value or error in MenuListType: $line");
			$log->debug("Option values: MenuListType = $MenuListType");
			return undef;
		}
	}
	return undef;
}

sub parseCategory {
	my $line = shift;
	if ($line =~ /^\s*--\s*PlaylistCategory\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*PlaylistCategory\s*[:=]\s*([^:]+)\s*(.*)$/;
		my $category = $1;
		$category =~ s/\s+$//;
		$category =~ s/^\s+//;

		if ($category) {
			return $category;
		} else {
			$log->debug("No value or error in category: $line");
			$log->debug("Option values: category = $category");
			return undef;
		}
	}
	return undef;
}

sub parseTrackOrder {
	my $line = shift;
	if ($line =~ /^\s*--\s*PlaylistTrackOrder\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*PlaylistTrackOrder\s*[:=]\s*([^:]+)\s*(.*)$/;
		my $trackOrder = $1;
		$trackOrder =~ s/\s+$//;
		$trackOrder =~ s/^\s+//;

		if ($trackOrder) {
			return $trackOrder;
		} else {
			$log->debug("No value or error in trackOrder: $line");
			$log->debug("Option values: trackOrder = $trackOrder");
			return undef;
		}
	}
	return undef;
}

sub parseLimitOption {
	my $line = shift;
	if ($line =~ /^\s*--\s*PlaylistLimitOption\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*PlaylistLimitOption\s*[:=]\s*([^:]+)\s*(.*)$/;
		my $limitOption = $1;
		$limitOption =~ s/\s+$//;
		$limitOption =~ s/^\s+//;

		if ($limitOption) {
			return $limitOption;
		} else {
			$log->debug("No value or error in limitOption: $line");
			$log->debug("Option values: limitOption = $limitOption");
			return undef;
		}
	}
	return undef;
}

sub parseScope {
	my $line = shift;
	if ($line =~ /^\s*--\s*Scope\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*Scope\s*[:=]\s*([^:]+)\s*(.*)$/;
		my $scope = $1;
		$scope =~ s/\s+$//;
		$scope =~ s/^\s+//;

		if ($scope) {
			return $scope;
		} else {
			$log->debug("No value or error in scope: $line");
			return undef;
		}
	}
	return undef;
}

sub parseVirtualLibraryName {
	my $line = shift;

	if ($line =~ /^\s*--\s*PlaylistVirtualLibraryName\s*\d\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*PlaylistVirtualLibraryName\s*(\d)\s*[:=]\s*([^:]+)\s*(.*)$/;
		my $VLnumber = $1;
		my $VLname = $2;

		$VLnumber =~ s/^\s+//;
		$VLnumber =~ s/\s+$//;

		$VLname =~ s/^\s+//;
		$VLname =~ s/\s+$//;

		if ($VLnumber && $VLname) {
			my %VLnameItem = (
				'number' => $VLnumber,
				'name' => $VLname,
			);
			return \%VLnameItem;
		} else {
			$log->warn("Error in parameter: $line");
			$log->warn("Parameter values: number = $VLnumber, name = $VLname");
			return undef;
		}
	}
	return undef;
}

sub parseVirtualLibraryID {
	my $line = shift;

	if ($line =~ /^\s*--\s*PlaylistVirtualLibraryID\s*\d\s*[:=]\s*/) {
		$line =~ m/^\s*--\s*PlaylistVirtualLibraryID\s*(\d)\s*[:=]\s*([^:]+)\s*(.*)$/;
		my $VLnumber = $1;
		my $VLid = $2;

		$VLnumber =~ s/^\s+//;
		$VLnumber =~ s/\s+$//;

		$VLid =~ s/^\s+//;
		$VLid =~ s/\s+$//;

		if ($VLnumber && $VLid) {
			my %VLidItem = (
				'number' => $VLnumber,
				'id' => $VLid,
			);
			return \%VLidItem;
		} else {
			$log->warn("Error in parameter: $line");
			$log->warn("Parameter values: number = $VLnumber, id = $VLid");
			return undef;
		}
	}
	return undef;
}

*escape = \&URI::Escape::uri_escape_utf8;

1;
