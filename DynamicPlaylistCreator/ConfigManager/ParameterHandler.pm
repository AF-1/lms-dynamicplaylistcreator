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

package Plugins::DynamicPlaylistCreator::ConfigManager::ParameterHandler;

use strict;
use warnings;
use utf8;

use base qw(Slim::Utils::Accessor);
use Slim::Utils::Log;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);
use HTML::Entities;
use Time::Local;

__PACKAGE__->mk_accessor(rw => qw(parameterPrefix criticalErrorCallback));

my $newUnicodeHandling = 0;

my $log = logger('plugin.dynamicplaylistcreator');
my $cache = Slim::Utils::Cache->new();
my $prefs = preferences('plugin.dynamicplaylistcreator');

sub new {
	my ($class, $parameters) = @_;

	my $self = $class->SUPER::new();
	$self->parameterPrefix($parameters->{'parameterPrefix'});
	$self->criticalErrorCallback($parameters->{'criticalErrorCallback'});
	if (UNIVERSAL::can("Slim::Utils::Unicode", "hasEDD")) {
		$newUnicodeHandling = 1;
	}
	return $self;
}

sub quoteValue {
	my $value = shift;
	$value =~ s/\'/\'\'/g;
	return $value;
}

sub addValuesToTemplateParameter {
	my ($self, $p, $currentValues) = @_;

	if ($p->{'type'} =~ '^sql.*') {
		my $listValues = $self->getSQLTemplateData($p->{'data'});
		if ($p->{'type'} =~ /.*optional.*/) {
			my %empty = (
				'id' => '',
				'name' => '',
				'value' => ''
			);
			unshift @{$listValues}, \%empty;
		}
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} =~ 'function.*') {
		my $listValues = $self->getFunctionTemplateData($p->{'data'});
		if ($p->{'type'} =~ /.*optional.*list$/) {
			my %empty = (
				'id' => '',
				'name' => '',
				'value' => ''
			);
			unshift @{$listValues}, \%empty;
		}
		if ($p->{'value'}) {
			for my $v (@{$listValues}) {
				$v->{'selected'} = 1;
			}
		}
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} =~ 'virtuallibraries') {
		my $listValues = Plugins::DynamicPlaylistCreator::Plugin->getVirtualLibraries();
		my %empty = (
			'id' => '',
			'name' => '',
			'value' => ''
		);
		unshift @{$listValues}, \%empty;
		if ($p->{'value'}) {
			for my $v (@{$listValues}) {
				$v->{'selected'} = 1;
			}
		}
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} eq 'contributorlistcachedall') {
		my $listValues = $cache->get('dplc_contributorlist_all') || [];
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} eq 'contributorlistcachedalbumartists') {
		my $listValues = $cache->get('dplc_contributorlist_albumartists') || [];
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} eq 'contributorlistcachedcomposers') {
		my $listValues = $cache->get('dplc_contributorlist_composers') || [];
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} eq 'genrelistcached') {
		my $listValues = $cache->get('dplc_genrelist') || [];
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} eq 'contenttypelistcached') {
		my $listValues = $cache->get('dplc_contenttypes') || [];
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} eq 'releasetypelistcached') {
		my $listValues = $cache->get('dplc_releasetypes') || [];
		$p->{'values'} = $listValues;
	} elsif ($p->{'type'} =~ '.*list$' || $p->{'type'} =~ '.*checkboxes$') {
		my @listValues = ();
		my @values = split(/,/, $p->{'data'});
		for my $value (@values){
			my @idName = split(/=/, $value);
			my %listValue = (
				'id' => $idName[0],
				'name' => $idName[1]
			);
			if (scalar(@idName) > 2) {
				$listValue{'value'} = $idName[2];
			} else {
				$listValue{'value'} = $idName[0];
			}
			push @listValues, \%listValue;
		}
		if ($p->{'type'} =~ /.*optional.*list$/) {
			my %empty = (
				'id' => '',
				'name' => '',
				'value' => ''
			);
			unshift @listValues, \%empty;
		}
		$p->{'values'} = \@listValues;
	}

	if (defined($currentValues)) {
		$self->setValueOfTemplateParameter($p, $currentValues);
	}
}

