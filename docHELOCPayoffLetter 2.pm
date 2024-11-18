package docHELOCPayoffLetter;

use warnings;
use strict;
use Data::Dumper;
use List::Util qw(max min);

use GPD;
use Markup::CommonUS;

use generalUtils qw(print_debug trim convert_datetime);
use xmlRenderUtils;    # currency_fmt
use POQUtils qw(:all);

my $font8    = "Interstate-Light+8";
my $font10   = "Interstate-Light+10";
my $fontli10 = "Interstate-LightItalic+10";
my $fontb10  = "Interstate-Bold+10";
my $fontb12  = "Interstate-Bold+12";
my $fontb14  = "Interstate-Bold+14";
my $fonta8   = "ArialMT+8";
my $fonta10  = "ArialMT+10";

my $grmap;
my $skipfinalist = 0;

sub print_doc {
	my ( $pack, $constmap, $stockkey, $skipf ) = @_;

	$skipfinalist = 1 if defined $skipf && $skipf == 1;

	$grmap = get_graphics( $constmap, 'heloc_payoff' );
	my $tp   = Time::Piece->new();          # current datetime for all pages
	my $date = $tp->strftime("%m/%d/%Y");

	my $pgcnt = 5;
	my $rc    = 0;
	foreach my $pg ( 1 .. 5 ) {
		if ( ( $pg + $rc ) % 2 == 1 ) {
			new_sheet $stockkey;
		}
		else {
			start_reverse;
		}
		$rc = page_layout( $pack, $constmap, $date, $pg, $stockkey );
		$pgcnt += 1 if $rc > 0;
		#print "loop page $pg: $rc\n";
	}
	$pgcnt += $rc;
	print "print_doc return page count: $pgcnt\n";
	return $pgcnt;
}

