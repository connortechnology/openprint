<%@ Language="VBScript"%>
<%Title="Produts/Magazine&Booklet"%>
<% Dim step, insdiscount
	step = "fase1"
	insdiscount = 100 
	choosescript= "magazine" 
%>
<!--#include file="rsy.asp" -->
<!--#include file="rs.asp" -->
<!--#include file="rsx.asp" -->
<!--#include file="rsxx.asp" -->
<!--#include file="rs16x.asp" -->
<!--#include file="rs17x.asp" -->
<!--#include file="rs18x.asp" -->
<!--#include file="rs19x.asp" -->
<%

dim conn5x, strConn5x

strConn5x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn5x = Server.CreateObject("ADODB.Connection")
conn5x.Open StrConn5x 


SQL = "SELECT * FROM BookletPrice12x12"

Set rs5x = Server.CreateObject("ADODB.Recordset")

rs5x.Open SQL, Conn5x

%>
<!--#include file="../headerpro.asp" -->
<table border="0" cellpadding="10" cellspacing="0"  width="584" height="470">
  <tr>
    <td valign="top" class=text>
<form name="autoSumForm" action=../shoppingcart/review_order.asp method="post">
<input type=hidden name=product value="Booklet">
<input name="sizep" type=hidden value="12 x 12" size="10">
<input type=hidden name=xchange onFocus="startCalc();" onBlur="stopCalc();" value="<%=rsy("price1")%>">
<input type=hidden name=tfifty onFocus="startCalc();" onBlur="stopCalc();" value="50">
<input type=hidden onFocus="startCalc();" onBlur="stopCalc();" size=1 name=color1 value="<%=rsx("price2")%>">
<input name="color" type=hidden value="<%=rsx("desc2")%>" size="10">
 <table border="0" cellspacing="1" width="560">
  <tr>
    <td width="260" valign="top">
      <table border="0" cellpadding="10" cellspacing="0" width="100%" height="25">
        <tr>
          <td width="100%" height="260">
            <p align="center"><img border="0" src="images/Magazineico.jpg"></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>Magazine/Booklet
            size:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15">
          <br>
            <font class=textsize><a href="mag-book.asp" class="linksize">6 x 6</a>  | <a href="mag-book8x11.asp" class="linksize">5.5 x 8.5</a>
       |
             <a href="mag-book12x12.asp" class="linksize">8.5 x 11</a>  |&nbsp;12 x 12</font></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><hr></td>
        </tr>
        <tr>
          <td width="100%" height="34" class=textorange><b>File Preparation:<br>
            </b>
      <img border="0" src="../images/spaziatore.gif" height=7 width="15"><br>
            <a href="../templates/magazines.asp" class="linksize">Download templates</a><br>
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
    <td width="100%" colspan="2" height="1" class=textorange>Quantity<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm1Value()" onBlur="stopCalc();" size=1 name=bprice>
     <OPTION value='<%=rs5x("price1")%>'><%=rs5x("desc1")%>
      <OPTION value='<%=rs5x("price2")%>'><%=rs5x("desc2")%>
      <OPTION value='<%=rs5x("price3")%>'><%=rs5x("desc3")%>
      <OPTION value='<%=rs5x("price4")%>'><%=rs5x("desc4")%>
      <OPTION value='<%=rs5x("price5")%>'><%=rs5x("desc5")%>
      <OPTION value='<%=rs5x("price6")%>'><%=rs5x("desc6")%>
      <OPTION value='<%=rs5x("price7")%>'><%=rs5x("desc7")%>
      <OPTION value='<%=rs5x("price8")%>'><%=rs5x("desc8")%>
      <OPTION value='<%=rs5x("price9")%>'><%=rs5x("desc9")%>
      <OPTION value='<%=rs5x("price10")%>'><%=rs5x("desc10")%></SELECT><br>
      <input onChange="startCalc();" onBlur="stopCalc();" type=hidden name="quantity" value="<%=rs5x("desc1")%>" size="10">
    </td>
  </tr>
  <tr>
    <td width="100%" height="2" valign="top" colspan="2"><hr size="1" color="#DADADA">
</td>
  </tr>
  <tr>
    <td width="100%" height="55" valign="top" class=textorange colspan="2">Number of Pages<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
      <SELECT onChange="startCalc(); setForm17Value()" onBlur="stopCalc();" size=1 name=nofpages1>
      <OPTION value='<%=rs16x("price1")%>'><%=rs16x("desc1")%>
      <OPTION value='<%=rs16x("price2")%>'><%=rs16x("desc2")%>
      <OPTION value='<%=rs16x("price3")%>'><%=rs16x("desc3")%>
      <OPTION value='<%=rs16x("price4")%>'><%=rs16x("desc4")%>
      <OPTION value='<%=rs16x("price5")%>'><%=rs16x("desc5")%>
      <OPTION value='<%=rs16x("price6")%>'><%=rs16x("desc6")%>
      <OPTION value='<%=rs16x("price7")%>'><%=rs16x("desc7")%>
      <OPTION value='<%=rs16x("price8")%>'><%=rs16x("desc8")%>
		</SELECT><br><input type=hidden name="nofpages" value="<%=rs16x("desc1")%>" size="10">
