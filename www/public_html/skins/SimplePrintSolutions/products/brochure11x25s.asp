<%@ Language="VBScript"%>
<%Title="Produts/Brochure"%>
<% Dim step, insdiscount
	step = "fase1"
	insdiscount = 100 
	choosescript= "brochure" 
%>
<!--#include file="rsy.asp" -->
<!--#include file="rs.asp" -->
<!--#include file="rsx.asp" -->
<!--#include file="rsxx.asp" -->
<!--#include file="rs6x.asp" -->
<%

dim conn5x, strConn5x

strConn5x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn5x = Server.CreateObject("ADODB.Connection")
conn5x.Open StrConn5x 


SQL = "SELECT * FROM BrochurePrice11x25"

Set rs5x = Server.CreateObject("ADODB.Recordset")

rs5x.Open SQL, Conn5x

%>
<!--#include file="../headerpro.asp" -->
<table border="0" cellpadding="10" cellspacing="0"  width="584" height="470">
  <tr>
    <td valign="top" class=text>
<form name="autoSumForm" action=../shoppingcart/review_order.asp method="post">
<input type=hidden name=product value="Brochure">
<input name="sizep" type=hidden value="11 x 25.5" size="10">
<input type=hidden name=xchange onFocus="startCalc();" onBlur="stopCalc();" value="<%=rsy("price1")%>">
<input type=hidden name=tfifty onFocus="startCalc();" onBlur="stopCalc();" value="1000">
 <table border="0" cellspacing="1" width="560">
  <tr>
    <td width="260" valign="top">
      <table border="0" cellpadding="10" cellspacing="0" width="100%" height="25">
        <tr>
          <td width="100%" height="260">
            <p align="center"><img border="0" src="images/Brochureicon.jpg" width="200" height="169"></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>Brochure Size:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <font class=textsize><a href="brochure8x11s.asp" class="linksize">8.5 x 11</a> | <a href="brochure8x14.asp" class="linksize">8.5 x 14</a> |
             <a href="brochure11x17s.asp" class="linksize">11 x 17</a> | 11 x 25.5</font></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><hr></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>File Preparation:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <a href="../templates/brochure.asp" class="linksize">Download templates</a><br>
</td>
        </tr>
      </table>
    </td>
    <td bgcolor="#c9c9c9" width="300">
 
<table border="0" cellspacing="1" width="100%">
  <tr>
    <td width="100%">
      <table border="0" cellspacing="5" width="100%" cellpadding="5">
        <tr>
          <td width="100%" class=subtext><b>INSTANT PRICING</b></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF">
      <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3>
        <tr>
          <td width="100%">
          <!-- FIRST BOX -->
          <table border="0" cellspacing="0" width="100%" height="1">
  <tr>
    <td width="100%" height="1" class=textorange>Quantity<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm1Value()" onBlur="stopCalc();" size=1 name=bprice>
      <OPTION value='<%=rs5x("price6")%>'><%=rs5x("desc6")%></OPTION>
      <OPTION value='<%=rs5x("price7")%>'><%=rs5x("desc7")%></OPTION>
      <OPTION value='<%=rs5x("price8")%>'><%=rs5x("desc8")%></OPTION>
      <OPTION value='<%=rs5x("price9")%>'><%=rs5x("desc9")%></OPTION>
      <OPTION value='<%=rs5x("price10")%>'><%=rs5x("desc10")%></OPTION></SELECT><br>
      <input onChange="startCalc();" onBlur="stopCalc();" type=hidden name="quantity" value="<%=rs5x("desc6")%>" size="10">
    </td>
  </tr>
  <tr>
    <td width="100%" height="2" valign="top"><hr size="1" color="#DADADA">
</td>
  </tr>
  <tr>
    <td width="100%" height="55" valign="top" class=textorange>Colors&nbsp;<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm2Value()" onBlur="stopCalc();" size=1 name=color1>
      	<option value='<%=rsx("price1")%>'><%=rsx("desc1")%>
		<option value='<%=rsx("price2")%>'><%=rsx("desc2")%>
		<option value='<%=rsx("price3")%>'><%=rsx("desc3")%>
		</SELECT><br>
      <input name="color" type=hidden value="<%=rsx("desc1")%>" size="10">
</td>
  </tr>
  <tr>
    <td width="100%" height="21" valign="top"><hr size="1" color="#DADADA">
    </td>
  </tr>
  <tr>
    <td width="100%" height="21" valign="top" class=textorange>Paper<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
 	<SELECT onChange="startCalc(); setForm3Value()" onBlur="stopCalc();" size=1 name=paper1>
      <OPTION value='<%=rs("price3")%>'><%=rs("desc3")%></OPTION>
      <OPTION value='<%=rs("price4")%>'><%=rs("desc4")%></OPTION>  
      <OPTION value='<%=rs("price5")%>'><%=rs("desc5")%></OPTION>  
      <OPTION value='<%=rs("price6")%>'><%=rs("desc6")%></OPTION>
      <OPTION value='<%=rs("price7")%>'><%=rs("desc7")%></OPTION>
      <OPTION value='<%=rs("price8")%>'><%=rs("desc8")%></OPTION></SELECT>
