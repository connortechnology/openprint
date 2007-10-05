package openprint::paper_purchase_order;

use MIME::QuotedPrint;
use Mail::Sendmail;
use Email::Valid;
use Date::Calc qw(Add_Delta_Days);

use strict;

require sql;
require configuration;
require openprint::Currency;
require openprint::customer;
require openprint::paper;

sub delete {
	my ( $log, $dbh, $order_id ) = @_;
	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( $log, $dbh, 'DELETE FROM Paper_Purchase_Order_Contents WHERE PaperPurchaseOrder_Id=?',$order_id);
	sql::execute( $log, $dbh, 'DELETE FROM Paper_Purchase_Orders WHERE Id =?', $order_id );
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub delete

sub history {
	my ( $r, $log, $dbh, $variable ) = @_;

	# FIXME
	if ( ! $openprint::session{'company_id'} ) {
		return;
	} # end if

	ssi::get_start_end_dates( $log, $dbh, $variable,
			$r->param('ddmStartYear'),
			$r->param('ddmStartMonth'),
			$r->param('ddmStartDay'),
			$r->param('ddmEndYear'),
			$r->param('ddmEndMonth'),
			$r->param('ddmEndDay') );


	$_ = "SELECT Id, PONum, to_char(Created, 'MM/DD/YYYY'), SupplierTo, Status, Total\n".
		"FROM Paper_Purchase_Orders WHERE date(Created_on) BETWEEN date('$$variable{'StartDate'}') AND date('$$variable{'EndDate'}')\n";
	$_ .= "ORDER BY Id DESC\n";

	@{$$variable{'PURCHASEORDERS'}} = sql::execute( $log, $dbh, $_ );

} # end sub history

sub display {
	my ( $r, $log, $dbh, $variable ) = @_;

	my $error = '';
	my $ppo_index = $r->param('PaperPurchaseOrderIndex');
	if ( $r->param('btnFunction') eq 'DeletePaper' ) {
		my $paper_index = $r->param('PaperIndex');
		if ( $paper_index ) {
			sql::execute( $log, $dbh, 'DELETE FROM Paper_Purchase_Order_Contents WHERE PaperPurchaseOrder_Id=? AND Paper_Id=?', $ppo_index, $paper_index );
		} # end if
	} elsif ( $r->param('btnFunction') eq 'Delete' ) {
		openprint::paper_purchase_order::delete( $log, $dbh, $ppo_index );
		$$variable{'Redirect'} = '/employee/inventory/purchase_orders.html';
		return;
	} elsif ( $r->param('btnFunction') eq 'Send' ) {
		sql::update( $log, $dbh, 'Paper_Purchase_Orders', "Id=$ppo_index",
				'Status',				'Sent',
				);
	} elsif ( $r->param('btnFunction') eq 'Received' ) {
		my ( $status ) = sql::execute( $log, $dbh, 'SELECT Status FROM Paper_Purchase_Orders WHERE Id=?', $ppo_index );
		if ( $status eq 'Sent' ) {
			# Only do this once
			sql::update( $log, $dbh, 'Paper_Purchase_Orders', "Id=$ppo_index",
					'WarehouseLocation',	$r->param('WarehouseLocation'),
					'Received',				join('-', $r->param('ddmReceivedDateYear'), $r->param('ddmReceivedDateMonth'), $r->param('ddmReceivedDateDay') ),
					'Status',				'Received',
					);

			my @papers = sql::execute( $log, $dbh, 'SELECT Paper_Id, Quantity, (SELECT InStock FROM Paper_Inventory WHERE Paper_Inventory.Paper_Id=Paper_Purchase_Order_Contents.Paper_Id AND UpdateTime = (SELECT MAX(UpdateTime) FROM Paper_Inventory WHERE Paper_Inventory.Paper_Id=Paper_Purchase_Order_Contents.Paper_Id)) FROM Paper_Purchase_Order_Contents WHERE PaperPurchaseOrder_Id=?', $ppo_index );
			while ( @papers ) {
				my ( $paper_index, $quantity, $instock ) = splice @papers, 0, 3;
	
				sql::insert( $log, $dbh, 'Paper_Inventory', 
						'Paper_Id',	$paper_index,
						'User_Id',	$openprint::session{'user_id'}, 
						'PO_Id',		$ppo_index,
						'Delta',		$quantity,
						'InStock',		$instock + $quantity,
						'UpdateTime',	'NOW()',
						'Comment',		'Received Paper',
						);
			} # end while
		} # end if
	} elsif ( $r->param('btnFunction') eq 'Save' ) {
		if ( ! $ppo_index ) {
			( $ppo_index ) = sql::execute( $log, $dbh, "SELECT nextval('PaperPurchaseOrderIndex_seq')" );
			$error .= sql::insert( $log, $dbh, 'Paper_Purchase_Orders', 
					'id',			$ppo_index,
					'user_id',		$openprint::session{'user_id'},
					'SupplierTo',		$r->param('To'),	
					'SupplierAttn',		$r->param('Attn'),
					'SupplierFrom',		$r->param('From'),
					'SupplierFaxNo',	$r->param('FaxNo'),
					'PONum',			$r->param('PONum') ? $r->param('PONum') : undef,
					'ExpectedArrival',	'NOW()',
					'GST',				'0.00',
					'Total',			'0.00',
					'Status',			'Incomplete',
					'updated_on',		'NOW()',
					'currency_id',	$r->param('Currency') ? $r->param('Currency') : undef,
					);
		} else {
			$error .= sql::update( $log, $dbh, 'Paper_Purchase_Orders', "Index=$ppo_index",
					'UserIndex',		$openprint::session{'user_id'},
					'SupplierTo',		$r->param('To'),	
					'SupplierAttn',		$r->param('Attn'),
					'SupplierFrom',		$r->param('From'),
					'SupplierFaxNo',	$r->param('FaxNo'),
					'ExpectedArrival',	'NOW()',
					'PONum',			$r->param('PONum') ? $r->param('PONum') : undef,
					'GST',				'0.00',
					'Total',			'0.00',
					'Status',			'Incomplete',
					'LastModified',		'NOW()',
					'CurrencyIndex',	$r->param('Currency') ? $r->param('Currency') : undef,
					);
		} # end if $ppoindex

		if ( $r->param('PaperBrand') ) {
# See if we can get a single paper out of it
			my @papers = openprint::paper::get_paper( $log, $dbh,  
						$r->param('PaperBrand'),
						$r->param('PaperFinish'),
						$r->param('PaperColour'),
						$r->param('PaperWeight'),
						$r->param('PaperSheetSize'),
						);
			if ( @papers != 1 ) {
				$error .= "Cannot determine a unique paper.";
			} else {
				sql::execute( $log, $dbh, 'DELETE FROM Paper_Purchase_Order_Contents WHERE PaperPurchaseOrder_Id=? AND Paper_Id=?', $ppo_index, $papers[0] );
# Now insert Papers
				$error .= sql::insert( $log, $dbh, 'Paper_Purchase_Order_Contents',
						'PaperPurchaseOrder_Id', $ppo_index,
						'Paper_Id',				@papers,
						'Quantity',					$r->param('PaperQuantity'),
						'Description',				$r->param('PaperDescription'),
						'Price',					$r->param('PaperPrice'),
						'MWeight',					$r->param('PaperMWeight'),
						'Width',					$r->param('PaperWidth'),
						'Height',					$r->param('PaperHeight'),
						);
			} # end if
		} # end if insert paper

	} # end if btnFunction == Save

	# Update it on every refresh... a bit ugly...
	sql::execute( $log, $dbh, 'UPDATE Paper_Purchase_Orders SET Total=(SELECT SUM((Price*strMWeight::numeric) * Quantity/1000) FROM Paper_Purchase_Order_Contents, Paper WHERE lngIndex=Paper_Id AND PaperPurchaseOrder_Id=?) WHERE Index=?', $ppo_index, $ppo_index );
	sql::execute( $log, $dbh, 'UPDATE Paper_Purchase_Orders SET GST=Total*0.07 WHERE Id=?', $ppo_index );

	if ( $error ne '' ) {
		$$variable{'Error'} = $error;
		$$variable{'PaperBrand'} = $r->param('PaperBrand');
		$$variable{'PaperFinish'} = $r->param('PaperFinish');
		$$variable{'PaperColour'} = $r->param('PaperColour');
		$$variable{'PaperWeight'} = $r->param('PaperWeight');
		$$variable{'PaperSheetSize'} = $r->param('PaperSheetSize');
		$$variable{'PaperPrice'} = $r->param('PaperPrice');
		$$variable{'PaperQuantity'} = $r->param('PaperQuantity');
		$$variable{'PaperDescription'} = $r->param('PaperDescription');
	} # end if

	if ( $ppo_index ) {
		@$variable{'To',
			'Attn',
			'From',
			'FaxNo',
			'PONum',
			'GST',
			'SubTotal',
			'Total',
			'Status',
			'Date',
			'ReceivedDate',
			'WarehouseLocation',
			'CurrencyIndex',
} = sql::execute( $log, $dbh, "SELECT SupplierTo, SupplierAttn, SupplierFrom, SupplierFaxNo, PONum, ROUND(GST,2), ROUND(Total,2), ROUND(GST+Total,2), Status, to_char( now(),'Day Month DD, YYYY'), to_char( Received,'Day Month DD, YYYY'), WarehouseLocation, CurrencyIndex FROM Paper_Purchase_Orders WHERE Id=$ppo_index" );
		$$variable{'PPOIndex'} = $ppo_index;

		$_ = "SELECT paper_id, Description, strName, strFinish, strWeight, Width || 'x' || Height,
			Price, ROUND(Price * strMWeight::numeric,2), Quantity, ROUND((Price*strMWeight::numeric) * Quantity/1000,2) FROM Paper_Purchase_Order_Contents, Paper WHERE PaperPurchaseOrder_id=$ppo_index AND id = paper_id";
		@{$$variable{'Contents'}} = sql::execute( $log, $dbh, $_ );
		$$variable{'PaperPurchaseOrderIndex'} = $ppo_index;
		if ( $$variable{'CurrencyIndex'} ) {
			my $Currency = new openprint::Currency( $$variable{'CurrencyIndex'} );
	
			@$variable{'CurrencyName','CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
		} # end if
	} else {
		$$variable{'Status'} = 'Incomplete';
	} # end if

	$$variable{'CurrencyOptions'} = ssi::fill_drop_down( $log, $dbh, "SELECT id, Name FROM Currencies ORDER BY lower(Name)", $$variable{'CurrencyIndex'} );

} # end sub display

sub update_status {
	my ( $r, $log, $dbh, $ppo_index ) = @_;

} # end sub update_status

sub load_paper {
	my ( $r, $log, $dbh, $variable, $ppo_index, $paper_index ) = @_;
	my %results;
	$_ = "SELECT paper_id, Description, Name, Finish, Calliper, Width || 'x' || Height, MWeight, Width, Height,
		Quantity, Price FROM Paper_Purchase_Order_Contents, Paper WHERE PaperPurchaseOrder_id=$ppo_index AND paper_id=$paper_index AND Paper_Purchase_Order_Contents.paper_id=id";
	@results{'PaperIndex','PaperDescription','PaperBrand','PaperFinish','PaperWeight','PaperSheetSize','PaperMWeight', 'PaperWidth','PaperHeight','PaperQuantity','PaperPrice'} = sql::execute( $log, $dbh, $_ );
	return join( '|', map { $_ . '~' . $results{$_} } keys %results );
} # end sub load_paper
1;
__END__
