var usesImages = false;

function writeButton( btnName, imageName, onClick, href, alt ) {
	document.write( createButton( btnName, imageName, onClick, href, alt ) );
} // end function writeButton()

function createButton( btnName, imageName, onClick, href, alt ) {
	if ( href=='' ) {
		href='#';
	} // end if
	var html = "<a id=\""+btnName+"\" href=\""+href+"\" ";
	if ( imageName != '' ) {
		html += "class=\"buttonImageOff\" onMouseOver=\"if ( typeof(btnOn) == 'function' ) btnOn('"+btnName+"');\" onmouseout=\"if ( typeof(btnOff) == 'function') btnOff('"+btnName+"');\" ";
	} else {
		html += "class=\"buttonOff\" ";
	} // end if
	if ( onClick ) {
		html += "onClick=\""+onClick+"return false;\" ";
	}
	if ( usesImages && imageName != '' ) {
		html += "><img src=\"/images/buttons/off/"+imageName+"\" border=\"0\" name=\""+btnName+"Button\"";
		if ( alt != '' ) {
			html += "alt=\""+alt+"\"";
		} // end if
		html += "/>";
		// cache the on state
		var button = new Image();
		button.src = "/images/buttons/on/"+imageName;
	} else {
		html += "><span class=\"l\"></span><span class=\"c\">" + alt + "</span><span class=\"r\"></span>";
	}
	html += "</a>";
	return html;
} // end function createButton

function btnOn( btnName ) {
	if ( usesImages ) {
		var image = document.images[btnName+'Button'];
		var filename;

		if ( image ) {
			filename = image.src.substring( image.src.lastIndexOf('/') + 1 );
			image.src = '/images/buttons/on/' + filename;
			window.status = image.alt;
		} else {
			alert("Couldn't find image! " + btnName );
		} // end if
	} else {
		var element=$(btnName);
		if ( element ) {
			element.className = element.className.replace(/buttonImageOff/, 'buttonImageOn');
		} // end if
	} // end if

	return true;
} // end function btnOn( btnName )

function btnOff( btnName ) {
	if ( usesImages ) {
		var image = document.images[btnName+'Button'];
		if ( image ) {
			var filename = image.src.substring( image.src.lastIndexOf('/') + 1 );
			image.src = '/images/buttons/off/' + filename;
			window.status = '';
		} // end if
	} else {
		var element=$(btnName);
		if ( element ) {
			element.className = element.className.replace(/buttonImageOn/, 'buttonImageOff');
		} // end if
	} // end if
} // end function btnOn( btnName )

