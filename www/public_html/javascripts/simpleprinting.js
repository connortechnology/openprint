function FoldType_onchange( select ) {
	var foldtype = get_ddm_value( select );
	var image = document.images['FoldType'];
	if ( image ) {
		if ( foldtype != '' ) {
			image.style.display = 'inline';
			image.src = '/images/templates/' + foldtype +  '.gif';
		} else {
			image.style.display = 'none';
		} // end if
	} // end if
	remove_div('OrderButton');
} // end function

function cbFoldType_onchange( results ) {
	//var select = jsrs_cbFillDDM( results, 'Custom' );
	//Dimensions_onchange( select );
}

function calc( formName, force ) {
	var form = getFormObj(formName);

	if ( form.HoleDrilling && ( get_rdb_value( form.HoleDrilling ) == 'Y' ) ) {
		if ( form.txtHoleQty.value == '' ) {
			form.txtHoleQty.value = '1';
		} // end if
	} // end if

	var div = document.getElementById('AlertDiv');
	if ( ! div ) {
		alert('No alert div.');
	} else {
		div.hide();
	} // end if

	if ( gettingNewPrice && ! force ) {
		setTimeout("calc('"+formName+"');", 1000 );
		return;
	} // end if
	gettingNewPrice = true;
	var h = form.serialize(true);
	h.ServiceType = 'Project';
	h.callback = 'cbCalc';
	new Ajax.Request( '/main/project/_calc.json', { method: 'post', parameters: h, evalScripts: true } );
	remove_div('Buttons');
	add_div('Processing');
}

function cbCalc( results ) {
	cbFillResults(results);
	var form = getFormObj('f1');
	add_div('Buttons');
	remove_div('Processing');
	
	if ( form.Status.value == 'uncalculated' ) {
		remove_div('OrderButton');
	} else {
		add_div('OrderButton');
	} // end if

	if ( form.Scoring ) {
		if ( 'Y' == get_rdb_value( form.Scoring ) ) {
			add_div('ScoringDiv');
		} else {
			remove_div('ScoringDiv');
		} // end if
	} // end if
	if ( form.rdbCover ) {
		if ( get_value(form.rdbCover)=='Self' ) {
			remove_div('CoverStocks');
		} else if ( get_value(form.rdbCover)=='Different') {
			add_div('CoverStocks');
		} // end if
	} // end if
}


function Dimensions_onchange( select, signature ) {
	remove_div('OrderButton');
	// Refreshes Paper
	///jsrsExecute( '/jsrs.htm', cbFillDropDowns, 'openprint::paper::get_paper', get_parameters(select.form, '', '' ) );
	rdbSuppliedStock_onchange( select, signature );
	//calc( select.form.name );
} // end if

var contentWin;
function breakdown_window(project_id) {
	if (contentWin != null) {
		Dialog.alert("Close the window 'Test' before opening it again!",{width:200, height:130});
	} else {
		contentWin = new Window({maximizable: false, resizable: false, hideEffect:Element.hide, showEffect:Element.show, destroyOnClose: true,
				className:"alphacube", width:640, height:480
				} );
		contentWin.setAjaxContent('/content/prin/_breakdown.html', {parameters:'project_id='+project_id}, true);
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
} // end function breakdown_window

function click_order( form ) {
	if ( ! form.txtPrice1.value ) {
		alert( "The project is not complete, and so cannot be ordered yet." );
		return;
	} // end if
	form.action='/main/order/information.html';
	form.btnFunction.value='Process Order';
	form.submit();
}
function click_quote( form ) {
	if ( ! form.txtPrice1.value ) {
		alert( "The project is not complete, and so cannot be quoted yet." );
		return;
	} // end if 
	form.action='/main/quote/information.html';
	form.btnFunction.value='Process Quote';
	form.submit();
}
function click_upload( form ) {
	window.location = '/upload/upload_center.html?ProjectIndex=' + form.ProjectIndex.value;
}
