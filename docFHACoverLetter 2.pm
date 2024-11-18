package docFHACoverLetter;

use warnings;
use strict;
use Data::Dumper;
use Time::Piece;
use List::Util qw(min max);

#use lib $ENV{CCS_RESOURCE}."\\Global\\GPD\\ver\\3.00";
use GPD;
use Markup::CommonUS;

#use lib "../../Common";
use generalUtils qw(print_debug trim convert_datetime);
use POQUtils qw(:all);

my $font8   = "Interstate-Light+8";
my $font10  = "Interstate-Light+10";
my $fontb10 = "Interstate-Bold+10";
my $fontb12 = "Interstate-Bold+12";
my $fontb14 = "Interstate-Bold+14";
my $fonta8  = "ArialMT+8";
my $fonta10 = "ArialMT+10";

my $skipfinalist = 0;

sub print_doc {
	my ( $pack, $constmap, $stockkey, $skipf ) = @_;    # grmpa: hash of graphic names

	$skipfinalist = 1 if ( defined $skipf && $skipf == 1 );

	my $grmap = get_graphics( $constmap, 'fha_cover' );

	my $tp   = Time::Piece->new();
	my $date = $tp->strftime("%m/%d/%y");

	my $entity   = find_entity_id($pack);
	my $fullname = $pack->{PrivateLabel}->{FullName};
	my $plgrmap  = get_pl_graphic_map($constmap);
	my $entgrmap = $plgrmap->{$entity};
	my $pladdr   = get_pl_addresslines($pack);

	my $pgcnt = 1;    # 1 cover page

	new_sheet $stockkey;

	# print sls_return address on top left:
	my $rtnaddr = ($pladdr) ? $pladdr : get_return_address( $constmap, $fullname );
	my $x       = 1.9;
	my $y       = print_page_top( $constmap, $plgrmap, $entity, $fullname, $rtnaddr );

	# print header section:
	$y = print_header( $constmap, $pack, $x, $y );

	# print cover section:
	$y = 10.4;
	my $namestr = get_names($pack);
	put "Dear " . $namestr . '.', $x, $y, $font10;
	my $phone = $pack->{PrivateLabel}->{ContactPointTelephone} || '000-000-0000';
	print "phone: $phone\n";

	$y = 11.2;
	my $para1 =
"This is in reply to an inquiry/request for payoff figures or an offer to tender an amount to prepay in full your "
		. "FHA-insured mortgage which "
		. $fullname
		. " is servicing.";
	my $w1 = wrap $para1, $font10, 0.4, 'L', 19.05;
	emit_wrap $w1, $x, $y;

	$y = 13.0;
	my $para2 =
		  $fullname
		. " will only accept payoff funds on the first day of any month during the mortgage term; or will accept "
		. "payoff funds whenever tendered which include interest paid to the first day of the month following the date payoff "
		. "funds are received.";
	my $w2 = wrap $para2, $font10, 0.4, 'L', 19.05;
	emit_wrap $w2, $x, $y;

	$y = 16;
	my $para3 =
		"If you should have any questions regarding this notice, please contact our Customer Care Department at $phone "
		. "Payoff Request Fax #720-241-7537.";
	my $w3 = wrap $para3, $font10, 0.4, 'L', 19.05;
	emit_wrap $w3, $x, $y;

	$y = 18.35;
	put $fullname, $x, $y, $font10;

	#    $y += 0.4;
	pos_graphic(
		name                   => $grmap->{cover},
		page_num               => 1,
		is_gray                => 1,
		xpos                   => 0,
		ypos                   => 0,
		allow_unembedded_fonts => 1,
		allow_annotations      => 1,
	);

	$y = 19.5;
	my $miranda = ( int($entity) >= 1 ) ? $entgrmap->{mini} : $grmap->{miranda};
	if ( $miranda ne '' ) {
		pos_graphic(
			name                   => $miranda,
			page_num               => 1,
			is_gray                => 1,
			xpos                   => $x,
			ypos                   => $y,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);
	}

	# print bankrupt notice:
	$y = 21.59;
	pos_graphic(
		name                   => $grmap->{notice},
		page_num               => 1,
		is_gray                => 1,
		xpos                   => $x,
		ypos                   => $y,
		allow_unembedded_fonts => 1,
		allow_annotations      => 1,
	);

	# print address footer, R-align and wrap by width 3.25
	print_footer( $constmap, $entity );

	return $pgcnt;
}

sub print_header {
	my ( $constmap, $pack, $x, $y ) = @_;

	$y = max( $y, 5.08 );
	my ( $br1, $br2 ) = get_borrower($pack);
	my $addrs = get_mail_addrs($pack);    #print "get_mail_addrs return: ", Dumper $addrs;
	if ( $br1 ne '' && $addrs->[0] =~ /$br1/i || $br2 ne '' && $addrs->[0] =~ /$br2/i ) {
		shift @$addrs;
	}
	if ( $br2 ne '' && $addrs->[0] =~ /$br2/i ) {
		shift @$addrs;
	}
	my @addrlist = ( $br1, $br2, @$addrs );

	my %args = (
		name_addr  => \@addrlist,
		xpos       => 2.54,
		ypos       => 4.7625,
		font       => $fonta10,
		leading    => 0.34,
		wrap_width => 8.25
	);
	$args{skipFinalist} = 1 if $skipfinalist;
	Markup::CommonUS::name_address(%args);

	my $propaddrs = get_property_addrs($pack);

	my $tp         = Time::Piece->new();
	my $rawdate    = $pack->{DocumentInformation}->{LetterDate} || '';
	my $letterdate = ($rawdate) ? convert_datetime( $rawdate, "%Y%m%d", "%m/%d/%Y" ) : $tp->strftime("%m/%d/%Y");
	my $acctno     = $pack->{LoanInformation}->{ACCOUNT_NUMBER};

	$x = 12.7;
	my $x2 = 15.75;
	put 'Letter Date:', $x, $y, $font10;
	put $letterdate, $x2, $y, $font10, 'R', 5;
	$y += 0.4;

	put 'Loan Number:', $x, $y, $font10;
	put $acctno, $x2, $y, $font10, 'R', 5;
	$y += 0.4;

	put 'Property Address:', $x, $y, $font10;
	my $line1 = shift @$propaddrs;
	if ( length($line1) > 24 ) {
		my $w = wrap $line1, $font10, 0.4, 'R', 5.02;
		emit_wrap $w, $x2, $y;
		$y += 0.4;
	}
	else {
		put $line1, $x2, $y, $font10, 'R', 5;
	}
	$y += 0.4;
	foreach my $line (@$propaddrs) {
		put $line, $x2, $y, $font10, 'R', 5;
		$y += 0.4;
	}

	return $y;
}

1;
