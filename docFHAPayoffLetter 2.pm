package docFHAPayoffLetter;

use warnings;
use strict;
use Data::Dumper;
use List::Util qw(max min);

#use lib $ENV{CCS_RESOURCE}."\\Global\\GPD\\ver\\3.00";
use GPD;
use Markup::CommonUS;

#use lib "../../Common";
use generalUtils qw(trim convert_datetime);
use xmlRenderUtils;    # currency_fmt;
use POQUtils qw(:all);

# module globals:
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

	$skipfinalist = 1 if ( defined $skipf && $skipf == 1 );

	$grmap = get_graphics( $constmap, 'fha_payoff' );
	my $tp   = Time::Piece->new();          # current datetime for all pages
	my $date = $tp->strftime("%m/%d/%Y");
	#print "fha payoff letter - $date >> grmap ", Dumper $grmap;

	# add coverpage as page 1
	my $pgnum = get_cur_num_sheets;
	my $pgcnt = 5;
	foreach my $pg ( 2 .. 6 ) {
		if ( $pg % 2 == 0 ) {
			new_sheet $stockkey;
		}
		else {
			start_reverse;
		}
		page_layout( $pack, $constmap, $date, $pg - 1 );
	}
	return $pgcnt;
}

sub page_layout {
	my ( $pack, $constmap, $date, $pg ) = @_;

	my $x = 1.905;
	my $y = 0.5;
	my ( $br1, $br2 ) = get_borrower($pack);
	my $name    = ( $br1 ne '' ) ? $br1 : $pack->{MailingAddress}->{MAILING_ADDRESS_1};
	my $acctno  = $pack->{LoanInformation}->{ACCOUNT_NUMBER};
	my $amended = ( lc( $pack->{PayoffQuote}->{AmendedPOQ} ) eq 'true' ) ? 1 : 0;
	my $yesTX   = $pack->{PayoffQuote}->{TXDisclosure};

	my $entity    = find_entity_id($pack);
	my $fullname  = $pack->{PrivateLabel}->{FullName};
	my $phnum     = $pack->{PrivateLabel}->{ContactPointTelephone};
	my $payoffurl = $pack->{PrivateLabel}->{EntityWebAddress};
	my $namestr   = $fullname;
	$namestr .= ' c/o Specialized Loan Servicing LLC' if int($entity) != 1;
	my $pladdr  = get_pl_addresslines($pack);
	my $plgrmap = get_pl_graphic_map($constmap);

	if ( $pg == 1 ) {
		my $rtnaddr = ($pladdr) ? $pladdr : get_return_address( $constmap, $fullname );
		#print "print_page_top rtnaddr >> ", Dumper $rtnaddr;
		$y = print_page_top( $constmap, $plgrmap, $entity, $fullname, $rtnaddr );

		if ($amended) {
			put "Amended", 8.75, 10.165, $fontb14;
		}
		$y = print_header( $pack, $x, $y );

		$y = print_stmt_section( $pack, $constmap, $x, 10.16, $rtnaddr );

		$y = print_loan_info( $pack, $x, 14.6 );

		print_footer( $constmap, $entity );
	}

	if ( $pg == 2 ) {
		$y = print_top_date($date);

		pos_graphic(
			name                   => $grmap->{funds},
			page_num               => 1,
			is_gray                => 1,
			xpos                   => 0,
			ypos                   => 0,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
			xalign                 => 'L',
			yalign                 => 'T',
		);

		$y = 5.0292;
		# add wrap_txt for below 2 txts:
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

		$x = 3.175;
		$y = 10.795;    #max( $y, 7 );
		my $msg = "Inc. ODI Text Information Required: PIF $acctno $name";
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
		if ( $perdiem > 0 ) {
			put $txt[0], $x, $y, $font10;
			$y += 0.4;
			put $txt[1], $x, $y, $fontli10;
		}
	}

	if ( $pg == 3 ) {
		$y = print_top_date( $date, $acctno );

		# payoff table
		$y = 3.2;
		pos_graphic(
			name                   => $grmap->{table},
			page_num               => 1,
			is_gray                => 1,
			xpos                   => 0,
			ypos                   => 0,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);
		print_table( $pack, $x, $y );

		my $txt = get_undertable_txt( $entity, $pack );
		my $wrtxt = wrap $txt, $font10, 0.4, 'L', 19.05;
		emit_wrap $wrtxt, 1.905, 20.955;
	}

	if ( $pg == 4 ) {    # payoff details, bankrupt notice
		$y = print_top_date( $date, $acctno );
		$y = max( $y, 3.56 );

		pos_graphic(
			name                   => $grmap->{details},
			page_num               => 1,
			is_gray                => 1,
			xpos                   => 0,
			ypos                   => 0,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);

		if ( $yesTX eq 'true' ) {
			print "print TX addition: $grmap->{TX}\n";
			pos_graphic(
				name                   => $grmap->{TX},
				is_gray                => 1,
				xpos                   => 1.905,
				ypos                   => 3.81,
				allow_unembedded_fonts => 1,
				allow_annotations      => 1,
			);
		}

		write_page4_toptext($fullname);

		$y = 13.84;
		my $graceday = $pack->{PayoffQuote}->{Grace_Days};
#my $unpdchg = $pack->{PayoffQuote}->{UnpaidLateCharge} ? currency_fmt($pack->{PayoffQuote}->{UnpaidLateCharge}) : '0.00';
		my $unpdchg =
			$pack->{PayoffQuote}->{NextLateChargeCollection}
			? currency_fmt( $pack->{PayoffQuote}->{NextLateChargeCollection} )
			: '0.00';
		my $txt1 = $graceday . " days after the regular due date, this amount may be deducted from";
		put $txt1, 7.64, $y, $font10;
		my $txt2 = 'the payoff late charge in the amount of $' . $unpdchg . ' has been included.';
		put $txt2, 2.54, $y + 0.4, $font10;

		$y = 18.5;
		my $txt6 = "6.   New York Properties - Please contact " . $fullname . " for Loan Assignments.";
		put $txt6, 1.905, $y, $font10;

		$y += 0.8;
		my $txtq =
"If you have any questions regarding this information, please contact Customer Care toll free at $phnum, Monday "
			. "through Friday, 6:00 a.m. until 6:00 p.m. MT.  We accept calls from relay services. "
			. "We provide translation services for individuals who indicate a language preference other than English. "
			. "Se habla espa\x{f1}ol.";
		my $wrap_txt = wrap $txtq, $font10, 0.4, 'L', 19.05;
		emit_wrap $wrap_txt, $x, $y;    #3.81;

		$y += 1.6;
		put "Sincerely,", $x, $y, $font10;
		put "Customer Service", $x, $y + 0.8, $font10;

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
	}

	if ( $pg == 5 ) {    # no page top
		$y = 2.54;
		pos_graphic(
			name                   => $grmap->{escrow},
			page_num               => 1,
			is_gray                => 1,
			xpos                   => 0,
			ypos                   => 0,
			allow_unembedded_fonts => 1,
			allow_annotations      => 1,
		);

		my $txt =
qq/or log on to $payoffurl to make the update. This will ensure that your escrow funds will be mailed to your correct address. FAILURE TO UPDATE YOUR MAILING ADDRESS MAY RESULT IN MIS-DIRECTED MAIL AND DELAY IN RECEIVING YOUR ESCROW REFUND CHECK./;
		my $wrtxt = wrap $txt, $font10, 0.4, 'L', 18.5;
		emit_wrap $wrtxt, 2.54, 8.1;

		$y = 15.12;
		put $payoffurl, 4.85, $y, $font10;
		$y += 0.45;
		put $phnum, 4.6, $y, $fonta10;
		$y += 0.86;
		put $namestr, 3.175, $y, $fonta10;

		$x = 7;
		$y = 18.45;
		put $acctno, $x, $y, $font10;
		$y += 0.65;
		put $name, $x, $y, $font10;
		$y += 0.4;
		put $br2, $x, $y, $font10 if $br2 ne '';
	}
	return;
}

