// From now on this file should only have stuff related to paper in it

function body_onLoad() {
	if ( typeof(selectProjectTemplate) == 'function' ) {
		selectProjectTemplate( 'f1' );
	} else if ( typeof(calc) == 'function' ) {
		calc('f1');
	} // end if
} // end function body_onLoad();

function paper_price_calc( element, group ) {
	var form = element.form;
	if ( ! form ) 
		alert( 'no form' );
	if ( element.name.match( /^StockPricePerM/ ) ) {
		var costperm = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		if ( get_value( form.elements['StockType'+group] ) == 'Roll' ) {
			var wpsi = form.elements['basis_mweight'+group].value / (form.elements['basis_width'+group]*form.elements['basis_height'+group]);
			var area = form.elements['txtSpecificStockWidth'+group].value * form.elements['txtSpecificStockHeight'+group].value;
			form.elements['CustomStockPrice'+group].value = do_decimals( costperm / (wpsi * area * 1000), 2);
		} else {
			if ( form.elements['txtCustomMWeight'+group].value ) {
				form.elements['CustomStockPrice'+group].value = do_decimals( costperm / (form.elements['txtCustomMWeight'].value / 100), 2 );
			} // end if
		} // end if
	} else {
		var costcwt = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );

		if ( get_value( form.elements['StockType'+group] ) == 'Roll' ) {
			return;
		} else {
			if ( ! form.elements['txtCustomMWeight'+group].value ) {
				$('PaperAlert'+group).innerHTML = 'Please enter MWeight';
				return;
			} // end if

			form.elements['StockPricePerM'+group].value = do_decimals( costcwt * form.elements['txtCustomMWeight'+group].value / 100, 2 );
		} // end if
	} // end if
} // end function


function mweight_to_gsm( form, signature ) {
	var width;
	var height;
	var mweight;
	if ( get_value( form.elements['StockType'+signature] ) == 'Roll' ) {
		mweight = parseFloat(1*form.elements['basis_mweight'+signature].value);
		width = parseFloat(1*form.elements['basis_width'+signature].value);
		height = parseFloat(1*form.elements['basis_height'+signature].value);
	} else { // sheet
		mweight = parseFloat(1*form.elements['txtCustomMWeight'+signature].value);
		width = parseFloat(1*form.elements['txtSpecificStockWidth'+signature].value);
		height = parseFloat(1*form.elements['txtSpecificStockHeight'+signature].value);
	} //e nd if
	var gsm = Math.round((mweight/1000)/(width*height)*70306450)/100;
	form.elements['txtStockGSM'+signature].value = gsm;
}
function gsm_to_mweight( form, signature ) {
	var gsm = parseFloat(1*form.elements['txtStockGSM'+signature].value);
	var width;
	var height;
	var mweight;

	width = parseFloat(1*form.elements['basis_width'+signature].value);
	height = parseFloat(1*form.elements['basis_height'+signature].value);
	mweight = Math.round((gsm/703064.5)*(width*height)*100000)/100;
	form.elements['basis_mweight'+signature].value = mweight;

	width = parseFloat(1*form.elements['txtSpecificStockWidth'+signature].value);
	height = parseFloat(1*form.elements['txtSpecificStockHeight'+signature].value);
	mweight = Math.round((gsm/703064.5)*(width*height)*100000)/100;
	form.elements['txtCustomMWeight'+signature].value = mweight;
}


function get_parameters( form, id, selected ) {
	gettingNewPrice = true;

    var parameters = new Array (
			selected,
			form.elements['ddmStockBrand'+id] ? get_ddm_value( form.elements['ddmStockBrand'+id] ) : '',
			form.elements['ddmStockFinish'+id] ? get_ddm_value( form.elements['ddmStockFinish'+id] ) : '',
			form.elements['ddmStockColour'+id] ? get_ddm_value( form.elements['ddmStockColour'+id] ) : '',
			form.elements['ddmStockWeight'+id] ? get_value( form.elements['ddmStockWeight'+id] ) : '',
			form.elements['rdbSuppliedStock'+id] ? get_value( form.elements['rdbSuppliedStock'+id] ) : '',
			id, /* press */
			form.ProjectIndex.value
	);
	parameters[parameters.length] = form.ProjectType ? form.ProjectType.value : '';
	parameters[parameters.length] = form.txtSpecificStockWidth ? form.txtSpecificStockWidth.value : '';
	parameters[parameters.length] = form.txtSpecificStockHeight ? form.txtSpecificStockHeight.value : '';
	parameters[parameters.length] = form.txtWidth ? form.txtWidth.value : '';
	parameters[parameters.length] = form.txtHeight ? form.txtHeight.value : '';
	return parameters;
} // end function get_parameters( form )

