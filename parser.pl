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
    my $output = $_[0];
    $output = $1 if $output =~ m/In.*\[\d*\]: (.*)/;
    $output = $1 if $output =~ m/Out.*\[\d*\]: (.*)/;
    $output =~ s/\\"/'/g;
    return $output;
}


# open a handle to the ipynb file
open my $fh, '<', $ARGV[0] or die $!;

my $redirecting = 0; # are we redirecting output to the iPython process?
my $code_line;
my $executing;       # which line of code is running?
foreach (<$fh>) {
    if (m/```python/) {
        $redirecting = 1;
        next;
    } elsif (m/```/) {
        $redirecting = 0;
    }

    if ($redirecting) {
        $code_line = $1 . "\n" if $_ =~ m/"(.*)\\n/; # read the line of code
        # $code_line =~ tr/\\//d;                      # remove escape for newlines
        if ($code_line =~ m/^>>>/ || $code_line =~ m/^\.\.\./) {
            # if code_line is actually a line of code
            # send it to iPython unless it's a comment
            $code_line =~ s/\\"/"/g;
            # print "sending $code_line";
            print $ipython_in $code_line unless $code_line =~ m/^#/;
            $executing = $code_line;
        } else {
            # print "saw $code_line";
            next if $code_line eq "\\n\n" or $code_line eq "\n" or $code_line =~ m/^#/;
            # if code_line isn't a line of code, then it's the output we should expect
            $output = <$ipython_out>;
            $output = strip_output($output);
            
            while ($output eq "\n" or $output eq '') {
                $output = <$ipython_out>;
                $output = strip_output($output);
            }
            # print "\n\noutput: $output";

            chomp $output;
            chomp $code_line;

            if ($output ne $code_line) {
                print "Error!\n\n    '$code_line'\n\ndoes not match\n\n    '$output'\n\n" .
                    "in\n\n    $executing\n\n";
            }
        }
    }
}

print "Finished!\n";

close($ipython_in);
close($ipython_out);
waitpid $pid, 0;

# TODO figure out why it throws an exception-ignored error and BrokenPipeError at the end
