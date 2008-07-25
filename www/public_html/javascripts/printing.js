function versions_onkeyup( e ) {
	new Ajax.Updater( 'Version_Descriptions', '_version_descriptions.html', { method: 'get', parameters: e.form.serialize() } );
}

function filter_colours( side, signature ) {
	// For each of the colours
	for ( var index = 1; index < 10; index += 1 ) {
		var type_element = $('ColourCoatingType'+side+index+signature);
		if ( ! type_element ) continue;
		var type = type_element.value;
		if ( ! type ) continue;
		// we can have many PMS's
		if ( type == 'PMS' ) continue;

		// clear my selected type out of the other dropdowns
		for ( var j = index+1; j <= 10; j += 1 ) {
			var t = $('ColourCoatingType'+side+j+signature);
			if ( ! t ) continue;

			var option_index = get_option_index( t, type );
			if ( -1 != option_index ) {
				t.options[option_index] = null;
				continue;
			} // end if
		} // end for each colour
	} // end for each colour index
} // end function filter_colours

function SpecialColour_onchange( element, side, index, signature ) {
	var spec = 'ColourCoating'+side+index+signature;

	var type_element = $('ColourCoatingType'+side+index+signature);
	var type = type_element.value;
	if ( type ) {
		element.form.elements[spec].checked=true;

		if ( ! $('ColourCoating'+side+(1+parseInt(index))+signature) ) {
			// Add another colour
			new Ajax.Request('/includes/main/proj/_additional_colour_coating.html', { 
				method: 'get', 
				parameters: { 
					'Side': side, 
					'index' : 1+parseInt(index),
					'Signature' : signature 
				},
				onSuccess: function(response){
					new Insertion.After($(spec), response.responseText);
					filter_colours(side,signature);
					
					}
			} );
		} else {
			filter_colours(side,signature);
		} // end if
	} else {
		element.form.elements[spec].checked=false;

		if ( type != 'PMS' ) {
			for ( var i = 1; i < 10; i += 1 ) {
				if ( i == index ) continue;

				// if the colour exists
				var t = $('ColourCoatingType'+side+i+signature);
				if ( t ) {

					for ( var m = 0; m < type_element.options.length; m += 1 ) {
						var v = type_element.options[m].value;
						// see if it is in there
						if ( ! isin_ddm( t, v ) ) {
							add_option( t, v, type_element.options[m].text );
							sort_ddm( t );
							// need tos ort, add later FIXME
						} // end if
					} // end for each colour
				} // end if
			} // end for each option in type_element
		} // end if
	} // end if

	if ( (!type) || ( -1 != type.indexOf('Overall') ) ) {
		$('ColourCoatingCoverage'+side+index+signature).hide();
	} else {
		$('ColourCoatingCoverage'+side+index+signature).show();
	} // end if
	if ( -1 != type.indexOf('PMS') ) {
		$('ColourCoatingColour'+side+index+signature).show();
	} else {
		$('ColourCoatingColour'+side+index+signature).hide();
	} // end if
	calc(element.form.name);
} // end function

function chkSpecial_onClick(chkBox) {
	return;
	var name = 'txt' + chkBox.name.substr(3);
	var form = chkBox.form;

	if ( chkBox.checked == false ) {
		form.elements[name].value = '';
	} // end if
} // end function

