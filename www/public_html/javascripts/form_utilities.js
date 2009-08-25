function isin ( array, value ) {
	if ( array ) {
		for ( var i = 0; i < array.length; i += 1 ) {
			if ( array[i] == value ) 
				return true;
		} // end for
	} else {
		//alert("Array has no properties. " + array + ": value: " + value );
	} // end if
	return false;
} // end function isin

function get_value( obj ) {
	if ( ! obj ) {
		return;
	} // end if
	if ( obj.type == 'select-one' ) {
		return get_ddm_value( obj );
	} else if ( obj.type == 'radio' ) {
		return get_rdb_value( obj.form, obj.name );
	} else if ( obj.type == 'hidden' || obj.type == 'text' ) {
		return obj.value;
	} else if ( obj.length ) {
		for ( var x = 0; x < obj.length; x += 1 ) {
			if ( obj[x].checked )
				return obj[x].value;
		}
	} else {
		return obj.innerHTML;
	} // end if
	return obj.value;
}

function get_select_value ( ddm ) {
	var selected = new Array();
	if ( ddm ) {
		for ( var index = 0; index < ddm.options.length; index += 1 ) {
			if ( ddm.options[index].selected ) {
				selected[selected.length] = ddm.options[index].value;
			} // end if
		} // end for
	} else {
		alert("null ddm passsed to get_select_value");
	} // end if
	return selected;
} // end function get_select_value

function set_rdb_value( rdb, value ) {
	for ( var x = 0; x < rdb.length; x ++ ) {
		if ( rdb[x].value == value ) {
			rdb[x].checked = true;
		} else {
			rdb[x].checked = false;
		} // end if
	} // end for
}

function get_rdb_value( rdb ) {
	if ( ! rdb ) {
		alert( "Radio button not found");
	} else {
		for ( var x = 0; x < rdb.length; x ++ ) {
			if ( rdb[x].checked == true ) {
				return rdb[x].value;
			} // end if
		} // end for
	} // end if
	return null;
} // end function

function fill_ddm ( ddm, options, onchange ) {
	if ( ddm ) {
		ddm.disabled = true;
		//ddm.onchange = null;
		clear_ddm( ddm );
		for( var index = 0; index < options.length; index += 1 ) {
			ddm.options[ddm.options.length] = create_option( options[index].value, options[index].text );
		} // end for
		//ddm.onchange = onchange;
		ddm.disabled = false;
	} // end if
} // end function fill_ddm

function clear_ddm ( ddm ) {

	if ( ddm ) {
		var disabled = ddm.disabled;
		if ( ! disabled ) {
			ddm.disabled = true;
		} // end if

		if ( ddm.options ) {
			for ( var index = ddm.options.length; index >= 0; index -- ) {
				// this last if eliminates the mac problem.
				if (ddm.options[index])
					ddm.options[index] = null;
			} // end for
		} else {
			alert("clear_ddm: null ddm.options");
		}
		ddm.selectedIndex = -1;
		ddm.disabled = disabled;
	} else {
		alert("clear_ddm: null ddm " + ddm);
	}
} // end function clear_ddm

function create_option( value, text ) {
	var option = document.createElement("OPTION");
	option.text = text;
	option.value = value;
	return option;
}

function add_option( ddm, value, text, selectedValue ) {
	if ( ddm ) {
			var option = create_option( value, text );
			var index = ddm.options.length;
			ddm.options[index] = option;
			if ( ddm.selectedIndex == -1 || option.value == selectedValue ) {
				ddm.selectedIndex = index;
				option.selected = true;
			} else {
				option.selected = false;
			} // end if
	} else {
		alert('add_option: null ddm ' + ddm);
	} // end if
	return option;
} // end function add_option

function isin_ddm ( array, value ) {
	if ( array ) {
		for ( var i = 0; i < array.length; i += 1 ) {
			if ( array[i].value == value )
				return true;
		} // end for
	} else {
		alert("isin_ddm: null array" );
	}
	return false;
} // end function isin_ddm

function get_option_index ( array, value ) {
	if ( array ) {
		for ( var i = 0; i < array.length; i += 1 ) {
			if ( array[i] && array[i].value == value )
				return i;
		} // end for
	} else {
		alert("get_option_index: null array" );
	}
	return -1;
} // end function get_option_index

