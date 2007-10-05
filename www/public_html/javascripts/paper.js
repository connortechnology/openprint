function body_onLoad() {
	var form = getFormObj('f1');
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, '', '' ) );
} // end function body_onLoad();

function get_parameters( form, id, selected ) {

    var parameters = new Array ( selected, id );

	if ( form.elements['Name'+id] ) 
		parameters.push( 'Name', get_ddm_value( form.elements['Name'+id] ) ); 
	if ( form.elements['Finish'+id] ) 
		parameters.push( 'Finish', get_ddm_value( form.elements['Finish'+id] ) );
	if ( form.elements['Colour'+id] ) 
		parameters.push( 'Colour', get_ddm_value( form.elements['Colour'+id] ) );
	if ( form.elements['Weight'+id] ) 
		parameters.push( 'Weight', get_ddm_value( form.elements['Weight'+id] ) );
	return parameters;
} // end function get_parameters( form )

function Name_onChange( element, id ) {
	var form = element.form;
	form.elements['Name'+id].disabled = true;
	form.elements['Finish'+id].disabled = true;
	form.elements['Colour'+id].disabled = true;
	form.elements['Weight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, 'Name') );

} // end function Name_onChange()

function Finish_onChange( element, id ) {
	var form = element.form;
	form.elements['Name'+id].disabled = true;
	form.elements['Finish'+id].disabled = true;
	form.elements['Colour'+id].disabled = true;
	form.elements['Weight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, 'Finish') );
} // end function Finish_onChange();

function Colour_onChange( element, id ) {
	var form = element.form;
	form.elements['Name'+id].disabled = true;
	form.elements['Finish'+id].disabled = true;
	form.elements['Colour'+id].disabled = true;
	form.elements['Weight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id,'Colour') );

} // end function Colour_onChange();

function Weight_onChange( element, id ) {
	var form = element.form;
	form.elements['Name'+id].disabled = true;
	form.elements['Finish'+id].disabled = true;
	form.elements['Colour'+id].disabled = true;
	form.elements['Weight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, 'Weight') );
} // end function Weight_onChange();

function fill_drop_down( results ) {
	var form = getFormObj('f1');
	var id;

    var BrandOptions = new Array();
    BrandOptions[BrandOptions.length] = create_option( '', 'Please select one' );
    var FinishOptions = new Array();
    FinishOptions[FinishOptions.length] = create_option( '', 'Please select one' );
    var ColourOptions = new Array();
    ColourOptions[ColourOptions.length] = create_option( '', 'Please select one' );
    var WeightOptions = new Array();
    WeightOptions[WeightOptions.length] = create_option( '', 'Please select one' );
    var SheetSizeOptions = new Array();
    SheetSizeOptions[SheetSizeOptions.length] = create_option( '', 'Please select one' );

    var aOptionPairs = results.split('|');
    for ( var i = 0; i < aOptionPairs.length; i++ ){
        if ( aOptionPairs[i].indexOf('~') != -1 ) {
            var aOptions = aOptionPairs[i].split('~');
            switch ( aOptions[0] ) {
                case 'Brand':
                    BrandOptions[BrandOptions.length] = create_option( aOptions[1], aOptions[2] );
                    break;
                case 'Finish':
                    FinishOptions[FinishOptions.length] = create_option( aOptions[1], aOptions[2] );
                    break;
                case 'Colour':
                    ColourOptions[ColourOptions.length] = create_option( aOptions[1], aOptions[2] );
                    break;
                case 'Weight':
                    WeightOptions[WeightOptions.length] = create_option( aOptions[1], aOptions[2] );
                    break;
                case 'SheetSize':
                    SheetSizeOptions[SheetSizeOptions.length] = create_option( aOptions[1], aOptions[2] );
                    break;
				case 'id':
					id = aOptions[1];
					break;
            } // end switch
        } // end if
    } // end for
	if ( form.elements['Name'+id] ) {
		if ( BrandOptions.length > 1 ) {
			var selectedValue = get_ddm_value( form.elements['Name'+id] );
			fill_ddm( form.elements['Name'+id], BrandOptions, form.elements['Name'+id].onchange );
			
			if ( BrandOptions.length == 2 ) {
				ddm_select_by_index( form.elements['Name'+id], 1 );
			} else {
				ddm_select_by_value( form.elements['Name'+id], selectedValue, 0 );
			} // end if
		} // end if
		form.elements['Name'+id].disabled = false;
	} // end if

	if ( form.elements['Finish'+id] ) {
		if ( FinishOptions.length > 1 ) {
			var selectedValue = get_ddm_value( form.elements['Finish'+id] );
			fill_ddm( form.elements['Finish'+id], FinishOptions, form.elements['Finish'+id].onchange );
			if ( FinishOptions.length == 2 ) {
				ddm_select_by_index( form.elements['Finish'+id], 1 );
			} else {
				ddm_select_by_value( form.elements['Finish'+id], selectedValue, 0 );
			} // end if
		} // end if
		form.elements['Finish'+id].disabled = false;
	} // end if

	if ( form.elements['Colour'+id] ) {
		if ( ColourOptions.length > 1 ) {
			var selectedValue = get_ddm_value( form.elements['Colour'+id] );
			fill_ddm( form.elements['Colour'+id], ColourOptions, form.elements['Colour'+id].onchange );
			if ( ColourOptions.length == 2 ) {
				ddm_select_by_index( form.elements['Colour'+id], 1 );
			} else {
				ddm_select_by_value( form.elements['Colour'+id], selectedValue, 0 );
			} // end if
		} // end if
		form.elements['Colour'+id].disabled = false;
	} // end if

	if ( form.elements['Weight'+id] ) {
		if ( WeightOptions.length > 1 ) {
			var selectedValue = get_ddm_value( form.elements['Weight'+id] );
			fill_ddm( form.elements['Weight'+id], WeightOptions, form.elements['Weight'+id].onchange );
			if ( WeightOptions.length == 2 ) {
				ddm_select_by_index( form.elements['Weight'+id], 1 );
			} else {
				ddm_select_by_value( form.elements['Weight'+id], selectedValue, 0 );
			} // end if
		} // end if
		form.elements['Weight'+id].disabled = false;
	} // end if

} // end function fill_drop_down( results ) {

function cbFillDropDowns( results ) {
	fill_drop_down( results );
	if ( typeof calc == 'function' ) 
		calc('f1');
} // end function cbFillDropDowns( results )
