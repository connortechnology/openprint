function body_onLoad() {
	var form = getFormObj('f1');
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, '', '' ) );
} // end function body_onLoad();

function get_parameters( form, id, selected ) {

    var parameters = new Array ( selected, id );

	if ( form.elements['Manufacturer'+id] ) 
		parameters.push( 'manufacturer_id', get_ddm_value( form.elements['Manufacturer'+id] ) ); 

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

function Manufacturer_onChange( element, id ) {
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

	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, 'Manufacturer') );
} // end function Manufacturer_onChange

function Name_onChange( element, id ) {
	var form = element.form;
	form.elements['Name'+id].disabled = true;
	form.elements['Finish'+id].disabled = true;
	form.elements['Colour'+id].disabled = true;
	if ( form.elements['Weight'+id] ) form.elements['Weight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, 'Name') );

} // end function Name_onChange()

function Finish_onChange( element, id ) {
	var form = element.form;
	form.elements['Name'+id].disabled = true;
	form.elements['Finish'+id].disabled = true;
	form.elements['Colour'+id].disabled = true;
	if ( form.elements['Weight'+id] ) form.elements['Weight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, 'Finish') );
} // end function Finish_onChange();

function Colour_onChange( element, id ) {
	var form = element.form;
	form.elements['Name'+id].disabled = true;
	form.elements['Finish'+id].disabled = true;
	form.elements['Colour'+id].disabled = true;
	if ( form.elements['Weight'+id] ) form.elements['Weight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id,'Colour') );

} // end function Colour_onChange();

function Weight_onChange( element, id ) {
	var form = element.form;
	form.elements['Name'+id].disabled = true;
	form.elements['Finish'+id].disabled = true;
	form.elements['Colour'+id].disabled = true;
	if ( form.elements['Weight'+id] ) form.elements['Weight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, 'Weight') );
} // end function Weight_onChange();

function fill_drop_down( results ) {
	var form = getFormObj('f1');
	var id;

	var ManufacturerOptions = new Array();
	ManufacturerOptions[ManufacturerOptions.length] = create_option( '', 'Please select one' );
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
                case 'Manufacturer':
                    ManufacturerOptions[ManufacturerOptions.length] = create_option( aOptions[1], aOptions[2] );
                    break;
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

	var manufacturer_ddm;
	if ( form.elements['Manufacturer'+id] ) {
		manufacturer_ddm = form.elements['Manufacturer'+id];
	} // end if
	if ( manufacturer_ddm ) {
		if ( ManufacturerOptions.length > 1 ) {
			var selectedValue = get_ddm_value( manufacturer_ddm );
			fill_ddm( manufacturer_ddm, ManufacturerOptions, manufacturer_ddm.onchange );
			
			if ( ManufacturerOptions.length == 2 ) {
				ddm_select_by_index( manufacturer_ddm, 1 );
			} else {
				ddm_select_by_value( manufacturer_ddm, selectedValue, 0 );
			} // end if
		} // end if
		manufacturer_ddm.disabled = false;
	} // end if

	var name_ddm;
	if ( form.elements['Name'+id] ) {
		name_ddm = form.elements['Name'+id];
	} else if ( form.elements['ddmName'+id] ) {
		name_ddm = form.elements['ddmName'+id];
	} // end if
	if ( name_ddm ) {
		if ( BrandOptions.length > 1 ) {
			var selectedValue = get_ddm_value( name_ddm );
			fill_ddm( name_ddm, BrandOptions, name_ddm.onchange );
			
			if ( BrandOptions.length == 2 ) {
				ddm_select_by_index( name_ddm, 1 );
			} else {
				ddm_select_by_value( name_ddm, selectedValue, 0 );
			} // end if
		} // end if
		name_ddm.disabled = false;
	} // end if

	var finish_ddm;

	if ( form.elements['Finish'+id] ) {
		finish_ddm = form.elements['Finish'+id];
	} else if ( form.elements['ddmFinish'+id] ) {
		finish_ddm = form.elements['ddmFinish'+id];
	} // end if
	if ( finish_ddm ) {
		if ( FinishOptions.length > 1 ) {
			var selectedValue = get_ddm_value( finish_ddm );
			fill_ddm( finish_ddm, FinishOptions, finish_ddm.onchange );
			if ( FinishOptions.length == 2 ) {
				ddm_select_by_index( finish_ddm, 1 );
			} else {
				ddm_select_by_value( finish_ddm, selectedValue, 0 );
			} // end if
		} // end if
		finish_ddm.disabled = false;
	} // end if

	var colour_ddm;
	if ( form.elements['Colour'+id] ) {
		colour_ddm = form.elements['Colour'+id];
	} else if ( form.elements['ddmColour'+id] ) {
		colour_ddm = form.elements['ddmColour'+id];
	} // end if
	if ( colour_ddm ) {
		if ( ColourOptions.length > 1 ) {
			var selectedValue = get_ddm_value( colour_ddm );
			fill_ddm( colour_ddm, ColourOptions, colour_ddm.onchange );
			if ( ColourOptions.length == 2 ) {
				ddm_select_by_index( colour_ddm, 1 );
			} else {
				ddm_select_by_value( colour_ddm, selectedValue, 0 );
			} // end if
		} // end if
		colour_ddm.disabled = false;
	} // end if

	var weight_ddm;
	if ( form.elements['Weight'+id] ) {
		weight_ddm = form.elements['Weight'+id];
	} else if ( form.elements['ddmWeight'+id] ) {
		weight_ddm = form.elements['ddmWeight'+id];
	} // end if
	if ( weight_ddm ) {
		if ( WeightOptions.length > 1 ) {
			var selectedValue = get_ddm_value( weight_ddm );
			fill_ddm( weight_ddm, WeightOptions, weight_ddm.onchange );
			if ( WeightOptions.length == 2 ) {
				ddm_select_by_index( weight_ddm, 1 );
			} else {
				ddm_select_by_value( weight_ddm, selectedValue, 0 );
			} // end if
		} // end if
		weight_ddm.disabled = false;
	} // end if

} // end function fill_drop_down( results ) {

function cbFillDropDowns( results ) {
	fill_drop_down( results );
	if ( typeof calc == 'function' ) 
		calc('f1');
} // end function cbFillDropDowns( results )
