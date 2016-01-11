
// set the starting image.
var i = 0;          

// The time to wait before moving to the next image. Set to 3 seconds by default.
var wait = 4000;

// The Fade Function
function SwapImage(x,y) {       
    $(image_slide[x]).appear({ duration: 1.5 });
    $(image_slide[y]).fade({duration: 1.5});
}

// the onload event handler that starts the fading.
function StartSlideShow() {
    play = setInterval('Play()',wait);
    $('PlayButton').hide();
    $('PauseButton').appear({ duration: 0});
                                
}

function Play() {
    var imageShow, imageHide;

    imageShow = i+1;
    imageHide = i;
    
    if (imageShow == image_slide.length) {
        SwapImage(0,imageHide); 
        i = 0;                  
    } else {
        SwapImage(imageShow,imageHide);         
        i++;
    }
}

function Stop () {
    clearInterval(play);                
    $('PlayButton').appear({ duration: 0});
    $('PauseButton').hide();
}

function GoNext() {
    clearInterval(play);
    $('PlayButton').appear({ duration: 0});
    $('PauseButton').hide();
	Play();
}

function GoPrevious() {
    clearInterval(play);
    $('PlayButton').appear({ duration: 0});
    $('PauseButton').hide();

    var imageShow, imageHide;
                
    imageShow = i-1;
    imageHide = i;
    
    if (i == 0) {
        SwapImage(image_slide.length -1,imageHide); 
        i = image_slide.length -1;     
        
        //alert(NumOfImages-1 + ' and ' + imageHide + ' i=' + i)
                    
    } else {
        SwapImage(imageShow,imageHide);         
        i--;
        
        //alert(imageShow + ' and ' + imageHide)
    }
}
