function selectProjectTemplate( formName ) {
	var form = getFormObj( formName );
	var ddm = form.ddmProjectSize;
	if ( ddm ) {
		var TemplateType = get_value( form.rdbTemplateType );
		var selected_size = get_value( form.ddmProjectSize );
		clear_ddm(ddm);
		if ( TemplateType ) {
			if ( options[TemplateType] ) {
				for ( var x = 0; x < options[TemplateType].length; x++ ) {
					var value = options[TemplateType][x].value;
					var text = options[TemplateType][x].text;
					add_option( ddm, options[TemplateType][x].text, options[TemplateType][x].value );
				} // end for
			} else {
				if ( ! TemplateType ) {
					alert("We do not have dimensions for the selected project template at this time.\n\nPlease select custom in the size pull down and input your finished and flat dimensions in the supplied text boxes.");	
				} // type
			} // end if
		} // end if TemplateType
		add_option( form.ddmProjectSize, 'Custom','Custom' );
		ddm_select_by_value( form.ddmProjectSize, selected_size );
		ddmProjectSize_onChange( form );
	} else {
		calc(formName);
	} // end if ddm
} // end function selectProjectTemplate( form );

function ddmProjectSize_onChange( form ) {
	var index = form.ddmProjectSize.selectedIndex;
	if (form.ddmProjectSize.options[index]&& form.ddmProjectSize.options[index].value != 'Custom' ) {
		var dimensions = form.ddmProjectSize.options[form.ddmProjectSize.selectedIndex].value.split(',');
		var finished = dimensions[0].split('x');
		var flat = dimensions[1].split('x');
		form.txtFinalWidth.value = finished[0];
		form.txtFinalHeight.value = finished[1];
		form.txtWidth.value = flat[0];
		form.txtHeight.value = flat[1];
	} // end if
	calc( form.name );
} // end function ddmProjectSize_onChange();

