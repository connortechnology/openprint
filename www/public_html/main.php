<?php 
	if ( $_GET['product'] == 1 or $_GET['product'] == 2 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Flyers&ProjectTypeName=Flyers');
	} else if ( $_GET['product'] == 3 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Posters&ProjectTypeName=Posters');
	} else if ( $_GET['product'] == 4 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Banners&ProjectTypeName=Banners');
	} else if ( $_GET['product'] == 5 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Door%20Hangers&ProjectTypeName=Door%20Hangers');
	} else if ( $_GET['product'] == 9 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Labels&ProjectTypeName=Labels');
	} else if ( $_GET['product'] == 10 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Postcards&ProjectTypeName=Postcards');
	} else if ( $_GET['product'] == 11 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Greeting%20Cards&ProjectTypeName=Greeting%20Cards');
	} else if ( $_GET['product'] == 12 or $_GET['product'] == 13 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Rack%20Cards&ProjectTypeName=Rack%20Cards');
	} else if ( $_GET['product'] == 14 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=BusinessCards&ProjectTypeName=BusinessCards');
	} else if ( $_GET['product'] == 15 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Letterhead&ProjectTypeName=Letterhead');
	} else if ( $_GET['product'] == 16 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Envelopes&ProjectTypeName=Envelopes');
	} else if ( $_GET['product'] == 17 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=ScratchPads&ProjectTypeName=Note%20Pads');
	} else if ( $_GET['product'] == 18 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=ScratchPads&ProjectTypeName=Note%20Pads');
	} else if ( $_GET['product'] == 19 or $_GET['product'] == 21 or $_GET['product'] == 22 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Reports&ProjectTypeName=Reports');
	} else if ( $_GET['product'] == 20 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=PresentationFolders&ProjectTypeName=Presentationi%20Folders');
	} else if ( $_GET['product'] == 23 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Newsletters&ProjectTypeName=Newsletters');
	} else if ( $_GET['product'] == 24 or $_GET['product'] == 27 ) {
	header('Location: /content/prin/prin_multi.html?ProjectType=Magazines&ProjectTypeName=Magazines');
	} else if ( $_GET['product'] == 25 ) {
	header('Location: /content/prin/prin_multi.html?ProjectType=Manuals&ProjectTypeName=Manuals');
	} else if ( $_GET['product'] == 26 ) {
	header('Location: /content/prin/prin_broc.html?ProjectType=Brochures&ProjectTypeName=Brochures');
	} else {
	header('Location: /specials.html');
	} # end if
?>