sub setValueOfTemplateParameter {
	my ($self, $p, $currentValues) = @_;

	if (defined($currentValues)) {
		if ($p->{'type'} =~ '^sql.*' || $p->{'type'} =~ 'function.*' || $p->{'type'} =~ '.*list$' || $p->{'type'} =~ '.*checkboxes$' || $p->{'type'} =~ /listcached/) {
			my $listValues = $p->{'values'};

			for my $v (@{$listValues}) {
				if (($p->{'id'} eq 'includedratings' || $p->{'id'} eq 'exactrating') && defined($currentValues->{$v->{'value'}})) {
					$v->{'selected'} = 1;
				} elsif ($currentValues->{$v->{'value'}}) {
					$v->{'selected'} = 1;
				} else {
					$v->{'selected'} = undef;
				}
			}
		} else {
			for my $v (keys %{$currentValues}) {
				$p->{'value'} = $v;
			}
		}
	}
}

sub parameterIsSpecified {
	my ($self, $params, $parameter) = @_;

	if ($parameter->{'type'} =~ /.*multiplelist$/ || $parameter->{'type'} =~ /.*checkboxes$/ || $parameter->{'type'} =~ /listcached/) {
		my $selectedValues = undef;
		if ($parameter->{'type'} =~ /.*multiplelist$/ || $parameter->{'type'} eq 'contributorlistcachedall' || $parameter->{'type'} eq 'contributorlistcachedalbumartists' || $parameter->{'type'} eq 'contributorlistcachedcomposers') {
			$selectedValues = $self->getMultipleListQueryParameter($params, $self->parameterPrefix.'_'.$parameter->{'id'});
		} else {
			$selectedValues = $self->getCheckBoxesQueryParameter($params, $self->parameterPrefix.'_'.$parameter->{'id'});
		}
		if (scalar(keys %{$selectedValues}) > 0) {
			return 1;
		}
	} elsif ($parameter->{'type'} =~ /.*singlelist$/) {
		my $selectedValue = $params->{$self->parameterPrefix.'_'.$parameter->{'id'}};
		if (defined($selectedValue)) {
			return 1;
		}
	} else {
		if ($params->{$self->parameterPrefix.'_'.$parameter->{'id'}}) {
			return 1;
		}
	}
	return 0;
}

