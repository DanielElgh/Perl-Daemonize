#!/usr/bin/perl
use Daemonize;
use warnings;
use FindBin;
use strict;

our $PROGRAM_NAME = 'demo_app';

my $reload = 0;
my $terminate = 0;

$SIG{HUP} = sub { $reload = 1 };
$SIG{TERM} = sub { $terminate = 1 };

exit main(@ARGV);

sub main {
    print "This will appear on your screen before we daemonize and is printed by thedemo application itself.\n";
    my $name = 'overridden_name';

    daemonize($name, 2);

    print "This is sent to /dev/null and will not appear on your screen.\n";

    my $logfile = "$FindBin::Bin/$name.log";
    open my $log, '>', $logfile or die("main: Unable to open logfile '$logfile' for writing: $!\n"); 
    select $log;
    $|++; 

    print $log "Daemon started with pid $$\n";
    
    while (!$terminate) {
        if ($reload) {
            # Reload configuration and reset $reload variable
            $reload = 0;
            print $log "Configuration reloaded\n";
        }
        print $log "Message from daemon\n";
        sleep 60;
    }

    print $log "Received terminate signal - Shutting down daemon gracefully\n";
    close $log;
    return 0;
}

__END__
 The daemonize() function can be called in several ways.

 - daemonize();          # Defaults to $PROGRAM_NAME and a 10 second init timeout.
                         # Falls back to the original process name if $PROGRAM_NAME isn't set.
 - daemonize($name);     # Overrides $PROGRAM_NAME and keeps the 10 second init timeout.
 - daemonize($name, 2);  # Overrides the program name and sets a 2 second init timeout.
 - daemonize(undef, 2);  # Uses $PROGRAM_NAME as program name but overrides the init timeout.
