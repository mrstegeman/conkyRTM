#!/usr/bin/perl
# -----------------------------------------------------------------------------
# Copyright (C) 2010 Mike Stegeman <mrstegeman@gmail.com>
# Last Revision: Oct 29, 2010
# -----------------------------------------------------------------------------
#
# Description:
#   This script fetches an RTM (http://www.rememberthemilk.com) user's tasks
#   and ouputs them for use with Conky (http://conky.sourceforge.net)
#
# Required Modules:
#   HTML::Entities -
#       http://search.cpan.org/~gaas/HTML-Parser-3.68/lib/HTML/Entities.pm
#   Date::Calc -
#       http://search.cpan.org/~stbey/Date-Calc-6.3/lib/Date/Calc.pod
#   DateTime -
#       http://search.cpan.org/~drolsky/DateTime/lib/DateTime.pm
#   DateTime::Format::Strptime -
#       http://search.cpan.org/~drolsky/DateTime-Format-Strptime/lib/DateTime/Format/Strptime.pm
#
#   Note: These modules may be available through user repositories
# -----------------------------------------------------------------------------

use strict;
use warnings;
use Pod::Usage;
use HTML::Entities;
use Getopt::Long qw(:config pass_through);
use Date::Calc qw(Today_and_Now Date_to_Days Add_Delta_Days Day_of_Week
                  Month_to_Text English_Ordinal Day_of_Week_Abbreviation);
use DateTime::Format::Strptime;

# Initializations
my ($user, $pass, $days, $time, $tcolor, $hcolor, $tindent, $hindent, $eindent,
    $alignr, $alignc, $font, $not_due, $inc_tags, $exc_tags, $white_lists,
    $black_lists, $location, $estimate, $priority, $priorities, $help, $man,
    $overdue, $noheaders, $miltime, @tasks);

$tcolor = $hcolor = '';
$hindent = $tindent = $eindent = 0;

# Get integer equivalent of today's date
my ($ano, $mes, $dia, $hora, $minuto) = Today_and_Now();
my $today = Date_to_Days($ano, $mes, $dia);
my $now = $hora * 60 + $minuto;

# Get all options from command line
GetOptions(
    "u|user=s" => \$user,
    "p|pass=s" => \$pass,
    "d|days=s" => \$days,
    "t|time" => \$time,
    "tcolor=s" => \$tcolor,
    "hcolor=s" => \$hcolor,
    "tindent=i" => \$tindent,
    "hindent=i" => \$hindent,
    "eindent=i" => \$eindent,
    "r|alignr" => \$alignr,
    "c|alignc" => \$alignc,
    "f|font=s" => \$font,
    "n|not-due" => \$not_due,
    "include-tags=s" => \$inc_tags,
    "ignore-tags=s" => \$exc_tags,
    "white-lists=s" => \$white_lists,
    "black-lists=s" => \$black_lists,
    "l|location" => \$location,
    "e|estimate" => \$estimate,
    "y|priority" => \$priority,
    "priorities=s" => \$priorities,
    "h|help" => \$help,
    "m|man" => \$man,
    "o|overdue" => \$overdue,
    "no-headers" => \$noheaders,
    "24-hour" => \$miltime,
);

# Check for required inputs
pod2usage(-verbose => 2) and exit if $man;
pod2usage(-verbose => 1) and exit if ($help or not $user or not $pass or @ARGV);

# Fix color representation
if ($tcolor =~ /^color\d$/) {
    $tcolor = "\${$tcolor}";
}
elsif ($tcolor ne '') {
    $tcolor = "\${color $tcolor}";
}

if ($hcolor =~ /^color\d$/) {
    $hcolor = "\${$hcolor}";
}
elsif ($hcolor ne '') {
    $hcolor = "\${color $hcolor}";
}

# Get atom feed
my $wget_cmd = "wget -O - -q --no-cache --http-user='$user' " .
    "--http-password='$pass' http://www.rememberthemilk.com/atom/$user/";
