function get_parameters( form, id, selected ) {

    var parameters = new Array ( 'Selected', selected, 'ID', id );

	if ( form.elements['Owner'+id] ) 
		parameters.push( 'Owner', get_ddm_value( form.elements['Owner'+id] ) ); 
	if ( form.elements['Manufacturer'+id] ) 
		parameters.push( 'Manufacturer', get_ddm_value( form.elements['Manufacturer'+id] ) ); 
	if ( form.elements['Name'+id] ) 
		parameters.push( 'Name', get_ddm_value( form.elements['Name'+id] ) ); 
	if ( form.elements['ddmName'+id] ) 
		parameters.push( 'name_id', get_ddm_value( form.elements['ddmName'+id] ) ); 

	if ( form.elements['Finish'+id] ) 
		parameters.push( 'Finish', get_ddm_value( form.elements['Finish'+id] ) );
	if ( form.elements['ddmFinish'+id] ) 
		parameters.push( 'finish_id', get_ddm_value( form.elements['ddmFinish'+id] ) );

	if ( form.elements['Colour'+id] ) 
		parameters.push( 'Colour', get_ddm_value( form.elements['Colour'+id] ) );
	if ( form.elements['ddmColour'+id] ) 
		parameters.push( 'colour_id', get_ddm_value( form.elements['ddmColour'+id] ) );

	if ( form.elements['Weight'+id] ) 
		parameters.push( 'Weight', get_ddm_value( form.elements['Weight'+id] ) );
	if ( form.elements['ddmWeight'+id] ) 
		parameters.push( 'weight_id', get_ddm_value( form.elements['ddmWeight'+id] ) );

	return parameters;
} // end function get_parameters( form )

function filter_onChange( element, id, selected ) {
	var form = element.form;

	if ( form.elements['Manufacturer'+id] ) {
		form.elements['Manufacturer'+id].disabled = true;
	} // end if

	if ( form.elements['Name'+id] ) {
		form.elements['Name'+id].disabled = true;
	} else if ( form.elements['ddmName'+id] ) {
		form.elements['ddmName'+id].disabled = true;
	} // end if
	if ( form.elements['Finish'+id] ) {
		form.elements['Finish'+id].disabled = true;
	} else if ( form.elements['ddmFinish'+id] ) {
		form.elements['ddmFinish'+id].disabled = true;
	} // end if
	if ( form.elements['Colour'+id] ) {
		form.elements['Colour'+id].disabled = true;
	} else if ( form.elements['ddmColour'+id] ) {
		form.elements['ddmColour'+id].disabled = true;
	} // end if
	if ( form.elements['Weight'+id] ) {
		form.elements['Weight'+id].disabled = true;
	} else if ( form.elements['ddmWeight'+id] ) {
		form.elements['ddmWeight'+id].disabled = true;
	} // end if

	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, selected ) );

} // end function Name_onChange()
function Manufacturer_onChange( element, id ) {
	filter_onChange( element, id, 'Manufacturer' );
} // end function Name_onChange()

function Name_onChange( element, id ) {
	filter_onChange( element, id, 'Name' );
} // end function Name_onChange()

function Finish_onChange( element, id ) {
	filter_onChange( element, id, 'Finish' );
} // end function Finish_onChange();

function Colour_onChange( element, id ) {
	filter_onChange( element, id, 'Colour' );
} // end function Colour_onChange();

function Weight_onChange( element, id ) {
	filter_onChange( element, id, 'Weight' );
} // end function Weight_onChange();

function fill_drop_down( results ) {
	var form = getFormObj('f1');
	var id;

    var aOptionPairs = results.split('|');

	var Options = new Array();
    for ( var i = 0; i < aOptionPairs.length; i++ ){
        if ( aOptionPairs[i].indexOf('~') != -1 ) {
            var aOptions = aOptionPairs[i].split('~');
            switch ( aOptions[0] ) {
				case 'id':
					id = aOptions[1];
					break;
				default:
					if ( ! Options[aOptions[0]] ) {
						Options[aOptions[0]] = new Array();
						Options[aOptions[0]][Options[aOptions[0]].length] = create_option( '', 'Please select one' );
					} // end if
					Options[aOptions[0]][Options[aOptions[0]].length] = create_option( aOptions[1], aOptions[2] );
					break;
            } // end switch
        } // end if
    } // end for

	var fields = new Array ( 'Owner','Manufacturer','Name','Finish','Colour','Weight' );
	for ( var i = 0; i < fields.length; i+=1 ) {
		var field = fields[i];
		if ( ! form.elements[field+id] ) continue;

		if ( Options[field] && ( Options[field].length > 1 ) ) {
			var selectedValue = get_ddm_value( form.elements[field+id] );
			fill_ddm( form.elements[field+id], Options[field], form.elements[field+id].onchange );
			
			if ( Options[field].length == 2 ) {
				ddm_select_by_index( form.elements[field+id], 1 );
			} else {
				ddm_select_by_value( form.elements[field+id], selectedValue, 0 );
			} // end if
		} // end if
		form.elements[field+id].disabled = false;
	} // end for each field in fields

} // end function fill_drop_down( results ) {

function cbFillDropDowns( results ) {
	fill_drop_down( results );
	if ( typeof calc == 'function' ) 
		calc('f1');
} // end function cbFillDropDowns( results )
