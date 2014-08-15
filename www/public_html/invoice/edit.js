function update_totals( ) {
	var total;
	var timetrack_total = $('timetrack_total');
	if ( timetrack_total ) {
		timetrack_total = parseFloat(timetrack_total.innerHTML.replace(/[^\d\.]/g,'') );
		total += timetrack_total;
	} // end if
	var product_total = $('product_total');
	if ( product_total ) {
		product_total = parseFloat(product_total.innerHTML.replace(/[^\d\.]/g,'') );
		total += product_total;
	} // end if
	var order_total = $('order_total');
	if ( order_total ) {
		order_total = parseFloat(order_total.innerHTML.replace(/[^\d\.]/g,'') );
		total += order_total;
	} // end if
	if ( $('subtotal') ) {
		$('subtotal').innerHTML = do_decimals( total, 2 );
	} else {
		alert('no subtotal');
	} // end if
} // end function

function update_product( product_id ) {
	$('product-total-'+product_id).innerHTML = do_decimals( parseFloat($('product-price-'+product_id).value) * parseFloat($('product-quantity-'+product_id).value), 2 );
} // end function update_product

function add_timetrack( timetrack_id ) {
	new Ajax.Updater( 'Timetracks', '_timetracks.html', {
			parameters: {
				invoice_id: invoice_id,
				timetrack_id: timetrack_id,
				action: 'add'
			},
			onComplete: function(transport) {
				update_totals();
				TableKit.reload();
			},
			onFailure: function(transport) {
				alert('failure to include');
			}
	} );
} // end function add_timetrack( invoice_id)
function del_timetrack( timetrack_id ) {
	new Ajax.Updater( 'Timetracks', '_timetracks.html', {
			parameters: {
				invoice_id: invoice_id,
				timetrack_id: timetrack_id,
				action: 'remove'
			},
			onComplete: function(transport) {
				update_totals();
				TableKit.reload();
			},
			onFailure: function(transport) {
				alert('failure to remove timetrack');
			}
		} );
} // end function del_timetrack(invoice_id)
function add_order( order_id ) {
	new Ajax.Updater( 'Orders', '_invoiced_orders.html', {
			parameters: {
				invoice_id: invoice_id,
				order_id: order_id,
				action: 'add'
			},
			onComplete: function(transport) {
				update_totals();
				TableKit.reload();
			},
			onFailure: function(transport) {
				alert('failure to include');
			}
	} );
} // end function add_order( invoice_id)
function del_order( order_id ) {
	new Ajax.Updater( 'Orders', '_invoiced_orders.html', {
			parameters: {
				invoice_id: invoice_id,
				order_id: order_id,
				action: 'remove'
			},
			onComplete: function(transport) {
				update_totals();
				TableKit.reload();
			},
			onFailure: function(transport) {
				alert('failure to remove timetrack');
			}
		} );
} // end function del_order(invoice_id)

function invoicee_change(ddm) {
	new Ajax.Request( '_invoicee_onchange.json', { parameters: { invoice_id: invoice_id, invoicee_id: ddm.getValue() } } );
	if ( invoice_id ) {
		new Ajax.Updater( 'Timetracks', '_timetracks.html', {
		   parameters: {
					invoice_id: invoice_id,
					invoicee_id: ddm.getValue() 
			   },
				onComplete: function(transport) {
					update_totals();
					TableKit.reload();
				},
				onFailure: function(transport) {
					alert('failure to include');
				}
		} );
		new Ajax.Updater( 'Orders', '_invoiced_orders.html', {
			parameters: {
				invoice_id: invoice_id,
				invoicee_id: ddm.getValue() 
			},
			onComplete: function(transport) {
				update_totals();
				TableKit.reload();
			},
			onFailure: function(transport) {
				alert('failure to include');
			}
		} );
	} // end if invoice_id
} // end function invoicee_change(ddm)
