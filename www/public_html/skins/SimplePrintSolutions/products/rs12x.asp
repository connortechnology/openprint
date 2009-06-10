<%

dim conn12x, strConn12x

strConn12x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn12x = Server.CreateObject("ADODB.Connection")
conn12x.Open StrConn12x 


SQL = "SELECT * FROM coating"

Set rs12x = Server.CreateObject("ADODB.Recordset")

rs12x.Open SQL, Conn12x

%>