function rdbSuppliedStock_onchange( element, id ) {
	var form = element.form;
	if ( gettingNewPrice ) {
		if ( timeout ) clearTimeout( timeout );
		timeout = setTimeout( 'rdbSuppliedStock_onchange($(' + element.id + '),"' + id + '");', 1000 );
		return;
	} // end if
	timeout = null;
	if ( form.elements['ddmStockBrand'+id] ) form.elements['ddmStockBrand'+id].disabled = true;
	if ( form.elements['ddmStockFinish'+id] ) form.elements['ddmStockFinish'+id].disabled = true;
	if ( form.elements['ddmStockColour'+id] ) form.elements['ddmStockColour'+id].disabled = true;
	if ( form.elements['ddmStockWeight'+id] ) form.elements['ddmStockWeight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_paper', get_parameters(form, id, 'Supplied') );
} // end function rdbSuppliedStock_onchange( element, id )

function ddmStockBrand_onchange( element, id ) {
	var form = element.form;
	if ( gettingNewPrice ) {
		if ( timeout )
			clearTimeout( timeout );
		timeout = setTimeout( 'ddmStockBrand_onchange(document.' + element.form.name + '.elements["' + element.name + '"],"' + id + '");', 1000 );
		return;
	} // end if
	timeout = null;
	if ( form.elements['ddmStockBrand'+id] ) form.elements['ddmStockBrand'+id].disabled = true;
	if ( form.elements['ddmStockFinish'+id] ) form.elements['ddmStockFinish'+id].disabled = true;
	if ( form.elements['ddmStockColour'+id] ) form.elements['ddmStockColour'+id].disabled = true;
	if ( form.elements['ddmStockWeight'+id] ) form.elements['ddmStockWeight'+id].disabled = true;

	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_paper', get_parameters(form, id, 'Name') );

} // end function ddmStockBrand_onchange()

function txtSpecificStockBrand_onKeyUp( element ) {
	//ddm_select_by_value( element.form.ddmStockBrand, 'Customer Supplied', 0 );
	//ddmStockBrand_onchange();
} // end function txtSpecificStockBrand_onKeyUp()


function ddmStockFinish_onchange( element, id ) {
	var form = element.form;
	if ( gettingNewPrice ) {
		if ( timeout )
			clearTimeout( timeout );
		timeout = setTimeout( 'ddmStockFinish_onchange(document.' + form.name + '.elements["' + element.name + '"],"' + id + '");', 1000 );
		return;
	} // end if
	timeout = null;
	if ( form.elements['ddmStockBrand'+id] ) form.elements['ddmStockBrand'+id].disabled = true;
	if ( form.elements['ddmStockFinish'+id] ) form.elements['ddmStockFinish'+id].disabled = true;
	if ( form.elements['ddmStockColour'+id] ) form.elements['ddmStockColour'+id].disabled = true;
	if ( form.elements['ddmStockWeight'+id] ) form.elements['ddmStockWeight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_paper', get_parameters(form, id, 'Finish') );

} // end function ddmStockFinish_onchange();

function txtSpecificStockFinish_onKeyUp( element ) {
	//if ( get_ddm_value(form.ddmStockBrand) != 'Customer Supplied' ) {
		////form.txtSpecificStockFinish.value = '';
	////} else {
		//ddm_select_by_value( element.form.ddmStockFinish, '' );
	//} // end if
}

