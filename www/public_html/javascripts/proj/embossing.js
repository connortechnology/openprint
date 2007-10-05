var debug = true;
var die_debug = true;

var breakdown = '';

function calc( formName ){
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
        } else {
			if ( form.elements[index].name == 'hdnBreakdown' ) {
			} else {
				arguments[arguments.length] = form.elements[index].name;
				arguments[arguments.length] = form.elements[index].value;
			} // end if
		} // end if
    } // end for

    jsrsExecute( '/jsrs.htm', cbFillResults, 'openprint::print_embossing::external_calc', arguments );
} // end calc_packaging()

function cbFillResults( results ) {
    var pairs = results.split('|');
    var form = getFormObj('f1');

    for ( var i = 0; i < pairs.length; i += 1 ){
        if ( pairs[i].indexOf('~') != -1 ) {
            var data = pairs[i].split('~');

            if ( form.elements[data[0]] ) {
//alert( form.elements[data[0]].type );
				if ( form.elements[data[0]].type == 'select-one' ) {
					var selected_option = '';
					var option_pairs = data[1].split(':');
					var options = new Array();
					for ( var option_index = 0; option_index < option_pairs.length; option_index += 1 ) {
						var option = option_pairs[option_index].split(';');
						options[options.length] = create_option( option[0], option[1] );
						if ( option[2] == 'selected' ) {
							selected_option = option[0];
						} // end if
					} // end for
					clear_ddm( form.elements[data[0]] );
					fill_ddm( form.elements[data[0]], options );
					ddm_select_by_value( form.elements[data[0]], selected_option );
				} else {
					form.elements[data[0]].value = data[1];
				} // end if
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
	} // end if */
	return true;
} // end function