sub page_layout {
	my ( $pack, $constmap, $date, $pg, $stockkey ) = @_;

	my $x = 1.905;
	my $y = 0.5;

	my ( $br1, $br2 ) = get_borrower($pack);
	my $name    = ( $br1 ne '' ) ? $br1 : $pack->{MailingAddress}->{MAILING_ADDRESS_1};
	my $acctno  = $pack->{LoanInformation}->{ACCOUNT_NUMBER};
	my $expdate = convert_datetime( $pack->{DocumentInformation}->{Expiration_Date}, '%Y%m%d', "%m/%d/%y" );
	my $amended = ( lc( $pack->{PayoffQuote}->{AmendedPOQ} ) eq 'true' ) ? 1 : 0;
	my $yesTX   = $pack->{PayoffQuote}->{TXDisclosure};

	my $entity    = find_entity_id($pack);
	my $fullname  = $pack->{PrivateLabel}->{FullName};
	my $payoffurl = $pack->{PrivateLabel}->{EntityWebAddress};
	my $phnum     = $pack->{PrivateLabel}->{ContactPointTelephone};
	my $namestr   = $fullname;
	$namestr .= ' c/o Specialized Loan Servicing LLC' if int($entity) != 1;
	my $pladdr  = get_pl_addresslines($pack);
	my $plgrmap = get_pl_graphic_map($constmap);

	if ( $pg == 1 ) {
		my $rtnaddr = ($pladdr) ? $pladdr : get_return_address( $constmap, $fullname );
		#print "print_page_top rtnaddr >> ", Dumper $rtnaddr;
		$y = print_page_top( $constmap, $plgrmap, $entity, $fullname, $rtnaddr );

		if ($amended) {
			put "Amended", 13.135, 10.165, $fontb14;
		}
		$y = print_header( $pack, $x, $y );

		$y = print_stmt_section( $pack, $constmap, $x, 10.16, $rtnaddr );

		$y = print_loan_info( $pack, $x, 14.6 );

		$y = print_interest_info( $pack, $x, $y );

		print_footer( $constmap, $entity );

		return 0;
	}

	if ( $pg == 2 ) {
		$y = print_top_date($date);

		$y = max( $y, 2.54 );
		pos_graphic(
			name                   => $grmap->{funds},
			is_gray                => 1,
			xpos                   => 0,
			ypos                   => 0,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);

		$y = 5.0292;
		my $wrtxt1 = qq/All parties must remain diligent and confirm that payoff instructions are authentic before funds
			 are wired. You must call and confirm the wire instructions directly with $fullname. Please call $fullname
			 at $phnum to confirm the wire instructions and payoff amount./;
		my $wrtxt2 = qq/Please pay attention to the details of each payoff statement. When wiring funds to $fullname,
			the beneficiary on the wire instructions must be Specialized Loan Servicing LLC, 6200 S Quebec St, Ste. 300,
			Greenwood Village, CO 80111./;
		my $wt1 = wrap $wrtxt1, $font10, 0.4, 'L', 19.05;
		my $wt2 = wrap $wrtxt2, $font10, 0.4, 'L', 19.05;
		emit_wrap $wt1, $x, $y;
		$y += 1.6;
		emit_wrap $wt2, $x, $y;

		my $msg = "Inc. ODI Text Information Required: PIF $acctno $name";
		$x = 3.175;
		$y = 10.795;
		put $msg, $x, $y, $font10;

		$y = 13.462;
		put $namestr, $x, $y, $font10;

		my $perdiem = sprintf( "%.4f", $pack->{PayoffQuote}->{Per_Diem_Interest} || 0 );
		my @txt = (
			"Funds received after the expiration date will accrue interest per diem in the amount of \$$perdiem. ",
			"FUNDS RECEIVED AFTER 5:00 PM EASTERN WILL BE CONSIDERED RECEIVED THE FOLLOWING DAY."
		);
		$x = 1.905;
		$y = 15.316;
		put $txt[0], $x, $y, $font10;
		$y += 0.4;
		put $txt[1], $x, $y, $fontli10;

		return 0;
	}

	if ( $pg == 3 ) {
		$y = print_top_date( $date, $acctno );

		# payoff table
		$y = 3.2;
		pos_graphic(
			name                   => $grmap->{table},
			is_gray                => 1,
			xpos                   => 0,
			ypos                   => 0,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);
		print_table( $pack, $x, $y );

		my $txtarr = get_undertable_txt( $entity, $pack );
		$y = 23.81;
		foreach my $txt (@$txtarr) {
			if ( length($txt) > 0 ) {
				my $wrtxt = wrap $txt, $font10, 0.4, 'L', 19.05;
				emit_wrap $wrtxt, $x, $y;
			}
			else {
				$y += 0.4;
			}
			$y += 0.4;
		}

		return 0;
	}

	if ( $pg == 4 ) {    # payoff details, bankrupt notice
		$y = print_top_date( $date, $acctno );
		$y = max( $y, 3.56 );

		pos_graphic(
			name                   => $grmap->{details},
			is_gray                => 1,
			xpos                   => 0,
			ypos                   => 0,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);
		write_page4_text($pack);

		$y = 14.13;
		my $graceday = $pack->{PayoffQuote}->{Grace_Days};
#my $unpdchg = $pack->{PayoffQuote}->{UnpaidLateCharge} ? currency_fmt($pack->{PayoffQuote}->{UnpaidLateCharge}) : '0.00';
		my $unpdchg =
			$pack->{PayoffQuote}->{NextLateChargeCollection}
			? currency_fmt( $pack->{PayoffQuote}->{NextLateChargeCollection} )
			: '0.00';
		my $txt1 = $graceday . " days after the regular due date, this amount may be deducted from";
		put $txt1, 7.63, $y, $font10;
		my $txt2 = 'the payoff late charge in the amount of $' . $unpdchg . ' has been included.';
		$y += 0.4;
		put $txt2, 2.54, $y, $font10;

		$x = 1.905;
		$y = 18.84;
		put "6.", $x, $y, $font10;    # missing on graphic
		my $txt6 = "New York Properties - Please contact $fullname for Loan Assignments.";
		put $txt6, 2.54, $y, $font10;
		$y += 0.6;

		my $endtxt =
			  "If you have any questions regarding this information, please contact Customer Care toll free at "
			. $phnum
			. ", Monday through Friday, 6:00 a.m. until 6:00 p.m. MT. We accept calls from relay services. "
			. "We accept calls from relay services. We provide translation services for individuals who indicate a language "
			. "preference other than English. Se habla espa\x{f1}ol.";

		my $wrtxt = wrap $endtxt, $font10, 0.4, 'L', 19.05;
		emit_wrap $wrtxt, $x, $y;
		$y += 2.0;
		put "Sincerely,", $x, $y, $font10;
		$y += 0.4;
		put "Customer Service", $x, $y, $font10;
		no utf8;

		$y = 23;
		pos_graphic(
			name                   => $grmap->{notice},
			page_num               => 1,
			is_gray                => 1,
			xpos                   => $x,
			ypos                   => $y,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);

		if ( $yesTX eq 'true' ) {    # add a new page
			print "print TX addition: $grmap->{TX}\n";
			new_sheet $stockkey;
			pos_graphic(
				name                   => $grmap->{TX},
				is_gray                => 1,
				xpos                   => 1.905,
				ypos                   => 1.5,
				allow_unembedded_fonts => 1,
				allow_annotations      => 1,
			);
			return 1;
		}

		return 0;
	}

	if ( $pg == 5 ) {    # no page top
		$x = 2.54;
		$y = 2;

		pos_graphic(
			name                   => $grmap->{escrow},
			is_gray                => 1,
			xpos                   => 0,
			ypos                   => 0,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);

		$y = 8.15;
		my $esctxt =
			"or log on to $payoffurl to make the update. This will ensure that your escrow funds will be mailed to 
            your correct address. FAILURE TO UPDATE YOUR MAILING ADDRESS MAY RESULT IN MIS-DIRECTED MAIL AND DELAY
            IN RECEIVING YOUR ESCROW REFUND CHECK.";
		my $wrapesc = wrap $esctxt, $font10, 0.5, 'L', 18.5;
		emit_wrap $wrapesc, $x, $y;

		$y = 15.15;
		put $payoffurl, 4.85, $y, $font10;
		$y += 0.45;
		put $phnum, 4.6, $y, $fonta10;
		put $namestr, 3.175, $y + 0.86, $fonta10;

		$x = 7.12;
		$y = 18.45;
		put $acctno, $x, $y, $font10;
		$y += 0.75;
		put $name, $x, $y, $font10;
		$y += 0.6;
		put $br2, $x, $y, $font10 if $br2 ne '';

		return 0;
	}
}

