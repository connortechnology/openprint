function remove_div( divname ) {
    var div = document.getElementById(divname);
    if ( div ) {
        div.style.display = 'none';
    } // end if
}
function add_div( divname ) {
    var div = document.getElementById(divname);
    if ( div ) {
        div.style.display = '';
		return div;
    } // end if
}

function hide_div( divname ) {
    var div = $(divname);
    if ( div ) {
        div.style.visibility = 'hidden';
    } // end if
}
function show_div( divname, e ) {
    var div = $(divname);
    if ( div ) {
	
        var posx = 0;
        var posy = 0;
        if (!e) e = window.event;
		if ( e ) {
			if (e.pageX || e.pageY) {
				posx = parseInt(e.pageX);
				posy = parseInt(e.pageY);
			} else if (e.clientX || e.clientY) {
				posx = parseInt(e.clientX);
				posy = parseInt(e.clientY);
				if( document.documentElement && ( document.documentElement.scrollTop || document.documentElement.scrollLeft ) ) {
					posx += parseInt( document.documentElement.scrollLeft ); posy += parseInt( document.documentElement.scrollTop );
				} else if( document.body && ( document.body.scrollTop || document.body.scrollLeft ) ) {
					posx += parseInt( document.body.scrollLeft ); posy += parseInt( document.body.scrollTop );
				}
			} // end if
			if ( posx + div.offsetWidth > document.body.offsetWidth ) {
				posx = document.body.offsetWidth - div.offsetWidth;
			} // end if
			div.style.left = posx + 'px';
			posy += 10; // to move it south of the mouse cursor
			div.style.top = posy + 'px';
		} // end if
		div.style.visibility = 'visible';
		if ( div.style.display == '' ) {
			div.style.display='block';
		}
	} else {
		alert("Div not found: " + divname );
	} // end if
} // end function

function open_window(url,title,options) {
	var upload_window = window.open(url,title,options);
	upload_window.focus();
}

function toggleContent( divID, show_url, inputs, hide_url ) {
	var div = $( divID );

	var params = new Array();
	if ( inputs ) {
	while ( inputs.length ) {
		params[params.length] = inputs.shift() + '=' + inputs.shift();
	}
	} // end if


	if ( div.style.display == 'none' ) {
		div.show();
		new Ajax.Updater( divID, show_url, { method: 'get', parameters: params.join('&'), evalScripts: true } );
	} else {
		div.hide();
		if ( hide_url )
			new Ajax.Updater( divID, hide_url, { method: 'get', parameters: params.join('&'), evalScripts: true } );
	} // end if
} // end function AjaxToggleContent


function LoadContent( divID, page, parameters, message ) {
	var div = $( divID );
	if ( div ) {
		if ( message ) div.innerHTML = message;
		else div.innerHTML = 'Please wait....';
	} // end if
	var method = 'get';
	//alert( typeof parameters );
	if ( typeof parameters == 'object' ) {
		parameters = parameters.serialize();
	} 
	if ( parameters.length > 8190 ) 
		method = 'post';
	
	new Ajax.Updater( divID, page, { method: method, parameters: parameters, evalScripts: true } );
}

var contentWin;
function bug_report_window() {
	if (contentWin != null) { 
		Dialog.alert("Close the window 'Test' before opening it again!",{width:200, height:130});
	} else { 
		contentWin = new Window({maximizable: false, resizable: false, hideEffect:Element.hide, showEffect:Element.show, destroyOnClose: true,
className:"alphacube", width:400, height:420
		} );
		//contentWin.setContent('test_content', true, true)
		contentWin.setAjaxContent('/bug_report.html', null , true);
		// Set up a windows observer, check ou debug window to get messages
		myObserver = {
			onDestroy: function(eventName, win) {
			   if (win == contentWin) {
				   contentWin = null;
				   Windows.removeObserver(this);
			   }
		   }
		}
		Windows.addObserver(myObserver);
	}
} // end function bug_report

var popupWin;
function popup_window( url, parameters, options ) {
	if ( ! popupWin ) {
		var width = 400;
		var height = 400;
		if ( options ) {
			if ( options.width ) width = options.width;
			if ( options.height ) height = options.height;
		} // end if
		popupWin = new Window({maximizable: false, resizable: true, hideEffect:Element.hide, showEffect:Element.show, destroyOnClose: true, className:"alphacube", width:width, height:height} );
		// Set up a windows observer, check ou debug window to get messages
		myObserver = {
onDestroy: function(eventName, win) {
			   if (win == popupWin) {
				   popupWin = null;
				   Windows.removeObserver(this);
			   }
		   }
		}
		Windows.addObserver(myObserver);
	} // end if
	popupWin.setHTMLContent('Loading... please wait');
	popupWin.showCenter();
	if ( parameters ) {
		url += '?' + parameters;
	}
	popupWin.setAjaxContent(url, null , true);
} // end function popup_window


function toggleInput( name ) {
$('txt'+name).value='';
$(name).selectedIndex=0;
$(name).toggle();
$('txt'+name).toggle();
}
