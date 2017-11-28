#!/usr/bin/perl
# -----------------------------------------------------------------------------
# Copyright (C) 2011 Mike Stegeman <mrstegeman@gmail.com>
# Last Revision: Oct 12, 2011
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
my ($atom_url, $days, $time, $tcolor, $hcolor, $tindent, $hindent, $eindent,
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
    'u|url=s' => \$atom_url,
    'd|days=s' => \$days,
    't|time' => \$time,
    'tcolor=s' => \$tcolor,
    'hcolor=s' => \$hcolor,
    'tindent=i' => \$tindent,
    'hindent=i' => \$hindent,
    'eindent=i' => \$eindent,
    'r|alignr' => \$alignr,
    'c|alignc' => \$alignc,
    'f|font=s' => \$font,
    'n|not-due' => \$not_due,
    'include-tags=s' => \$inc_tags,
    'ignore-tags=s' => \$exc_tags,
    'white-lists=s' => \$white_lists,
    'black-lists=s' => \$black_lists,
    'l|location' => \$location,
    'e|estimate' => \$estimate,
    'y|priority' => \$priority,
    'priorities=s' => \$priorities,
    'h|help' => \$help,
    'm|man' => \$man,
    'o|overdue' => \$overdue,
    'no-headers' => \$noheaders,
    '24-hour' => \$miltime,
);

# Check for required inputs
pod2usage(-verbose => 2) and exit if $man;
pod2usage(-verbose => 1) and exit if ($help or not $atom_url or @ARGV);

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
my $wget_cmd = "wget -O - -q --no-cache '$atom_url'";
my $xml = `$wget_cmd`;
$xml =~ s/\n//g;
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
my $pat = ($miltime ? '%R' : '%I:%M%P');
my $strp4 = new DateTime::Format::Strptime(pattern => $pat);

# Set up white/black tags, white/black lists, and priority list
my %wtags = map {lc($_) => 1} split(/,/, $inc_tags) if $inc_tags;
my %btags = map {lc($_) => 1} split(/,/, $exc_tags) if $exc_tags;
my %wlists = map {lc($_) => 1} split(/,/, $white_lists) if $white_lists;
my %blists = map {lc($_) => 1} split(/,/, $black_lists) if $black_lists;
my %pri_list = map {lc($_) => 1} split(/,/, $priorities) if $priorities;

# Parse atom feed
&parse($xml);

# Check for font settings
print "\${font $font}" if $font;

# Get tasks
my @daylist = (0 .. --$days);
unshift(@daylist, 'od') if $overdue;
push(@daylist, 'inf') if $not_due;
map(&get_tasks($_), @daylist);


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
    my ($title, $due, $pri, $est, $tags, $loc, $post, $list, $delta);
    while ($xml =~ /$rtm_re/g) {
        $title = ($1 ? decode_entities($1) : '');
        $due = ($2 ? decode_entities($2) : '');
        $pri = ($3 ? decode_entities($3) : '');
        $est = ($4 ? decode_entities($4) : '');
        $tags = ($5 ? decode_entities($5) : '');
        $loc = ($6 ? decode_entities($6) : '');
        $post = ($7 ? decode_entities($7) : '');
        $list = ($8 ? decode_entities($8) : '');

        # Check for no due date
        if ($due eq 'never') {
            $delta = 'inf';
        }
        else {
            my ($day, $due_time, @d);
            # Full due date, with time
            if ($due =~ /:/) {
                $day = $strp1->parse_datetime($due);
                $due_time = $day->hour() * 60 + $day->minute();
                $due = $strp4->format_datetime($day);
            }
            # Short due date, without time
            else {
                $day = $strp2->parse_datetime($due);
                $due_time = $now;
                $due = 'never';
            }

            @d = split(/ /, $strp3->format_datetime($day));
            $delta = Date_to_Days($d[0], $d[1], $d[2]) - $today;
            if ($delta < 0 or ($delta == 0 and ($due_time - $now) < 0)) {
                $delta = 'od';
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
    my ($flag, $str);
    my $date = ($noheaders ? '' : &format_header($delta));

    # Loop over all tasks in list
    TASK:
    for my $task (@tasks) {
        # Check if task is in time range
        if ($task->{'delta'} eq $delta) {
            # Check if task matches black list
            next TASK if $blists{lc($task->{'list'})};
            # Check if task matches white list
            if (keys(%wlists)) {
                next TASK unless $wlists{lc($task->{'list'})};
            }
            # Check if task matches black tag list
            foreach (split(/,/, $task->{'tags'})) {
                next TASK if $btags{lc($_)};
            }
            # Check if task matches white tag list
            if (keys(%wtags)) {
                $flag = 1;
                map {$flag = 0 if $wtags{lc($_)}} split(/,/, $task->{'tags'});
                next TASK if $flag;
            }
            # Check if task matches priority list
            if (keys(%pri_list)) {
                next TASK unless $pri_list{lc($task->{'priority'})};
            }

            # Flag was never set - print task
            ++$count;
            $str = $tcolor;
            # Check if user wants due times
            if ($time and $task->{'due'} ne 'never' and
                $task->{'delta'} ne 'od') {

                $str .= "$task->{'due'} - ";
            }
            $str = &align_text($str . $task->{'title'}, $tindent);
            # Check if user wants locations
            if ($location) {
                $str .= &align_text("Location: $task->{'location'}", $eindent);
            }
            # Check if user wants estimates
            if ($estimate) {
                $str .= &align_text("Estimate: $task->{'estimate'}", $eindent);
            }
            # Check if user wants priorities
            if ($priority) {
                $str .= &align_text("Priority: $task->{'priority'}", $eindent);
            }
            # Print header if this is the first task
            print ($count == 1 ? "${date}${str}" : $str);
        }
    }
}

# Format task day header
sub format_header {
    my $delta = shift;
    my $str;

    if ($delta eq 'inf') {
        $str = "${hcolor}Other Tasks:";
    }
    elsif ($delta eq 'od') {
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
        $str = $hcolor . sprintf('Tasks Due on %s, %.3s %s:',
                                    Day_of_Week_Abbreviation(
                                        Day_of_Week($year, $month, $day)),
                                    Month_to_Text($month),
                                    English_Ordinal($day));
    }

    return &align_text($str, $hindent);
}

# Aligns and indents text
sub align_text {
    my ($str, $indent) = @_;

    if ($alignc) {
        return "\${alignc}${str}\n";
    }
    elsif ($alignr) {
        return "\${alignr}${str}${indent}\n";
    }
    else {
        return "${indent}${str}\n";
    }
}

__END__

=head1 NAME

 conkyRTM.pl

=head1 SYNOPSIS

 ./conkyRTM.pl -u ATOM_URL [options]

=head1 DESCRIPTION

 Perl script to output a user's RTM tasks to Conky

 To use this in Conky, put something like this in your .conkyrc:
     ${execpi 3600 perl /path/to/conkyRTM.pl -u USER -p PASS [options]}


=head1 ARGUMENTS

 -u URL, --url=URL       Specifies the Atom URL to be used for RTM

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
                         Valid priorities are 1, 2, 3, and none
 --no-headers            Don't show day headers.
 --24-hour               Show due times in 24 hour format
 -h, --help              Print this text and exit
 -m, --man               Print full documentation

=head1 AUTHOR

 Mike Stegeman <mrstegeman@gmail.com>

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
