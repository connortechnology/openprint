<%

dim conn16x, strConn16x

strConn16x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn16x = Server.CreateObject("ADODB.Connection")
conn16x.Open StrConn16x 


SQL = "SELECT * FROM nofpages"

Set rs16x = Server.CreateObject("ADODB.Recordset")

rs16x.Open SQL, Conn16x

%>