function validate_data(formName) {
	var form = getFormObj( formName );
	var text = '';
    if ( form.txtWidth && ! ( 0 < parseFloat(form.txtWidth.value) ) ) {
        text += "Please enter the Width of your Project\n";
    } // end if
    if ( form.txtHeight && ! ( 0 < parseFloat(form.txtHeight.value) ) ) {
        text += "Please enter the Height of your Project\n";
    } // end if
	if ( form.txtWidth && form.txtHeight && form.txtFinalWidth && form.txtFinalHeight ) {
	   if ( form.txtWidth.value * form.txtHeight.value < form.txtFinalWidth.value * form.txtFinalHeight.value ) {
	   		text += "Your Finished Dimenstions may not exceed your Flat Dimensions.\n";
	 	} // end if		
	} // end if

	var stockBrand = form.ddmStockBrand ? get_ddm_value(form.ddmStockBrand) : '';
	var stockFinish = form.ddmStockFinish ? get_ddm_value(form.ddmStockFinish) : '';
	var stockColour = form.ddmStockColour ? get_ddm_value(form.ddmStockColour) : '';

	var stockWeight = form.ddmStockWeight ? get_ddm_value(form.ddmStockWeight) : '';
	if ( stockBrand == 'Customer Supplied' && form.txtSpecificStockCalliper && form.txtSpecificStockCalliper.value ) {
		stockWeight = form.txtSpecificStockCalliper.value;
	} // end if
	
	if ( stockBrand == '' && form.txtSpecificStockBrand && form.txtSpecificStockBrand.value == '' ) {
		text += "Please Select a Paper Brand\n";
	} // end if
	if ( form.elements['txtSpecificStockWidth'] && form.elements['txtSpecificStockHeight'] && form.txtSpecificStockWidth.value && form.txtSpecificStockHeight.value ) {
		if ( (parseFloat(form.txtWidth.value) <= parseFloat(form.txtSpecificStockWidth.value) && parseFloat(form.txtHeight.value) <= parseFloat(form.txtSpecificStockHeight.value) )  ||
				(parseFloat(form.txtWidth.value) <= parseFloat(form.txtSpecificStockHeight.value) && parseFloat(form.txtHeight.value) <= parseFloat(form.txtSpecificStockWidth.value)) ) { 
			// we have good sheet size
		} else {
			text += "The sheet size you have entered is too small for the dimesions of your project, please enter a larger sheet size.";	
		} // end if
	} // end if
	if ( ! ( stockFinish || (form.txtSpecificStockFinish && form.txtSpecificStockFinish.value ) ) ) {
		text += "Please Select a Paper Finish\n";
	} // end if
	if ( ! ( stockColour || ( form.txtSpecificStockColour && form.txtSpecificStockColour.value ) ) ) {
		text += "Please Select a Paper Colour\n";
	} // end if
	if ( ! ( stockWeight  || ( form.txtSpecificStockWeight && form.txtSpecificStockWeight.value ) ) ) {
		text += "Please Select a Paper Weight\n";
	} // end if

 // Presentation Folder Fields:
	if ( form.elements['chkLeftPocket'] && form.elements['chkRightPocket'] ) {
		if ( ! ( form.chkLeftPocket.checked || form.chkRightPocket.checked ) ) {
			text += "Please specify which side your pockets will go on.";
		} // end if
	} // end if
	if ( form.elements['rdbPocketSize'] && ! ( form.rdbPocketSize[0].checked || form.rdbPocketSize[1].checked ) ) {
		text += "Please specify this size of your pockets.";
	} // end if

	return true;
} // end function validate_data

function calc_print( formName, force ) {

	var form = getFormObj( formName );


	if ( gettingNewPrice && ! force ) {
		// This prevents concurrent price getting
		if ( timeout ) clearTimeout( timeout );
		timeout = setTimeout("calc('f1');", 1000 );	
		return;
	} // end if
	//timeout = null;

	clear_price_data(form);
	jsrsExecute( '/jsrs.htm', cbFillPrintResults, 'openprint::service::external_calc', get_variables(formName,'Printing') );
	return;
} // end calc_print


function clear_price_data( form ) {

	for ( var qtyNum = 1; qtyNum <= 3; qtyNum += 1 ) {
		if ( quantities[qtyNum-1] > 0 ) {
			if ( form.elements['StockType'+qtyNum] ) form.elements["StockType"+qtyNum].value = '';
			if ( form.elements['txtPrice'+qtyNum] && form.elements['OverridePrice'+qtyNum] && ! form.elements['OverridePrice'+qtyNum].checked ) form.elements["txtPrice"+qtyNum].value = '';
			if ( form.elements['txtUnitPrice'+qtyNum] ) form.elements["txtUnitPrice"+qtyNum].value = '';
			if ( form.elements["txtPressSheetQty"+qtyNum] ) form.elements["txtPressSheetQty"+qtyNum].value = '';
			if ( form.elements["txtPlateQuantity"+qtyNum] ) form.elements["txtPlateQuantity"+qtyNum].value = '';
			
			if ( form.elements["txtImposition"+qtyNum] ) {
				if ( ( ! form.elements['chkOverrideImposition'+qtyNum] ) || ( ! form.elements['chkOverrideImposition'+qtyNum].checked ) ) {
					//form.elements["txtImposition"+qtyNum].value = '';
				} // end if
			} // end if
			if ( form.elements["txtImageWidth"+qtyNum]) form.elements["txtImageWidth"+qtyNum].value = '';
			if ( form.elements["txtImageHeight"+qtyNum]) form.elements["txtImageHeight"+qtyNum].value = '';
			if ( form.elements['hdnImpositionColumns'+qtyNum]) form.elements['hdnImpositionColumns'+qtyNum].value = '';
			if ( form.elements['hdnImpositionRows'+qtyNum]) form.elements['hdnImpositionRows'+qtyNum].value = '';
			if ( form.elements['hdnImpositionDutchColumns'+qtyNum]) form.elements['hdnImpositionDutchColumns'+qtyNum].value = '';
			if ( form.elements['hdnImpositionDutchRows'+qtyNum]) form.elements['hdnImpositionDutchRows'+qtyNum].value = '';
			//form.elements["txtAdditionalPrice"+qtyNum].value = '0.00';
			if ( ! ( form.elements['chkOverridePress'+qtyNum] && form.elements['chkOverridePress'+qtyNum].checked ) ) {
				if ( form.elements['ddmPress'+qtyNum] ) {
					if ( form.elements['ddmPress'+qtyNum].type == 'select-one' ) {
						ddm_select_by_index( form.elements['ddmPress'+qtyNum], 0 );
					} else {
						form.elements['ddmPress'+qtyNum].value = '';
					} // end if
				} // end if
			} // end if
			if ( form.elements['chkOverridePageQuantity'+qtyNum] && ! form.elements['chkOverridePageQuantity'+qtyNum].checked ) {
				form.elements['PageQuantity'+qtyNum].value='';
			} // end if
			if ( form.elements['ddmRunStyle'+qtyNum] ) {
				if ( 
					! ( form.elements['chkOverrideRunStyle'+qtyNum] && form.elements['chkOverrideRunStyle'+qtyNum].checked ) 
					&& form.elements['ddmRunStyle'+qtyNum].type == 'select-one' 
					) {
					ddm_select_by_index( form.elements['ddmRunStyle'+qtyNum], 0 );
				} // end if
			} // end if
		} // endif
	} // end for

} // end function