my $xml = `$wget_cmd`;
print "${hcolor}Could not connect to network.\n" and exit unless $xml;

# Set indentations
$tindent = ($tindent > 0 ? ' ' x $tindent : '');
$hindent = ($hindent > 0 ? ' ' x $hindent : '');
$eindent = ($eindent > 0 ? ' ' x $eindent : '');

# Long date format from atom feed -- DON'T CHANGE!!
my $strp1 = new DateTime::Format::Strptime(pattern => '%a %d %b %y at %I:%M%p');
# Short date format from atom feed -- DON'T CHANGE!!
my $strp2 = new DateTime::Format::Strptime(pattern => '%a %d %b %y');
# Format used with Date::Calc -- DON'T CHANGE!!
my $strp3 = new DateTime::Format::Strptime(pattern => '%Y %m %d');
# Format for due date/time printing in conky
my $pat = (defined $miltime ? '%R' : '%I:%M%P');
my $strp4 = new DateTime::Format::Strptime(pattern => $pat);

# Set up white tags
my @wtags = split(/,/, $inc_tags) if defined $inc_tags;

# Set up black tags
my @btags = split(/,/, $exc_tags) if defined $exc_tags;

# Set up white lists
my @wlists = split(/,/, $white_lists) if defined $white_lists;

# Set up black lists
my @blists = split(/,/, $black_lists) if defined $black_lists;

# Set up priority list
my @pri_list = split(/,/, $priorities) if defined $priorities;

# Parse atom feed
&parse($xml);

# Check for font settings
print "\${font $font}" if defined $font;

# Get tasks
&get_tasks('od') if $overdue;
foreach (0 .. ($days - 1)) {
    &get_tasks($_);
}
&get_tasks('inf') if $not_due;


# Parses atom feed
sub parse {
    my $rtm_re = qr/<entry>.+?<title type=\"html\">\s*(.+?)\s*<\/title>.+?\"/ .
                 qr/rtm_due_value\">\s*(.+?)\s*<\/span>.+?\"/ .
                 qr/rtm_priority_value\">\s*(.+?)\s*<\/span>.+?\"/ .
                 qr/rtm_time_estimate_value\">\s*(.+?)\s*<\/span>.+?\"/ .
                 qr/rtm_tags_value\">\s*(.+?)\s*<\/span>.+?\"/ .
                 qr/rtm_location_value\">\s*(.+?)\s*<\/span>.+?\"/ .
                 qr/rtm_postponed_value\">\s*(.+?)\s*<\/span>.+?\"/ .
                 qr/rtm_list_value\">\s*(.+?)\s*<\/span>.+?<\/entry>/;

    # loop over entry tags
    while ($xml =~ /$rtm_re/g) {
        my $title = ($1 ? decode_entities($1) : '');
        my $due = ($2 ? $2 : '');
        my $pri = ($3 ? $3 : '');
        my $est = ($4 ? $4 : '');
        my $tags = ($5 ?$5 : '');
        my $loc = ($6 ? $6 : '');
        my $post = ($7 ? $7 : '');
        my $list = ($8 ? $8 : '');

        my $delta;
        # Check for full due date, with time
        if ($due eq 'never') {
            $delta = 'inf';
            $due = 'none';
        }
        else {
            my ($day, $due_time, @d);
            if ($due =~ /:/) {
                $day = $strp1->parse_datetime($due);
                $due_time = $day->hour() * 60 + $day->minute();
                $due = $strp4->format_datetime($day);
            }
            # Short due date, without time
            else {
                $day = $strp2->parse_datetime($due);
                $due_time = $now;
                $due = "none";
            }

            @d = split(/ /, $strp3->format_datetime($day));
            $delta = Date_to_Days($d[0], $d[1], $d[2]) - $today;
            if ($delta < 0 or ($delta == 0 and ($due_time - $now) < 0)) {
                $delta = "od";
            }
        }

        push(@tasks, {
                title => $title,
                delta => $delta,
                due => $due,
                estimate => $est,
                priority => $pri,
                list => $list,
                location => $loc,
                tags => $tags
            });
    }
}

