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
  bpz = document.autoSumForm.bprice.options[document.autoSumForm.bprice.selectedIndex].value;
  clr = document.autoSumForm.color1.value;
  
  fin = document.autoSumForm.finishing1.options[document.autoSumForm.finishing1.selectedIndex].value;  
  mat = document.autoSumForm.material1.options[document.autoSumForm.material1.selectedIndex].value; 

  wid = document.autoSumForm.width.options[document.autoSumForm.width.selectedIndex].value; 
  hei = document.autoSumForm.height.options[document.autoSumForm.height.selectedIndex].value; 
  
  pap = document.autoSumForm.paper1.value;
  trn = document.autoSumForm.turnaround1.options[document.autoSumForm.turnaround1.selectedIndex].value;
  dis = document.autoSumForm.insdiscount.value;


  Singolo1 = ((((qty / tft) * (pap * 1)) + ((qty / tft) * (fin * 1)) + ((qty / tft) * (wid * hei * 1)) + ((qty / tft) * (mat * 1)) + (trn * 1) + (clr * 1) + (bpz * 1)) / (qty * 1)); 
  
  stotale1 = (((qty / tft) * (pap * 1)) + ((qty / tft) * (fin * 1)) + ((qty / tft) * (wid * hei * 1)) + ((qty / tft) * (mat * 1)) + (trn * 1) + (clr * 1) + (bpz * 1)); 
  
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
function setForm14Value() {
    var selectedItem      = document.autoSumForm.material1.selectedIndex;
    var selectedItemText  = document.autoSumForm.material1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.material.value = selectedItemText;
    }
    else {
        document.autoSumForm.material.value = "";
      
    }
}
//-->
<!--
function setForm15Value() {
    var selectedItem      = document.autoSumForm.finishing1.selectedIndex;
    var selectedItemText  = document.autoSumForm.finishing1.options[selectedItem].text;
    
    if (selectedItem != -1) {
        document.autoSumForm.finishing.value = selectedItemText;
    }
    else {
        document.autoSumForm.finishing.value = "";
      
    }
}
//-->