function get_ddm_value ( ddm ) {
	var value = "";
	if ( ddm ) {
		if ( ddm.selectedIndex != -1 && ddm.options[ddm.selectedIndex] ) {
				value = ddm.options[ddm.selectedIndex].value;
		} else {
			//alert("No Options: " + ddm.name);
		} // end if
	} else {
		alert("null ddm passed to get_ddm_value : " + ddm);
	} // end if
	return value;
} // end function
function get_ddm_text ( ddm ) {
	if ( ddm ) {
		if ( ddm.selectedIndex != -1 && ddm.options[ddm.selectedIndex] ) {
			return ddm.options[ddm.selectedIndex].text;
		} // end if
	} else {
		alert("null ddm passed to get_ddm_value : " + ddm);
	} // end if
} // end function

function ddm_select_by_index( ddm, index ) {
	if ( ddm ) {
		if ( ddm.type != 'select-one' ) {
			alert( ddm.name + " is not a drop down!" );
			return;
		} // end fi
		if ( index == -1 ) {
			ddm.selectedIndex = -1;
		} else if ( index >= ddm.options.length ) {
			alert("Selecting an index too large!" + index);
		} else {
			//ddm.selectedIndex = index;
			if ( ddm.options[index] ) {
				if ( ddm.selectedIndex != index )
					ddm.selectedIndex = index;
				if ( ! ddm.options[index].selected ) 
					ddm.options[index].selected = true;
			} // end if
		} // end if
	} else {
		alert( "null ddm passed to ddm_select_by_index" );
	} // end if
} // end function ddm_select_by_index( ddm, index );

function ddm_select_by_value( ddm, value, defaultValue ) {
	if ( ddm && ddm.options ) {
		for ( var index = 0; index < ddm.options.length; index += 1 ) {
			if ( ddm.options[index] && (ddm.options[index].value == value) ) {
				ddm_select_by_index( ddm, index );
				return true;
			} // end if
		} // end for
		if ( defaultValue ) {
			ddm_select_by_index( ddm, defaultValue );
			return true;
		} // end nif
	} else {
		alert( "null ddm passed to ddm_select_by_value" );
	} // end if
	return false;
} // end function ddm_select_by_value( ddm, value );
function ddm_select_by_text( ddm, value, defaultValue ) {
	if ( ddm ) {
		for ( var index = 0; index < ddm.options.length; index += 1 ) {
			if ( ddm.options[index] && ddm.options[index].text == value ) {
				ddm_select_by_index( ddm, index );
				return;
			} // end if
		} // end for
		if ( defaultValue ) {
			ddm_select_by_index( ddm, defaultValue );
		} // end nif
	} else {
		alert( "null ddm passed to ddm_select_by_text" );
	} // end if
} // end function ddm_select_by_text( ddm, value );

function filterDDM( filter, ddm ) {
	if ( ! filter.value.length ) {
		ddm.selectedIndex = 0;
		return;
	} // end if
	var chunk1 = filter.value.toLowerCase();
	if ( ddm.selectedIndex > 0 ) {
		for ( var index = ddm.selectedIndex; index; index -= 1 ) {
			var chunk2 = ddm.options[index].text.toLowerCase();
			if ( chunk1 > chunk2 ) {
				ddm.selectedIndex = index;
				break;
			} // end if
		} // end for
	} // end if
	if ( ddm.selectedIndex == 0 && ddm.options.length ) 
		ddm.selectedIndex = 1;
	for ( var index = ddm.selectedIndex; index < ddm.options.length; index += 1 ) {
		var chunk2 = ddm.options[index].text.toLowerCase();
		if ( chunk1 <= chunk2 ) {
			ddm.selectedIndex = index;
			return;
		} // end if
		//} // end if
	} // end for
   // Assumes that the first entry is "SElect One"
	for ( var index = 1; index < ddm.selectedIndex; index += 1 ) {
		var chunk2 = ddm.options[index].text.toLowerCase();
		if ( chunk1 <= chunk2 ) {
			ddm.selectedIndex = index;
			return;
		} // end if
		//} // end if
	} // end for

} // end function filterDDM

