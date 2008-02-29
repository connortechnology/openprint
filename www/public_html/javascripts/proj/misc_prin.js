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

