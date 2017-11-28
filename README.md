# Description

conkyRTM can be used to output one or several task list(s) from Remember the Milk into Conky, with formatting.

# Atom URL

To find your RTM Atom URL, login to RTM and click on the Atom icon at the top right. It looks like this:
![Atom icon](https://image.flaticon.com/icons/svg/0/110.svg)

# Basic Usage

`./conkyRTM.pl -u URL`

# Conky Usage

`${execpi 3600 perl /path/to/conkyRTM.pl -u URL [options]}`

# Requirements

* HTML::Entities
   * http://search.cpan.org/dist/HTML-Parser/lib/HTML/Entities.pm
* Date::Calc
   * http://search.cpan.org/dist/Date-Calc/lib/Date/Calc.pod
* DateTime
   * http://search.cpan.org/dist/DateTime/lib/DateTime.pm
* DateTime::Format::Strptime
   * http://search.cpan.org/dist/DateTime-Format-Strptime/lib/DateTime/Format/Strptime.pm
