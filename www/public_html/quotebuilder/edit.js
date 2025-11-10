const showBillingFields = (element) => {
  let billingCheck = document.getElementById("billing").style.display;
  if (billingCheck === "none") {
    document.getElementById("billing").style.display = "block";
  } else {
    document.getElementById("billing").style.display = "none";
  }
};

$j(function () {
  displaySalesTab();
  getDate()
  //default sales page

  //hide numbers table
  $j("#showPhoneNumbers").hide();

  $j("#inputPhoneNumber").focusin(function () {
    $j("#showPhoneNumbers").fadeIn();
  });
  $.("#inputPhoneNumber").focusout(function () {
    $.("#showPhoneNumbers").fadeOut();
  });

  //show euclid field
  $j('a.euclid').click(function(e){
    e.preventDefault();
    //console.log("click E", this)
    $j('tr.euclid-fields').toggle();
  });

  var firstTabEl = document.querySelector("#myTab li:last-child a");

  $j("button.btn.btn-primary.btn-qb, a.vss").click(function (e) {
    console.log("Request service button pressed");
    $j("#sales-tab").removeClass("active");
    $j("#sales").removeClass("active");
    $j("#quotebuilder-tab").addClass("active");
    $j("#quotebuilder").addClass("active");
  });

  $j("#question-notes-btn").click(function(){
    $j("#question-notes").toggle();
  })

  ///////

  var firstTab = new bootstrap.Tab(firstTabEl);

  firstTab.show();

  ///////
});

function getDate(){
  let date = new Date();
  const strDate = (date.getMonth()+1) + "/" + date.getDate() + "/" + date.getFullYear() ;
  console.log(strDate)
 
  document.getElementById("date").innerHTML = strDate;
}