sub print_header {
	my ( $pack, $x, $y ) = @_;

	$y = max( $y, 5.2 );
	$x = max( $x, 1.905 );
	my $y2 = $y;

	my ( $br1, $br2 ) = get_borrower($pack);
	my $addrs = get_mail_addrs($pack);
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

	my $tp = Time::Piece->new();

	my $propaddrs = get_property_addrs($pack);

	my $expdate = convert_datetime( $pack->{DocumentInformation}->{Expiration_Date}, '%Y%m%d', "%m/%d/%y" );
	my $orgdate = convert_datetime( $pack->{PayoffQuote}->{OriginationDate},         "%Y%m%d", "%m/%d/%y" );

	my $ldate      = $pack->{DocumentInformation}->{LetterDate};
	my $letterdate = ($ldate) ? convert_datetime( $ldate, "%Y%m%d", "%m/%d/%y" ) : $tp->strftime("%m/%d/%y");
	my $acctno     = $pack->{LoanInformation}->{ACCOUNT_NUMBER};
	my $rate       = sprintf( "%.5f", $pack->{PayoffQuote}->{INTEREST_RATE_CURRENT} );
	my $amt =
		$pack->{LoanInformation}->{BALANCE_PRINCIPAL_ORIGINAL}
		? currency_fmt( $pack->{LoanInformation}->{BALANCE_PRINCIPAL_ORIGINAL} )
		: '0.00';

	$x = 12.7;
	$y = $y2;
	my $x2 = 15.5;
	put 'Loan Number: ', $x, $y, $font10;
	put $acctno, $x2, $y, $font10, 'R', 5;
	$y += 0.4;
	put 'Issue Date: ', $x, $y, $font10;
	put $letterdate, $x2, $y, $font10, 'R', 5;
	$y += 0.4;
	put 'Payoff Good Through: ', $x, $y, $fontb10;
	put $expdate, $x2, $y, $font10, 'R', 5;
	$y += 0.4;
	put 'Interest Rate: ', $x, $y, $font10;
	put $rate. '%', $x2, $y, $font10, 'R', 5;
	$y += 0.4;
	put 'Orig. Ln Date: ', $x, $y, $font10;
	put $orgdate, $x2, $y, $font10, 'R', 5;
	$y += 0.4;
	put 'Orig. Ln Amt: ', $x, $y, $font10;
	put '$' . $amt, $x2, $y, $font10, 'R', 5;    # amt in currency format?
	$y += 0.4;

	return $y;
}

