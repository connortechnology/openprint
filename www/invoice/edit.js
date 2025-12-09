function update_totals( ) {
	let total;
	const timetrack_total_element = document.getElementById('timetrack_total');
	if (timetrack_total_element) {
		total += parseFloat(timetrack_total_element.innerHTML.replace(/[^\d\.]/g, ''));
	} // end if
	const product_total_element = document.getElementById('product_total');
	if (product_total_element) {
		total += parseFloat(product_total_element.innerHTML.replace(/[^\d\.]/g, ''));
	} // end if
	const order_total_element = document.getElementById('order_total');
	if (order_total_element) {
		total += parseFloat(order_total_element.innerHTML.replace(/[^\d\.]/g,''));
	} // end if

  const subtotal_element = document.getElementById('subtotal');
	if (subtotal_element) {
		subtotal_element.innerHTML = do_decimals(total, 2);
	} else {
		alert('no subtotal');
	} // end if
} // end function

function update_product( product_id ) {
  const total = getElementById('product-total-'+product_id);
  const price = getElementById('product-price-'+product_id);
  const quantity = getElementById('product-quantity-'+product_id);
	total.innerHTML = do_decimals( parseFloat(price.value) * parseFloat(quantity.value), 2 );
} // end function update_product

function add_timetrack(button) {
  const timetrack_id = button.getAttribute('data-id');

  $j.ajax({
    url: '_timetracks.html',
    data: {
      invoice_id: invoice_id,
      timetrack_id: timetrack_id,
      action: 'add'
    },

    success: function(data) {
      $j('#Timetracks').html(data);
      update_event_bindings();
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
    }
  } );
} // end function add_timetrack( invoice_id)

function del_timetrack( button ) {
  const timetrack_id = button.getAttribute('data-id');
  $j.ajax({
    url: '_timetracks.html',
    data: {
      invoice_id: invoice_id,
      timetrack_id: timetrack_id,
      action: 'remove'
    },

    success: function(data) {
      $j('#Timetracks').html(data);
      update_event_bindings();
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
    }
  } );
} // end function del_timetrack(invoice_id)

function reload_timetracks() {
  $j.ajax({
      url: '_timetracks.html',
      data: {
				invoice_id: invoice_id,
        timetrack_start_year: $j('#timetrack_start_year').val(),
        timetrack_start_month: $j('#timetrack_start_month').val(),
        timetrack_start_day: $j('#timetrack_start_day').val(),
        timetrack_end_year: $j('#timetrack_end_year').val(),
        timetrack_end_month: $j('#timetrack_end_month').val(),
        timetrack_end_day: $j('#timetrack_end_day').val(),
			},

      success: function(data) {
        $j('#Timetracks').html(data);
        update_event_bindings();
				update_totals();
				if (typeof TableKit !== 'undefined') TableKit.reload();
      }
    });
} // end function reload_timetracks

function add_order( order_id ) {
  $j.ajax({
    url: '_invoiced_orders.html', 
    data: {
      invoice_id: invoice_id,
      order_id: order_id,
      action: 'add'
    },

    success: function(data) {
      $j('#Orders').html(data);
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
    }
  } );
} // end function add_order( invoice_id)

function del_order( order_id ) {
  $j.ajax({
    url: '_invoiced_orders.html',
    data: {
      invoice_id: invoice_id,
      order_id: order_id,
      action: 'remove'
      },
    success: function(data) {
      $j('#Orders').html(data);
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
    }
  });
} // end function del_order(invoice_id)

function reload_orders() {
  $j.ajax({
    url: '_invoiced_orders.html',
    data: { invoice_id: invoice_id, },
    success: function(data) {
      $j('#Orders').html(data);
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
    }
  });
} // end function del_order(invoice_id)

function invoicee_change(ddm) {
  $j.ajax({
    url: '_invoicee_onchange.js',
    data: {
      invoice_id: invoice_id, 
      invoicee_id: ddm.value
    },
    success: function(data) {
      if ( invoice_id ) {
        reload_timetracks();
        reload_orders();
      } // end if invoice_id
    }
  });
} // end function invoicee_change(ddm)

function add_tax( tax_id ) {
  console.log(tax_id);
  if (tax_id) {
    $j.ajax({
      url: '_taxes_edit.html',
      data: {
        invoice_id: invoice_id,
        tax_id: tax_id,
        action: 'add'
      },
      success: function(data) {
        $j('#Taxes').html(data);
        update_totals();
        if (typeof TableKit !== 'undefined') TableKit.reload();
      }
    });
  }
}

function delete_tax( tax_id ) {
  $j.ajax({
    url: '_taxes_edit.html',
    data: {
      invoice_id: invoice_id,
      tax_id: tax_id,
      action: 'delete'
    },
    success: function(data) {
      $j('#Taxes').html(data);
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
    }
  });
}

function update_taxes( form ) {
  if ( invoice_id ) {
    $j.ajax({
      url: '_taxes_edit.html?action=reset&invoice_id='+invoice_id,
      data: $j(form).serialize(),
      success: function(data) {
        $j('#Taxes').html(data);
        update_totals();
        if (typeof TableKit !== 'undefined') TableKit.reload();
      }
    });
  }
} // end function update_taxes

function del_interest(button) {
  const interest_id = button.getAttribute('data-interest_id');
  if (!interest_id) {
    console.log('No interest id on button');
    console.log(button);
  }
  $j.ajax({
    url: '_interests.html',
    data: { action: 'delete', 'invoice_id': invoice_id, 'interest_id': interest_id },
    success: function(data) {
      $j('#Interests').html(data);
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
      update_event_bindings();
    }
  });
}

function del_product(button) {
  const product_id = button.getAttribute('data-product_id');
  if (!product_id) {
    console.log('No product id on button');
    console.log(button);
  }
  $j.ajax({
    url: '_invoiced_products.html?action=remove&amp;product_id='+product_id,
    method: 'post',
    data: $j('#f1').serialize(),
    success: function(data) {
      $j('#InvoicedProducts').html(data);
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
      update_event_bindings();
    }
  });
}

function add_product(button) {
  $j.ajax({
    url: '_invoiced_products.html?action=add',
    method: 'post',
    data: $j('#f1').serialize(),
    success: function(data) {
      $j('#InvoicedProducts').html(data);
      update_totals();
      if (typeof TableKit !== 'undefined') TableKit.reload();
      update_event_bindings();
    }
  });
}