# Get all tasks with a given delta time from today
sub get_tasks {
    my $delta = shift;
    my $count = 0;

    my $date = (defined $noheaders ? '' : &format_header($delta));

    # Loop over all tasks in list
    for my $task (@tasks) {
        # Define flag: 0 = keep, 1 = discard
        my $flag = 0;

        # Check if task is in time range
        if ($task->{'delta'} eq $delta) {
            # Check if task matches black list
            if (@blists) {
                foreach (@blists) {
                    $flag = 1 if lc eq lc($task->{'list'});
                }
            }
            next if $flag;

            # Check if task matches white list
            if (@wlists) {
                $flag = 1;
                foreach (@wlists) {
                    $flag = 0 if lc eq lc($task->{'list'});
                }
            }
            next if $flag;

            # Check if task matches black tag list
            if (@btags) {
                foreach my $btag (@btags) {
                    foreach (split(/,/, $task->{'tags'})) {
                        $flag = 1 if lc($btag) eq lc;
                    }
                }
            }
            next if $flag;

            # Check if task matches white tag list
            if (@wtags) {
                $flag = 1;
                foreach my $wtag (@wtags) {
                    foreach (split(/,/, $task->{'tags'})) {
                        $flag = 0 if lc($wtag) eq lc;
                    }
                }
            }
            next if $flag;

            # Check if task matches priority list
            if (@pri_list) {
                $flag = 1;
                foreach (@pri_list) {
                    $flag = 0 if lc eq lc($task->{'priority'});
                }
            }
            next if $flag;

            # Flag was never set - print task
            ++$count;
            my $str = $tcolor;
            # Check if user wants due times
            if ($time and $task->{'due'} ne "none" and
                $task->{'delta'} ne "od") {

                $str .= "$task->{'due'} - ";
            }
            $str .= $task->{'title'};
            # Check for alignment
            if ($alignc) {
                $str = "\${alignc}$str\n";
            }
            elsif ($alignr) {
                $str = "\${alignr}${str}${tindent}\n";
            }
            else {
                $str = "${tindent}${str}\n";
            }
            # Check if user wants locations
            if ($location) {
                my $estr = "Location: $task->{'location'}";
                # Check for alignment
                if ($alignc) {
                    $str .= "\${alignc}$estr\n";
                }
                elsif ($alignr) {
                    $str .= "\${alignr}${estr}${eindent}\n";
                }
                else {
                    $str .= "${eindent}${estr}\n";
                }
            }
            # Check if user wants estimates
            if ($estimate) {
                my $estr = "Estimate: $task->{'estimate'}";
                # Check for alignment
                if ($alignc) {
                    $str .= "\${alignc}$estr\n";
                }
                elsif ($alignr) {
                    $str .= "\${alignr}${estr}${eindent}\n";
                }
                else {
                    $str .= "${eindent}${estr}\n";
                }
            }
            # Check if user wants priorities
            if ($priority) {
                my $estr = "Priority: $task->{'priority'}";
                # Check for alignment
                if ($alignc) {
                    $str .= "\${alignc}$estr\n";
                }
                elsif ($alignr) {
                    $str .= "\${alignr}${estr}${eindent}\n";
                }
                else {
                    $str .= "${eindent}${estr}\n";
                }
            }
            # Print header if this is the first task
            if ($count == 1) {
              $str = "${date}${str}";
            }
            print $str;
        }
    }
}