sub print_stmt_section {
	my ( $pack, $constmap, $x, $y, $rtnaddr ) = @_;

	$x = max( $x, 1.905 );
	$y = 10.16;
	my $x2 = 12;
	put "FHA Payoff Statement Form", $x, $y, $fontb14;
	$y += 1.4;
	put "Requested By:", $x, $y, $fontb10;
	my $sentlines = get_stmt_send_to_lines($pack);
	list $sentlines, $x, $y + 0.4, $font10, 0.4;

	my $fullname = $pack->{PrivateLabel}->{FullName};
	#my $slsaddrs = get_return_address($constmap, $fullname);
	put "Mortgage Servicer:", $x2, $y, $fontb10;
	list $rtnaddr, $x2, $y + 0.4, $font10, 0.4;

	return $y + 0.5;
}

sub print_loan_info {
	my ( $pack, $x, $y ) = @_;

	$x = max( $x, 1.905 );
	my $expdate = convert_datetime( $pack->{DocumentInformation}->{Expiration_Date}, '%Y%m%d', "%m/%d/%y" );

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
	my $duedate = convert_datetime( $pack->{LoanInformation}->{DATE_NEXT_DUE}, "%Y%m%d", "%m/%d/%Y" );
	put $duedate, 7, $y, $font10;

	$y += 1;
	my $msg =
"THIS STATEMENT REFLECTS THE TOTAL AMOUNT DUE UNDER THE TERMS OF THE NOTE/SECURITY INSTRUMENT THROUGH THE CLOSING DATE WHICH IS "
		. $expdate;
	$msg .=
" or the date the loan is transferred to a new servicer. If this obligation is not paid in full by this date, then you should request an updated payoff amount before closing.";
	my $wrap_txt = wrap $msg, $font10, 0.4, 'L', 19.05;
	emit_wrap $wrap_txt, $x, $y;

	my $due =
		$pack->{LoanInformation}->{TotalDueMinusUnappliedFundsAmount}
		? currency_fmt( $pack->{LoanInformation}->{TotalDueMinusUnappliedFundsAmount} )
		: '0.00';
	$y += 0.4 * 3 + 0.8;
	put 'Total Amount Due:', $x, $y, $fontb10;
	put '$' . $due, 7, $y, $fontb10;

	return $y + 0.5;
}

