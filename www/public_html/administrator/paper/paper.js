
function mweight_to_gsm( form ) {
	var mweight;
	var width;
	var height;
	if ( get_value( form.elements['type'] ) == 'Roll' ) {
		mweight = parseFloat(1*form.elements['basis_mweight'].value);
		width = parseFloat(1*form.elements['basis_width'].value);
		height = parseFloat(1*form.elements['basis_height'].value);
	} else { // sheet
		mweight = parseFloat(1*form.elements['mweight'].value);
		width = parseFloat(1*form.elements['width'].value);
		height = parseFloat(1*form.elements['height'].value);
	} //e nd if

	var gsm = Math.round((mweight/1000)/(width*height)*70306450)/100;
	form.elements['gsm'].value = gsm;
}
function gsm_to_mweight( form ) {
	var gsm = parseFloat(1*form.elements['gsm'].value);
	var width;
	var height;
	var mweight;

	width = parseFloat(1*form.elements['basis_width'].value);
	height = parseFloat(1*form.elements['basis_height'].value);
	mweight = Math.round((gsm/703064.5)*(width*height)*100000)/100;
	form.elements['basis_mweight'].value = mweight;

	width = parseFloat(1*form.elements['width'].value);
	height = parseFloat(1*form.elements['height'].value);
	mweight = Math.round((gsm/703064.5)*(width*height)*100000)/100;
	form.elements['mweight'].value = mweight;
}

function calc_price( element ) {
	var matches;
	if ( matches = element.name.match( /^costcwt-(.*)$/ ) ) {
		var index = matches[1];
		var costcwt = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var markup = parseFloat(1*element.form.elements['markup-'+index].value.replace(/[^\d\-\.]/g, '' )) /100;
		var pricecwt = costcwt * ( 1 + markup );
		element.form.elements['pricecwt-'+index].value = do_decimals( pricecwt, 2 ); 

		if ( element.form.elements['mweight'] && element.form.elements['mweight'].value ) {
			element.form.elements['costperm-'+index].value = do_decimals( costcwt * element.form.elements['mweight'].value / 100, 2 );
			element.form.elements['priceperm-'+index].value = do_decimals( pricecwt * element.form.elements['mweight'].value / 100, 2 );
		} else if ( element.form.elements['wpsi'] ) {
			element.form.elements['costperm-'+index].value = do_decimals( costcwt * element.form.elements['wpsi'].value * element.form.elements['width'].value * element.form.elements['height'].value * 1000, 2);
			element.form.elements['priceperm-'+index].value = do_decimals( pricecwt * element.form.elements['wpsi'].value * element.form.elements['width'].value * element.form.elements['height'].value * 1000, 2);
		} // end if
	} else if ( matches = element.name.match( /costperm-(.*)/ ) ) {
		var index = matches[1];
		var costperm = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var markup = parseFloat(1*element.form.elements['markup-'+index].value.replace(/[^\d\-\.]/g, '' )) /100;
		var priceperm = costperm * ( 1 + markup );
		element.form.elements['priceperm-'+index].value = do_decimals( priceperm, 2 ); 

		if ( element.form.elements['mweight'] && element.form.elements['mweight'].value ) {
			element.form.elements['costcwt-'+index].value = do_decimals( costperm / (element.form.elements['mweight'].value / 100), 2 );
			element.form.elements['pricecwt-'+index].value = do_decimals( priceperm / (element.form.elements['mweight'].value / 100), 2 );
		} else if ( element.form.elements['wpsi'] )  {
			element.form.elements['costcwt-'+index].value = do_decimals( costperm / (element.form.elements['wpsi'].value * element.form.elements['width'].value * element.form.elements['height'].value * 1000), 2);
			element.form.elements['pricecwt-'+index].value = do_decimals( priceperm / (element.form.elements['wpsi'].value * element.form.elements['width'].value * element.form.elements['height'].value * 1000), 2);
		} // end if
	} else if ( matches = element.name.match( /markup-(.*)/ ) ) {
		var index = matches[1];

		var markup = parseFloat( 1*(element.value.replace(/[^\d\-\.]/g, '' ) ) );

		var costcwt = parseFloat( element.form.elements['costcwt-'+index].value.replace(/[^\d\-\.]/g, '' ) );
		if ( costcwt != '' ) {
			var newvalue = costcwt * ( markup/100 + 1 );
			element.form.elements['pricecwt-'+index].value = do_decimals( newvalue, 2 );
		} // end if
		if ( element.form.elements['costperm-'+index] ) {
			var costperm = parseFloat( element.form.elements['costperm-'+index].value.replace(/[^\d\-\.]/g, '' ) );
			if ( costperm != '' ) {
				var newvalue = costperm * ( markup/100 + 1 );
				element.form.elements['priceperm-'+index].value = do_decimals( newvalue, 2 );
			} // end if
		} // end if
	} else if ( matches = element.name.match( /pricecwt-(.*)/ ) ) {
		var index = matches[1];

		var costcwt = parseFloat(element.form.elements['costcwt-'+index].value.replace(/[^\d\-\.]/g, '' ) );
		var price = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		if ( costcwt ) {
			element.form.elements['markup-'+index].value = do_decimals( ((price / costcwt)-1)*100, 2 );
		
			if ( element.form.elements['priceperm-'+index] ) {
				element.form.elements['priceperm-'+index].value = do_decimals( element.form.elements['costperm-'+index].value * ( 1 + element.form.elements['markup-'+index].value/100), 2 );
			} // end if
		} // end if
	} else if ( matches = element.name.match( /priceperm-(.*)/ ) ) {
		var index = matches[1];

		var priceperm = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var costperm = parseFloat(element.form.elements['costperm-'+index].value.replace(/[^\d\-\.]/g, '' ) );
		if ( costperm ) {
			element.form.elements['markup-'+index].value = do_decimals( ((price / costperm)-1)*100, 2 );
			element.form.elements['pricecwt-'+index].value = do_decimals( element.form.elements['costcwt-'+index].value * ( 1 + element.form.elements['markup-'+index].value/100), 2 );
		} // end if
	} // end if
} // end function
