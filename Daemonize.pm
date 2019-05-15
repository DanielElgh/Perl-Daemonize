#!/bin/false
# Daemonize module by Daniel Elgh, 2019-04-20
#
package Daemonize;
use POSIX qw(close setsid);
use Cwd qw(chdir);
use warnings;
use FindBin;
use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(daemonize);

sub setProcName {
    my $procName = $_[0];
    if (defined $procName) {
        $0 = $procName;
        return 0;
    }
    if (defined $main::PROGRAM_NAME) {
        $0 = $main::PROGRAM_NAME;
    }
    return 0;
}

sub getProcName {
    my $pid = $_[0] // $$;
    my $file = "/proc/$pid/comm";
    my $name;
    if (-e $file && open my $fh, '<', $file) {
        $name = <$fh>;
        close $fh;
    }
    if (!defined $name) {    
        if (!-e $file) {
            return '';
        }
        die("getProcName: comm-file exists but can not be read\n");
    }
    chomp($name);
    return $name;
}

sub closeFilehandles {
    opendir my $dh, "/proc/self/fd/" or die("closeFilehandles: Unable to open '/proc/self/fd/': $!\n");
    my @fhs = grep { m/\d/ && $_ > 2 } readdir($dh);
    closedir $dh;
    POSIX::close($_) foreach (@fhs);
}

sub redirectStdStreams {
    open STDIN, '<', '/dev/null' or die("redirectStdStreams: Unable to redirect STDIN to /dev/null\n");
    open STDOUT, '>', '/dev/null' or die("redirectStdStreams: Unable to redirect STDOUT to /dev/null\n");
    open STDERR, '>', '/dev/null' or die("redirectStdStreams: Unable to redirect STDERR to /dev/null\n");
}

sub getPidFile {
    my @locations = qw(/run/ /var/run/ /dev/smh/ /run/smh/ /tmp/ /var/tmp/);
    push @locations, "$FindBin::Bin/";
    foreach my $loc (@locations) {
        if (-d $loc && -w $loc) {
            return($loc . getProcName() . '.pid');
        }
    }
    die("getPidFile: Unable to find proper location for the PID-file\n");
}

sub isPidDaemon {
    my $pid = $_[0] // die("isPidDaemon: Missing argument\n");
    if (kill(0, $pid) && (getProcName($pid) eq getProcName($$))) {
        return 1;
    }
    return 0;
}

sub readPidFile {
    my $file = getPidFile();
    if (!-e $file) {
        return undef;
    }
    local $/;
    open my $fh, '<', $file or die("readPidFile: Unable to open '$file': $!\n");
    my $pid = <$fh>;
    close $fh;
    if ($pid =~ m/\D/) {
        die("readPidFile: PID-file is corrupt\n");
    }
    return $pid;
}

sub writePidFile {
    my $file = getPidFile();
    open my $fh, '>', $file or die("writePidFile: Unable to open '$file' for writing: $!\n");
    print $fh $$;
    close $fh;
    return 0;
}

sub waitfordaemon {
    my $initTimeout = $_[0] // 10;
    for (my $i = 0; $i < $initTimeout; $i++) {
        my $pidFromFile = readPidFile();
        if (defined $pidFromFile && isPidDaemon($pidFromFile)) {
            print "Daemon successfully spawned with pid: $pidFromFile\n";
            exit 0;
        }
        sleep 1;
    }
    die("waitfordaemon: Failed to properly spawn daemon...\n");
}

sub daemonize {
    my $procName = $_[0];
    my $initTimeout = $_[1];
    setProcName($procName);
    my $pidFromFile = readPidFile();
    if (defined $pidFromFile && isPidDaemon($pidFromFile)) {
        print "daemonize: One (1) instance is already running. PID: $pidFromFile\n";
        exit 3;
    }
    closeFilehandles();
    my $pid = fork();
    if (!defined $pid) {
        die("daemonize: Unable to fork off from original process\n");
    } elsif ($pid) {
        waitfordaemon($initTimeout);
    }
    setsid();
    
    $pid = fork();
    exit 0 if ($pid);
    die("daemonize: Unable to fork off from child") if (!defined $pid);

    umask(0);
    chdir('/') or warn("daemonize: Unable to change directory to root: $!\n");
    redirectStdStreams();
    writePidFile();
}
=head1 NAME

Daemonize - Module to help spawn SysV-like daemons

=head1 DESCRIPTION

This module helps creating SysV-like daemons of Perl processes. All you have to do is C<use Daemonize;> and call C<daemonize();>. Please note that this module intends to be educational. The code is not tested for production use.

=head1 AUTHOR

Daniel Elgh

=head1 LICENSE

MIT License

=cut

1;
