<%

dim connx, strConnx

strConnx = "Provider = Microsoft.Jet.OLEDB.4.0; Data Source = " &_
	   Server.MapPath("../database/shop.mdb")

Set connx = Server.CreateObject("ADODB.Connection")
connx.Open StrConnx 


SQL = "SELECT * FROM color"

Set rsx = Server.CreateObject("ADODB.Recordset")

rsx.Open SQL, Connx

%>