sub print_table {
	my ( $pack, $x, $y ) = @_;

	my $x2 = max( $x, 16.75 );
	$y = max( $y, 5.65 );
	my $delta = 0.7615;
	my $r     = 4;

	my $amt = currency_fmt( $pack->{PayoffQuote}->{BALANCE_PRINCIPAL_CURRENT} );
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	my $tp      = Time::Piece->new();
	my $curdate = $tp->strftime("%m/%d/%Y");
	my $date =
		$pack->{DocumentInformation}->{Int_Calc_to_Date}
		? convert_datetime( $pack->{DocumentInformation}->{Int_Calc_to_Date}, "%Y%m%d", "%m/%d/%Y" )
		: $curdate;
	put $date, 4.6, $y, $font10;
	$amt =
		$pack->{DocumentInformation}->{Interest_Charge}
		? currency_fmt( $pack->{DocumentInformation}->{Interest_Charge} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$amt =
		( $pack->{LoanInformation}->{EscrowAdvancesAmount} )
		? currency_fmt( $pack->{LoanInformation}->{EscrowAdvancesAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt = $pack->{PayoffQuote}->{UnpaidLateCharge} ? currency_fmt( $pack->{PayoffQuote}->{UnpaidLateCharge} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{PayoffQuote}->{PrepaymentPenaltyFeeAmount}
		? currency_fmt( $pack->{PayoffQuote}->{PrepaymentPenaltyFeeAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{DocumentInformation}->{Statement_nbsFee}
		? currency_fmt( $pack->{DocumentInformation}->{Statement_nbsFee} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{LoanInformation}->{CurrentDeferredPrincipalBalanceAmount}
		? currency_fmt( $pack->{LoanInformation}->{CurrentDeferredPrincipalBalanceAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		( $pack->{LoanInformation}->{CurrentDeferredInterestBalanceAmount} )
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
	$amt = $pack->{PayoffQuote}->{PRAAmount} ? currency_fmt( $pack->{PayoffQuote}->{PRAAmount} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt = $pack->{PayoffQuote}->{Option_Ins_Due} ? currency_fmt( $pack->{PayoffQuote}->{Option_Ins_Due} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt = $pack->{PayoffQuote}->{Recording_Fees} ? currency_fmt( $pack->{PayoffQuote}->{Recording_Fees} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt = $pack->{PayoffQuote}->{Release_Prep_Fee} ? currency_fmt( $pack->{PayoffQuote}->{Release_Prep_Fee} ) : '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{PayoffQuote}->{CorporateAdvanceTotalAmount}
		? currency_fmt( $pack->{PayoffQuote}->{CorporateAdvanceTotalAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;
	$amt =
		$pack->{PayoffQuote}->{UnappliedFundsAmount}
		? currency_fmt( $pack->{PayoffQuote}->{UnappliedFundsAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$date =
		$pack->{PayoffQuote}->{FHA_PMI_Calc_To_Date}
		? convert_datetime( $pack->{PayoffQuote}->{FHA_PMI_Calc_To_Date}, "%Y%m%d", "%m/%d/%Y" )
		: $curdate;
	$amt =
		$pack->{PayoffQuote}->{FHA_Or_PMI_Amount} ? currency_fmt( $pack->{PayoffQuote}->{FHA_Or_PMI_Amount} ) : '0.00';
	put $date, 9, $y, $font10;
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$date =
		$pack->{DocumentInformation}->{Int_Calc_to_Date}
		? convert_datetime( $pack->{DocumentInformation}->{Int_Calc_to_Date}, "%Y%m%d", "%m/%d/%Y" )
		: $curdate;
	$amt =
		$pack->{PayoffQuote}->{Anticipated_Escrow_Disb_TaxIns}
		? currency_fmt( $pack->{PayoffQuote}->{Anticipated_Escrow_Disb_TaxIns} )
		: '0.00';
	put $date, 8.4, $y, $font10;
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta;

	$amt =
		$pack->{PayoffQuote}->{Escrow_Funds_Avail_Cover_Anticipated_Disb}
		? currency_fmt( $pack->{PayoffQuote}->{Escrow_Funds_Avail_Cover_Anticipated_Disb} )
		: '0.00';
	put '$' . $amt, $x2, $y, $font10, 'R', $r;
	$y += $delta + 0.06;
	$amt =
		$pack->{LoanInformation}->{TotalDueMinusUnappliedFundsAmount}
		? currency_fmt( $pack->{LoanInformation}->{TotalDueMinusUnappliedFundsAmount} )
		: '0.00';
	put '$' . $amt, $x2, $y, $fontb12, 'R', $r;
	return;
}

sub get_undertable_txt {
	my ( $entity, $pack ) = @_;

	my $fullname = $pack->{PrivateLabel}->{FullName};

	my $txt =
"Please be advised the payoff amount specified above is valid through the stated expiration date or the date the loan "
		. "is transferred to a new servicer. If you have been notified that $fullname intends to transfer your loan, you must ensure "
		. "$fullname receives your payoff prior to the date of transfer arrangements with the new servicer. However, these are subject to "
		. "final verification upon receipt of payoff funds by $fullname, unless prohibited by applicable state law, including but not limited "
		. "to Wisconsin. We reserve the right to adjust these figures and refuse any funds that are insufficient to pay the loan in full for "
		. "any reason, unless prohibited by applicable state law including but not limited to Wisconsin. Normal transactions and escrow "
		. "disbursements will continue to the date of payoff, which may affect the balance due.";

	return ( int($entity) != 0 ) ? $txt : '';
}

1;
