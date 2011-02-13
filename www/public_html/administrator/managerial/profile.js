
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
	new Ajax.Request( '_field_tr.html', { 
			method: 'get', 
			parameters: { 
				action: 'Add'
			},
			onSuccess: function( transport ) {
				$('fields').insert({top: transport.responseText} );
			}
		} 
	);
} // end function newField
function copyField( id ) {
	var form = $('f1');
	new Ajax.Request( '_field_tr.html', { 
			parameters: { 
				field_id: id,
				action: 'Copy',
				required: get_value(form.elements['required-'+id])
			},
			onSuccess: function( transport ) {
				$('field_'+ id).insert({after: transport.responseText} );
			}
		} 
	);
}
function delField( id ) {
	new Ajax.Request('_field_tr.html', 
		{ 
			method: 'get', 
			parameters: { 
				field_id: id,
				action: 'Delete'
			},
			onSuccess: function( transport ) {
				if ( transport.responseText ) {
					alert( transport.responseText );
				} else {
					var tr = $('field_'+id); tr.parentNode.removeChild(tr);
				} // end if
			}
		} 
	);
}

function upField( field_id ) {
	new Ajax.Updater('fields','_user_fields_tbody.html', { 
			method: 'get', 
			parameters : { action: 'up', field_id: field_id }
		}
	);
} // end function upField