sub print_header {
	my ( $pack, $x, $y ) = @_;

	$y = max( $y, 5.08 );
	my $y2 = $y;

	my $tp   = Time::Piece->new();
	my $date = $tp->mdy('/');

	my $expdate = convert_datetime( $pack->{DocumentInformation}->{Expiration_Date}, '%Y%m%d', "%m/%d/%y" );
	my $orgdate = convert_datetime( $pack->{PayoffQuote}->{OriginationDate},         "%Y%m%d", "%m/%d/%y" );

	my ( $br1, $br2 ) = get_borrower($pack);
	my $addrs = get_mail_addrs($pack);
	if ( $br1 ne '' && $addrs->[0] =~ /$br1/i || $br2 ne '' && $addrs->[0] =~ /$br2/i ) {
		shift @$addrs;
	}
	if ( $br2 ne '' && $addrs->[0] =~ /$br2/i ) {
		shift @$addrs;
	}
	my @addrlist = grep { !/^\s*$/ } ( $br1, $br2, @$addrs );
	#list \@addrlist, $x, $y, $font10, 0.4;
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
	my $ldate     = $pack->{DocumentInformation}->{LetterDate};
	my $curtp     = Time::Piece->new;

	my $letterdate = ($ldate) ? convert_datetime( $date, "%Y%m%d", "%m/%d/%y" ) : $curtp->strftime("%m/%d/%y");
	my $acctno = $pack->{LoanInformation}->{ACCOUNT_NUMBER};

	my $rate = sprintf( "%.5f", $pack->{PayoffQuote}->{INTEREST_RATE_CURRENT} );
	my $amt =
		$pack->{LoanInformation}->{BALANCE_PRINCIPAL_ORIGINAL}
		? currency_fmt( $pack->{LoanInformation}->{BALANCE_PRINCIPAL_ORIGINAL} )
		: '0.00';

	$x = 12.7;
	$y = $y2;
	my $x2 = $x + 3.3;
	put 'Loan Number:', $x, $y, $font10;
	put $acctno, $x2, $y, $font10, 'R', 4.2;
	$y += 0.4;
	put 'Issue Date:', $x, $y, $font10;
	put $letterdate, $x2, $y, $font10, 'R', 4.2;
	$y += 0.4;
	put 'Payoff Good Through:', $x, $y, $font10;
	put $expdate, $x2, $y, $font10, 'R', 4.2;
	$y += 0.4;
	put 'Interest Rate:', $x, $y, $font10;
	put $rate. '%', $x2, $y, $font10, 'R', 4.2;
	$y += 0.4;
	put 'Orig. Ln Date:', $x, $y, $font10;
	put $orgdate, $x2, $y, $font10, 'R', 4.2;
	$y += 0.4;
	put 'Orig. Ln Amt:', $x, $y, $font10;
	put '$' . $amt, $x2, $y, $font10, 'R', 4.2;    # amt in currency format?
	$y += 0.4;

	return $y;
}

