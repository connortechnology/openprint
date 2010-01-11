function calc( formName ){
	if ( gettingNewPrice ) {
		if ( timeout )
			clearTimeout( timeout );
		timeout = setTimeout( "calc('" + formName + "');", 1000 );
		return;
	} // end if
	timeout = null;
    gettingNewPrice = true;
	var form = getFormObj(formName);
	var h = form.serialize(true);
	h.service_type = 'Stitching';
	new Ajax.Request( '/main/project/_calc.json', { method: 'post', parameters: h, evalScripts: true } );
} // end calc_packaging()

function validate_data(formName) {
	var form = getFormObj(formName);
	var text = '';

	if ( text ) {
		text = "Your form is incomplete !\n\nIf you would like to continue please click OK, otherwise click Cancel and complete the following fields: \n\n" + text;
		if ( ! confirm(text)) {
			// if the click Cancel on the pop-up, then return false to cancel the submit
			return false;
		} // end if
	} // end if
	return true;
} // end function
