
var filters = new Array( 'Owner', 'Group', 'Manufacturer', 'Brand','Finish','Colour','Weight','Quality', 'Size','Material','type','width','height' );

function filter_onChange( element, id, selected ) {
	var form = element.form;
	var h = new Hash();
	h.set('form', element.form.name);
	h.set('selected', element.name);
    for ( var index = 0, len = filters.length; index < len; ++index ) {
        var filter = form.elements[filters[index]+id];
        if ( filter ) {
            h.set(filters[index], get_value( filter ) );
			if ( filter.type == 'select-one' ) {
            filter.disabled = true;
			} // end if
			filter = form.elements[filters[index]+'_exclude'+id];
			if ( filter ) {
				h.set(filter.name, get_value( filter ) );
			} // end if
		} // end if filter exists
        var filter = form.elements[filters[index].toLowerCase()+'_id'+id];
        if ( filter ) {
			var v = get_value( filter );
            if ( ! v ) continue;
			
			h.set(filter.name, v );
			if ( filter.type == 'select-one' ) {
				filter.disabled = true;
			} // end if
			filter = form.elements[filters[index].toLowerCase()+'_id_exclude'+id];
			if ( filter ) {
				var v = get_value( filter );
				if ( v ) h.set(filter.name, v );
			} // end if
        } // end if filter exists
    } // end for 
    new Ajax.Request( '/employee/inventory/_stock.json', { parameters: h, evalScripts: true } );
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
		ddm = form.elements[key+'_id'];
		} // end if
		if ( ! ddm ) {
		ddm = form.elements[key.toLowerCase()+'_id'];
		} // end if
		if ( ( ! ddm ) || ( ddm.type != 'select-one' ) ) {
//alert('No ddmStock'+key+suffix);
			continue;
		} // end if
		var selectedValue = ddm.getValue();

		for ( var ddm_index = 0, ddm_len = value.length; ddm_index < ddm_len; ddm_index += 2 ) {
			options[options.length] = create_option( value[ddm_index], value[ddm_index+1] );
		} // end for
		fill_ddm( ddm, options );
		if ( options.length == 2 ) {
			ddm_select_by_index( ddm, 1 );
		} else {
			ddm_select_by_value( ddm, selectedValue );
		} // end if
	} // end for each key

	// turn drop downs back on
	for ( var index = 0, len = filters.length; index < len; ++index ) {
		var filter = form.elements[filters[index]];
		if ( filter ) {
			filter.disabled = false;
			continue;
		} // end if filter exists
		var filter = form.elements[filters[index].toLowerCase()+'_id'];
		if ( filter ) {
			filter.disabled = false;
			continue;
		} // end if filter exists
	} // end for 
	calc(form.name);
} // end function Stock_Fill
