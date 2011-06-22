function load_content_type( index, type ) {
	$('content-'+index).innerHTML = '';
	new Ajax.Updater('content-'+index, '_po_content_'+type+'.html', { method: 'get', parameters: { content_id: index } } );
} // end function load_content_type

function set_description(index) {
	var desc = $('description-'+index);
	desc.value = '';
	if ( $('mweight-'+index) ) { 
		desc.value += $('mweight-'+index).value +'M ';
	} // end if
	var type = $('stocktype-'+index);
	if ( type && type.options[type.selectedIndex].value ) {
		desc.value += type.options[type.selectedIndex].value + ' ';
	} // end if
	desc.value += $('name-'+index).value;
}


function calc_price( element ) {
	var re = /(.*)-(.*)/
	var matches = re.exec( element.name );
	if ( matches ) {
		var index = matches[2];
		$('price-'+index).value = $('price-'+index).value.replace(/[^\d\-\.]/g, '' );
		re =  /^\s*(\+|-)?((\d+(\.\d+)?)|(\.\d+))\s*$/;
		if ( ! re.test($('price-'+index).value) ) $('price-'+index+'-alert').innerHTML = 'Not a valid price!';
		else $('price-'+index+'-alert').innerHTML = '';
		$('qty-'+index).value = $('qty-'+index).value.replace(/[^\d\-\.]/g, '' );
		var cost = parseFloat( $('price-'+index).value );
		var qty = parseFloat( $('qty-'+index).value );
		var type = get_value( $('type-'+index) );
		if ( type == 'Roll Stock' ) {
			qty /= 100;
		} else if ( type == 'Sheet Stock' ) {
			var mweight = parseFloat( $('mweight-'+index).value.replace(/[^\d\-\.]/g, '' ) );
			qty = qty * mweight / 100000;
		} // end if
		$('total-'+index).value = do_decimals( cost * qty, 2 );
	} // end if
	update_totals( element.form );
} // end function calc_price
function update_totals( form ) {
	var subtotal = 0;
	var re = /total-(.+)/

	for ( var index = 0; index < form.elements.length; index += 1 ) {
		var e = form.elements[index];
		var matches = re.exec( e.name );
		if ( matches ) {
			subtotal += parseFloat(1*e.value);
		} // end if
	} // end for
	$('subtotal').innerHTML = do_decimals( subtotal, 2 );
	var total = subtotal;
	for ( var i = 0; i < tax_ids.length; i+= 1 ) {
		var tax = 0;
		
		if ( form.elements['tax_charge-'+tax_ids[i]].checked ) {
			tax = subtotal * $('tax_rate-'+tax_ids[i]).innerHTML/100;
		} else {
			tax = 0;
		} // end if
		$('tax_amount-'+tax_ids[i]).innerHTML = do_decimals( tax, 2 );
		total += parseFloat( tax );
	} // end for

	$('total').innerHTML = do_decimals( total, 2 );
} // end function update_totals
function getSelectionId(input, li) {
	var re = /(\w+)-(\w+)/;
	var matches = re.exec( input.id );
	if ( matches ) {
		if ( matches[1] == 'item' ) {
			var description = Ajax.Autocompleter.extract_value(li, 'description');
			if ( description != 'undefined' ) 
				$('description-'+matches[2]).value;
			var price = Ajax.Autocompleter.extract_value(li, 'price');
			if ( price != 'undefined' )
				$('price-'+matches[2]).value = price;
		} // end if
	} // end if
} // end function getSelectionId

/*
function update_taxes( form ) {
	new Ajax.Request( '_update_taxes.json?po_id=<? echo ( $$variable{'PurchaseOrder'}->id() ) ?>', { parameters: form.serialize() } );
} // end function update_taxes
*/

  tinyMCE.init({
	theme : "advanced",
	mode: "specific_textareas",
	editor_selector : "mce",
	theme_advanced_toolbar_location : "top",
	theme_advanced_buttons1 : "bold,italic,underline,strikethrough,separator,justifyleft,justifycenter,justifyright,justifyfull",
	theme_advanced_buttons2 : "bullist,numlist,outdent,indent,sub,sup,charmap",
	theme_advanced_buttons3 : "",
	auto_resize : true,

  });