function jsrs_FillDDM ( formName, selectName, sql, callback ) {
	var params = new Array();
	params[params.length] = formName;
	params[params.length] = selectName;
	params[params.length] = sql;

	jsrsExecute( '/jsrs.htm', callback, 'openprint::jsrs_handler::fill_ddm', params );
}

function jsrs_cbFillDDM( results ) {
	var form;
	var ddm;
	var selectedValue;
	var options = new Array;

	var pairs = results.split('|');
	for ( var i = 0; i < pairs.length; i += 1 ){
		if ( pairs[i].indexOf('~') != -1 ) {
			var data = pairs[i].split('~');
			if ( data[0] == 'Form' ) {
				form = document.forms[data[1]];
			} else if ( data[0] == 'Select' ) {
				if ( ! form ) {
					alert('No Form!');
				} else {
					ddm = form.elements[data[1]];
					if ( ! ddm ) {
						alert("No ddm: " + data[1] );
					} else {
						selectedValue = get_ddm_value( ddm );
						clear_ddm( ddm );
					} // end if
				} // end if
			} else if ( data[0] == 'Option' ) {
				options[options.length] = pairs[i];
			} else if ( data[0] == 'Selected' ) {
				selectedValue = data[1];
			} // end if
		} // end if
	} // end for
	if ( ddm ) {
		for ( var i=0; i < options.length; i += 1 ) {
				var data = options[i].split('~');
				add_option( ddm, data[1], data[2] );
		} // end for
		ddm_select_by_value( ddm, selectedValue );

	} // end if
	return ddm;
}

/* Added by Antonio */

/*
 *	Pass it the Month and Year and it'll return the number of days within the
 *	specified month. Year is optional. If no year is passed and the month chosen
 *	is February, the default return value is 29.
 */
function returnNumberOfDays(month, year) {
	var numberOfDays;

	if(month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12 ) {
		// January
		numberOfDays = 31;
	} else if(month == 2) {
		// February
		if(isLeapYear(year) && year) {
		 numberOfDays = 29;
		} else {
		 numberOfDays = 28;
		}
	} else if(month == 4 || month == 6 || month == 9 || month == 11 ) {
		// April
		numberOfDays = 30;
	} else {
		numberOfDays = 31;
	}

	return numberOfDays;
}


/*
 *	Pass it a year value and it will return a boolean.
 *	True = Year passed is a leap year
 *	False = Year passed is not a leap year
 */
function isLeapYear(year) {
	var isLeapYear;

	if(year % 4 != 0) {
		isLeapYear = false;
	} else if(year % 400 == 0) {
		isLeapYear = true;
	} else if(year % 100 == 0) {
		isLeapYear = false;
	} else {
		isLeapYear = true;
	}

	return isLeapYear;
}

/*
 *	Pass it the:
 *	1) year (value)
 *	2) month (value)
 *	3) day drop down (object)
 *	4) selected day (value) if any
 *	It will alter the day drop down object to have the proper amount of days.
 *	if specified it will set the default selection to the passed selected day.
 */
function setDaysDropDown(year, month, dayDropDown, selectedDay) {
	selectedDay = parseInt(selectedDay);
	var numberOfDays = returnNumberOfDays(month,year);
	if ( numberOfDays < selectedDay ) {
		selectedDay = numberOfDays;
	} // end if

	if ( dayDropDown.options[dayDropDown.options.length-1].value > numberOfDays ) {
		for ( var i = dayDropDown.options.length-1; i > numberOfDays; i -= 1 ) {
			if ( dayDropDown.options[i].value > numberOfDays ) {	
				dayDropDown.options[i] = null;
			} // end if
		} // end for
	} else if ( dayDropDown.options[dayDropDown.options.length-1].value < numberOfDays ) {
		for ( var i = parseInt(dayDropDown.options[dayDropDown.options.length-1].value); i < numberOfDays; i += 1 ) {
			dayDropDown.options[dayDropDown.options.length] = new Option( i+1, i+1 );
		} // end for
	} // end if

	ddm_select_by_value( dayDropDown, selectedDay );
}

