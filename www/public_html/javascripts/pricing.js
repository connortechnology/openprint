"use strict";

function calc_from_quantity(element) {
  let precision = element.getAttribute('precision');
  if (!precision) precision = 5;
  const re = /quantity-(.*)/
  const matches = re.exec( element.name );
  if ( matches ) {
    const index = matches[1];
    const quantity = parseFloat( floatize( element ) );
    const markup = parseFloat(1*floatize( element.form.elements['markup-'+index] ) ) /100;
    const cost = parseFloat(1* floatize( element.form.elements['cost-'+index] ) );
    if (element.form.elements['total-'+index]) {
      element.form.elements['price-'+index].value = do_decimals( cost * ( 1 + markup ), precision );
      element.form.elements['total-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision );
    } else {
      element.form.elements['price-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision );
    }
    if ( element.form.elements['chk-'+index] ) {
      element.form.elements['chk-'+index].checked=true;
    } // end if
  } else {
    console.log("calc_from_quantity called from something other than a quantity "+element.name);
  } // end if
} // end function calc_from_quantity

function calc_from_cost(element) {
  let precision = element.getAttribute('precision');
  if (!precision) precision = 5;
  console.log("Using precision: " + precision);
  const elements = element.form.elements;
  const re = /cost-(.*)/;
  const matches = re.exec(element.name);
  if (matches) {
    const index = matches[1];
    const cost = parseFloat(floatize(element));
    const markup = parseFloat(1* floatize(elements['markup-'+index])) /100;
    const quantity = elements['quantity-'+index] ? parseFloat(1* floatize(elements['quantity-'+index])) : 1;
    if (elements['total-'+index]) {
      elements['price-'+index].value = do_decimals( cost * ( 1 + markup ), precision );
      elements['total-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision );
    } else {
      elements['price-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision );
    }
    if (elements['chk-'+index]) {
      elements['chk-'+index].checked=true;
    } // end if
  } else {

  } // end if matched
} // end function calc_from_cost

function calc_from_markup(element) {
  let precision = element.getAttribute('precision');
  if (!precision) precision = 5;
  const elements = element.form.elements;

  const re = /markup-(.*)/
  const matches = re.exec( element.name );
  if ( matches ) {
    const index = matches[1];

    const cost = parseFloat(floatize(elements['cost-'+index]));
    if ( cost != '' ) {
      const markup = parseFloat(1*floatize(element));
      const quantity = elements['quantity-'+index] ?parseFloat(1*floatize(elements['quantity-'+index])) : 1;

      if (elements['total-'+index]) {
        elements['price-'+index].value = do_decimals( cost * ( 1 + markup ), precision );
        elements['total-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision );
      } else {
        elements['price-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision );
      } // end if
    } // end if

    if (elements['chk-'+index]) {
      elements['chk-'+index].checked=true;
    } // end if
  } // end if matches
} // end function

function calc_from_price(element) {
  let precision = element.getAttribute('precision');
  if (!precision) precision = 5;
  const elements = element.form.elements;
	const re = /^price-(.*)$/;
	const matches = re.exec( element.name );
	if ( matches ) {
		const index = matches[1];

		if (!elements['cost-'+index] ) {
			alert("No cost element for " + index);
			return;
		} // end if
		const cost = parseFloat( floatize(elements['cost-'+index] ) );
		const price = parseFloat( floatize(element) );
		if ( cost ) {
			const quantity = elements['quantity-'+index] ? parseFloat(1*floatize(elements['quantity-'+index])) : 1;
			elements['markup-'+index].value = do_decimals( ((price / (cost*quantity))-1)*100, precision );
		} // end if
    if (elements['total-'+index]) {
		  elements['total-'+index].value = do_decimals( cost * quantity * ( 1 + markup ), precision );
    }
		if (elements['chk-'+index]) {
			elements['chk-'+index].checked=true;
		} // end if
	} // end if
} // end function

function add_price (form, pricelist_id, equipment_id) {
	$('prices-'+pricelist_id+'-'+equipment_id).innerHTML = 'Please wait...loading.';
	new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_prices_table_body.html?action=add&pricelist_id='+pricelist_id,
    { method: 'post', parameters:form.serialize(), evalScripts: true } );
} /* end function del_price() */

function del_price ( form, pricelist_id, equipment_id, price_id ) {
	$('prices-'+pricelist_id+'-'+equipment_id).innerHTML = 'Please wait...loading.';
	new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_prices_table_body.html?action=delete&price_id='+price_id,
    { method: 'post', parameters:form.serialize(), evalScripts: true } );
} /* end function del_price() */

function copy_price ( form, pricelist_id, equipment_id, price_id ) {
	$('prices-'+pricelist_id+'-'+equipment_id).innerHTML = 'Please wait...loading.';
	new Ajax.Updater( 'prices-'+pricelist_id+'-'+equipment_id, '_prices_table_body.html?action=copy&price_id='+price_id,
    { method: 'post', parameters:form.serialize(), evalScripts: true } );
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

function check_price( element ) {
    var form = element.form;
    var matches;
    if ( matches = element.name.match( /^\w+\-(\d+)$/ ) ) {
        var id = matches[1];
		var container = $('Price-'+id);

		if ( ! container ) {
			console.error("No element found for Price-"+id);
			return;
		}
        if (
            element_changed( form.elements['min-'+id] ) ||
            element_changed( form.elements['max-'+id] ) ||
            element_changed( form.elements['units-'+id] ) ||
            element_changed( form.elements['cost-'+id] ) ||
            element_changed( form.elements['markup-'+id] ) ||
            element_changed( form.elements['price-'+id] ) ||
            element_changed( form.elements['discount-'+id] )
           ) {
			container.addClassName('changed');
        } else {
            container.removeClassName('changed');
        } // end if
    } else {
        alert('Not matched' + element.name);
    } // end if
} // end function check_field