// This function does all the extra stuff required for printing
function cbFillPrintResults( results ) {
	cbFillResults( results );
	var form = getFormObj( 'f1' );

	for ( var i = 1; i <= 3; i += 1 ) {
		var ddm = form.elements['ddmStockSheetSize'+i];
		if ( ! ddm ) {
			continue;
		} // end if
		if ( ddm.selectedIndex == -1 || ddm.selectedIndex == 0 ) {
			var width = form.elements['StockWidth'+i].value;
			var height = form.elements['StockHeight'+i].value;
			var type = form.elements['StockType'+i].value;
		
			if ( type == 'Sheet' ) {
				if ( ! ddm_select_by_value( ddm, width + 'x' + height, false ) ) {
					ddm.options[ddm.options.length] = new Option( width + 'x' + height, width + 'x' + height, true );
				} // end if
			} else if ( type == 'Roll' ) {
				if ( ! ddm_select_by_value( ddm, width, false ) ) {
					ddm.options[ddm.options.length] = new Option( width + '" Roll', width, true );
					ddm_select_by_value( ddm, width );
				} // end if
			} // end if
		} // end if
	} // end for

    var addServices = new Array();
    var cancelAddFolding = false;
    if ( form.NeedFolding.value > 0 ) {
        if ( form.HasFolding.value == 0 ) {
            if ( FoldingQuestionFlag && confirm("Your project needs folding.  Click OK to automatically add folding to your project.") ) {
               // addService( 'f1', 'Folding' );
                addServices[addServices.length] = 'Folding';
            } else {
                cancelAddFolding = true;
            } // end if
            FoldingQuestionFlag = false;
        } // end if
    } // end if

    if ( form.NeedScoring.value > 0 && cancelAddFolding == false ) {
        if ( form.HasScoring.value == 0 && (form.HasFolding.value > 0 || (form.txtFinalWidth && form.txtFinalHeight) ) ) {
            if ( ScoringQuestionFlag && confirm("The selected paper needs to be scored before folding, or else the edge will crack.  Click OK to automatically add scoring to your project.") ) {
             //   addService( 'f1', 'Scoring' );
                addServices[addServices.length] = 'Scoring';
            } // end if
            ScoringQuestionFlag = false;
        } // end if
    } // end if

    if ( form.NeedCutting.value > 0 ) {
        if ( form.HasCutting.value == 0 ) {
            if ( CuttingQuestionFlag && confirm("Your project needs cutting.  Click OK to automatically add cutting to your project.") ) {
             //   addService( 'f1', 'Cutting' );
                addServices[addServices.length] = 'Cutting';
            } // end if
            CuttingQuestionFlag = false;
        } // end if
    } // end if

    if ( addServices.length ) {
         addService( 'f1', addServices);
    } // end if

} // end function cbFillPrintResults( results )

var ScoringQuestionFlag = true;
var FoldingQuestionFlag = true;
var CuttingQuestionFlag = true;