function Serialize( form ) {
	var parameters = new Array();
	for ( var index = 0; index < form.elements.length ; index += 1 ) {
		if ( form.elements[index].type == 'radio' ) {
			if ( form.elements[index].checked == true ) {
				parameters[parameters.length] = form.elements[index].name;
				parameters[parameters.length] = form.elements[index].value;
			} // end if
		} else if ( form.elements[index].type == 'checkbox' ) {
			if ( form.elements[index].checked == true ) {
				parameters[parameters.length] = form.elements[index].name;
				parameters[parameters.length] = form.elements[index].value;
			} // end if
		} else if ( form.elements[index].type == 'select-one' ) {
			if ( form.elements[index].selectedIndex != -1 ) {
				parameters[parameters.length] = form.elements[index].name;
				parameters[parameters.length] = form.elements[index].options[form.elements[index].selectedIndex].value;
			} // end if
		} else if ( form.elements[index].type == 'select-multiple' ) {
			for ( var option_index = 0; option_index < form.elements[index].options.length; option_index += 1 ) {
				if ( form.elements[index].options[option_index].selected ) {
					parameters[parameters.length] = form.elements[index].name;
					parameters[parameters.length] = form.elements[index].options[option_index].value;
				} // end if
			} // end if
		} else if ( form.elements[index].type == 'text' || form.elements[index].type == 'hidden' ||  form.elements[index].type=='textarea') {
			if ( form.elements[index].name ) {
				parameters[parameters.length] = form.elements[index].name;
				parameters[parameters.length] = form.elements[index].value;
			} // end if
		} else {
		} // end if
	} // end for
	return parameters;
} // end function serialize

function select_all( form, element_name, checked ) {
	for ( var i=0; i< form.elements.length; i += 1 ) {
		if ( form.elements[i].name == element_name ) {
			if ( form.elements[i].length ) {
				for ( var j = 0; j < form.elements[i].length; j += 1 ) {
					form.elements[i][j].checked = checked;
				} // end for
			} else {
				form.elements[i].checked = checked;
			} // end if
		} // end if
	} // end for
}

/* Added by Antonio */

function selectAllCheckboxes( masterCheckBox, targetForm ) {
	var i;
	for(i = 0; i < targetForm.length; i++) {
		if(targetForm[i].type == 'checkbox' && targetForm[i].name != masterCheckBox.name) {
		 targetForm[i].checked = masterCheckBox.checked;
		}
	}
}
/* ------------ form scripts ------------ */

function clearSelect( what ) {
		for ( var k = 0; k < what.options.length; k++ ) {
				what.options[k].selected = 0;
				what.options[0].selected = 1;
		} 
}

function clearForm(form) {
	for ( var i=0; i < form.elements.length; i += 1 ) {
		var e = form.elements[i];
		if ( ! e.type )
			continue;
		if ( e.type == 'checkbox' || e.type == 'radio' ) {
			e.checked = '';
		} else if (e.type == 'hidden' || e.type == 'password' || e.type == 'text' || e.type == 'textarea' ) {
			e.value = '';
		} else if ( e.type == 'select-one' ) {
			e.selectedIndex = 0;
			while ( e.selectedIndex > 0 ) {
				e.options[e.selectedIndex].selected = false;
			} // end while
		} else if ( e.type == 'select-multiple' ) {
			while ( e.selectedIndex >= 0 ) {
				e.options[e.selectedIndex].selected = false;
			} // end while
		} else {
			//alert(e.type);
		} // end if
	} // end for
} // end function clearForm(form)

function element_changed( element ) {
	if ( element.type == 'select-one' ) {
		for ( var optionIndex = 0; optionIndex < element.options.length; optionIndex += 1 ) {
			if ( element.options[optionIndex].selected != element.options[optionIndex].defaultSelected ) {
				return true;
			} // end if
		} // end for
		return false;
	} else if ( element.type == 'text' ) {
		return ! element.value == element.defaultValue;	
	} else if ( element.type == 'password' ) {
		return ! element.value == element.defaultValue;	
	} else if ( element.type == 'textarea' ) {
		return ! element.value == element.defaultValue;	
	} else if ( element.type == 'radio' ) {
		return ! element.checked == element.defaultChecked;
	} else if ( element.type == 'checkbox' ) {
		return ! element.checked == element.defaultChecked;
	} // end if
} // end function element_changed

var fmChange = 0;
function changed( form ) {
	for ( var index = 0; index < form.elements.length; index += 1 ) {
		if ( form.elements[index].length ) {
			for ( var subindex = 0; subindex < form.elements[index].length; subindex += 1 ) {
				if ( element_changed( form.elements[index][subindex] ) ) {
					return true;
				} // end if
			} // end for
		} else {
			if ( element_changed( form.elements[index] ) ) {
				return true;
			} // end if
		} // end if
	} // end for
	return false;
} // end function changed

