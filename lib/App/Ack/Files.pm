package App::Ack::Files;

use App::Ack ();
use App::Ack::File ();

use File::Next 1.16 ();

use warnings;
use strict;
use 5.010;

=head1 NAME

App::Ack::Files

=head1 SYNOPSIS

A factory object for creating a stream of L<App::Ack::File> objects.

=head1 METHODS

=head2 from_argv( \%opt, \@starting_points )

Return an iterator that does the file finding for us.

=cut

sub from_argv {
    my $class = shift;
    my $opt   = shift;
    my $start = shift;

    my $self = bless {}, $class;

    my $descend_filter = $opt->{descend_filter};

    if ( $opt->{n} ) {
        $descend_filter = sub {
            return 0;
        };
    }

    $self->{iter} =
        File::Next::files( {
            file_filter     => $opt->{file_filter},
            descend_filter  => $descend_filter,
            error_handler   => _generate_error_handler(),
            warning_handler => sub {},
            sort_files      => $opt->{sort_files},
            follow_symlinks => $opt->{follow},
        }, @{$start} );

    return $self;
}

=head2 from_file( \%opt, $filename )

Return an iterator that reads the list of files to search from a
given file.  If I<$filename> is '-', then it reads from STDIN.

=cut
# TODO: add a --read0 flag that only works for --files-from and -x
sub from_file {
    my $class = shift;
    my $opt   = shift;
    my $file  = shift;

    my $error_handler = _generate_error_handler();
    my $iter =
        File::Next::from_file( {
            error_handler   => $error_handler,
            warning_handler => $error_handler,
            sort_files      => $opt->{sort_files},
        }, $file ) or return undef;

    return bless {
        iter => $iter,
    }, $class;
}


=head2 from_stdin()

This is for reading input lines from STDIN, not the list of files
from STDIN.

=cut


sub from_stdin {
    my $class = shift;

    my $self  = bless {}, $class;

    $self->{iter} = sub {
        state $has_been_called = 0;

        if ( !$has_been_called ) {
            $has_been_called = 1;
            return '-';
        }
        return;
    };

    return $self;
}


sub next {
    my $self = shift;

    my $file = $self->{iter}->();

    return unless defined($file);

    return App::Ack::File->new( $file );
}


sub _generate_error_handler {
    if ( $App::Ack::report_bad_filenames ) {
        return sub {
            my $msg = shift;
            App::Ack::warn( $msg );
        };
    }
    else {
        return sub {};
    }
}

1;