sub getValueOfTemplateParameter {
	my ($self, $params, $parameter) = @_;
	my $result = '';
	my $dbh = Slim::Schema->dbh;
	if ($parameter->{'type'} =~ /.*multiplelist$/ || $parameter->{'type'} =~ /.*checkboxes$/ || $parameter->{'type'} =~ /listcached/) {
		my $selectedValues = undef;
		if ($parameter->{'type'} =~ /.*multiplelist$/ || $parameter->{'type'} eq 'contributorlistcachedall' || $parameter->{'type'} eq 'contributorlistcachedalbumartists' || $parameter->{'type'} eq 'contributorlistcachedcomposers') {
			$selectedValues = $self->getMultipleListQueryParameter($params, $self->parameterPrefix.'_'.$parameter->{'id'});
		} else {
			$selectedValues = $self->getCheckBoxesQueryParameter($params, $self->parameterPrefix.'_'.$parameter->{'id'});
		}
		main::DEBUGLOG && $log->is_debug && $log->debug("Got ".scalar(keys %{$selectedValues})." values for ".$parameter->{'id'});
		my $values = $parameter->{'values'};
		for my $item (@{$values}) {
			if (defined($selectedValues->{$item->{'id'}})) {
				$result .= ',' if defined($result) && $result ne '';

				my $thisvalue = $item->{'value'};
				# if param = includeddecades, add years to decades
				if ($parameter->{'id'} eq "includeddecades") {
					my $decadeYears = $thisvalue;
					unless ($thisvalue == 0) {
						for (1..9) {
							$decadeYears .= ','.($thisvalue + $_);
						}
					}
					$thisvalue = $decadeYears;
				}

				if (!defined($parameter->{'rawvalue'}) || !$parameter->{'rawvalue'}) {
					$thisvalue = quoteValue($thisvalue);
				}
				if ($parameter->{'quotevalue'}) {
					$result .= "'".encode_entities($thisvalue, "&<>\'\"")."'";
				} else {
					$result .= encode_entities($thisvalue, "&<>\'\"");
				}
				main::DEBUGLOG && $log->is_debug && $log->debug("Got ".$parameter->{'id'}." = $thisvalue");
			}
		}
	} elsif ($parameter->{'type'} =~ /.*singlelist$/) {
		my $values = $parameter->{'values'};
		my $selectedValue = $params->{$self->parameterPrefix.'_'.$parameter->{'id'}};
		$selectedValue = Slim::Utils::Unicode::utf8decode_locale($selectedValue);
		for my $item (@{$values}) {
			if ($selectedValue && $selectedValue eq $item->{'id'}) {
				my $thisvalue = $item->{'value'};
				if (!defined($parameter->{'rawvalue'}) || !$parameter->{'rawvalue'}) {
					$thisvalue = quoteValue($thisvalue);
				}
				if ($parameter->{'quotevalue'}) {
					$result = "'".encode_entities($thisvalue, "&<>\'\"")."'";
				} else {
					$result = encode_entities($thisvalue, "&<>\'\"");
				}
				main::DEBUGLOG && $log->is_debug && $log->debug("Got ".$parameter->{'id'}." = $thisvalue");
				last;
			}
		}
	} elsif ($parameter->{'type'} eq 'multivaltext') {
		if ($params->{$self->parameterPrefix.'_'.$parameter->{'id'}}) {
			my $thisvalue = $params->{$self->parameterPrefix.'_'.$parameter->{'id'}};
			$thisvalue = Slim::Utils::Unicode::utf8decode_locale($thisvalue);
			main::INFOLOG && $log->is_info && $log->info('thisvalue = '.Data::Dump::dump($thisvalue));

			my @paramvalues = split(/;/, $thisvalue);
			my $quotedTextVal;

			foreach (@paramvalues) {
				if ($parameter->{'quotevalue'}) {
					$quotedTextVal .= ($quotedTextVal ? ',' : '')."'".encode_entities(trim_leadtail($_), "&<>\'\"")."'";
				} else {
					$quotedTextVal .= ($quotedTextVal ? ',' : '').encode_entities(trim_leadtail($_), "&<>\'\"");
				}
			}
			main::INFOLOG && $log->is_info && $log->info("Got ".$parameter->{'id'}." = $quotedTextVal");
			$result = $quotedTextVal;
		}
	} else {
		if ($params->{$self->parameterPrefix.'_'.$parameter->{'id'}}) {
			my $thisvalue = $params->{$self->parameterPrefix.'_'.$parameter->{'id'}};
			$thisvalue = Slim::Utils::Unicode::utf8decode_locale($thisvalue);
			if (!defined($parameter->{'rawvalue'}) || !$parameter->{'rawvalue'}) {
				$thisvalue = quoteValue($thisvalue);
			}

			$thisvalue = handleSearchText($thisvalue, $parameter->{'id'} =~ /commentssearchstring/ ? 1 : 0) if $parameter->{'type'} eq 'searchtext';
			$thisvalue = handleSearchURL($thisvalue) if $parameter->{'type'} eq 'searchurl';

			# filestamp: date -> epoch time
			if ($parameter->{'type'} eq 'text' && $parameter->{'id'} =~ /filetimestamp$/) {
				my ($days, $months, $years) = split(m@/@, $thisvalue);
				$thisvalue = timelocal(0,0,0,$days,$months-1,$years);
			}

			if ($parameter->{'quotevalue'}) {
				return "'".encode_entities($thisvalue, "&<>\'\"")."'";
			} else {
				return encode_entities($thisvalue, "&<>\'\"");
			}
			main::DEBUGLOG && $log->is_debug && $log->debug("Got ".$parameter->{'id'}." = $thisvalue");
		} else {
			if ($parameter->{'type'} =~ /.*checkbox$/) {
				$result = '0';
			}
			main::DEBUGLOG && $log->is_debug && $log->debug("Got ".$parameter->{'id'}." = $result");
		}
	}
	return $result;
}

