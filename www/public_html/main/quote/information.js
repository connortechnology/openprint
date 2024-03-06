function remove_product(button) {
  console.log('remove_product clicked');
  const data = $j(button.form).serialize();
  const product_id = button.getAttribute('data_product_id');
  $j.ajax({
    url: '_products.html?action=del&product_id='+product_id,
    data: data
  }).done(function(data) {
    console.log(data);
    $j('#Products').html(data);
    update_event_bindings();
    tinyMCE.init({
      mode : "specific_textareas",
      editor_selector : "mce",
      theme : "simple"
    });
  });
}

function add_product(button) {
  console.log('add_product clicked');
  const data = $j(button.form).serialize();
  $j.ajax({
    url: '_products.html?action=add',
    data: data
  }).done(function(data) {
    $j('#Products').html(data);
    update_event_bindings();
    tinyMCE.init({
      mode : "specific_textareas",
      editor_selector : "mce",
      theme : "simple"
    });
  });
}

window.addEventListener('DOMContentLoaded',function(){
  tinyMCE.init({
    mode : "specific_textareas",
    editor_selector : "mce",
    theme : "simple"
  });
});

function company_onchange( e ) {
  new Ajax.Request( '_company_information.json', { parameters: { company_id: e.value } } );
} // end function
function user_onchange( e ) {
  new Ajax.Request( '_user_information.json', { parameters: { user_id: e.value } } );
} // end function
