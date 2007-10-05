var debug = true;

function calc( formName ){
	if ( gettingNewPrice ) {
		setTimeout("calc('f1');", 1000 );
		return;
	} // end if

	gettingNewPrice = true;

	var form = getFormObj( formName );
	var arguments = new Array();

	for ( var index = 0; index < form.elements.length ; index += 1 ) {
        if ( form.elements[index].type == 'radio' ) {
            if ( form.elements[index].checked == true ) {
                arguments[arguments.length] = form.elements[index].name;
                arguments[arguments.length] = form.elements[index].value;
            } // end if
        } else if ( form.elements[index].type == 'checkbox' ) {
            if ( form.elements[index].checked == true ) {
                arguments[arguments.length] = form.elements[index].name;
                arguments[arguments.length] = form.elements[index].value;
            } // end if
        } else if ( form.elements[index].type == 'select-one' ) {
            if ( form.elements[index].selectedIndex != -1 ) {
                arguments[arguments.length] = form.elements[index].name;
                arguments[arguments.length] = form.elements[index].options[form.elements[index].selectedIndex].value;
            } // end if
        } else {
			if ( form.elements[index].name == 'hdnBreakdown' ) {
			} else {
				arguments[arguments.length] = form.elements[index].name;
				arguments[arguments.length] = form.elements[index].value;
			} // end if
		} // end if
	} // end for

	jsrsExecute( '/jsrs.htm', cbFillResults, 'openprint::print_gluing::external_calc', arguments );

} // end calc()

function cbFillResults( results ) {
    var pairs = results.split('|');
    var form = getFormObj('f1');

    for ( var i = 0; i < pairs.length; i += 1 ){
        if ( pairs[i].indexOf('~') != -1 ) {
            var data = pairs[i].split('~');

            if ( form.elements[data[0]] )
                form.elements[data[0]].value = data[1];
        } // end if
    } // end for
	gettingNewPrice = false;
} // end function cbFillResults

function validate_data( formName ) {
	var form = getFormObj( formName );
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
