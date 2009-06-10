<%

dim connxx, strConnxx

strConnxx = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set connxx = Server.CreateObject("ADODB.Connection")
connxx.Open StrConnxx 


SQL = "SELECT * FROM turna"

Set rsxx = Server.CreateObject("ADODB.Recordset")

rsxx.Open SQL, Connxx

%>

