#!/usr/bin/perl
#
# Author: David Mascharka
#
# Parses the code blocks in an ipython notebook file and ensures any reported output matches
# the actual iPython output. For example:
#    ```python
#    >>> a = 7
#    >>> a
#    7
#    ```
# will pass, but:
#    ```python
#    >>> a = 7
#    >>> a
#    2
# will rightfully print the following:
#    Error!
#        '7'
#    does not match
#        '2'
#    in
#        >>> a
#
# Usage: perl parser.pl /path/to/notebook.ipynb

use strict;
use warnings;
use IPC::Open2;

my $ipython_out;
my $ipython_in;
my $pid = open2($ipython_out, $ipython_in, 'ipython');
print "Opened an iPython process\n";
my $output;
foreach (0..3) {
    $output = <$ipython_out>; # gobble the header
}

sub strip_output {
    # take in a line of output from iPython and strip anything we don't want
    $_ = $_[0];
    $_ = $1 if m/In.*\[\d*\]: (.*)/;
    $_ = $1 if m/Out.*\[\d*\]: (.*)/;
    $_ = $1 while m/\.\.\.: (.*)/;
    $_ =~ s/\\"/'/g;
    return $_;
}

sub run_codeblock {
    my $fh = $_[0];
    my $block_begin = tell $fh;
    my $block_has_output = 0;
    until (eof($fh) || ($_ = readline $fh) =~ m/```/) {
        if (m/>>>/) {
            $block_has_output = 1;
            last;
        }
    }
    seek $fh, $block_begin, 0;

    my $in_multiline = 0;
    unless ($block_has_output) {
        until (eof($fh) || ($_ = readline $fh) =~ m/```/) {
            my $code_line = $1 . "\n" if m/"(.*)\\n/;
            $code_line =~ s/\\"/"/g;
            print $ipython_in $code_line unless $code_line =~ m/^#/;
        }
        return;
    }

    my $output;
    my $executing;
    until (eof($fh) || ($_ = readline $fh) =~ m/```/) {
        my $code_line = $1 . "\n" if m/"(.*)\\n/;
        if ($code_line =~ m/^>>>/ || $code_line =~ m/^\.\.\./) {
            $in_multiline = 1 if $code_line =~ m/^\.\.\./;
            $code_line =~ s/\\"/"/g;
            print $ipython_in $code_line unless $code_line =~ m/^#/;
            $executing = $code_line;
        } else {
            print $ipython_in "\n" if $in_multiline;
            $in_multiline = 0;
            next if $code_line eq "\\n\n" || $code_line eq "\n" || $code_line =~ m/^#/;
            $output = <$ipython_out>;
            $output = strip_output($output);

            while ($output eq "\n" || $output eq '') {
                $output = <$ipython_out>;
                $output = strip_output($output);
            }
            chomp $output;
            chomp $code_line;

            if ($output ne $code_line) {
                print "Error!\n\n    '$code_line'\n\ndoes not match\n\n    '$output'\n\n" .
                    "in\n\n    $executing\n\n";
            }
        }
    }
}

# open a handle to the ipynb file
open my $fh, '<', $ARGV[0] or die $!;

until (eof($fh)) {
    $_ = readline $fh;
    run_codeblock($fh) if m/```python/;
}

print "Finished!\n";

close($ipython_in);
close($ipython_out);
waitpid $pid, 0;

close($fh);

# TODO figure out why it throws an exception-ignored error and BrokenPipeError at the end