</td>
  <tr>
    <td width="100%" colspan="2" height="21" valign="top"><hr size="1" color="#DADADA">
    </td>
  </tr>
    <tr>
    <td width="46%" height="21" valign="top" class=textorange>Cover Paper<br>
      <img border="0" src="../images/spaziatore.gif" height=6 width="15"><br>
 	<SELECT onChange="startCalc(); setForm18Value()" onBlur="stopCalc();" size=1 name=cpaper1>
   		<OPTION value='<%=rs17x("price1")%>'><%=rs17x("desc1")%>
      <OPTION value='<%=rs17x("price2")%>'><%=rs17x("desc2")%>
      <OPTION value='<%=rs17x("price3")%>'><%=rs17x("desc3")%></SELECT>
      <input type=hidden name="cpaper" value="<%=rs17x("desc1")%>" size="10">
</td>
    <td width="54%" height="21" valign="top">
    </td>
  </tr>
  <tr>
    <td width="100%" colspan="2" height="21" valign="top"><hr size="1" color="#DADADA">
    </td>
  </tr>
</table>

          <table border="0" cellspacing="0" width="100%" height="1">
          </table>
          <table border="0" cellspacing="0" width="100%" height="1">
            <tr>
              <td width="46%" height="21" valign="top" class="textorange">Inside Pages Paper<br>
                <img border="0" src="../images/spaziatore.gif" height="6" width="15"><br>
                <select onChange="startCalc(); setForm3Value()" onBlur="stopCalc();" size="1" name="paper1">
                  <option value="<%=rs("price4")%>"><%=rs("desc4")%></option>
                  <option value="<%=rs("price2")%>"><%=rs("desc2")%></option>
                  <option value="<%=rs("price3")%>"><%=rs("desc3")%></option>
                </select><br><input type=hidden name="paper" value="<%=rs("desc4")%>" size="10">
              </td>
              <td width="54%" height="21" valign="top"></td>
            </tr>
            <tr>
              <td width="100%" colspan="2" height="21" valign="top">
                <hr size="1" color="#DADADA">
              </td>
            </tr>
            <tr>
              <td width="46%" height="21" valign="top" class="textorange">Inside Pages Color<br>
                <img border="0" src="../images/spaziatore.gif" height="6" width="15"><br>
                <select onChange="startCalc(); setForm20Value()" onBlur="stopCalc();" size="1" name="icolor1">
                  <option value="<%=rs19x("price2")%>"><%=rs19x("desc2")%></option>
                  <option value="<%=rs19x("price4")%>"><%=rs19x("desc4")%></option>
                </select><input type=hidden name="icolor" value="<%=rs19x("desc2")%>" size="10"></td>
              <td width="54%" height="21" valign="top"></td>
            </tr>
          </table>
          <table border="0" cellspacing="0" width="100%" height="1">
            <tr>
              <td width="100%" colspan="2" height="21" valign="top">
                <hr size="1" color="#DADADA">
              </td>
            </tr>
            <tr>
              <td width="46%" height="21" valign="top" class="textorange">Bindery<br>
                <img border="0" src="../images/spaziatore.gif" height="6" width="15"><br>
                <select onChange="startCalc(); setForm19Value()" onBlur="stopCalc();" size="1" name="binder1">
                  <option value="<%=rs18x("price1")%>"><%=rs18x("desc1")%></option>
                  <option value="<%=rs18x("price2")%>"><%=rs18x("desc2")%></option>
                </select><input type=hidden name="binder" value="<%=rs18x("desc1")%>" size="10"></td>
              <td width="54%" height="21" valign="top"></td>
            </tr>
          </table>
          <table border="0" cellspacing="0" width="100%" height="1">
</table>

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
   <select onChange="startCalc(); setForm4Value()" onBlur="stopCalc();" name="turnaround1">
					<option selected="selected" value='<%=rsxx("price1")%>'><%=rsxx("desc1")%></option>
					<option value='<%=rsxx("price2")%>'><%=rsxx("desc2")%>
					<option value='<%=rsxx("price3")%>'><%=rsxx("desc3")%>
				</select>
   <br><input type=hidden name="turnaround" value="<%=rsxx("desc1")%>" size="10">
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
        <input onChange="startCalc(); " onBlur="stopCalc();" value='100' type=hidden name="insdiscount" size="20">
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

rs5x.Close
set rs5x = Nothing

conn5x.Close
Set conn5x = Nothing

%>
<%

rs16x.Close
set rs16x = Nothing

conn16x.Close
Set conn16x = Nothing

%>
<%

rs17x.Close
set rs17x = Nothing

conn17x.Close
Set conn17x = Nothing

%>
<%

rs18x.Close
set rs18x = Nothing

conn18x.Close
Set conn18x = Nothing

%>