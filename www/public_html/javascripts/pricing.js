
function calc_from_quantity( element ) {
	var re = /quantity-(.*)/
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[1];
		var quantity = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var markup = parseFloat(1*element.form.elements['markup-'+index].value.replace(/[^\d\-\.]/g, '' )) /100;
		var cost = parseFloat(1*element.form.elements['cost-'+index].value.replace(/[^\d\-\.]/g, '' ));
		element.form.elements['price-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), 5 ); 
	} // end if
} // end function calc_from_quantity

function calc_from_cost( element ) {
	var re = /cost-(.*)/
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[1];
		var cost = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var markup = parseFloat(1*element.form.elements['markup-'+index].value.replace(/[^\d\-\.]/g, '' )) /100;
		var quantity = 1;
		if ( element.form.elements['quantity-'+index] ) {
			quantity =  parseFloat(1*element.form.elements['quantity-'+index].value.replace(/[^\d\-\.]/g,''));
		} // end if
		element.form.elements['price-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), 5 ); 
	} // end if
} // end function calc_from_cost
function calc_from_markup( element ) {
	var re = /markup-(.*)/
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[1];

		var cost = parseFloat( element.form.elements['cost-'+index].value.replace(/[^\d\-\.]/g, '' ) );
		if ( cost != '' ) {
			var markup = parseFloat( 1*(element.value.replace(/[^\d\-\.]/g, '' ) ) );
			var quantity = 1;
			if ( element.form.elements['quantity-'+index] ) {
				quantity =  parseFloat(1*element.form.elements['quantity-'+index].value.replace(/[^\d\-\.]/g,''));
			} // end if
			var newvalue = cost * quantity * ( markup/100 + 1 );
			element.form.elements['price-'+index].value = do_decimals( newvalue, 5 );
		} // end if
	} // end if
} // end function
function calc_from_price( element ) {
	var re = /price-(.*)/
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[1];

		var cost = parseFloat(element.form.elements['cost-'+index].value.replace(/[^\d\-\.]/g, '' ) );
		var price = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		if ( cost ) {
			var quantity = 1;
			if ( element.form.elements['quantity-'+index] ) {
				quantity =  parseFloat(1*element.form.elements['quantity-'+index].value.replace(/[^\d\-\.]/g,''));
			} // end if
			element.form.elements['markup-'+index].value = do_decimals( ((price / (cost*quantity))-1)*100, 2 );
		} // end if
	} // end if
} // end function
function del_price ( form, pricelist_id, equipment_id, price_id ) {
	$('prices-'+pricelist_id+'-'+equipment_id).innerHTML = 'Please wait...loading.';
	new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_prices_table_body.html?action=delete&price_id='+price_id, { method: 'post', parameters:form.serialize() } );
} /* end function del_price() */
function copy_price ( form, pricelist_id, equipment_id, price_id ) {
	$('prices-'+pricelist_id+'-'+equipment_id).innerHTML = 'Please wait...loading.';
	new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_prices_table_body.html?action=copy&price_id='+price_id, { method: 'post', parameters:form.serialize() } );
} /* end function add_price() */