# Format task day header
sub format_header {
    my $delta = shift;
    my $str = '';

    if ($delta eq "inf") {
        $str = "${hcolor}Other Tasks:";
    }
    elsif ($delta eq "od") {
        $str = "${hcolor}Overdue Tasks:";
    }
    elsif ($delta == 0) {
        $str = "${hcolor}Tasks Due Today:";
    }
    elsif ($delta == 1) {
        $str = "${hcolor}Tasks Due Tomorrow:";
    }
    else {
        my ($year, $month, $day) = Add_Delta_Days($ano, $mes, $dia, $delta);
        $str = $hcolor . sprintf("Tasks Due on %s, %.3s %s:",
                                    Day_of_Week_Abbreviation(
                                        Day_of_Week($year, $month, $day)),
                                    Month_to_Text($month),
                                    English_Ordinal($day));
    }

    # Check for alignment
    if ($alignr) {
        $str = "\${alignr}${str}${hindent}\n";
    }
    elsif ($alignc) {
        $str = "\${alignc}${str}\n";
    }
    else {
        $str = "${hindent}${str}\n";
    }

    return $str;
}

__END__

=head1 NAME

 conkyRTM.pl

=head1 SYNOPSIS

 ./conkyRTM.pl -u USER -p PASSWORD [options]

=head1 DESCRIPTION

 Perl script to output a user's RTM tasks to Conky

 To use this in Conky, put something like this in your .conkyrc:
     ${execpi 3600 perl /path/to/conkyRTM.pl -u USER -p PASS [options]}


=head1 ARGUMENTS

 -u USER, --user=USER           Specifies the username to be used for RTM
 -p PASSWORD, --pass=PASSWORD   Specifies the password to be used for RTM

=head1 OPTIONS

 -d N, --days=N          Specifies how many days (N) to grab tasks for
 -t, --time              Show time task is due in output
 -e, --estimate          Show task's time estimate in output.
 -y, --priority          Show task's priority in output.
 -l, --location          Show task's location in output.
 --tcolor=COLOR          Specify color for tasks. COLOR can be given as a
                         word, i.e. blue, as hex, i.e. 0000ff, or as
                         colorN as in Conky
 --hcolor=COLOR          Specify color for day headers. COLOR can be
                         given as a word, i.e. blue, as hex, i.e. 0000ff,
                         or as colorN as in Conky
 --tindent=N             Specify number of spaces to indent tasks.
 --hindent=N             Specify number of spaces to indent day headers.
 --eindent=N             Specify number of spaces to indent extra task
                         information, i.e. location, estimate, or
                         priority.
 -r, --alignr            Right-align output in Conky
 -c, --alignc            Center-align output in Conky
 -f FONT, --font=FONT    Specify font to be used for output. FONT should
                         be in one of the following formats:
                            --> font_name
                            --> font_name:size=SIZE
                            --> :size=SIZE
                         NOTE: SIZE is an integer
 -n, --not-due           Include tasks without a due date in output
 -o, --overdue           Include overdue tasks
 --include-tags=TAGS     Include only tasks matching specified tags in
                         output. TAGS is a comma separated list, i.e.
                         tag1,tag2,tag3
 --ignore-tags=TAGS      Exclude all tasks matching specified tags from
                         output. TAGS is a comma separated list, i.e.
                         tag1,tag2,tag3
 --white-lists=LISTS     Include only tasks in specified lists in output.
                         LISTS is a comma separated list, i.e.
                         list1,list2,list3
 --black-lists=LISTS     Exclude all tasks in specified lists from
                         output. LISTS is a comma separated list, i.e.
                         list1,list2,list3
 --priorities=PRIORITIES Include only tasks matching specified priorities
                         in output. PRIORITIES is a comma separated list.
                         Valid priorities are pri1, pri2, pri3, none
 --no-headers            Don't show day headers.
 -l, --location          Show location of tasks in output
 --24-hour               Show due times in 24 hour format
 -h, --help              Print this text and exit
 -m, --man               Print full documentation

=head1 AUTHOR

 Mike Stegeman

=head1 LICENSE

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
