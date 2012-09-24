function getSelectedLocation(text, li) {
	if ( li.id ) {
		new Ajax.Request( '/location/_load_location.json', { parameters: { location_id: li.id } } );
	} // end if
}
