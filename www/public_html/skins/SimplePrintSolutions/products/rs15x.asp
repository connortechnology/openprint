<%

dim conn15x, strConn15x

strConn15x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn15x = Server.CreateObject("ADODB.Connection")
conn15x.Open StrConn15x 


SQL = "SELECT * FROM nofmonths"

Set rs15x = Server.CreateObject("ADODB.Recordset")

rs15x.Open SQL, Conn15x

%>