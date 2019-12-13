
function calc_from_exchange(form) {
  if ( form.amount.value && form.amount_locked.checked ) {
    form.value.value = form.amount.value * form.exchange.value;
  } else if ( form.value.value && form.value_locked.checked ) {
    form.amount.value = form.value.value / form.exchange.value;
  }
}

function calc_exchange_from_value(form) {
  form.exchange.value = form.value.value / form.amount.value;
}

function pay_invoice( invoice_id ) {
  $j.ajax({
    url: '_paid.html',
    data: { 'payment_id': payment_id, 'invoice_id': invoice_id },
    dataType: 'html',
    success: function(html) {
      $j('#Paid').html(html);
      load_unpaid();
    },
    error: function(e){
      alert('failure to pay');
    }
  } );
}  // end function pay_invoice( invoice_id)

function unpay_invoice( invoice_id ) {
  $j.ajax({
    url: '_unpaid.html',
    data: { 'payment_id': payment_id, 'invoice_id': invoice_id },
    dataType: 'html',
    success: function(html) {
      $j('#Unpaid').html(html);
      load_paid();
    },
    error: function(e){
      alert('failure to unpay');
    }
  } );
}  // end function unpay_invoice(invoice_id)

function load_paid( ) {
  $j.ajax({
    url: '_paid.html',
    data: { 'payment_id': payment_id },
    dataType: 'html',
    success: function(html) {
      $j('#Paid').html(html);
    },
    error: function(e){
      alert('failure to load paid');
    }
  } );
}  // end function load_paid

function load_unpaid( ) {
  $j.ajax({
    url: '_unpaid.html',
    data: { 'payment_id': payment_id },
    dataType: 'html',
    success: function(html) {
      $j('#Unpaid').html(html);
    },
    error: function(e){
      alert('failure to load unpaid');
    }
  } );
}  // end function load_unpaid()