sub print_stmt_section {
	my ( $pack, $constmap, $x, $y, $rtnaddr ) = @_;

	$x = max( $x, 2 );
	$y = max( $y, 10.16 );
	my $x2 = 12;
	put "Home Equity Line of Credit Payoff Statement", $x, $y, $fontb14;
	$y += 1;
	put "Requested By:", $x, $y, $fontb10;

	my $sentlines = get_stmt_send_to_lines($pack);
	my $sz        = ( scalar(@$sentlines) + 1 );
	list $sentlines, $x, $y + 0.4, $font10, 0.4;

	my $fullname = $pack->{PrivateLabel}->{FullName};
	#my $slsaddrs = get_return_address($constmap, $fullname);
	#my $sz1 = (scalar(@$slsaddrs) + 1);
	my $sz1 = ( scalar(@$rtnaddr) + 1 );

	put "Mortgage Servicer:", $x2, $y, $fontb10;
	list $rtnaddr, $x2, $y + 0.4, $font10, 0.4;

	return $y + max( $sz, $sz1 );
}

sub print_loan_info {
	my ( $pack, $x, $y ) = @_;

	$x = max( $x, 1.905 );
	my $expdate = convert_datetime( $pack->{DocumentInformation}->{Expiration_Date}, '%Y%m%d', "%m/%d/%Y" );

	my ( $br1, $br2 ) = get_borrower($pack);
	my $name = ( $br1 ne '' ) ? $br1 : $pack->{MailingAddress}->{MAILING_ADDRESS_1} || '';
	my $propaddrs = get_property_addrs($pack);

	put "Loan Information", $x, $y, $fontb12;
	$y += 1;
	put 'MORTGAGOR:', $x, $y, $font10;
	put $name, 7, $y, $font10 if $name ne '';
	$y += 0.4;
	put 'COLLATERAL:', $x, $y, $font10;
	foreach my $line (@$propaddrs) {
		put $line, 7, $y, $font10;
		$y += 0.4;
	}

	put 'NEXT PAYMENT DUE DATE:', $x, $y, $font10;
	my $date = convert_datetime( $pack->{LoanInformation}->{DATE_NEXT_DUE}, "%Y%m%d", "%m/%d/%Y" );
	put $date, 7, $y, $font10;

	$y += 1;
	my $msg =
		  "This is a daily simple interest revolving line of credit. Figures are based on information available "
		. "as of the date of this letter. The following is the amount to pay to close your line of credit. These "
		. "figures expire "
		. $expdate . '.';
	my $wrap_txt = wrap $msg, $font10, 0.4, 'L', 19.05;
	emit_wrap $wrap_txt, $x, $y;

	my $due =
		$pack->{LoanInformation}->{TotalDueMinusUnappliedFundsAmount}
		? currency_fmt( $pack->{LoanInformation}->{TotalDueMinusUnappliedFundsAmount} )
		: '0.00';
	$y += 0.4 * 2 + 0.4;
	put 'Total Amount Due:', $x, $y, $fontb10;
	put '$' . $due, 7, $y, $fontb10;

	return $y + 0.5;
}