function fmCheck( form ) {
	if ( $('ButtonsTop') ) $('ButtonsTop').hide();
	if ( $('ButtonsBottom') ) $('ButtonsBottom').hide();
	if ( fmChange == 1 ) {
		if ( ( ! changed(form) ) || confirm("Are you sure you want to leave this record without saving your changes?") ) {
			fmChange == 0;
			form.submit();
		} 
	} else if (fmChange == 2) {
		fmChange = 0;
		if ( confirm("Are you sure you want to delete this record?") ) {
			form.submit();
		} 
	} else if (fmChange == 3) {
		fmChange = 0;
		if ( confirm("Are you sure you want to save your changes?") ) {
			form.submit();
		} 
	} else if ( form.btnFunction && form.btnFunction.value == 'Undelete' ) {
		fmChange = 0;
		if ( confirm("Are you sure you want to undelete this company?") ) {
			form.submit();
		} 
	} else {
		form.submit();
	}
	if ( $('ButtonsTop') ) $('ButtonsTop').show();
	if ( $('ButtonsBottom') ) $('ButtonsBottom').show();
}

function addCheck(form) {
	if (fmChange == 1) {
		if (confirm("Are you sure you want to create a new record, without saving your changes")) {
			clearForm(form);
		}
	} else { 
		clearForm(form);
	}
}

function submitCheck() {
	if (fmChange == 1) {
		return confirm("Are you sure you want to reset this record without saving your changes?");
	}
}


function summary(summaryPage) {
var summaryPage;
window.open(summaryPage,'pop','newWin,left=140,width=640,top=50,height=400,resizable=yes,scrollbars=yes,menubar=no,toolbar=yes,location=no,directories=yes,status=yes');
}

function checkInputData( inputItem ) {
	 if ( inputItem && inputItem.value ) {
			// Value exists.
		return true;
	 } // end if
	 // No value!
	 return false;
}

function checkLoginData( usernameInput, passwordInput ) {
	if( ! checkInputData(usernameInput) ) {
		// Display login name error.
		add_div( 'missingLoginMessage' );
		usernameInput.focus();
		return false;
	} else {
		remove_div( 'missingLoginMessage' );
	}

	if( passwordInput && !checkInputData(passwordInput) ) {
		// Display login password error.
		add_div( 'missingPasswordMessage' );
		passwordInput.focus();
		return false;
	} else {
		remove_div( 'missingPasswordMessage' );
	}

	usernameInput.form.submit();
	return false;
}

function checkForgotPasswordData ( emailInput )
{
	 var pass = 1;
	 
	 if( !checkInputData( emailInput ) )
	 {
			// Display email error.
			document.getElementById('forgotPassword_missingEmailMessage').style.display = 'block';
			pass *= 0;
	 }
	 else
	 {
			document.getElementById('forgotPassword_missingEmailMessage').style.display = 'none';
	 }

	 if( pass )
	 {
			// Passed. Submit the form and it's data.
			document.f2.submit();
			return false;
	 }	 
}

function showHideDiv(divId, formTrigger)
{
	 if(formTrigger == true)
	 {
			document.getElementById(divId).style.display='block';
	 }
	 else
	 {
			document.getElementById(divId).style.display='none';
	 }
}

function toggleMenu( element, a, b ) {
	if ( ! element )
		return;

	if ( element.className == a ) {
		element.className = b;
	} else {
		element.className = a;
	} // end if
}

function email_check(str) {

	var at="@"
	var dot="."
	var lat=str.indexOf(at)
	var lstr=str.length
	var ldot=str.indexOf(dot)
	if (str.indexOf(at)==-1){
		 return false
	}

	if (str.indexOf(at)==-1 || str.indexOf(at)==0 || str.indexOf(at)==lstr){
		 return false
	}

	if (str.indexOf(dot)==-1 || str.indexOf(dot)==0 || str.indexOf(dot)==lstr){
			return false
	}

	 if (str.indexOf(at,(lat+1))!=-1){
			return false
	 }

	 if (str.substring(lat-1,lat)==dot || str.substring(lat+1,lat+2)==dot){
			return false
	 }

	 if (str.indexOf(dot,(lat+2))==-1){
			return false
	 }
	
	 if (str.indexOf(" ")!=-1){
			return false
	 }

	 return true					
}

