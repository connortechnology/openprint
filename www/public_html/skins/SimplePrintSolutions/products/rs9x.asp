<%

dim conn9x, strConn9x

strConn9x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn9x = Server.CreateObject("ADODB.Connection")
conn9x.Open StrConn9x 


SQL = "SELECT * FROM stitching"

Set rs9x = Server.CreateObject("ADODB.Recordset")

rs9x.Open SQL, Conn9x

%>