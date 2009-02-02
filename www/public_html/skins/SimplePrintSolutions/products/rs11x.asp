 
<%

dim conn11x, strConn11x

strConn11x = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set conn11x = Server.CreateObject("ADODB.Connection")
conn11x.Open StrConn11x 


SQL = "SELECT * FROM businesscardslot"

Set rs11x = Server.CreateObject("ADODB.Recordset")

rs11x.Open SQL, Conn11x

%>