function ddmStockColour_onchange( element, id ) {
	var form = element.form;
	if ( gettingNewPrice ) {
		if ( timeout )
			clearTimeout( timeout );
		timeout = setTimeout( 'ddmStockColour_onchange(document.' + form.name + '.elements["' + element.name + '"],"' + id + '");', 1000 );
		return;
	} // end if
	timeout = null;
	if ( form.elements['ddmStockBrand'+id] ) form.elements['ddmStockBrand'+id].disabled = true;
	if ( form.elements['ddmStockFinish'+id] ) form.elements['ddmStockFinish'+id].disabled = true;
	if ( form.elements['ddmStockColour'+id] ) form.elements['ddmStockColour'+id].disabled = true;
	if ( form.elements['ddmStockWeight'+id] ) form.elements['ddmStockWeight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_paper', get_parameters(form, id,'Colour') );

	//if ( form.txtSpecificStockColour && get_ddm_value(form.ddmStockColour) ) form.txtSpecificStockColour.value='';
} // end function ddmStockColour_onchange();

function txtSpecificStockColour_onKeyUp( element ) {
	//if ( get_ddm_value(form.ddmStockBrand) != 'Customer Supplied' ) {
		//form.txtSpecificStockColour.value = '';
	//} else {
		//ddm_select_by_value( element.form.ddmStockColour, '' );
	//} // end if
}

function ddmStockWeight_onchange( element, id ) {
	var form = element.form;
	if ( gettingNewPrice ) {
		if ( timeout )
			clearTimeout( timeout );
		timeout = setTimeout( 'ddmStockWeight_onchange(document.' + form.name + '.elements["' + element.name + '"],"' + id + '");', 1000 );
		return;
	} // end if
	timeout = null;

	if ( form.elements['ddmStockBrand'+id] ) form.elements['ddmStockBrand'+id].disabled = true;
	if ( form.elements['ddmStockFinish'+id] ) form.elements['ddmStockFinish'+id].disabled = true;
	if ( form.elements['ddmStockColour'+id] ) form.elements['ddmStockColour'+id].disabled = true;
	if ( form.elements['ddmStockWeight'+id] ) form.elements['ddmStockWeight'+id].disabled = true;
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_paper', get_parameters(form, id, 'Weight') );
} // end function ddmStockWeight_onchange();

function txtSpecificStockWeight_onKeyUp( element ) {
} // end function txtSpecificStockWieght_onKeyUp()

function txtSpecificStockCalliper_onKeyUp( element ) {
}

