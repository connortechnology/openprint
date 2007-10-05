
function calc( formName ){
	gettingNewPrice = true;
	jsrsExecute( '/jsrs.htm', cbFillResults, 'openprint::service::external_calc', get_variables( formName, 'Skids') );

} // end calc

function cbFillResults( results ) {
    var pairs = results.split('|');
    var form = getFormObj('f1');

    for ( var i = 0; i < pairs.length; i += 1 ){
        if ( pairs[i].indexOf('~') != -1 ) {
            var data = pairs[i].split('~');

			 if ( data[0] == 'txtItemsPerPackage' && form.chkOverrideItemsPerPackage && form.chkOverrideItemsPerPackage.checked ) {
             } else if ( form.elements[data[0]] ) {
			 	form.elements[data[0]].value = data[1];
			 } // end if
        } // end if
    } // end for
	gettingNewPrice = false;
} // end function cbFillResults

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