<br><input name="paper" type=hidden value="<%=rs("desc3")%>" size="10">
</td>
  </tr>
  <tr>
    <td width="100%" height="21" valign="top"><hr size="1" color="#DADADA">
    </td>
  </tr>
  <tr>
    <td width="100%" height="21" valign="top" class=textorange>Paper Fold<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
 	<SELECT onChange="startCalc(); showimage7();" onBlur="stopCalc();" size=1 name=folding1>
   <option value='<%=rs6x("price4")%>'><%=rs6x("desc4")%>
	<option value='<%=rs6x("price2")%>'><%=rs6x("desc2")%>
	<option value='<%=rs6x("price3")%>'><%=rs6x("desc3")%>
	<option value='<%=rs6x("price1")%>'><%=rs6x("desc3")%></SELECT>
	<input name="folding" type=hidden value="<%=rs6x("desc4")%>" size="10">
</td>
  </tr></table>

          <!-- END FIRST BOX --></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF">
    <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3>
        <tr>
          <td width="100%">
          <!-- SECOND BOX -->
             <img border="0" src="../images/spaziatore.gif" height=5 width="15"><br>
   <font class=textorange>Turnaround</font><br>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
   <select onChange="startCalc(); showimage4();" onBlur="stopCalc();" name="turnaround1">
					<option selected="selected" value='<%=rsxx("price1")%>'><%=rsxx("desc1")%></option>
					<option value='<%=rsxx("price2")%>'><%=rsxx("desc2")%></option>
					<option value='<%=rsxx("price3")%>'><%=rsxx("desc3")%></option>
				</select>
   <br><input name="turnaround" type=hidden value="<%=rsxx("desc3")%>" size="10">
   <img border="0" src="../images/spaziatore.gif" height=5 width="15"><!-- END SECOND BOX --></td>
        </tr>
      </table>

    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF">
    
   <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3>
        <tr>
          <td width="100%">
          <!-- THIRD BOX -->
           <table border="0" cellspacing="0" width="100%" height="1">
      <tr>
    <td width="100%" colspan="2" height="21" valign="top" class=textorange>
 	Each<br>
    <img border="0" src="../images/spaziatore.gif" height=4 width="15"><br>
 <input class="right" type=text name="rate" size="20">
    </td>
  </tr>
  <tr>
    <td width="100%" colspan="2" height="1" valign="top"><img border="0" src="../images/spaziatore.gif" height=4 width="15"></td>
  </tr>
  <tr>
    <td width="100%" colspan="2" height="21" valign="top" class=textorange>Subtotal <br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <input class="right" type=text name="subtotal" size="20">
        <input onChange="startCalc(); " onBlur="stopCalc();" value='10' type=hidden name="insdiscount" size="20">
      <input type=hidden name="discount" size="20">
     	</td>
  </tr>
</table>
          <!-- END THIRD BOX --></td>
        </tr>
      </table>
    
    </td>
  </tr>
  <tr>
    <td width="100%" bgcolor="#FFFFFF">
    
   <table border="0" cellpadding="5" cellspacing="5" width="100%" class=back3>
        <tr>
          <td width="100%">
          <!-- FOURTH BOX -->
          <table border="0" cellpadding="0" cellspacing="0" width="100%" height="1">
  	<tr>
    <td width="100%" height="1">
    <p align="right">
 	<input type=submit name=b value="Continue">
    </p>
	 </td>
  	</tr>
	</table>

          <!-- END FOUTH BOX --></td>
        </tr>
      </table>
    
    </td>
  </tr>
</table>
 
</td>
  </tr>
</table>
</form></td>
  </tr>
</table>
<!--#include file="../bottom.asp" -->
<%

rsy.Close
set rsy = Nothing

conny.Close
Set conny = Nothing

%>
<%

rs.Close
set rs = Nothing

conn.Close
Set conn = Nothing

%>
<%

rsx.Close
set rsx = Nothing

connx.Close
Set connx = Nothing

%>
<%

rsxx.Close
set rsxx = Nothing

connxx.Close
Set connxx = Nothing

%>
<%

rs6x.Close
set rs6x = Nothing

conn6x.Close
Set conn6x = Nothing

%>
<%

rs5x.Close
set rs5x = Nothing

conn5x.Close
Set conn5x = Nothing

%>