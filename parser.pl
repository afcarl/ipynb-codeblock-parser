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

sub strip_output {
    # take in a line of output from iPython and strip anything we don't want
    $_ = $_[0];
    $_ = $1 while m/In.*\[\d*\]: (.*)/;
    $_ = $1 while m/Out.*\[\d*\]: (.*)/;
    $_ = $1 while m/\.{3}: (.*)/;
    s/\\"/'/g;
    return $_;
}

sub block_has_output {
    # does the current block of code have any output?
    # if it has >>> input prompts, then it has output
    # note that this then requires you to provide output for all `>>>`-prompted lines
    my $fh = $_[0];
    my $block_begin = tell $fh;
    my $has_output = 0;
    until (eof($fh) || ($_ = readline $fh) =~ m/```/) {
        if (m/>>>/) {
            $has_output = 1;
            last;
        }
    }
    seek $fh, $block_begin, 0;
    return $has_output;
}

sub run_codeblock {
    my($fh, $ipython_in, $ipython_out) = @_;

    unless (block_has_output($fh)) {
        # if there's no output, simply forward every non-comment in the cell to iPython
        until (eof($fh) || ($_ = readline $fh) =~ m/```/) {
            $_ = $1 . "\n" if m/"(.*)\\n/;
            s/\\"/"/g;
            print $ipython_in $_ unless m/^#/;
        }
        return;
    }

    # if you get here, there's output in the cell
    my $in_multiline = 0; # flag for multiline input, which needs an extra newline to run
    my $executing;        # current line of code that is executing
    until (eof($fh) || ($_ = readline $fh) =~ m/```/) {
        my $line = $1 . "\n" if m/"(.*)\\n/;
        if ($line =~ m/^>>>/ || $line =~ m/^\.{3}/) {
            $in_multiline = 1 if $line =~ m/^\.{3}/;
            $line =~ s/\\"/"/g;
            print $ipython_in $line unless $line =~ m/^#/;
            $executing = $line;
        } else {
            print $ipython_in "\n" if $in_multiline;
            $in_multiline = 0;
            next if $line eq "\\n\n" || $line eq "\n" || $line =~ m/^#/;
            my $output = <$ipython_out>;
            $output = strip_output($output);

            while ($output eq "\n" || $output eq '') {
                $output = <$ipython_out>;
                $output = strip_output($output);
            }
            chomp $output;
            chomp $line;

            if ($output ne $line) {
                print "Error!\n\n    '$line'\n\ndoes not match\n\n    '$output'\n\n" .
                    "in\n\n    $executing\n\n";
            }
        }
    }
}

my($ipython_in, $ipython_out);
my $pid = open2($ipython_out, $ipython_in, 'ipython');

print "Opened an iPython process\n";
foreach (0..3) {
    $_ = <$ipython_out>; # gobble the header
}

# open a handle to the ipynb file
open my $fh, '<', $ARGV[0] or die $!;

until (eof($fh)) {
    $_ = readline $fh;
    run_codeblock($fh, $ipython_in, $ipython_out) if m/```\s*python/;
}

print "Finished!\n";

close($ipython_in);
close($ipython_out);
waitpid $pid, 0;

close($fh);

# TODO figure out why it throws an exception-ignored error and BrokenPipeError at the end
