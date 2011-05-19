
function filter_onChange( element, id, selected ) {
	var form = element.form;

    var filters = new Array( 'Manufacturer', 'Name','Finish','Colour','Weight','Quality', 'Group', 'Size' );
    for ( var index = 0, len = filters.length; index < len; ++index ) {
        var filter = form.elements[filters[index]+id];
        if ( filter ) {
            h.set(filters[index], filter.getValue() );
            filter.disabled = true;
        //} else {
            //alert('filter ' + 'ddmStock'+filters[index]+id );
        } // end if filter exists
    } // end for 
    new Ajax.Request( '/administrator/stock/_paper.json', { parameters: h, evalScripts: true } );

	//jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(form, id, selected ) );

} // end function Name_onChange()
