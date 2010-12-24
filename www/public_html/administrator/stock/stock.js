
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
function CommaFormatted(amount)
{
	var delimiter = ","; // replace comma if desired
	var a = amount.split('.',2)
	var d = a[1];
	var i = parseInt(a[0]);
	if(isNaN(i)) { return ''; }
	var minus = '';
	if(i < 0) { minus = '-'; }
	i = Math.abs(i);
	var n = new String(i);
	var a = [];
	while(n.length > 3)
	{
		var nn = n.substr(n.length-3);
		a.unshift(nn);
		n = n.substr(0,n.length-3);
	}
	if(n.length > 0) { a.unshift(n); }
	n = a.join(delimiter);
	if(d.length < 1) { amount = n; }
	else { amount = n + '.' + d; }
	amount = minus + amount;
	return amount;
}
// end of function CommaFormatted()
function CurrencyFormatted(amount)
{
	var i = parseFloat(amount);
	if(isNaN(i)) { i = 0.00; }
	var minus = '';
	if(i < 0) { minus = '-'; }
	i = Math.abs(i);
	i = parseInt((i + .005) * 100);
	i = i / 100;
	s = new String(i);
	if(s.indexOf('.') < 0) { s += '.00'; }
	if(s.indexOf('.') == (s.length - 2)) { s += '0'; }
	s = minus + s;
	return s;
}
// end of function CurrencyFormatted()

