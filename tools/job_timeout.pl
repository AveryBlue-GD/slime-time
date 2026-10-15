#!/usr/bin/perl
# Usage: job_timeout.pl SECONDS PIDFILE COMMAND [ARGS...]
# Runs COMMAND in its own process group (so its children - OS.execute, a nav_fuzz web child - are in it too), writes its pid
# to PIDFILE, and kills that whole group when SECONDS pass (exit 124) or when this wrapper gets INT/TERM (exit 130/143).
# Only ever signals the group it created itself. Portable: macOS has no `timeout`, but it has perl. Used by tools/test_all.sh.
use strict;
use warnings;
my ($limit, $pidfile, @cmd) = @ARGV;
my $pid = fork();
die "fork: $!" unless defined $pid;
if ($pid == 0) {
    setpgrp(0, 0);
    exec @cmd or exit 127;
}
if (open(my $fh, '>', $pidfile)) { print $fh $pid; close $fh; }
sub reap { kill 'KILL', -$pid; kill 'KILL', $pid; waitpid($pid, 0); }
$SIG{ALRM} = sub { reap(); exit 124; };
$SIG{INT}  = sub { reap(); exit 130; };
$SIG{TERM} = sub { reap(); exit 143; };
alarm $limit;
waitpid($pid, 0);
alarm 0;
kill 'KILL', -$pid;  # stragglers of a job that finished
my $st = $?;
exit(($st & 127) ? 128 + ($st & 127) : ($st >> 8));