function addLoadEvent(func) {
	var oldonload = window.onload;
	if (typeof window.onload != 'function') {
		window.onload = func;
	} else {
		window.onload = function() {
			if ( oldonload ) oldonload();
			func();
		}
	}
}

function Country_onchange( country_ddm, state ) {
	var country = get_ddm_value( country_ddm );
	var state_label = $(country_ddm.name + '_state');
	var postal_label = $(country_ddm.name + '_postal');
	if ( country == 'US' ) {
		jsrs_FillDDM( country_ddm.form.name, state.name, "('',' Select ', @states::states )", jsrs_cbFillDDM );
		if ( state_label ) state_label.innerHTML='State:';
		if ( postal_label ) postal_label.innerHTML='ZIP Code:';
	} else if ( country == 'CA' ) {
		jsrs_FillDDM( country_ddm.form.name, state.name, "('',' Select ', @provinces::provinces )", jsrs_cbFillDDM );
		if ( state_label ) state_label.innerHTML='Province:';
		if ( postal_label ) postal_label.innerHTML='Postal Code:';
	} else {
		if ( state_label ) state_label.innerHTML='State/Province:';
		if ( postal_label ) postal_label.innerHTML='Postal Code:';
	} // end if
} // end function

function countLines(strtocount, cols) {
	var hard_lines = 1;
	var last = 0;
	while ( true ) {
		last = strtocount.indexOf("\n", last+1);
		if ( last == -1 ) break;
		hard_lines ++;
	}
	var soft_lines = Math.round(strtocount.length / (cols-1));
	var hard = eval("hard_lines  " + unescape("%3e") + "soft_lines;");
	if ( hard ) soft_lines = hard_lines;
	return soft_lines;
}

function textarea_resize( element ) {
	element.rows = countLines(element.value,element.cols);
} // end function textarea_resize

function set_today( e_y, e_m, e_d, e_h, e_min ) {
	var d = new Date();
	ddm_select_by_value( e_y, 1900+d.getYear() );
	ddm_select_by_value( e_m, d.getMonth()+1 );
	ddm_select_by_value( e_d, d.getDate() );
	if ( e_h )
		ddm_select_by_value( e_h, d.getHours() );
	if ( e_min )
		ddm_select_by_value( e_min, d.getMinutes() );
} // end function set_today

Ajax.Autocompleter.extract_value = 
function (value, className) {
	var result;

	var elements = 
		document.getElementsByClassName(className, value);
	if (elements && elements.length == 1) {
		result = elements[0].innerHTML.unescapeHTML();
	}

	return result;
};
function check_time_starting( form, starting_prefix, ending_prefix ) {
    var start;
    var end;

    if ( get_value( form.time_associated ) == 1 ) {
        start = new Date( form.elements[starting_prefix+'_year'].value, form.elements[starting_prefix+'_month'].value, form.elements[starting_prefix+'_day'].value, form.elements[starting_prefix+'_hour'].value, form.elements[starting_prefix+'_minute'].value );
        end = new Date( form.elements[ending_prefix+'_year'].value, form.elements[ending_prefix+'_month'].value, form.elements[ending_prefix+'_day'].value, form.elements[ending_prefix+'_hour'].value, form.elements[ending_prefix+'_minute'].value );
    } else {
        start = new Date( form.elements[starting_prefix+'_year'].value, form.elements[starting_prefix+'_month'].value, form.elements[starting_prefix+'_day'].value );
        end = new Date( form.elements[ending_prefix+'_year'].value, form.elements[ending_prefix+'_month'].value, form.elements[ending_prefix+'_day'].value );
    } // end if

    if ( start > end ) {
        ddm_select_by_value( form.elements[ending_prefix+'_year'], form.elements[starting_prefix+'_year'].value );
        ddm_select_by_value( form.elements[ending_prefix+'_month'], form.elements[starting_prefix+'_month'].value );
        ddm_select_by_value( form.elements[ending_prefix+'_day'], form.elements[starting_prefix+'_day'].value );
        if ( get_value( form.time_associated ) == 1 ) {
            ddm_select_by_value( form.elements[ending_prefix+'_hour'], form.elements[starting_prefix+'_hour'].value );
            ddm_select_by_value( form.elements[ending_prefix+'_minute'], form.elements[starting_prefix+'_minute'].value );
        } // end if
    } // end if
} // end function check_time_starting

