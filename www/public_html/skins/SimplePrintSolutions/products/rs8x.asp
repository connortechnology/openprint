<%

dim conn8x, strConn8x

strConn8x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn8x = Server.CreateObject("ADODB.Connection")
conn8x.Open StrConn8x 


SQL = "SELECT * FROM holedrilling"

Set rs8x = Server.CreateObject("ADODB.Recordset")

rs8x.Open SQL, Conn8x

%>