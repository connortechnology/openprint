
function filter_onChange( element, id, selected ) {
	var form = element.form;
	var h = new Hash();
	h.set('form', element.form.name);
	h.set('selected', element.name);
    var filters = new Array( 'Group', 'Manufacturer', 'Name','Finish','Colour','Weight','Quality', 'Size','Material' );
    for ( var index = 0, len = filters.length; index < len; ++index ) {
        var filter = form.elements[filters[index]+id];
        if ( filter ) {
            h.set(filters[index], filter.getValue() );
            filter.disabled = true;
        //} else {
            //alert('filter ' + 'ddmStock'+filters[index]+id );
        } // end if filter exists
    } // end for 
    new Ajax.Request( '/administrator/stock/_stock.json', { parameters: h, evalScripts: true } );

	//jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, selected ) );

} // end function Name_onChange()

function cbStockFillResults( results ) {
	var form = $(results.get('form'));
	if ( ! form ) {
		alert('No form for ' + results.get('form') );
		return;
	} // end if
	results.unset('form');

    var keys = results.keys();

    for ( var index = 0, len = keys.length; index < len; ++index ) {
        var key = keys[index];
        var value = results.get(key);
		var options = new Array();
		options[0] = create_option( '', 'select one' );
		var ddm = form.elements[key];
		if ( ! ddm ) {
//alert('No ddmStock'+key+suffix);
			continue;
		} // end if
		var selectedValue = ddm.getValue();

		for ( var ddm_index = 0, ddm_len = value.length; ddm_index < ddm_len; ++ddm_index ) {
			options[options.length] = create_option( value[ddm_index], value[ddm_index] );
		} // end for
		fill_ddm( ddm, options );
		if ( options.length == 2 ) {
			ddm_select_by_index( ddm, 1 );
		} else {
			ddm_select_by_value( ddm, selectedValue );
		} // end if
	} // end for each key

	// turn drop downs back on
	var filters = new Array( 'Manufacturer', 'Name','Finish','Colour','Weight','Quality', 'Group', 'SheetSize', 'Size','Material' );
	for ( var index = 0, len = filters.length; index < len; ++index ) {
		var filter = form.elements[filters[index]];
		if ( filter ) {
			filter.disabled = false;
		} // end if filter exists
	} // end for 
	calc(form.name);
} // end function Stock_Fill
