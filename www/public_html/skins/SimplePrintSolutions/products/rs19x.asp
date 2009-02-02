<%

dim conn19x, strConn19x

strConn19x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn19x = Server.CreateObject("ADODB.Connection")
conn19x.Open StrConn19x 


SQL = "SELECT * FROM insidecolor"

Set rs19x = Server.CreateObject("ADODB.Recordset")

rs19x.Open SQL, Conn19x

%>