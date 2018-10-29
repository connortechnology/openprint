
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
