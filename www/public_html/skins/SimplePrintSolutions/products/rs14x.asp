<%

dim conn14x, strConn14x

strConn14x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn14x = Server.CreateObject("ADODB.Connection")
conn14x.Open StrConn14x 


SQL = "SELECT * FROM finishing"

Set rs14x = Server.CreateObject("ADODB.Recordset")

rs14x.Open SQL, Conn14x

%>
