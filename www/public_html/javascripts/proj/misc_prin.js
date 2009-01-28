// The following are GLOBAL variables
var gettingNewPrice = false;
var submitForm = false;

var breakdownWin = new Array();

function show_breakdown( index ) {
	if ( gettingNewPrice )
		return;
    if (breakdownWin[index] == null) {
		breakdownWin[index] = new Window({maximizable: false, resizable: false, hideEffect:Element.hide, showEffect:Element.show, destroyOnClose: false, className:'alphacube', width:500, height:420 } );
		breakdownWin[breakdownWin[index]] = index;

		// Set up a windows observer, check ou debug window to get messages
		myObserver = {
			onDestroy: function(eventName, win) {
				if ( win == breakdownWin[breakdownWin[win]] ) {
					breakdownWin[breakdownWin[win]] = null;
					breakdownWin[win] = null;

					win.getContent().hide;
					Windows.removeObserver(this);
				} // end if
			} // onDestroy
		} // myObserver
		Windows.addObserver(myObserver);
	} // end if
	breakdownWin[index].setContent( 'hdnBreakdown'+index, false, false );
	breakdownWin[index].showCenter();
} // end function show_breakdown

function submit_handler( formName ) {
	var form = getFormObj( formName );
	if ( ! form ) {
		return false;
	}

	if ( gettingNewPrice && ! confirm('The system is still calculating a price.  Click OK to continue saving, or Cancel to wait for the system') ) {
		return;
		
	} // end if
	var status = true;
	if ( typeof(validate_data) == 'function' ) {
		status = validate_data(formName);
	} // end nif

	if (status) {
		if ( window.name == 'popup' ) {
			var vars = Serialize( form );
			vars.unshift( 'openprint::print::view_services' );
			vars.unshift( '' ); //DIV
			jsrsExecute( '/jsrs.htm', cbWindowSaveClose, 'openprint::jsrs_handler::exec', vars );

		} else {
		form.submit();
		} // end if
	} // end if
	return status;

} // end function submit_form

function cbWindowSaveClose( results ) {
	window.close();
} 


function getFormObj( formName ) {
	var form = document.forms[formName];
	return form;
}

function do_decimals( number, precision ) {
	var a = number.toString();
	number = parseFloat( 1* a.replace(/[^\d\-\.]/g, '' ) );
	if ( precision == '' ) {
		precision = 2;
	} else {
		var a = precision.toString();
		precision = parseFloat( 1* a.replace(/\D/g, '' ) );
	} // end if
	var result1 = number * Math.pow(10, precision);
	var result2 = Math.round(result1);
	var result3 = result2 / Math.pow(10, precision);
	return pad_with_zeros(result3, precision);
} // end function do_decimals

function pad_with_zeros(rounded_value, decimal_places) {
	var value_string = rounded_value.toString();
	var decimal_location = value_string.indexOf(".");
	if (decimal_location == -1) {
		decimal_part_length = 0;
		value_string += decimal_places > 0 ? "." : "";
	} else {
		decimal_part_length = value_string.length - decimal_location - 1;
	} // end if
	var pad_total = decimal_places - decimal_part_length;
	if (pad_total > 0) {
		for (var counter = 1; counter <= pad_total; counter++) {
			value_string += "0";
		} // end for
	} // end if
	return value_string;
}

function inkColourObject( ID, inkType, PMS, Name ) {
	this.serviceId = ID;
	this.pmsNumber = PMS;
	this.name = Name;
	this.inkType = inkType;
} // end function


	function get_page_quantity(form) {
		var pageQty = 1;
		if ( form.elements['rdbPageQuantity'] ) {
			pageQty = get_rdb_value(form,'rdbPageQuantity');
		} else if ( form.elements['txtNameQuantity'] ) {
			pageQty = parseInt(1*form.txtNameQuantity.value);
		} // end if
		pageQty = pageQty > 0 ? pageQty : 1;
		return pageQty;
	} // end function