function ddmStockSheetSize_onchange() {
	calc('f1');
} // end function ddmStockSheetSize_onchange();

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
				case 'Press':
					id = aOptions[1];
					break;
            } // end switch
        } // end if
    } // end for
	if ( form.elements['ddmStockBrand'+id] ) {
		if ( BrandOptions.length > 1 ) {
			var selectedValue = get_ddm_value( form.elements['ddmStockBrand'+id] );
			fill_ddm( form.elements['ddmStockBrand'+id], BrandOptions, 'ddmStockBrand_onchange' );
			
			if ( BrandOptions.length == 2 ) {
				ddm_select_by_index( form.elements['ddmStockBrand'+id], 1 );
			} else {
				ddm_select_by_value( form.elements['ddmStockBrand'+id], selectedValue, 0 );
				form.elements['ddmStockBrand'+id].disabled = false;
			} // end if
		} else {
			form.elements['ddmStockBrand'+id].disabled = false;
		} // end if
	} // end if

	if ( form.elements['ddmStockFinish'+id] ) {
		if ( FinishOptions.length > 1 ) {
			var selectedValue = get_ddm_value( form.elements['ddmStockFinish'+id] );
			fill_ddm( form.elements['ddmStockFinish'+id], FinishOptions, 'ddmStockFinish_onchange' );
			if ( FinishOptions.length == 2 ) {
				ddm_select_by_index( form.elements['ddmStockFinish'+id], 1 );
			} else {
				ddm_select_by_value( form.elements['ddmStockFinish'+id], selectedValue, 0 );
				form.elements['ddmStockFinish'+id].disabled = false;
			} // end if
		} else {
			form.elements['ddmStockFinish'+id].disabled = false;
		} // end if
	} // end if

	if ( form.elements['ddmStockColour'+id] ) {
		if ( ColourOptions.length > 1 ) {
			var selectedValue = get_ddm_value( form.elements['ddmStockColour'+id] );
			fill_ddm( form.elements['ddmStockColour'+id], ColourOptions, 'ddmStockColour_onchange' );
			if ( ColourOptions.length == 2 ) {
				ddm_select_by_index( form.elements['ddmStockColour'+id], 1 );
			} else {
				ddm_select_by_value( form.elements['ddmStockColour'+id], selectedValue, 0 );
				form.elements['ddmStockColour'+id].disabled = false;
			} // end if
		} else {
			form.elements['ddmStockColour'+id].disabled = false;
		} // end if
	} // end if

	
	if ( form.elements['ddmStockWeight'+id] ) {

		// Try to convert to a dropdown if we need one
		if ( ( WeightOptions.length > 2 ) && ( form.elements['ddmStockWeight'+id].type != 'select-one' ) ) {
			var input = $('StockWeightSelect'+id);
			if ( input ) {
				input.innerHTML = '<label>Weight:</label><select name="ddmStockWeight'+id+'" size="1" onchange="ddmStockWeight_onchange( this, \''+id+'\' );"></select>';
			} else { 
				alert('StockWeightSelect'+id+ ' not found');
			} // end if
		} // end if

		if ( form.elements['ddmStockWeight'+id].type == 'select-one' ) {
			if ( WeightOptions.length > 1 ) {
				var selectedValue = get_ddm_value( form.elements['ddmStockWeight'+id] );
				fill_ddm( form.elements['ddmStockWeight'+id], WeightOptions, 'ddmStockWeight_onchange' );
				if ( WeightOptions.length == 2 ) {
					ddm_select_by_index( form.elements['ddmStockWeight'+id], 1 );
				} else {
					ddm_select_by_value( form.elements['ddmStockWeight'+id], selectedValue, 0 );
					form.elements['ddmStockWeight'+id].disabled = false;
				} // end if
			} else {
				form.elements['ddmStockWeight'+id].disabled = false;
			} // end if
		} else { // must be hidden
			if ( WeightOptions.length == 2 ) {
				form.elements['ddmStockWeight'+id].value = WeightOptions[1].value;
			} else {
				form.elements['ddmStockWeight'+id].value = '';
			} // end if
		} // end if
	} // end if

	// Sheetsize gets special treatment, cuz it gets selected during price calcs
    if ( SheetSizeOptions.length > 1 ) {
		if ( form.elements['ddmStockSheetSize'+id] ) {
			var selectedValue = get_ddm_value( form.elements['ddmStockSheetSize'+id] );
			fill_ddm( form.elements['ddmStockSheetSize'+id], SheetSizeOptions, 'ddmStockSheetSize_onchange' );
			if ( SheetSizeOptions.length == 2 ) {
				ddm_select_by_index( form.elements['ddmStockSheetSize'+id], 1 );
			} else {
				ddm_select_by_value( form.elements['ddmStockSheetSize'+id], selectedValue, 0 );
				form.elements['ddmStockSheetSize'+id].disabled = false;
			} // end if
		} else {
			for ( var qty_index = 1; qty_index <= 3; qty_index += 1 ) {
				var ddm = form.elements['ddmStockSheetSize'+qty_index];
				if ( ddm ) {
					if ( form.elements['chkOverrideSheetSize'+qty_index].checked ) {
						var selectedValue = get_ddm_value( ddm );
						fill_ddm( ddm, SheetSizeOptions, 'ddmStockSheetSize_onchange' );
						ddm_select_by_value( ddm, selectedValue, 0 );
					} else {
						fill_ddm( ddm, SheetSizeOptions, 'ddmStockSheetSize_onchange' );
					} // end if
				} // end if
			} // end for
		} // end if
	} else {
		if ( form.elements['ddmStockSheetSize'+id] ) {
			form.elements['ddmStockSheetSize'+id].disabled = false;
		} // end if
    } // end if
} // end function fill_drop_down( results ) {

// Now all the call backs

function cbFillDropDowns( results ) {
	fill_drop_down( results );
	gettingNewPrice = false;
	calc('f1');
} // end function cbFillDropDowns( results )