function check_time_ending( form, starting_prefix, ending_prefix ) {
    var start;
    var end;
    if ( get_value( form.time_associated ) == 1 ) {
        start = new Date( form.elements[starting_prefix+'_year'].value, form.elements[starting_prefix+'_month'].value, form.elements[starting_prefix+'_day'].value, form.elements[starting_prefix+'_hour'].value, form.elements[starting_prefix+'_minute'].value );
        end = new Date( form.elements[ending_prefix+'_year'].value, form.elements[ending_prefix+'_month'].value, form.elements[ending_prefix+'_day'].value, form.elements[ending_prefix+'_hour'].value, form.elements[ending_prefix+'_minute'].value );
    } else {
        start = new Date( form.elements[starting_prefix+'_year'].value, form.elements[starting_prefix+'_month'].value, form.elements[starting_prefix+'_day'].value );
        end = new Date( form.elements[ending_prefix+'_year'].value, form.elements[ending_prefix+'_month'].value, form.elements[ending_prefix+'_day'].value );
    } // end if
    if ( start > end ) {
        ddm_select_by_value( form.elements[starting_prefix+'_year'], form.elements[ending_prefix+'_year'].value );
        ddm_select_by_value( form.elements[starting_prefix+'_month'], form.elements[ending_prefix+'_month'].value );
        ddm_select_by_value( form.elements[starting_prefix+'_day'], form.elements[ending_prefix+'_day'].value );
        if ( get_value( form.time_associated ) == 1 ) {
            ddm_select_by_value( form.elements[starting_prefix+'_hour'], form.elements[ending_prefix+'_hour'].value );
            ddm_select_by_value( form.elements[starting_prefix+'_minute'], form.elements[ending_prefix+'_minute'].value );
        } // end if
    } // end if
} // end function check_time_ending

function update_duration(form, starting_prefix, ending_prefix ) {
    if ( get_value( form.time_associated ) == 1 ) {
        var start = new Date( form.elements[starting_prefix+'_year'].value, form.elements[starting_prefix+'_month'].value, form.elements[starting_prefix+'_day'].value, form.elements[starting_prefix+'_hour'].value, form.elements[starting_prefix+'_minute'].value );
        var end = new Date( form.elements[ending_prefix+'_year'].value, form.elements[ending_prefix+'_month'].value, form.elements[ending_prefix+'_day'].value, form.elements[ending_prefix+'_hour'].value, form.elements[ending_prefix+'_minute'].value );
        var difference = parseInt( ( end - start ) / 1000 );
        var days = parseInt(difference/(60*60*24));
        difference -= days * ( 60*60*24 );
        var hours = parseInt( difference/(60*60) );
        difference -= hours * (60*60);
        var minutes = parseInt( difference/60 );
        $('duration').innerHTML = days+'days ' + hours+'hours ' + minutes + 'minutes';
    } else {
        var start = new Date( form.elements[starting_prefix+'_year'].value, form.elements[starting_prefix+'_month'].value, form.elements[starting_prefix+'_day'].value );
        var end = new Date( form.elements[ending_prefix+'_year'].value, form.elements[ending_prefix+'_month'].value, form.elements[ending_prefix+'_day'].value );
        var difference = parseInt( ( end - start ) / 1000 );
        var days = parseInt(difference/(60*60*24));
        $('duration').innerHTML = days +'days';
    } // end if
} // end function update_duration

function setup_ie_menu() {
	if (document.all && document.getElementById) {
		var navRoot = document.getElementById("menubar");
		if ( navRoot ) {
			for ( var i=0; i<navRoot.childNodes.length; i+= 1 ) {
				var node = navRoot.childNodes[i];
				if (node.nodeName=='LI') {
					node.onmouseover=function() {
						this.className+=' over';
					}
					node.onmouseout=function() {
						this.className=this.className.replace(' over', '');
					}
				} // end if
			} // end for
		} // end if
	}
} // end function setup_ie_menu