sub getXMLValueOfTemplateParameter {
	my ($self, $params, $parameter) = @_;
	my $dbh = Slim::Schema->dbh;
	my $result = '';
	if ($parameter->{'type'} =~ /.*multiplelist$/ || $parameter->{'type'} =~ /.*checkboxes$/ || $parameter->{'type'} =~ /listcached/) {
		my $selectedValues = undef;
		if ($parameter->{'type'} =~ /.*multiplelist$/ || $parameter->{'type'} eq 'contributorlistcachedall' || $parameter->{'type'} eq 'contributorlistcachedalbumartists' || $parameter->{'type'} eq 'contributorlistcachedcomposers') {
			$selectedValues = $self->getMultipleListQueryParameter($params, $self->parameterPrefix.'_'.$parameter->{'id'});
		} else {
			$selectedValues = $self->getCheckBoxesQueryParameter($params, $self->parameterPrefix.'_'.$parameter->{'id'});
		}
		main::DEBUGLOG && $log->is_debug && $log->debug("Got ".scalar(keys %{$selectedValues})." values for ".$parameter->{'id'}." to convert to XML");

		my $values = $parameter->{'values'};

		for my $item (@{$values}) {
				if (defined($selectedValues->{$item->{'id'}})) {
				$result = $result.'<value>';
				$result = $result.encode_entities($item->{'value'}, "&<>\'\"");
				$result = $result.'</value>';
				main::DEBUGLOG && $log->is_debug && $log->debug("Got ".$parameter->{'id'}." = ".$item->{'value'});
			}
		}
	} elsif ($parameter->{'type'} =~ /.*singlelist$/) {
		my $values = $parameter->{'values'};
		my $selectedValue = $params->{$self->parameterPrefix.'_'.$parameter->{'id'}};
		$selectedValue = Slim::Utils::Unicode::utf8decode_locale($selectedValue);
		for my $item (@{$values}) {
			if ($selectedValue && $selectedValue eq $item->{'id'}) {
				$result = $result.'<value>';
				$result = $result.encode_entities($item->{'value'}, "&<>\'\"");
				$result = $result.'</value>';
				main::DEBUGLOG && $log->is_debug && $log->debug("Got ".$parameter->{'id'}." = ".$item->{'value'});
				last;
			}
		}
	} else {
		if (defined($params->{$self->parameterPrefix.'_'.$parameter->{'id'}}) && $params->{$self->parameterPrefix.'_'.$parameter->{'id'}} ne '') {
			my $value = Slim::Utils::Unicode::utf8decode_locale($params->{$self->parameterPrefix.'_'.$parameter->{'id'}});
			$value = handleSearchText($value, $parameter->{'id'} =~ /commentssearchstring/ ? 1 : 0) if $parameter->{'type'} eq 'searchtext';
			$value = handleSearchURL($value) if $parameter->{'type'} eq 'searchurl';
			$result = '<value>'.encode_entities($value, "%_&<>\'\"").'</value>';
			main::DEBUGLOG && $log->is_debug && $log->debug("Got ".$parameter->{'id'}." = ".$value);
		} else {
			if ($parameter->{'type'} =~ /.*checkbox$/) {
				$result = '<value>0</value>';
			}
			main::DEBUGLOG && $log->is_debug && $log->debug("Got ".$parameter->{'id'}." = ".$result);
		}
	}
	return $result;
}

