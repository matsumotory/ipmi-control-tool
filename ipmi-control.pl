#!/usr/bin/perl

#
# IPMI Control Script for ipmitool
# AUTHOR matsumoto_r 2012/11/21
#

use strict;
use warnings;
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use File::Basename;

our $VERSION = "0.0.1";
our $SCRIPT  = basename($0);

$| = 1;

# ipmit config ver 1.5 -> -l lan, ver 2.0 -> -l lanplus
our $IPMITOOL = "/usr/bin/ipmitool";
our $IPMI_VER = "-l lan";
our $IPMI_USER = 'hoge';
our $IPMI_PASS = 'pass';
our $IP_LIST = './ipmi_target.list';
our $IPMI_CMD = "$IPMITOOL $IPMI_VER";

GetOptions (
    'h|help'     => \my $help,
    'v|version'  => \my $version,
    't|target=s' => \my $target,
    'm|method=s' => \my $method,
) or pod2usage(2);

$version and do { print "$SCRIPT: $VERSION\n"; exit 0 };
pod2usage(1) if $help;

die "ipmitool($IPMITOOL) not installed." if !-f $IPMITOOL;
die "target not found." if !defined $target;
die "target=(all) is allowed only method=(status).\n" if $target eq 'all' && $method ne 'status';
die "$IP_LIST is not found\n" if !-f $IP_LIST;

my $METHOD_MAP = {
    on        =>  \&go_on,
    off       =>  \&go_off,
    reboot    =>  \&go_reboot,
    reset     =>  \&go_reset,
    status    =>  \&go_status,
    console   =>  \&go_console,
    hwstatus  =>  \&go_hwstatus,
    laninfo   =>  \&go_laninfo,
};

if (exists $METHOD_MAP->{$method}) {
    my $ips = get_management_ip($target);
    foreach my $host (keys %$ips) {
        print "$host:\t";
        print $METHOD_MAP->{$method}->($ips->{$host});
    }
} else {
    print "NG: excuted method error. target=($target), method=($method)\n";
    exit 1;
}

exit 0;

sub go_on {
    my $management_ip = shift;
    return `$IPMI_CMD -H $management_ip -U $IPMI_USER -P "$IPMI_PASS" power on`;
}

sub go_off {
    my $management_ip = shift;
    return `$IPMI_CMD -H $management_ip -U $IPMI_USER -P "$IPMI_PASS" power off`;
}

sub go_reboot {
    my $management_ip = shift;

    my $time_out_sleep = 5;
    my $time_out_count = 1;
    my $time_out_count_max = 3;
    my $time_out_time = $time_out_sleep * $time_out_count_max;

    while ($time_out_count <= $time_out_count_max) {
        my $off_chk = `$IPMI_CMD -H $management_ip -U $IPMI_USER -P "$IPMI_PASS" power status`;
        if ($off_chk =~ /Chassis Power is off/) {
            print "OK: " . `$IPMI_CMD -H $management_ip -U $IPMI_USER -P "$IPMI_PASS" power on`;
            exit(0);
        }
        sleep $time_out_sleep;
        $time_out_count++;
    }

    print "NG: excuted power off error. (Time OUT $time_out_time sec)\n";
    exit(1);
}

sub go_reset {
    my $management_ip = shift;
    return `$IPMI_CMD -H $management_ip -U $IPMI_USER -P "$IPMI_PASS" power reset`;
}

sub go_status {
    my $management_ip = shift;
    return `$IPMI_CMD -H $management_ip -U $IPMI_USER -P "$IPMI_PASS" power status`;
}

sub go_console {
    my $management_ip = shift;
    system("$IPMI_CMD -H $management_ip -U $IPMI_USER -P '$IPMI_PASS' sol activate")   ?   die "console error."  :   exit 0;
}

sub go_hwstatus {
    my $management_ip = shift;
    print "summarizing hw status... just a moment\n";
    return "\n" . `$IPMI_CMD -H $management_ip -U $IPMI_USER -P "$IPMI_PASS" sdr`;
}

sub go_laninfo {
    my $management_ip = shift;
    print "summarizing lan info... just a moment\n";
    return "\n" . `$IPMI_CMD -H $management_ip -U $IPMI_USER -P "$IPMI_PASS" lan print 1`;
}

sub get_management_ip {
    my $target = shift;

    my ($global_ip, $management_ip);
    my @management_ips = ();
    my @global_ips = ();
    my $ips;

    open(DB, "< $IP_LIST");
    my @db = <DB>;
    close DB;

    if ($target eq 'all' && $method eq 'status') {
        foreach my $data (@db) {
            chomp($data);
            ($global_ip, $management_ip) = split(/\t| +/, $data);
            $ips->{$global_ip} = $management_ip;
        }
        return $ips;
    } else {
        foreach my $data (@db) {
            chomp($data);
            ($global_ip, $management_ip) = split(/\t| +/, $data);

            if ($global_ip eq $target) {
                $ips->{$global_ip} = $management_ip;
                return $ips;
            }
        }
        print "NG: no such target($target)\n";
        exit(1);
    }
}
__END__

=head1 NAME

ipmi-control.pl - control ipmitool

=head1 SYNOPSIS

 ./ipmi-control.pl -t ${TARGET} -m ${METHOD}

    ex) ./ipmi-control.pl -t example.cm -m status

 Options:
    -target -t                      control target host or ip pr all
    -method -m                      control methods(on off reboot reset status hwstatus laninfo)
    -help -h                        brief help message
    -version -v                     brief version

=head1 AUTHOR

MATSUMOTO Ryosuke

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
