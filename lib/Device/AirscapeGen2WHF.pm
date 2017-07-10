# ******************************************************************************
# Copyright (C) 2015 Michael R. Ferrara, All rights reserved.    -*- mode:perl -*-
#
# Santa Rosa, CA
#
# Query/Control an Airscape Whole House Fan fitted with Gen2 controls
#

package Device::AirscapeGen2WHF;

use 5.006;
use strict;
use warnings;

use Moose;
use Moose::Exporter;
use MooseX::ClassAttribute;
use namespace::autoclean;
use Log::Log4perl qw(:easy);     #So we can turn on logging really early if needed.
use LWP::Simple;
use Math::Utils qw(:utility);    #floor, ceil, etc...
use Time::HiRes qw( usleep );

=head1 NAME

Device::AirscapeGen2WHF - Query/Control an Airscape Whole House Fan fitted with Gen2 controls

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

has 'port' => ( is => 'rw', isa => 'Int', default => 80 );
has 'host' => ( is => 'rw', isa => 'Str' );

=head1 SYNOPSIS

This module allows one to query and control an Airscape whole house fan if it's fitted with Gen 2 controls.



    use Devcce::AirscapeGen2WHF;
    use Data::Dumper qw(Dumper);
    my $obj = Device::AirscapeGen2WHF->new(host=>'whf.example.com'); #Or IP address, of course
    
    my $status = $obj->query();
    print Dumper($status);

    $status=$obj->speedup(); #Turns fan on or bumps up speed one notch
    $status=$obj->setSpeed(5);
    print Dumper($status);
    ...


=head1 SUBROUTINES/METHODS

=head2 query

 $hashref = $obj->query();

Query status of the fan. Return a hashref of the current state. The following hash keys will be defined:

=over 

=item doorinprocess

=item timeremaining

=item macaddr

=item ipaddr

=item model

=item softver

=item interlock1

=item interlock2

=item cfm

=item power

=item inside

=item DNS1

=item attic

=item oa_temp

=item server_response

=item DIPS

=item switch2

=item setpoint

=item fanspd

=item coolingpower

=item cfmperwatt

=item EER

=back

=cut

sub query {
  my $self = shift;

  my $url = sprintf( "http://%s:%d/fanspd.cgi", $self->host, $self->port );
  my @content = split( "\n", get($url) );

  return ( $self->_decode( \@content ) );
}

sub _getVar {
  my $self    = shift;
  my $content = shift;
  my $var     = shift;

  foreach my $line (@$content) {
    chomp($line);
    chomp($line);
    if ( $line =~ /$var/ ) {
      $line =~ m|>(.*)</|;
      return ($1);
    }
  }
}

sub _decode {
  my $self    = shift;
  my $content = shift;

  my %state     = ();
  my @stateVars = qw( doorinprocess timeremaining macaddr ipaddr model softver interlock1 interlock2 cfm power
    inside DNS1 attic oa_temp server_response DIPS switch2 setpoint fanspd );
  foreach my $var (@stateVars) {
    $state{$var} = $self->_getVar( $content, $var );
  }
  $state{querytime} = time;

  if ( $state{fanspd} > 0 && $state{power} > 0 ) {
    $state{coolingpower} = floor( $state{inside} - $state{oa_temp} ) * 1.08 * $state{cfm};    #BTUh
    $state{cfmperwatt}   = $state{cfm} / $state{power};
    $state{EER}          = floor( $state{coolingpower} / $state{power} );
  } else {
    $state{coolingpower} = 0;
    $state{cfmperwatt}   = 0;
    $state{EER}          = 0;
  }

  return ( \%state );
}

=head2 speedup

$obj->speedup();

Increase fan setpoint speed by one. 

=cut

sub speedup {
  my $self = shift;

  my $url = sprintf( "http://%s:%d/fanspd.cgi?dir=1", $self->host, $self->port );
  my @content = split( "\n", get($url) );

  return ( $self->_decode( \@content ) );
}

=head2 speeddown

$obj->speeddown();

Decrease fan setpoint speed by one. 

=cut

sub speeddown {
  my $self = shift;

  my $url = sprintf( "http://%s:%d/fanspd.cgi?dir=3", $self->host, $self->port );
  my @content = split( "\n", get($url) );

  return ( $self->_decode( \@content ) );
}

=head2 timerAdd1hr

$obj->timerAdd1hr();

Add one hour to the countdown timer. Max is 12hrs.

=cut

sub timerAdd1hr {
  my $self = shift;

  my $url = sprintf( "http://%s:%d/fanspd.cgi?dir=2", $self->host, $self->port );
  my @content = split( "\n", get($url) );

  return ( $self->_decode( \@content ) );
}

=head2 stop

$obj->stop();

Shut down the fan.

=cut

sub stop {
  my $self = shift;

  my $url = sprintf( "http://%s:%d/fanspd.cgi?dir=4", $self->host, $self->port );
  my @content = split( "\n", get($url) );

  return ( $self->_decode( \@content ) );
}

=head2 waitDoors

$obj->waitDoors();

Routine returns when the doors are no longer operating.

=cut

sub waitDoors {
  my $self = shift;

  my $stat = $self->query();
  while ( $stat->{doorinprocess} ) {
    usleep(500000);
    $stat = $self->query();
  }
}

=head2 setSpeed

$obj->setSpeed($speed);

Set the fan setpoint speed to $speed, which may be an integer between 0 and 10. 0 means off.

=cut

sub setSpeed {
  my $self  = shift;
  my $speed = floor(shift);

  return if ( $speed < 0 || $speed > 10 );
  if ( $speed == 0 ) {
    $self->stop();
    return;
  }
  my $status = $self->query();
  while ( ( $status->{setpoint} + 0 ) != $speed ) {
    if ( ( $status->{setpoint} + 0 ) < $speed ) {
      $self->speedup();
    }
    if ( ( $status->{setpoint} + 0 ) > $speed ) {
      $self->speeddown();
    }
    sleep(1);
    $status = $self->query();
  }

  return;
}

=head1 AUTHOR

Mike Ferrara, C<< <mikef at mrf.sonoma.ca.us> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-device-airscapegen2whf at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Device-AirscapeGen2WHF>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Device::AirscapeGen2WHF


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Device-AirscapeGen2WHF>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Device-AirscapeGen2WHF>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Device-AirscapeGen2WHF>

=item * Search CPAN

L<http://search.cpan.org/dist/Device-AirscapeGen2WHF/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2017 Mike Ferrara.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


=cut

__PACKAGE__->meta->make_immutable;

1;    # End of Device::AirscapeGen2WHF
