// Calls to pull down info for one paper from a purchase Order
function loadPaper( formName, PurchaseOrderIndex, PaperIndex ) {
	var form = document.forms[formName];
	// Use generic callback
	jsrsExecute( '/jsrs.htm', cbFillResults, 'openprint::paper_purchase_order::load_paper', new Array( PurchaseOrderIndex, PaperIndex ) );
} // end function loadPaper

function body_onLoad(formName) {
	if ( ! formName ) formName = 'f1';
	var form = document.forms[formName];
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_paper', get_parameters(form) );
} // end function body_onLoad();

function get_parameters( form ) {
	gettingNewPrice = true;
	var parameters = new Array( '' );
	parameters[parameters.length] = get_ddm_value( form.PaperBrand );
	parameters[parameters.length] = get_ddm_value( form.PaperFinish );
	parameters[parameters.length] = get_ddm_value( form.PaperColour );
	parameters[parameters.length] = get_ddm_value( form.PaperWeight );
	return parameters;
} // end function get_parameters( form )

function PaperBrand_onChange( form ) {
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_by_name', get_parameters(form) );

} // end function PaperBrand_onChange()

function PaperFinish_onChange( form ) {
	var form = document.forms['f1'];
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_by_finish', get_parameters(form) );
} // end function PaperFinish_onChange();

function PaperColour_onChange( form ) {
	var form = document.forms['f1'];
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_by_colour', get_parameters(form) );
} // end function PaperColour_onChange();

function PaperWeight_onChange( form ) {
	var form = document.forms['f1'];
	jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::select_by_weight', get_parameters(form) );
} // end function PaperWeight_onChange();

function PaperSheetSize_onChange( form ) {
} // end function PaperSheetSize_onChange();

function fill_drop_down( results ) {
	var form = document.forms['f1'];

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
            } // end switch
        } // end if
    } // end for

    if ( BrandOptions.length > 1 ) {
        var selectedValue = get_ddm_value( form.PaperBrand );
        fill_ddm( form.PaperBrand, BrandOptions, 'PaperBrand_onChange' );
		
		if ( BrandOptions.length == 2 )
			ddm_select_by_index( form.PaperBrand, 1 );
		else
			ddm_select_by_value( form.PaperBrand, selectedValue, 0 );
	} // end if

    if ( FinishOptions.length > 1 ) {
        var selectedValue = get_ddm_value( form.PaperFinish );
        fill_ddm( form.PaperFinish, FinishOptions, 'PaperFinish_onChange' );
		if ( FinishOptions.length == 2 ) {
			ddm_select_by_index( form.PaperFinish, 1 );
		} else {
			ddm_select_by_value( form.PaperFinish, selectedValue, 0 );
		} // end if
	} // end if

    if ( ColourOptions.length > 1 ) {
        var selectedValue = get_ddm_value( form.PaperColour );
		fill_ddm( form.PaperColour, ColourOptions, 'PaperColour_onChange' );
		if ( ColourOptions.length == 2 )
			ddm_select_by_index( form.PaperColour, 1 );
		else
			ddm_select_by_value( form.PaperColour, selectedValue, 0 );
	} // end if

    if ( WeightOptions.length > 1 ) {
		var selectedValue = get_ddm_value( form.PaperWeight );
		fill_ddm( form.PaperWeight, WeightOptions, 'PaperWeight_onChange' );
		if ( WeightOptions.length == 2 ) {
			ddm_select_by_index( form.PaperWeight, 1 );
		} else {
			ddm_select_by_value( form.PaperWeight, selectedValue, 0 );
		} // end if
    } // end if

	if ( form.PaperSheetSize ) {
		// Sheetsize gets special treatment, cuz it gets selected during price calcs
		if ( SheetSizeOptions.length > 1 && form.PaperSheetSize ) {
			var selectedValue = get_ddm_value( form.PaperSheetSize );
			fill_ddm( form.PaperSheetSize, SheetSizeOptions, 'PaperSheetSize_onChange' );

			if ( SheetSizeOptions.length == 2 )
				ddm_select_by_index( form.PaperSheetSize, 1 );
			else
				ddm_select_by_value( form.PaperSheetSize, selectedValue,0 );
		} // end if
    } // end if

} // end function fill_drop_down( results ) {

function cbFillDropDowns( results ) {
	fill_drop_down( results );
	gettingNewPrice = false;
	if ( typeof(calc) == 'function' ) calc();
} // end function cbFillDropDowns( results )


