var timeout;

function body_onLoad() {
	if ( typeof(calc) == 'function' )
		calc('f1');
}

function calc( formName ) {
	var form = getFormObj( formName );
	if ( form && form.ServiceType ) {
		if ( gettingNewPrice ) {
			if ( timeout )
				clearTimeout( timeout );
			timeout = setTimeout( "calc('" + formName + "');", 1000 );
		} else {
			timeout = null;
			remove_div('AlertDiv');
			gettingNewPrice = true;
			jsrsExecute( '/jsrs.htm', cbFillResults, 'openprint::service::external_calc', get_variables( formName, form.ServiceType.value ) );
		} // end if
	} // end if
} // end calc()


function get_variables( formName, service_type ) {
	var form = getFormObj( formName );
	if ( ! form ) {
		alert('No form in get_variables');
	} // end if

    gettingNewPrice = true;

    var parameters = new Array();
	if ( service_type )
		parameters[parameters.length] = service_type;

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
        } else {
           if (
                ( form.elements[index].name == 'hdnBreakdown' )
                || ( form.elements[index].name == 'ContinueProject' )
                || ( form.elements[index].name == 'btnFunction' )
) {
            } else if ( form.elements[index].name && form.elements[index].value != '' ) {
				parameters[parameters.length] = form.elements[index].name;
				parameters[parameters.length] = form.elements[index].value;
			} // end if
		} // end if
    } // end for
	return parameters;
} // end get_variables()

function cbFillResults( results ) {
    var pairs = results.split('|');
    var form = getFormObj('f1');
	remove_div('AlertDiv');

    for ( var i = 0; i < pairs.length; i += 1 ){
        if ( pairs[i].indexOf('~') != -1 ) {
            var data = pairs[i].split('~');
            if ( data[0] == 'alert') {
				if (data[1] != '') {
					//var div = $("AlertDiv");
					var div = add_div('AlertDiv');
					if ( div ) {
						//div.update( data[1] );
						div.innerHTML = data[1];
					} else {
						alert( data[1] );
					} // end if
				} else {
					remove_div('AlertDiv');
				} // end if
				
                continue;
            } // end if

			var element = form.elements[data[0]];
            if ( element ) {
				if ( element.type == 'select-one' ) {
					ddm_select_by_value( element, data[1], -1 );
				} else if ( element.type == 'checkbox' ) {
					if ( element.value == data[1] ) {
						element.checked = true;
					} else {
						element.checked = false;
					} // end if
				} else if ( element.type == 'radio' ) {
				} else if ( element.type == 'text' ) {
					if ( ! element.gotFocus )
						element.value = data[1];
				} else if ( element.type == 'hidden' ) {
					element.value = data[1];
				} else {
					var elements = element;
					for ( var j=0; j < elements.length; j += 1 ) {
						if ( elements[j].value == data[1] ) {
							elements[j].checked = true;
						} else {
							elements[j].checked = false;
						} // end if
					} // end for
				} // end if
			} else if ( div = document.getElementById(data[0]) ) {
				div.style.visible = 'hidden';
				div.innerHTML = data[1];
				div.style.visible = 'visible';
			} // end if
        } // end if
    } // end for
    gettingNewPrice = false;
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