function calc_price( element ) {
	var form = element.form;
	var matches;
	if ( matches = element.name.match( /^costcwt-(.*)$/ ) ) {
		var index = matches[1];
		var costcwt = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var markup = parseFloat(1*form.elements['markup-'+index].value.replace(/[^\d\-\.]/g, '' )) /100;
		var pricecwt = costcwt * ( 1 + markup );
		form.elements['pricecwt-'+index].value = do_decimals( pricecwt, 2 ); 

		if ( form.elements['wpsi'] ) {
			if ( form.elements['costperfoot-'+index] ) {
				form.elements['costperfoot-'+index].value = do_decimals( costcwt * form.elements['wpsi'].value * 144 / 100, 2);
				form.elements['priceperfoot-'+index].value = do_decimals( pricecwt * form.elements['wpsi'].value * 144 / 100, 2);
			} // end if
			if ( form.elements['costperm-'+index] ) {
				form.elements['costperm-'+index].value = do_decimals( costcwt * form.elements['wpsi'].value * form.elements['width'].value * form.elements['height'].value * 10, 2);
				form.elements['priceperm-'+index].value = do_decimals( pricecwt * form.elements['wpsi'].value * form.elements['width'].value * form.elements['height'].value * 10, 2);
			} // end if
		} else if ( form.elements['mweight'] && form.elements['mweight'].value ) {
			if ( form.elements['costperm-'+index] ) {
				form.elements['costperm-'+index].value = do_decimals( costcwt * form.elements['mweight'].value / 100, 2 );
				form.elements['priceperm-'+index].value = do_decimals( pricecwt * form.elements['mweight'].value / 100, 2 );
			} // end if
		} // end if
	} else if ( matches = element.name.match( /costperm-(.*)/ ) ) {
		var index = matches[1];
		var costperm = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var markup = parseFloat(1*form.elements['markup-'+index].value.replace(/[^\d\-\.]/g, '' )) /100;
		var priceperm = costperm * ( 1 + markup );
		form.elements['priceperm-'+index].value = do_decimals( priceperm, 2 ); 

		if ( form.elements['wpsi'] )  {
			form.elements['costcwt-'+index].value = do_decimals( costperm / (form.elements['wpsi'].value * form.elements['width'].value * form.elements['height'].value * 10), 2);
			form.elements['pricecwt-'+index].value = do_decimals( priceperm / (form.elements['wpsi'].value * form.elements['width'].value * form.elements['height'].value * 10), 2);
			if ( form.elements['costperfoot-'+index] ) {
			form.elements['costperfoot-'+index].value = do_decimals( costperm / (form.elements['wpsi'].value * 144 * 1000), 2);
			form.elements['priceperfoot-'+index].value = do_decimals( priceperm / (form.elements['wpsi'].value * 144 * 1000), 2);
			} // end if
		} else if ( form.elements['mweight'] && form.elements['mweight'].value ) {
			form.elements['costcwt-'+index].value = do_decimals( costperm / (form.elements['mweight'].value / 100), 2 );
			form.elements['pricecwt-'+index].value = do_decimals( priceperm / (form.elements['mweight'].value / 100), 2 );
		} // end if
	} else if ( matches = element.name.match( /costperfoot-(.*)/ ) ) {
		var index = matches[1];
		var costperfoot = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var wpsi = parseFloat( form.elements['wpsi'].value );
		if ( ! wpsi ) alert( 'No wpsi!' );
		//var costperinch = ( costperfoot/144 ) * 100/wpsi;
		// 100/wpsi = # of inches in 100lbs.
		var costcwt = ( 100 * costperfoot ) / ( 144 * wpsi );
		var costperm = costcwt * wpsi * form.elements['width'].value * form.elements['height'].value * 1000;
		var markup = parseFloat(1*form.elements['markup-'+index].value.replace(/[^\d\-\.]/g, '' )) /100;

		form.elements['priceperfoot-'+index].value = do_decimals( costperfoot * ( 1 + markup ), 2);
		form.elements['costcwt-'+index].value = do_decimals( costcwt, 5 );
		form.elements['pricecwt-'+index].value = do_decimals( costcwt * ( 1 + markup ), 2);
		if ( form.elements['costperm-'+index] ) {
			form.elements['costperm-'+index].value = do_decimals( costperm, 2);
			form.elements['priceperm-'+index].value = do_decimals( costperm * ( 1 + markup ), 2 ); 
		} // end if
	} else if ( matches = element.name.match( /markup-(.*)/ ) ) {
		var index = matches[1];

		var markup = parseFloat( 1*(element.value.replace(/[^\d\-\.]/g, '' ) ) );

		var costcwt = parseFloat( form.elements['costcwt-'+index].value.replace(/[^\d\-\.]/g, '' ) );
		if ( costcwt != '' ) {
			var newvalue = costcwt * ( markup/100 + 1 );
			form.elements['pricecwt-'+index].value = do_decimals( newvalue, 2 );
		} // end if
		if ( form.elements['costperm-'+index] ) {
			var costperm = parseFloat( form.elements['costperm-'+index].value.replace(/[^\d\-\.]/g, '' ) );
			if ( costperm != '' ) {
				var newvalue = costperm * ( markup/100 + 1 );
				form.elements['priceperm-'+index].value = do_decimals( newvalue, 2 );
			} // end if
		} // end if
		if ( form.elements['costperfoot-'+index] && form.elements['priceperfoot-'+index] ) {
			var costperfoot = parseFloat( form.elements['costperfoot-'+index].value.replace(/[^\d\-\.]/g, '' ) );
			form.elements['priceperfoot-'+index].value = do_decimals( costperfoot * ( 1 + markup/100 ), 2);
		} // end if
	} else if ( matches = element.name.match( /pricecwt-(.*)/ ) ) {
		var index = matches[1];

		var costcwt = parseFloat(form.elements['costcwt-'+index].value.replace(/[^\d\-\.]/g, '' ) );
		var price = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		if ( costcwt ) {
			form.elements['markup-'+index].value = do_decimals( ((price / costcwt)-1)*100, 2 );
		
			if ( form.elements['priceperm-'+index] ) {
				form.elements['priceperm-'+index].value = do_decimals( form.elements['costperm-'+index].value * ( 1 + form.elements['markup-'+index].value/100), 2 );
			} // end if
		} // end if
	} else if ( matches = element.name.match( /priceperm-(.*)/ ) ) {
		var index = matches[1];

		var priceperm = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		var costperm = parseFloat(form.elements['costperm-'+index].value.replace(/[^\d\-\.]/g, '' ) );
		if ( costperm ) {
			form.elements['markup-'+index].value = do_decimals( ((price / costperm)-1)*100, 2 );
			form.elements['pricecwt-'+index].value = do_decimals( form.elements['costcwt-'+index].value * ( 1 + form.elements['markup-'+index].value/100), 2 );
			if ( form.elements['costperfoot-'+index] && form.elements['priceperfoot-'+index] ) {
				form.elements['priceperfoot-'+index].value = do_decimals( form.elements['costcwt-'+index].value * ( 1 + form.elements['markup-'+index].value/100), 2 );
			} // end if
		} // end if
	} // end if
} // end function
