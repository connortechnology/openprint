// The following are GLOBAL variables
var gettingNewPrice = false;
var submitForm = false;

var breakdownWin = new Array();

function show_breakdown( index ) {
	if ( gettingNewPrice )
		return;
    if (breakdownWin[index] == null) {
		breakdownWin[index] = new Window({maximizable: false, resizable: false, hideEffect:Element.hide, showEffect:Element.show, destroyOnClose: false, className:'alphacube', width:600, height:420, recenterAuto:false } );
		breakdownWin[breakdownWin[index]] = index;

		// Set up a windows observer, check ou debug window to get messages
		myObserver = {
			onDestroy: function(eventName, win) {
				if ( win == breakdownWin[breakdownWin[win]] ) {
					breakdownWin[breakdownWin[win]] = null;
					breakdownWin[win] = null;

					win.getContent().hide;
					Windows.removeObserver(this);
				} // end if
			} // onDestroy
		} // myObserver
		Windows.addObserver(myObserver);
	} // end if
	breakdownWin[index].setContent( 'hdnBreakdown'+index, false, false );
	breakdownWin[index].showCenter();
} // end function show_breakdown

function submit_handler( formName ) {
	var form = getFormObj( formName );
	if ( ! form ) {
		return false;
	}
	var AlertDiv = $('AlertDiv');
	if ( AlertDiv && AlertDiv.innerHTML ) {
		var alert_content = AlertDiv.innerHTML;
		alert_content = alert_content.replace(/<br\/?>/g, "\n" );
		if ( ! confirm( "There are unresolved errors:\n\n" + alert_content + "\n\n Click OK to continue saving, or Cancel to stop and fix the problem." ) ) {
			return false;
		} // end if
	} // end if

	if ( gettingNewPrice && ! confirm('The system is still calculating a price.  Click OK to continue saving, or Cancel to wait for the system') ) {
		return false;
	} // end if

	var Status = true;
	if ( typeof(validate_data) == 'function' ) {
		Status = validate_data(formName);
	} // end if

	if (Status) {
		form.submit();
	} // end if
	return Status;

} // end function submit_form

function cbWindowSaveClose( results ) {
	window.close();
} 
var timeout;
var block_calc = false;

function body_onLoad() {
	if ( typeof(selectProjectTemplate) == 'function' ) {
		selectProjectTemplate( 'f1' );
	} else if ( typeof(calc) == 'function' ) {
		calc('f1');
	} // end if
}

function calc( formName, force, options ) {
	if ( block_calc ) return;
	var form = getFormObj( formName );
	if ( form && form.ServiceType ) {
		if ( gettingNewPrice && ! force ) {
			if ( timeout ) clearTimeout( timeout );
			if ( options ) {
				timeout = setTimeout("calc_print('"+formName+"', 0, " + Object.toJSON( options ) + ");", 1000 );	
			} else {
				timeout = setTimeout( "calc('" + formName + "');", 1000 );
			}
		} else {
			timeout = null;
			var AlertDiv = $('AlertDiv');
			if ( AlertDiv ) {
				AlertDiv.innerHTML = '';
				AlertDiv.hide();
			} // end if
			var div = $('InformationDiv');
			if ( div ) {
				div.innerHTML = 'Calculating';
			} // end if
			gettingNewPrice = true;
			clear_price_data( form );
			var data = Form.serialize(form,true);
			var h = $H(data);
			h.each(function(pair) {
					if ( options ) {
						h.merge( options );
					}
					if ( pair.value == '' ) 
						h.unset(pair.key);
					if ( pair.key == 'btnFunction' ) 
						h.unset(pair.key);
					if ( pair.key == 'alert' ) 
						h.unset(pair.key);
					});
			new Ajax.Request( '/main/project/_calc.json', { method: 'post', parameters: h, evalScripts: true } );
		} // end if
	} // end if
} // end calc()

function cbFillResults( results ) {
	block_calc = true;
	var form = getFormObj('f1');
	var AlertDiv = $('AlertDiv');
	if ( AlertDiv ) {
		AlertDiv.innerHTML = '';
		AlertDiv.hide();
	} // end if
	if ( $('InformationDiv') )
		$('InformationDiv').hide();
	var keys = results.keys();

	for ( var index = 0, leni = keys.length; index < leni; index += 1 ) {
		var key = keys[index];
		var value = results.get(keys[index]);
		if ( key == 'alert') {
			if (value != '') {
				var div = $('AlertDiv');
				if ( div ) {
					div.innerHTML = value;
					div.show();
				} else {
					alert( value );
				} // end if
			} // end if
			var div = $('alert');
			if ( div ) { div.value = value };
			continue;
		} else if ( key == 'popup') {
			alert( value );
			continue;
		} else if ( key == 'information') {
			if (value != '') {
				var div = $("InformationDiv");
				if ( div ) {
					div.innerHTML = value;
					div.show();
				} // end if
			} // end if
			continue;
		} // end if

		var element = form.elements[key];
		if ( element ) {
			if ( element.type == 'select-one' ) {
				ddm_select_by_value( element, value, -1 );
			} else if ( element.type == 'checkbox' ) {
				if ( element.value == value ) {
					if ( ! element.checked ) {
						element.checked = true;
						if ( element.onchange ) element.onchange();
					} // endif
				} else {
					if ( element.checked ) {
						element.checked = false;
						if ( element.onchange ) element.onchange();
					} // endif
				} // end if
			} else if ( element.type == 'radio' ) {
			} else if ( element.type == 'text' || element.type == 'number' || element.type == 'email' ) {

				if ( element.value != value ) {
					if ( ! element.gotFocus ) {
						element.value = value;
					} 
					if ( element.onchange ) element.onchange();
				} // end if
			} else if ( element.type == 'hidden' ) {
				element.value = value;
			} else if ( element.length ) {
				var elements = element;
				for ( var j=0, lenj = elements.length; j < lenj; j += 1 ) {
					if ( elements[j].value == value ) {
						if ( ! elements[j].checked ) {
							elements[j].checked = true;
							if ( elements[j].onchange ) { elements[j].onchange(); }
						} // endif
					} else {
						if ( elements[j].checked ) {
							elements[j].checked = false;
							if ( elements[j].onchange ) { elements[j].onchange(); }
						} // endif
					} // end if
				} // end for

			} // end if
		} else if ( div = $(key) ) {
			if ( typeof(value)== "object" ) {
				if ( value.addClassName ) {
					div.addClassName( value.addClassName );
				}
				if (value.removeClassName ) {
					div.removeClassName( value.removeClassName );
				}
			} else {
			//alert('filling: ' + data[0] + ' with: ' + data[1] );
			//div.hide();
			div.innerHTML = value;
			//d//iv.show();
			}
		} else {
			//alert('didnt find: ' + data[0]);
		} // end if
	} // end for each 
    gettingNewPrice = false;
	block_calc = false;
} // end function cbFillResults

function clear_price_data( form ) {
    for ( var qtyNum = 1; qtyNum <= 3; qtyNum += 1 ) {
            if ( form.elements['txtPrice'+qtyNum] && form.elements['OverridePrice'+qtyNum] && ! get_value(form.elements['OverridePrice'+qtyNum]) ) form.elements["txtPrice"+qtyNum].value = '';
            if ( form.elements['txtUnitPrice'+qtyNum] ) form.elements["txtUnitPrice"+qtyNum].value = '';
            if ( form.elements['MPrice'+qtyNum] ) form.elements["MPrice"+qtyNum].value = '';
	} // end for
} // end function clear_price_data( form )
