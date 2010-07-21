function mweight_to_gsm( form, type_id ) {
	var mweight = parseFloat(1*form.elements['mweight-'+type_id].value);
	var width = parseFloat(1*form.elements['width-'+type_id].value);
	var height = parseFloat(1*form.elements['height-'+type_id].value);
	var gsm = parseInt((mweight/1000)/(width*height)*7030645.0)/10;
	form.elements['gsm-'+type_id].value = gsm;
}
function gsm_to_mweight( form, type_id ) {
	var gsm = parseFloat(1*form.elements['gsm-'+type_id].value);
	var width = parseFloat(1*form.elements['width-'+type_id].value);
	var height = parseFloat(1*form.elements['height-'+type_id].value);
	var mweight = parseInt((gsm/703064.5)*(width*height)*10000)/10;
	form.elements['mweight-'+type_id].value = mweight;
}

function delete_content( c_id ) {
	new Ajax.Request( '_manifest_content.html', {
		method: 'get',
		parameters: { content_id: c_id, action: 'Remove' },
		onSuccess: function(transport){
			var tr = $('tr-'+c_id);
			new Insertion.After('tr-'+c_id, transport.responseText);
			if(!tr){alert('tr not found');}else{tr.parentNode.removeChild(tr);}
		},
		evalScripts: true
	 } );
} // end function delete_conetnt( c_id )

function add_content(form, type_id) {
	new Ajax.Request( '_manifest_content.html', {
			method: 'get', 
			parameters: {
				action:		'Add',
				type_id:    type_id,
				manifest_id: form.manifest_id.value,
				rfidtag_id: $('rfidtag_id-'+type_id+'-').value,
				skid_id:    $('skid_id-'+type_id+'-').value,
				docket:     $('docket-'+type_id+'-').value,
				qty_lbs:    $('qty_lbs-'+type_id+'-').value
			},
			onSuccess: function (transport) { new Insertion.Before('totals-'+type_id, transport.responseText);return true; }, 
			evalScripts: true
		}
	);
}
function manifest_onsubmit(form) {

	var re = /^txtName-(\d+)$/;
	var fields_to_check = ['Manufacturer','Owner','Name','Finish','Colour'];
	for ( var i = 0; i < form.elements.length; i += 1 ) {
		var matches = re.exec( form.elements[i].name );
		
		if ( matches ) {
			var type_id = matches[1];
			for ( var field_index = 0; field_index < fields_to_check.length; field_index += 1 ) {
				var field = fields_to_check[field_index];	
			
				var field_name = field+'-'+type_id;
				if ( ! ( 
					( form.elements['txt'+field_name] && ( form.elements['txt'+field_name].value != '' ) ) || 
					( form.elements[field_name] && ( get_ddm_value( form.elements[field_name] ) != '' ) ) 
				) ) {
					alert( 'Please select the ' + field + ' of the stock.' );
					var div = $(field_name+'_div');
					if ( div ) div.className = 'error';
					return false;
				} // end if
			} // end foreach field
		} // end if
	} // end for each element

	return true;
} // end function manifest_onsubmit
