function order_action(command) {
  jQuery('#Results').load('_history.html?btnFunction='+command, { order_id: get_value( $('f2').order_id ) } );
}
