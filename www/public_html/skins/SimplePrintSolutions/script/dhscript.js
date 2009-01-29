<!--
/* This script and many more are available free online at
The JavaScript Source!! http://javascript.internet.com
Created by: Jim Stiles | www.jdstiles.com */
function startCalc(){
  interval = setInterval("calc()",1);
}
function calc(){
   xch = document.autoSumForm.xchange.value;
  tft = document.autoSumForm.tfifty.value;
  qty = document.autoSumForm.quantity.value;
  pap = document.autoSumForm.paper1.value;
  bpz = document.autoSumForm.bprice.options[document.autoSumForm.bprice.selectedIndex].value;
  clr = document.autoSumForm.color1.options[document.autoSumForm.color1.selectedIndex].value; 
  pef = document.autoSumForm.perforation1.options[document.autoSumForm.perforation1.selectedIndex].value;
  scr = document.autoSumForm.scoring1.options[document.autoSumForm.scoring1.selectedIndex].value;
  trn = document.autoSumForm.turnaround1.options[document.autoSumForm.turnaround1.selectedIndex].value;
  dis = document.autoSumForm.insdiscount.value;


  Singolo1 = ((((qty / tft) * (pap * 1)) + ((qty / tft) * (pef * 1)) + ((qty / tft) * (scr * 1)) + (trn * 1) + (clr * 1) + (bpz * 1)) / (qty * 1)); 
  
  stotale1 = (((qty / tft) * (pap * 1)) + ((qty / tft) * (pef * 1)) + ((qty / tft) * (scr * 1)) + (trn * 1) + (clr * 1) + (bpz * 1)); 
  
  Singolo = (Singolo1 * xch);
  
  stotale = (stotale1 * xch);	  

  disctot = (stotale - ((stotale * dis)/100));
  
  document.autoSumForm.discount.value = disctot.toFixed(2);
  document.autoSumForm.subtotal.value = stotale.toFixed(2);
  document.autoSumForm.rate.value = Singolo.toFixed(2); 	
	
}
function stopCalc(){
  clearInterval(interval);
}
//-->
<!--
function setForm1Value() {
    var selectedItem      = document.autoSumForm.bprice.selectedIndex;
    var selectedItemText  = document.autoSumForm.bprice.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.quantity.value = selectedItemText;
    }
    else {
        document.autoSumForm.quantity.value = "";
      
    }
}
//-->
<!--
function setForm2Value() {
    var selectedItem      = document.autoSumForm.color1.selectedIndex;
    var selectedItemText  = document.autoSumForm.color1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.color.value = selectedItemText;
    }
    else {
        document.autoSumForm.color.value = "";
      
    }
}
//-->
<!--
function setForm4Value() {
    var selectedItem      = document.autoSumForm.turnaround1.selectedIndex;
    var selectedItemText  = document.autoSumForm.turnaround1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.turnaround.value = selectedItemText;
    }
    else {
        document.autoSumForm.turnaround.value = "";
      
    }
}
//-->
<!--
function setForm5Value() {
    var selectedItem      = document.autoSumForm.perforation1.selectedIndex;
    var selectedItemText  = document.autoSumForm.perforation1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.perforation.value = selectedItemText;
    }
    else {
        document.autoSumForm.perforation.value = "";
      
    }
}
//-->
<!--
function setForm6Value() {
    var selectedItem      = document.autoSumForm.scoring1.selectedIndex;
    var selectedItemText  = document.autoSumForm.scoring1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.scoring.value = selectedItemText;
    }
    else {
        document.autoSumForm.scoring.value = "";
      
    }
}
//-->