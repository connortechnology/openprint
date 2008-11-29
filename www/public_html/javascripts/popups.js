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

function AjaxToggleContent( divID, show_url, inputs, hide_url ) {
	var div = $( divID );

	var params = new Array();
	while ( inputs.length ) {
		params[params.length] = inputs.shift() + '=' + inputs.shift();
	}


	if ( div.style.display == 'none' ) {
		div.show();
		new Ajax.Updater( divID, show_url, { method: 'get', parameters: params.join('&') } );
	} else {
		div.hide();
		if ( page_to_hide )
			new Ajax.Updater( divID, hide_url, { method: 'get', parameters: params.join('&') } );
	} // end if
} // end function AjaxToggleContent

function toggleContent( divID, page_to_display, inputs, page_to_hide ) {
	var div = $( divID );
	if ( div.style.display == 'none' ) {
		div.show();
		new Ajax.Updater(divID,page_to_display, {method:'get',parameters:inputs});
		//LoadContent( divID, page_to_display, inputs );
	} else {
		div.hide();
		if ( page_to_hide )
			new Ajax.Updater(divID,page_to_hide, {method:'get',parameters:inputs});
			//LoadContent( divID, page_to_hide, inputs );
	} // end if

} // end function toggleContent


function LoadContent( divID, page, inputs, message ) {
	var div = $( divID );
	if ( div ) {
		if ( message ) div.innerHTML = message;
		else div.innerHTML = 'Please wait....';
	} // end if
	if ( ! inputs ) {
		inputs = new Array();
	} // end if

    inputs.unshift(divID,page);
    jsrsExecute( '/jsrs.htm', cbLoadMyContent, 'openprint::jsrs_handler::load_content', inputs );

}

function cbLoadMyContent( results ) {
	var div;
	var content;
	var pairs = results.split('|');
	for ( var i = 0; i < pairs.length; i += 1 ){
		if ( pairs[i].indexOf('~') != -1 ) {
			var data = pairs[i].split('~');
			if ( data[0] == 'Div' ) {
				div = $( data[1] );
			} else if ( data[0] == 'Content' ) {
				content = data[1];
			} // end if
		} // end if
	} // end for
	if ( div ) {
		div.innerHTML = content;
	} else {
		alert('no div');
	} // end if
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


function ajax_window( url, width, height ) {
	if ( ! contentWin ) {
		if ( ! width )
			width = 400;
		
		contentWin = new Window({maximizable: false, resizable: true, hideEffect:Element.hide, showEffect:Element.show, destroyOnClose: true,
className:"alphacube", width:width, height:height
		} );
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
	} // end if
	contentWin.setAjaxContent(url, null , true);
}
