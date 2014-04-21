
function calc_from_quantity( element, precision ) {
	if ( ! precision ) precision = 5;
	var re = /quantity-(.*)/
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[1];
		var quantity = parseFloat( floatize( element ) );
		var markup = parseFloat(1* floatize( element.form.elements['markup-'+index] ) ) /100;
		var cost = parseFloat(1* floatize( element.form.elements['cost-'+index] ) );
		element.form.elements['price-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision ); 
		if ( element.form.elements['chk-'+index] ) {
			element.form.elements['chk-'+index].checked=true;
		} // end if
	} // end if
} // end function calc_from_quantity

function calc_from_cost( element, precision ) {
	if ( ! precision ) precision = 5;
	var re = /cost-(.*)/
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[1];
		var cost = parseFloat( floatize( element ) );
		var markup = parseFloat(1* floatize( element.form.elements['markup-'+index] )) /100;
		var quantity = 1;
		if ( element.form.elements['quantity-'+index] ) {
			quantity =  parseFloat(1* floatize( element.form.elements['quantity-'+index]));
		} // end if
		element.form.elements['price-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision ); 
		if ( element.form.elements['chk-'+index] ) {
			element.form.elements['chk-'+index].checked=true;
		} // end if
	} // end if
} // end function calc_from_cost

function calc_from_markup( element, precision ) {
	if ( ! precision ) precision = 5;
	var re = /markup-(.*)/
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[1];

		var cost = parseFloat( floatize( element.form.elements['cost-'+index] ) );
		if ( cost != '' ) {
			var markup = parseFloat( 1*floatize(element ) );
			var quantity = 1;
			if ( element.form.elements['quantity-'+index] ) {
				quantity = parseFloat(1*floatize(element.form.elements['quantity-'+index]));
			} // end if
			var newvalue = cost * quantity * ( markup/100 + 1 );
			element.form.elements['price-'+index].value = do_decimals( newvalue, precision );
		} // end if
		if ( element.form.elements['chk-'+index] ) {
			element.form.elements['chk-'+index].checked=true;
		} // end if
	} // end if
} // end function

function calc_from_price( element, precision ) {
	if ( ! precision ) precision = 2;
	var re = /^price-(.*)$/;
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[1];

		if ( ! element.form.elements['cost-'+index] ) {
			alert("No cost element for " + index);
			return;
		} // end if
		var cost = parseFloat( floatize(element.form.elements['cost-'+index] ) );
		var price = parseFloat( floatize(element) );
		if ( cost ) {
			var quantity = 1;
			if ( element.form.elements['quantity-'+index] ) {
				quantity = parseFloat(1*floatize(element.form.elements['quantity-'+index]));
			} // end if
			element.form.elements['markup-'+index].value = do_decimals( ((price / (cost*quantity))-1)*100, precision );
		} // end if
		if ( element.form.elements['chk-'+index] ) {
			element.form.elements['chk-'+index].checked=true;
		} // end if
	} // end if
} // end function

function add_price ( form, pricelist_id, equipment_id ) {
	$('prices-'+pricelist_id+'-'+equipment_id).innerHTML = 'Please wait...loading.';
	new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_prices_table_body.html?action=add&pricelist_id='+pricelist_id, { method: 'post', parameters:form.serialize() } );
} /* end function del_price() */

function del_price ( form, pricelist_id, equipment_id, price_id ) {
	$('prices-'+pricelist_id+'-'+equipment_id).innerHTML = 'Please wait...loading.';
	new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_prices_table_body.html?action=delete&price_id='+price_id, { method: 'post', parameters:form.serialize() } );
} /* end function del_price() */

function copy_price ( form, pricelist_id, equipment_id, price_id ) {
	$('prices-'+pricelist_id+'-'+equipment_id).innerHTML = 'Please wait...loading.';
	new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_prices_table_body.html?action=copy&price_id='+price_id, { method: 'post', parameters:form.serialize() } );
} /* end function add_price() */

function add_new_price ( service_id, pricelist_id, equipment_id ) {

	if ( $('prices-'+pricelist_id+'-'+equipment_id) ) {
		new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_price.html', { 
			parameters: { 
				pricelist_id: pricelist_id,
				equipment_id: equipment_id, 
				service_id: service_id,
				action: 'add'
			 }, 
			insertion: 'bottom' }
			);
	} else {
		new Ajax.Updater( 'pricelist-'+pricelist_id, '_prices_per_equipment.html', { 
			parameters: { 
				pricelist_id: pricelist_id,
				equipment_id: equipment_id, 
				service_id: service_id,
				action: 'add'
			 }, 
			insertion: 'bottom' }
			);
	} // end if
} // end function add_new_price ( service_id, pricelist_id, equipment_id )
