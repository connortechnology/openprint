function calc( formName ){
	gettingNewPrice = true;
    var form = getFormObj(formName);
	var h = form.serialize(true);
	h.ServiceType = 'Packaging';
	new Ajax.Request( '/main/project/_calc.json', { method: 'post', parameters: h, evalScripts: true } );
} // end calc

function validate_data(formName) {
    var form = getFormObj(formName);
    var text = '';

    if ( ! ( 0 < parseFloat(form.txtItemsPerPackage.value) ) ) {
        text += "Please enter a valid quantity of items.\n";
    } // end if

    if ( text ) {
        text = "Your form is incomplete !\n\nIf you would like to continue please click OK, otherwise click Cancel and complete the following fields: \n\n" + text;
        if ( ! confirm(text)) {
            // if the click Cancel on the pop-up, then return false to cancel the submit
            return false;
        } // end if
    } // end if
    return true;
} // end function