sub print_interest_info {
	my ( $pack, $x, $y ) = @_;

	$x = max( 2, $x );
	my $x2 = 8.38;
	$y = max( $y, 20.8 ) + 1;

	put 'INTEREST INFORMATION', $x, $y, $fontb12;

	$y += 1;
	my $duedate = convert_datetime( $pack->{LoanInformation}->{DATE_NEXT_DUE},  "%Y%m%d", "%m/%d/%y" );
	my $intpaid = convert_datetime( $pack->{PayoffQuote}->{InterestPaidToDate}, "%Y%m%d", "%m/%d/%Y" );
	my $perdiemint =
		$pack->{PayoffQuote}->{Per_Diem_Interest}
		? sprintf( "%.4f", $pack->{PayoffQuote}->{Per_Diem_Interest} )
		: '0.0000';
	my $intchg =
		$pack->{DocumentInformation}->{Interest_Charge}
		? currency_fmt( $pack->{DocumentInformation}->{Interest_Charge} )
		: '0.00';

	put "Interest Paid To Date:", $x, $y, $font10;
	put $intpaid, $x2, $y, $font10;    # adjust x here
	$y += 0.4;

	put "Daily Per Diem Interest Amount:", $x, $y, $font10;
	put '$' . $perdiemint, $x2, $y, $font10;
	$y += 0.4;

	put "Total Interest to be Charged:", $x, $y, $font10;
	put '$' . $intchg, $x2, $y, $font10;

	return $y + 0.5;
}

