
	function loadDivs( results ) {
		var rows = results.split('|');
		for ( var r = 0; r < rows.length; r += 1 ) {
			var cols = rows[r].split('~');
			if ( cols[0] == 'Div' ) {
				var div=$(cols[1]);
				if ( div ) {
					div.style.display = 'none';
					div.innerHTML = cols[2];
					var containers = $$('ul.shift');
					Sortable.create(cols[1], {dropOnEmpty:true,constraint:false,containment:containers,
							onUpdate:function(){
							jsrsExecute( '\/jsrs.htm', checkOrder, 'openprint::press_schedule2::drop_project', new Array( cols[1], Sortable.serialize(cols[1]) ) );
							}
							});

					div.style.display = 'block';
				} // end if
			} // end if
		} // end for
	} // end function loadDivs( results )

	function split_job( pid, sid, shift ) {
		var div = $( shift );
		if ( div )
			div.innerHTML = 'updating...';
		var code = "require openprint::press_schedule;\n";
		code += "return openprint::press_schedule::split_job( @specs{'p_id','s_id','shift'} );\n";
		jsrsExecute( '/jsrs.htm', loadDivs, 'jsrs::execute', new Array( 'code', code, 'p_id', pid, 's_id', sid, 'shift', shift ) );
	} // end function

	function jump_to_date( date ) {
		var form = date.params.inputField.form;
		var name = date.params.inputField.name;
		var reg = /ScheduleDate-(\d*)/;
		var ar = reg.exec( name );
		form.ServiceIndex.value = ar[1];
		form.btnFunction.value='JumpToDate';
		form.submit();
	}

	function setduedate( date ) {
		var form = date.params.inputField.form;
		var name = date.params.inputField.name;
		var reg = /ScheduleDate-(\d*)/;
		var ar = reg.exec( name );
		jsrsExecute( '/jsrs.htm', null, 'openprint::employee_schedule::set_duedate', new Array( ar[1], date.params.inputField.value ) );
		calendar.hide();
	}

	function checkOrder( results ) {
	} // end function

	function editOperator( period_id, operator, e ) {
		form = document.forms['f3'];
		if ( form ) {
			form.Period.value=period_id;
			ddm_select_by_value( form.Operator, operator );
			show_div( 'OperatorEdit', e );
		} // end if
	} // end function editOperator

	function saveOperator( period, operator, name ) {
		var div = $( period + 'Operator' );
		if ( div )
			div.onClick = 'editOperator(\''+period+'\', \''+operator+'\', event );';
			div.innerHTML = name;
		jsrsExecute( '/jsrs.htm', null, 'openprint::employee_schedule::set_operator', new Array( period, operator ) );
	} // end function saveOperator

	function editForms( project_index, service_index, forms, e ) {
		form = document.forms['f5'];
		if ( form ) {
			form.ProjectIndex.value=project_index;
			form.ServiceIndex.value=service_index;
			form.Forms.value=forms;
			show_div( 'FormsEdit', e );
		} // end if
	} // end function editImpressions

	function saveForms( project_index, service_index, forms ) {
		var div = $( service_index + 'Forms' );
		if ( div )
			div.onclick = 'editForms(' + project_index + ', ' + service_index + ', \'' + forms + '\', event );';
			div.innerHTML = forms+' forms';
		jsrsExecute( '/jsrs.htm', null, 'openprint::employee_schedule::set_forms', new Array( project_index, service_index, forms ) );
	} // end function saveOperator

	function editImpressions( project_index, service_index, impressions, e ) {
		form = document.forms['f4'];
		if ( form ) {
			form.ProjectIndex.value=project_index;
			form.ServiceIndex.value=service_index;
			form.Impressions.value=impressions;
			show_div( 'ImpressionsEdit', e );
		} // end if
	} // end function editImpressions

	function saveImpressions( project_index, service_index, impressions ) {
		var div = $( service_index + 'Impressions' );
		if ( div )
			div.innerHTML = '<span onClick="editImpressions('+project_index+', '+service_index+', \''+impressions+'\', event );">'+impressions+' imps</span>';
		jsrsExecute( '/jsrs.htm', null, 'openprint::employee_schedule::set_impressions', new Array( project_index, service_index, impressions ) );
	} // end function saveOperator

	function editComment( project_index, service_index, comment, e ) {
		form = document.forms['f2'];
		if ( form ) {
			form.ProjectIndex.value=project_index;
			form.ServiceIndex.value=service_index;
			form.Comment.value=comment;
			show_div('CommentEdit', e )	
		} // end if
	} 

	function saveComment( project_index, service_index, comment ) {
		var div = $( service_index + 'Comment' );
		if ( div )
			div.innerHTML = '<div style="width:100%;" onClick="editComment('+project_index+', '+service_index+', \''+comment+'\', event );">'+comment+'&nbsp;</div>';
		jsrsExecute( '/jsrs.htm', null, 'openprint::employee_schedule::set_comment', new Array( project_index, service_index, comment ) );
	} // end function saveComment
	function errFunc( t ) {
	}
	function applySchedule( ) {
		document.getElementsByClassName( 'Schedule', $('schedule') ).map (function(e){
			jsrsExecute( '/jsrs.htm', checkOrder, 'openprint::press_schedule2::drop_project', new Array( e.id, Sortable.serialize(e.id) ) );
		} );
		$('schedule').setStyle({background:'none'} );
	}  // end function

var popupWin;
function popup_window( url, parameters ) {
    if ( ! popupWin ) {
        popupWin = new Window({maximizable: false, resizable: true, hideEffect:Element.hide, showEffect:Element.show, destroyOnClose: true, className:"alphacube", width:400} );
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
    popupWin.setAjaxContent(url+'?'+parameters, null , true);
} // end function popup_window
