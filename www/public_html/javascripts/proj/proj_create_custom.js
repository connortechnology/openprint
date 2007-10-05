function submit_handler (form) {
	var status = validate_data(form);
	if (status) {
		status = checkSelections(form);
	} // end if
	if (status) {
		form.submit();
	} // end if
	return status;
} // end function submit_handler


function validate_data (form) {
	var text = '';

	if ( form.ddmDesign && ! ( get_value( form.ddmDesign ) ) ) {
		text += "Please specify the supplied format.\n";
	} // end if

	if (text) {
		text = "Please correct the following errors before proceeding:\n\n" + text;
		alert(text);
		return false;
	} // end if
	return true;
} //end function validate_data

function ddmDesign_onChange(form){
	if ( form.ddmDesign.selectedIndex == 1 ) {
		form.txtConventionalPlates.value = 0;
	} else {
		form.txtConventionalPlates.value = 1;
	} // end if
} // end function


function set_service( chk, service, checked ) {
	for ( var index = 0; index < chk.length; index += 1 ) {
		if ( chk[index].value == service ) {
			chk[index].checked = checked;
		} // end if
	} // end for
} // end function check_service

function check_service( chk, service ) {
	for ( var index = 0; index < chk.length; index += 1 ) {
		if ( chk[index].value == service ) {
			return chk[index].checked;
		} // end if
	} // end for
	//alert( "check_server: Service " + service + "not found!" );
} // end function check_service

function service_onclick( ) {
}

function checkSelections (form){

	if ( projectType != 'ColourCopies' && projectType != 'InkjetOutputs' && projectType !='NoPrintingRequired') {
		var design = get_value(form.ddmDesign);
		if ( design == 'FinalFilm' ) {
			if ( ! check_service( form.chkPrepressServices, 'FilmStripping' ) ) {
				set_service( form.chkPrepressServices, 'FilmStripping', true );
			} // end if
		} else if ( design == 'ElectronicFile' ) {
			if ( ! check_service( form.chkPrepressServices, 'Proofs' ) ) {
				//if (confirm ("We will require a proof in order to print your project.\n\nIf you would like to add a proof to your project please click OK, otherwise click Cancel to supply your own proof.")){
				set_service( form.chkPrepressServices, 'Proofs', true );
				//} // end if			
			} // end if
		} // end if
	} // end if

	if ( projectType == 'PresentationFolders' ) {
		if (  ! check_service( form.chkBinderyServices, 'DieCutting' ) ) {
			if (confirm ("Your project requires a die cutting service in order for us to fufill your request for Presentation Folders.\n\nIf you would like to add die cutting to your project please click OK, otherwise click Cancel.")){
				set_service( form.chkBinderyServices, 'DieCutting', true );
			} // end if			
		} // end if
	} else if ( projectType == 'ScratchPads' ) {
		if ( ! check_service( form.chkBinderyServices, 'Padding' ) ) {
			if (confirm ("Your project requires a padding service in order for us to fufill your request for scratch pads.\n\nIf you would like to add padding to your project please click OK, otherwise click Cancel.")){
				set_service( form.chkBinderyServices, 'Padding', true );
			} // end if			
		} // end if
	} // end if
	if ( check_service(form.chkBinderyServices, 'SaddleStitching') || check_service(form.chkBinderyServices, 'LoopStitching') ) {
		if ( ! check_service(form.chkBinderyServices, 'Folding') ) {
			//if (confirm ("Your project requires a folding service in order for us to fufill your request.\n\nIf you would like to add folding to your project please click OK, otherwise click Cancel.")){
               set_service( form.chkBinderyServices, 'Folding', true );
        	//} // end if
		} // end if
	} // edn if
	return true;
} // end checkFilmProofsPads()
