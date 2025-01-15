// From now on this file should only have stuff related to paper in it

function body_onLoad() {
	if ( typeof(selectProjectTemplate) == 'function' ) {
		selectProjectTemplate( 'f1' );
	} else if ( typeof(calc) == 'function' ) {
		calc('f1');
	} // end if
} // end function body_onLoad();

function paper_price_calc( element, group ) {
  console.log(element);
	var form = element.form;
	if ( ! form ) 
		console.log( 'no form' );
	if ( element.name.match( /^StockPricePerM/ ) ) {
		var costperm = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
		if ( get_value( form.elements['StockType'+group] ) == 'Roll' ) {
			var wpsi = form.elements['basis_mweight'+group].value / (form.elements['basis_width'+group]*form.elements['basis_height'+group]);
			var area = form.elements['txtSpecificStockWidth'+group].value * form.elements['txtSpecificStockHeight'+group].value;
			form.elements['CustomStockPrice'+group].value = do_decimals( costperm / (wpsi * area * 1000), 2);
		} else {
			if ( form.elements['txtCustomMWeight'+group].value ) {
				form.elements['CustomStockPrice'+group].value = do_decimals( costperm / (form.elements['txtCustomMWeight'+group].value / 100), 2 );
			} // end if
		} // end if
	} else {
		var costcwt = parseFloat( element.value.replace(/[^\d\-\.]/g, '' ) );
    
    const type = get_value( form.elements['StockType'+group] );
    console.log(type);
		if (type == 'Roll') {
			return;
		} else {
			if ( ! form.elements['txtCustomMWeight'+group].value ) {
				$j('#PaperAlert'+group).html('Please enter MWeight');
				return;
			} // end if

			form.elements['StockPricePerM'+group].value = do_decimals( costcwt * form.elements['txtCustomMWeight'+group].value / 100, 2 );
		} // end if
	} // end if
} // end function

function calc_basis_weight_from_weight(weight_element) {
  let re = /([\d\.]+)lb/i;
  let matches = re.exec(weight_element.value);
  if (matches) {
    const weight = matches[1];
    re = /^txtSpecificStockWeight(\d*)$/;
    matches = re.exec(weight_element.name);
    const signature = matches[1];
    console.log(signature, weight);
    const form = weight_element.form;
    form.elements['basis_mweight'+signature].value = weight * 2;
    mweight_to_gsm(form, signature);
    calc(form.name);
  } else {
    console.log("No match against "+weight_element.value);
  }
}

function mweight_to_gsm( form, signature ) {
	var width;
	var height;
	var mweight;
	if ( get_value( form.elements['StockType'+signature] ) == 'Roll' ) {
		mweight = parseFloat(1*form.elements['basis_mweight'+signature].value);
		width = parseFloat(1*form.elements['basis_width'+signature].value);
		height = parseFloat(1*form.elements['basis_height'+signature].value);
	} else { // sheet
		mweight = parseFloat(1*form.elements['txtCustomMWeight'+signature].value);
		width = parseFloat(1*form.elements['txtSpecificStockWidth'+signature].value);
		height = parseFloat(1*form.elements['txtSpecificStockHeight'+signature].value);
	} // end if
	// mweight is the weight of 1000 sheets, so calc the wpsi and multiply by 703064.5 to get gsm
	//console.log( "wpsi: " + (mweight/1000)/(width*height) );
	var gsm = Math.round((mweight/1000)/(width*height)*70306450)/100;
	form.elements['txtStockGSM'+signature].value = gsm;
}
function gsm_to_mweight( form, signature ) {
	var gsm = parseFloat(1*form.elements['txtStockGSM'+signature].value);
	var width;
	var height;
	var mweight;

	width = parseFloat(1*form.elements['basis_width'+signature].value);
	height = parseFloat(1*form.elements['basis_height'+signature].value);
	mweight = Math.round((gsm/703064.5)*(width*height)*100000)/100;
	form.elements['basis_mweight'+signature].value = mweight;

	width = parseFloat(1*form.elements['txtSpecificStockWidth'+signature].value);
	height = parseFloat(1*form.elements['txtSpecificStockHeight'+signature].value);
	mweight = Math.round((gsm/703064.5)*(width*height)*100000)/100;
	form.elements['txtCustomMWeight'+signature].value = mweight;
}

function ddmStockSheetSize_onchange() {
	calc('f1');
} // end function ddmStockSheetSize_onchange();