sub print_table {
	my ( $pack, $x, $y ) = @_;

	my $x2 = max( $x, 16.75 );
	$y = max( $y, 5.65 );
	my $delta = 0.762;
	my $r     = 4;

	my $amt =
		$pack->{PayoffQuote}->{BALANCE_PRINCIPAL_CURRENT}
		? currency_fmt( $pack->{PayoffQuote}->{BALANCE_PRINCIPAL_CURRENT} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	my $tp      = Time::Piece->new();
	my $curdate = $tp->strftime("%m/%d/%Y");
	my $date =
		$pack->{DocumentInformation}->{Int_Calc_to_Date}
		? convert_datetime( $pack->{DocumentInformation}->{Int_Calc_to_Date}, "%Y%m%d", "%m/%d/%Y" )
		: $curdate;
	$amt =
		$pack->{DocumentInformation}->{Interest_Charge}
		? currency_fmt( $pack->{DocumentInformation}->{Interest_Charge} )
		: '0.00';
	put $date, 5.41, $y, $font10;
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{LoanInformation}->{EscrowAdvancesAmount}
		? currency_fmt( $pack->{LoanInformation}->{EscrowAdvancesAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$amt = $pack->{PayoffQuote}->{UnpaidLateCharge} ? currency_fmt( $pack->{PayoffQuote}->{UnpaidLateCharge} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{DocumentInformation}->{Statement_nbsFee}
		? currency_fmt( $pack->{DocumentInformation}->{Statement_nbsFee} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt = $pack->{PayoffQuote}->{Release_Prep_Fee} ? currency_fmt( $pack->{PayoffQuote}->{Release_Prep_Fee} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$amt =
		$pack->{LoanInformation}->{CurrentDeferredPrincipalBalanceAmount}
		? currency_fmt( $pack->{LoanInformation}->{CurrentDeferredPrincipalBalanceAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{LoanInformation}->{CurrentDeferredInterestBalanceAmount}
		? currency_fmt( $pack->{LoanInformation}->{CurrentDeferredInterestBalanceAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{LoanInformation}->{CurrentDeferredExpenseAdvanceUnpaidBalanceAmount}
		? currency_fmt( $pack->{LoanInformation}->{CurrentDeferredExpenseAdvanceUnpaidBalanceAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{LoanInformation}->{CurrentDeferredExpenseAdvancePaidBalanceAmount}
		? currency_fmt( $pack->{LoanInformation}->{CurrentDeferredExpenseAdvancePaidBalanceAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{LoanInformation}->{CurrentDeferredAdminFeesBalanceAmount}
		? currency_fmt( $pack->{LoanInformation}->{CurrentDeferredAdminFeesBalanceAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{LoanInformation}->{CurrentDeferredLateChargeBalanceAmount}
		? currency_fmt( $pack->{LoanInformation}->{CurrentDeferredLateChargeBalanceAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{LoanInformation}->{CurrentDeferredEscrowAdvanceBalanceAmount}
		? currency_fmt( $pack->{LoanInformation}->{CurrentDeferredEscrowAdvanceBalanceAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$amt = $pack->{PayoffQuote}->{PRAAmount} ? currency_fmt( $pack->{PayoffQuote}->{PRAAmount} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt = $pack->{PayoffQuote}->{Option_Ins_Due} ? currency_fmt( $pack->{PayoffQuote}->{Option_Ins_Due} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt = $pack->{PayoffQuote}->{Recording_Fees} ? currency_fmt( $pack->{PayoffQuote}->{Recording_Fees} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$amt =
		$pack->{PayoffQuote}->{UnappliedFundsRetainedAmount}
		? currency_fmt( $pack->{PayoffQuote}->{UnappliedFundsRetainedAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{PayoffQuote}->{UnappliedFundsNettedAmount}
		? currency_fmt( $pack->{PayoffQuote}->{UnappliedFundsNettedAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{PayoffQuote}->{CorporateAdvanceTotalAmount}
		? currency_fmt( $pack->{PayoffQuote}->{CorporateAdvanceTotalAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{PayoffQuote}->{TerminationFeeAmount}
		? currency_fmt( $pack->{PayoffQuote}->{TerminationFeeAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$date =
		$pack->{PayoffQuote}->{FHA_PMI_Calc_To_Date}
		? convert_datetime( $pack->{PayoffQuote}->{FHA_PMI_Calc_To_Date}, "%Y%m%d", "%m/%d/%Y" )
		: $curdate;
	$amt =
		$pack->{PayoffQuote}->{Anticipated_Escrow_Disb_TaxIns}
		? currency_fmt( $pack->{PayoffQuote}->{Anticipated_Escrow_Disb_TaxIns} )
		: '0.00';
	put $date. ')', 8.41, $y, $font10;
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$amt =
		$pack->{PayoffQuote}->{Escrow_Funds_Avail_Cover_Anticipated_Disb}
		? currency_fmt( $pack->{PayoffQuote}->{Escrow_Funds_Avail_Cover_Anticipated_Disb} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$amt =
		$pack->{LoanInformation}->{TotalDueMinusUnappliedFundsAmount}
		? currency_fmt( $pack->{LoanInformation}->{TotalDueMinusUnappliedFundsAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $fontb12, 'R', $r;
	return;
}

sub get_undertable_txt {
	my ( $entity, $pack ) = @_;

	my $phnum    = $pack->{PrivateLabel}->{ContactPointTelephone};
	my $fullname = $pack->{PrivateLabel}->{FullName};

	my $txtstr =
		"Paying the amount above on or before the expiration date will close your Home Equity Line of Credit (HELOC). "
		. "You will no longer have access to the funds, and your lien will be released. If your HELOC is past the draw period, "
		. "receipt of funds will close your HELOC and your lien will be released. If your HELOC is within the draw period, "
		. "receipt of funds will pay down your HELOC and it will not be closed. If you wish to close your HELOC, and have the "
		. "lien released prior to your draw end date, we require an additional written request with your signature, or a copy "
		. "of your government issued ID, sent to: "
		. $fullname;
	$txtstr .= " c/o SLS " if ( int($entity) != 1 );
	$txtstr .=
		  ", P.O. Box 636005, Littleton, CO 80163-6005. For information on how to pay down your line of credit "
		. "please call our Customer Care Department at 800-315-4757 Monday - Friday, 6:00 a.m. until 6:00 p.m. MT.";
	my $txt = [$txtstr];

	return ( int($entity) != 0 ) ? $txt : [];
}

sub write_page4_text {
	my $pack = shift;

	my $fullname = $pack->{PrivateLabel}->{FullName};

	my $para1 =
"Please be advised the payoff amount specified is valid through the stated expiration date or the date the loan is
transferred to a new servicer. If you have been notified that $fullname intends to transfer your loan, you must ensure
$fullname receives your payoff prior to the date of transfer, or you must make payoff arrangements with the new
servicer.";
	my $h1 = 5;

	my $para2 =
"Your home equity line of credit is an open-ended account. Draws on your line of credit may increase the unpaid principal
balance of your loan. The above figures are subject to final verification upon receipt of payoff funds by $fullname. We
reserve the right to adjust these figures and refuse any funds that are insufficient to pay the loan in full for any reason
including, but not limited to, error in calculation of payoff due, previously dishonored payments, interest rate changes, or
additional advances between the date of this payoff statement and receipt of funds unless prohibited by applicable state
law, including but not limited to Wisconsin.";
	my $h2 = 7;

	my $para3 =
"Any further advances will increase the total due and the per diem finance charges. You are responsible for all advances
honored until the line of credit has been closed.";
	my $h3 = 3;

	my $para4 =
"If your loan provides for a waiver of the prepayment penalty due to sale, you will need to provide a copy of Closing
of Closing Disclosure, signed HUD1 or Settlement Statement with your payoff funds. Upon review, the prepayment penalty will
be waived or refunded at that time. Proof of sale must be received no later than 10 days after your payoff funds are
received to have the prepayment penalty refunded. $fullname will not remove the prepayment penalty prior to receipt
of payoff funds and proof of sale.";

	my $x        = 1.905;
	my $y        = 3.81;
	my $wraptxt1 = wrap $para1, $font10, 0.4, 'L', 19.05;
	emit_wrap $wraptxt1, $x, $y;
	$y += $h1 * 0.4;

	my $wraptxt2 = wrap $para2, $font10, 0.4, 'L', 19.05;
	emit_wrap $wraptxt2, $x, $y;
	$y += $h2 * 0.4;

	my $wraptxt3 = wrap $para3, $font10, 0.4, 'L', 19.05;
	emit_wrap $wraptxt3, $x, $y;
	$y += $h3 * 0.4;

	my $wraptxt4 = wrap $para4, $font10, 0.4, 'L', 19.05;
	emit_wrap $wraptxt4, $x, $y;
	return;
}

1;