sub getMultipleListQueryParameter {
	my ($self, $params, $parameter) = @_;

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
	my ($self, $params, $parameter) = @_;

	my %result = ();
	foreach my $key (keys %{$params}) {
		my $pattern = '^'.$parameter.'_(.*)';
		if ($key =~ /$pattern/) {
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
	my ($self, $sqlstatements) = @_;
	my @result =();
	my $dbh = Slim::Schema->dbh;

	for my $sql (split(/[;]/, $sqlstatements)) {
		main::DEBUGLOG && $log->is_debug && $log->debug("sql = ".Data::Dump::dump($sql));
		eval {
			$sql =~ s/^\s+//g;
			$sql =~ s/\s+$//g;
			next if !$sql;
			my $sth = $dbh->prepare($sql);
			main::DEBUGLOG && $log->is_debug && $log->debug("Executing: $sql");
			$sth->execute() or do {
				$log->error("Error executing: $sql");
				$sql = undef;
			};

			if ($sql =~ /^SELECT+/oi) {
				main::DEBUGLOG && $log->is_debug && $log->debug("Executing and collecting: $sql");
				my $id;
				my $name;
				my $value;
				$sth->bind_col(1, \$id);
				$sth->bind_col(2, \$name);
				$sth->bind_col(3, \$value);
				while($sth->fetch()) {
					if ($newUnicodeHandling) {
						my %item = (
							'id' => Slim::Utils::Unicode::utf8decode($id, 'utf8'),
							'name' => Slim::Utils::Unicode::utf8decode($name, 'utf8'),
							'value' => Slim::Utils::Unicode::utf8decode($value, 'utf8')
						);
						push @result, \%item;
					} else {
						my %item = (
							'id' => Slim::Utils::Unicode::utf8on(Slim::Utils::Unicode::utf8decode($id, 'utf8')),
							'name' => Slim::Utils::Unicode::utf8on(Slim::Utils::Unicode::utf8decode($name, 'utf8')),
							'value' => Slim::Utils::Unicode::utf8on(Slim::Utils::Unicode::utf8decode($value, 'utf8'))
						);
						push @result, \%item;
					}
				}
			}
			$sth->finish();
		};
		if ($@) {
			warn "Database error: $DBI::errstr";
			$self->criticalErrorCallback->("Running: $sql got error: <br>".$DBI::errstr);
		}
	}
	return \@result;
}

sub getFunctionTemplateData {
	my ($self, $data) = @_;
	my @params = split(/\,/, $data);
	my @result =();
	if (scalar(@params) == 2) {
		my $object = $params[0];
		my $function = $params[1];
		if (UNIVERSAL::can($object, $function)) {
			main::DEBUGLOG && $log->is_debug && $log->debug("Getting values for: $function");
			no strict 'refs';
			my $items = eval { &{$object.'::'.$function}() };
			if ($@) {
				warn "Function call error: $@";
			}
			use strict 'refs';
			if (defined($items)) {
				@result = @{$items};
			}
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

	if ($searchString =~ /%/ || $searchString =~ /_/) {
		$searchString =~ s/%/\\%/ if $searchString =~ /%/;
		$searchString =~ s/_/\\_/ if $searchString =~ /_/;
	}
	$searchString = Slim::Utils::Unicode::utf8decode_locale($searchString);

	if (!$prefs->get('exacttitlesearch') && !$skipExact) {
		main::DEBUGLOG && $log->is_debug && $log->debug('Not using exact title search');
		$searchString = Slim::Utils::Text::ignoreCaseArticles($searchString, 1);
	}
	return $searchString;
}

sub trim_leadtail {
	my ($str) = @_;
	$str =~ s{^\s+}{};
	$str =~ s{\s+$}{};
	return $str;
}

*escape = \&URI::Escape::uri_escape_utf8;
*unescape = \&URI::Escape::uri_unescape;

1;
