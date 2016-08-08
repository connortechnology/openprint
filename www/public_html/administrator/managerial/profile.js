
function check_field( element ) {
	var form = element.form;
	var matches;
	if ( matches = element.name.match( /^\w+\-(\d+)$/ ) ) {
		var id = matches[1];
		if ( 
			element_changed( form.elements['required-'+id] ) ||
			element_changed( form.elements['name-'+id] ) ||
			element_changed( form.elements['type-'+id] ) ||
			element_changed( form.elements['values-'+id] ) 
		   ) {
			$('field_'+id).addClassName('changed');
		} else {
			$('field_'+id).removeClassName('changed');
		} // end if
	} else {
		alert('Not matched' + element.name);
	} // end if
} // end function check_field 

function newField( ) {
	jQuery.ajax( '_field_tr.html', { 
			data: { 
				action: 'Add'
			} } ).done( function( html ) {
				$('#fields').insert({top: html });
			});
} // end function newField
function copyField( id ) {
	var form = jQuery('#f1')[0];
	jQuery.ajax( '_field_tr.html', { 
			data: { 
				field_id: id,
				action: 'Copy',
				required: get_value(form.elements['required-'+id])
			} } ).done(
			function( transport ) {
				$('#field_'+ id).insert({after: transport.responseText} );
			}
	);
}
function delField( id ) {
	jQuery.ajax('_field_tr.html', 
		{ 
			data: { 
				field_id: id,
				action: 'Delete'
			},
		} ).done(
			function( html ) {
				if ( html ) {
					alert( html );
				} else {
					var tr = $('#field_'+id); tr.parentNode.removeChild(tr);
				} // end if
			}
		} 
	);
}

function upField( field_id ) {
	jQuery('#fields'.load('_user_fields_tbody.html', { action: 'up', field_id: field_id } );
} // end function upField
