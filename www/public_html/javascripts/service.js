var timeout;
var block_calc = false;

function body_onLoad() {
	if ( typeof(selectProjectTemplate) == 'function' ) {
		selectProjectTemplate( 'f1' );
	} else if ( typeof(calc) == 'function' ) {
		calc('f1');
	} // end if
}

function calc( formName, force ) {
	if ( block_calc ) return;
	var form = getFormObj( formName );
	if ( form && form.ServiceType ) {
		if ( gettingNewPrice && ! force ) {
			if ( timeout ) clearTimeout( timeout );
			timeout = setTimeout( "calc('" + formName + "');", 1000 );
		} else {
			timeout = null;
			remove_div('AlertDiv');
			var div = $('InformationDiv');
			if ( div ) {
				div.innerHTML = 'Calculating';
			} // end if
			gettingNewPrice = true;
			new Ajax.Request( '/main/project/_calc.json', { method: 'post', parameters: form.serialize(), evalScripts: true } );
		} // end if
	} // end if
} // end calc()

function cbFillResults( results ) {
	block_calc = true;
    var form = getFormObj('f1');
	$('AlertDiv').hide();
	if ( $('InformationDiv') )
		$('InformationDiv').hide();
	var keys = results.keys();

	for ( var index = 0; index < keys.length; index += 1 ) {
		var key = keys[index];
		var value = results.get(keys[index]);
//if ( ! confirm( key + ' ' + value ) ) {
//break;
//}
	
		if ( key == 'alert') {
			if (value != '') {
				var div = $("AlertDiv");
				if ( div ) {
					div.innerHTML = value;
					div.show();
				} else {
					alert( value );
				} // end if
			} // end if

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
			} else if ( element.type == 'text' ) {
				if ( element.value != value ) {
				if ( ! element.gotFocus )
					element.value = value;
					if ( element.onchange ) element.onchange();
				} // end if
			} else if ( element.type == 'hidden' ) {
				element.value = value;
			} else if ( element.length ) {
				var elements = element;
				for ( var j=0; j < elements.length; j += 1 ) {
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
			//alert('filling: ' + data[0] + ' with: ' + data[1] );
			//div.hide();
			div.innerHTML = value;
			//d//iv.show();
		} else {
			//alert('didnt find: ' + data[0]);
		} // end if
	} // end for each 
    gettingNewPrice = false;
	block_calc = false;
} // end function cbFillResults

function addService( formName, service ) {
    var form = getFormObj(formName);
    var params = new Array ( form.ProjectIndex.value );
    params = params.concat(service);
    jsrsExecute( '/jsrs.htm', cbAddService, 'openprint::print_project::add_service', params);

} // end function addService

function cbAddService( results ) {
    calc('f1');
}
function delService( formName, service ) {
    var form = getFormObj(formName);
    jsrsExecute( '/jsrs.htm', cbDelService, 'openprint::print_project::del_service', new Array( form.ProjectIndex.value, service ) );
} // end function addService

function cbDelService( results ) {
    calc('f1');
}

