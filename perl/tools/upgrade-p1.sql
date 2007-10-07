
alter table configuration add Type TEXT;
alter table configuration add Description TEXT;
update configuration set value=value || ',/index.html' where name='public_URIs';
update configuration set value=value || ',/employee/account/login.html' where name='public_URIs';
alter table configuration add category text;
update configuration set category='Email Notifications' WHERE name LIKE '%Email%';
update configuration set category='Miscellaneous Settings' WHERE category IS NULL;
insert into configuration (name,value,type,description,category) values ('DateFormat','%a %b %e, %Y','text','Format string for all displayed dates.','Miscellaneous Settings' );
insert into configuration (name,value,type,description,category) values ('DateTimeFormat','%Y-%m-%d %H:%M','text','Format string used when displaying timstamps with both a date and a time part.','Miscellaneous Settings' );
insert into configuration (name,value,type,description,category) values ('ProjectMoneyFormat','%.0f.00','text','Format string used when displaying monetary amounts on projects.','Miscellaneous Settings' );
/*
insert into configuration (name,value,type,description,category) values ('EasyMode','Y','yes/no', 'Offer Easy (Basic) Mode', 'Miscellaneous Settings' );
*/
insert into configuration (name,value,type,description,category) values ('DetailedMode','Y','yes/no', 'Offer Detailed Mode', 'Miscellaneous Settings' );
insert into Configuration values ('Add Default Colour Proof', 'Y', 'yes/no', 'Whether or not to add a Colour proof to all projects.', 'Miscellaneous Settings');
insert into Configuration values ('Add Default Layout Proof', 'Y', 'yes/no', 'Whether or not to add a Layout proof to all projects.', 'Miscellaneous Settings');
insert into Configuration values ('Add Default Press Proof', 'N', 'yes/no', 'Whether or not to add a Press proof to all projects.', 'Miscellaneous Settings');
insert into configuration values ('QuoteDateFormat','%Y-%m-%d %H:%M','text','Format string used when displaying dates on quotes.','Miscellaneous Settings' );
insert into configuration values ('SendQuoteToAdmin','Y','yes/no','Whether or not to send a copy of all quotes to the admin.','Miscellaneous Settings' );
insert into configuration values ('DefaultInkCoverage','13%','text','Default value for PMS ink coverage.','Miscellaneous Settings' );
/*
insert into configuration values ('UPSUserID','cstrongman','text','User ID used to interface with UPS','Miscellaneous Settings' );
insert into configuration values ('UPSPassword','thomas1','text','Password used to interface with UPS','Miscellaneous Settings' );
insert into configuration values ('UPSAccessCode','BBA0AFDF45481B06','text','Access Code used to interface with UPS','Miscellaneous Settings' );
*/
insert into configuration values ('Dumb Cutting','Y','yes/no','Whether to use simple cutting calculations.','Miscellaneous Settings' );
insert into configuration values ('ProjectFilesPath','/srv/Project Files','text','Where to store files uploaded to the website.','Miscellaneous Settings' );
insert into configuration values ('ForceDigitalDyluxQuantity','2','text','Force a minimum quantity of Digital Dylux Proofs','Miscellaneous Settings' );
update configuration set value=value|| ',/site_map.html,/support/.*' where name='public_URIs';
/*
insert into configuration values ('','','text','','Miscellaneous Settings' );
*/
update configuration set type='yes/no' where name='UsesCookies';
update configuration set type='yes/no' where name='UsesBanners';
update configuration set type='yes/no' where name='NewCustomerAccountActivation';
update configuration set type='yes/no' where name='ShowAccountingOnOrder';
update configuration set type='pricelist' where name='DefaultUSPricelist';
update configuration set type='pricelist' where name='DefaultCAPricelist';

alter table tbl_Currency rename to Currencies;
alter table Currencies rename column lngindex to id;
alter table currencies rename column strname to name;
alter table currencies rename column strsymbol to symbol;
alter table Currencies add short TEXT;
alter table currencies add primary key (id);
update currencies set short='USD' WHERE name='US Dollars';
update currencies set short='CDN' WHERE name='Canadian Dollars';
CREATE TABLE Currency_Conversions (
    from_id     INTEGER NOT NULL, FOREIGN KEY (from_id) REFERENCES Currencies (id),
    to_id           INTEGER NOT NULL, FOREIGN KEY (to_id) REFERENCES Currencies (id),
    rate        float NOT NULL,
    PRIMARY KEY ( from_id, to_id )
);
insert into currency_conversions values (1,1,1);
insert into currency_conversions values (2,2,1);
insert into currency_conversions values (1,2,1);
insert into currency_conversions values (2,1,1);
update Configuration set value='1' where value='default';


alter table tbl_Customer rename to Company;
alter table Company rename column lngCustomerID To Index;
alter table Company rename column strcompanyname to strname;
alter table company rename column strpostalcodezip to strpostalcode;
alter table Company add currency_id integer;
alter table Company add foreign key (currency_id) references currencies (id);
drop sequence tbl_customer_lngcustomerid_seq;
create sequence companyIndex_seq;
select setval( 'companyIndex_seq', (select MAX(index) from company ) );


alter table tbl_customers_in_categories rename to companies_in_marketing_categories;
alter table companies_in_marketing_categories rename column lngcustomerid to Company_Id;
alter table companies_in_marketing_categories rename column lngcategoryid to Category_Id;

alter table tbl_customer_credit rename to company_credit;

alter table company_credit rename column lngcustomerindex to company_id;
alter table company_credit rename column dblcreditlimit to dbllimit;
alter table company_credit rename column dbldownpayment to downpayment;
alter table company_credit rename column ysncredithold to hold;
delete from company_credit where company_id NOT IN (SELECT Index FROM Company);
alter table company_credit add foreign key (company_id) references Company (index);



alter table tbl_Customer_Users rename to Users;
alter table Users rename column lnguserid to index;
drop sequence tbl_customer_users_lnguserid_se;
create sequence users_index_seq;
select setval('users_index_seq',(select max(index) FROM users));
alter table users alter index set default nextval('users_index_seq');

alter table Users rename column lngcustomerid to companyindex;
alter table Users rename column dtmlastloggedin to lastlogin;

alter table tbl_users_in_categories rename to users_in_marketing_categories;
alter table users_in_marketing_categories rename column lnguserindex to user_id;
alter table users_in_marketing_categories rename column lngcategoryindex to category_id;

alter table tbl_User_Types rename to user_types;

alter table tbl_price_lists rename to pricelists;
alter table pricelists rename column lngindex to index;
alter table pricelists rename column strname to name;
alter table pricelists rename column strdescription to description;
alter table pricelists rename column lngcurrencyindex to CurrencyIndex;
alter table pricelists add ci integer;
update pricelists set ci=currencyindex::integer;
alter table pricelists drop currencyindex;
alter table pricelists rename ci to currencyindex;




drop table tbl_Logged_in;

alter table tbl_Marketing_Categories rename to Marketing_Categories;
alter table marketing_categories rename column strgreeting to greeting;
alter table marketing_categories rename column lngindex to id;
alter table marketing_categories rename column strname to name;
alter table marketing_categories rename column strdescription to description;


alter  table tbl_orders rename to orders;
alter table orders rename column lngorderid to index;
alter table orders rename column lngcustomerid to companyindex;
alter table orders rename column lnguserid to userindex;
alter table orders rename column lngemployeeid to employeeindex;
alter table orders add currencyindex INTEGER;
update orders set currencyindex = (SELECT id FROM Currencies where name=strcurrencyname);
alter table orders drop strcurrencyname;
alter table orders drop strcurrencysymbol;
update orders set currencyindex=1 where currencyindex IS NULL and strcountry='CA';   
alter table orders alter currencyindex SET NOT NULL;

alter table tbl_Order_Contents rename to order_contents;
alter table order_contents rename column lngorderid to orderindex;

alter table tbl_order_log rename to order_log;
alter table order_log rename column lnguserindex to user_id;
alter table order_log rename column lngcustomerindex to company_id;
alter table order_log rename column lngorderindex to order_id;

alter table tbl_taxes rename to taxes;
alter table taxes rename txtstatename to state;
alter table taxes rename strstateid to country;
alter table taxes drop lngstateid;
delete from taxes where dblstatepercent=0 and dblfederalpercent=0 and dblharmonisedpercent=0;
update taxes set state=country;
update taxes set country='CA';
update taxes set dblstatepercent=NULL where dblstatepercent=0;
update taxes set dblfederalpercent=NULL where dblfederalpercent=0;
update taxes set dblharmonisedpercent=NULL where dblharmonisedpercent=0;

alter table tbl_Quotes add index integer;
update tbl_Quotes set index=lngQuoteID;
alter table tbl_quotes alter column index set not null;

alter table tbl_Quote_Details drop constraint "$1";
alter table tbl_Quote_Users_For drop constraint "$1";
alter table tbl_Quote_Users_By drop constraint "$1";

alter table tbl_Quotes drop constraint "tbl_quotes_pkey";
alter table tbl_Quotes drop column lngQuoteID;
alter table tbl_Quotes add primary key (index);

alter table tbl_Quote_Users_For add quoteindex integer;
update tbl_Quote_Users_For set quoteindex=lngquoteid;
alter table tbl_Quote_Users_For drop lngquoteid;
alter table tbl_Quote_Users_For add foreign key (quoteindex) references tbl_Quotes (index);

alter table tbl_Quote_Users_By add quoteindex integer;
update tbl_Quote_Users_By set quoteindex=lngquoteid;
alter table tbl_Quote_Users_BY drop lngquoteid;
alter table tbl_Quote_Users_By add foreign key (quoteindex) references tbl_Quotes (index);

alter table tbl_Quote_Details add quoteindex integer;
update tbl_Quote_Details set quoteindex=lngquoteid;
alter table tbl_Quote_Details add foreign key (quoteindex) references tbl_Quotes (index);
alter table tbl_Quote_Details drop column lngquoteid;
alter table tbl_Quotes rename column lngUserID to UserIndex;
alter table tbl_Quotes rename column lngCustomerID to CompanyIndex;
alter table tbl_Quotes add currency_id INTEGER;
update tbl_Quotes set currency_id = (SELECT id FROM Currencies where name=strcurrencyname);
alter table tbl_Quotes drop strcurrencyname;
alter table tbl_Quotes drop strcurrencysymbol;
update tbl_Quotes set currency_id=1 where currency_id IS NULL;   
alter table tbl_Quotes alter currency_id SET NOT NULL;
alter table tbl_Quotes drop strsessionid;


create sequence quotes_id_seq;
select setval('quotes_id_seq',(SELECT Max(Index) FROM tbl_Quotes));

alter table tbl_Quote_Details rename column lngprojectindex to ProjectIndex;

alter table tbl_Quote_Details add foreign key (quoteindex) references tbl_Quotes(index);


alter table tbl_projects rename column lngprojectindex to index;
alter table tbl_projects rename column lngcustomerid to companyindex;
alter table tbl_Projects rename column lnguserindex to userindex;
alter table tbl_Projects drop strmod;
alter table tbl_projects add order_id integer;
alter table tbl_projects add foreign key (order_id) references orders (index);
update tbl_projects set order_id=(SELECT MAX(orderindex) FROM order_contents where lngprojectindex=index);
alter table tbl_Projects add due_date date;
update tbl_Projects set due_date=(select MAX(duedate) FROM order_Contents where orderindex=order_id and lngprojectindex=index);

alter table tbl_Payments rename to payments;
alter table payments rename column lngindex to id;
alter table payments rename column lngorderid to order_id;
alter table payments rename column lngcustomerindex to company_id;
alter table payments rename column lnguserindex to user_id;
alter table payments add currency_id INTEGER;
/* Update currency */
update payments set currency_id = (SELECT id FROM Currencies where name=strcurrencyname);
/* If no currency is set, then try to grab it from the associated order */
update payments set currency_id=(SELECT Currency_id FROM orders where index=order_id) WHERE currency_id IS NULL;
/* If there are any left without a valid currency, then setup them to canadian */
update payments set currency_id = 1 where currency_id IS NULL;
alter table payments alter currency_id set not null;
alter table payments drop strcurrencyname;
alter table payments drop strcurrencysymbol;
alter table payments rename column dtmcreationdate to created_on;


alter table tbl_ProjectTypes rename to project_types;
alter table project_types add category_id INTEGER;

alter table tbl_Paper_recommendations rename to paper_recommendations;

alter table papers add cuttable boolean default true;
alter table papers add doublesided boolean default true;
alter table papers add perfecting boolean default false;
alter table papers add taxexempt1 boolean default false;
alter table papers add taxexempt2 boolean default false;
alter table papers add multipart boolean default false;
alter table papers add digital boolean default false;
alter table papers add score_required boolean default false;
alter table papers add sheets_per_package INTEGER;
alter table papers add basis_width	float;
alter table papers add basis_height	float;
alter table papers add basis_mweight	float;
alter table papers add wpsi	float;
update papers set gsm=mweight*703/(width*height) where not ( (width is null) or (height is null) or (width=0) or ( height=0) );
update papers set wpsi=(mweight*1000)/(width*height) where not ( (width is null) or (height is null) or (width=0) or ( height=0) );
update papers set type='Roll' where width IS NULL and height IS NULL;

alter table tbl_Paper_Prices rename to paper_prices;
alter table paper_prices add id integer;
create sequence paper_prices_id_seq;
alter table paper_prices alter id set default nextval('paper_prices_id_seq');
update paper_prices set id=nextval('paper_prices_id_seq');
alter table paper_prices alter id set not null;

alter table paper_purchase_order_contents rename column paperindex to paper_id;
alter table paper_purchase_order_contents rename column paperpurchaseorderindex to paperpurchaseorder_id;
alter table paper_purchase_orders rename column index to id;

CREATE TABLE ProjectType_RequiredServices (
    ProjectType_id  INTEGER NOT NULL, FOREIGN KEY (ProjectType_id) REFERENCES Project_Types (lngIndex),
    ServiceType_id  INTEGER NOT NULL, FOREIGN KEY (ServiceType_id) REFERENCES tbl_Service_Types (lngIndex),
    PRIMARY KEY (ProjectType_id, ServiceType_id)
);

alter table tbl_Project_log rename column lngprojectindex to Project_id;
alter table tbl_Project_log rename column lngcustomerindex to Company_id;
alter table tbl_Project_log rename column lnguserindex to user_id;
alter table tbl_Project_log rename to Project_Log;
create sequence project_log_id_seq;
alter table project_log add id integer;
alter table project_log alter id set default nextval('project_log_id_seq');
update project_log set id=nextval('project_log_id_seq');
alter table project_log alter id set not null;
alter table project_log drop constraint "project_log_pkey";
alter table project_log add primary key (id);
create index Project_log_idx on project_log (project_id,dtmtimestamp);


alter table tbl_project_templates rename to projecttemplate;
alter table projecttemplate add projecttype_id integer;
alter table projecttemplate add id integer;
create sequence ProjectTemplate_id_seq;
alter table projecttemplate alter id set default nextval('ProjectTemplate_id_seq');
update projecttemplate set id=nextval('ProjectTemplate_id_seq');
alter table projecttemplate alter id set not null;

update projecttemplate set projecttype_id=(select lngindex from project_types where strid=strprojecttype);    
/*
alter table projecttemplate drop strprojecttype;
*/
alter table projecttemplate rename strdimensions to description;
alter table projecttemplate rename strtemplatetype to type; 
update tbl_equipment_specifications set strname='Multipass' where strname='Allow Multi Pass';


alter table tbl_annual_sales rename to annualsales;
alter table annualsales rename column lngindex to id;
alter table annualsales rename column dblmin to min;
alter table annualsales rename column dblmax to max;
alter table tbl_employee_numbers rename to employeenumbers;

update tbl_service_types set strdetailedurl='bind/cutting.html' where strdetailedurl='bind/bind_cutt.html';
update tbl_service_types set strdetailedurl='bind/drilling.html' where strdetailedurl='bind/bind_dril.html';
update tbl_service_types set strdetailedurl='prep/colour_correction.html' where strdetailedurl='prep/prep_colo.html';
update tbl_service_types set strdetailedurl='prep/copy_dot.html' where strdetailedurl='prep/prep_copy_dot.html';
update tbl_service_types set strdetailedurl='pack/pack_by_quantity.html' where strdetailedurl='pack/pack_shri.html';
update tbl_service_types set strdetailedurl='pack/pack_by_quantity.html' where strdetailedurl='pack/pack_bundle.html';
update tbl_service_types set strdetailedurl='pack/pack_by_quantity.html' where strdetailedurl='pack/pack_kraf.html';
update tbl_service_types set strdetailedurl='bind/stitching.html' where strdetailedurl='bind/saddle_stitching.html';
update tbl_service_types set strdetailedurl='bind/stitching.html' where strdetailedurl='bind/loop_stitching.html';

update tbl_Materials set strid='Plain Carton' where strid='PlainCartons';

alter table tbl_equipment_specifications add min float;
update tbl_equipment_specifications set min=dblmin;
alter table tbl_equipment_specifications drop dblmin;
alter table tbl_equipment_specifications rename column min to dblmin;
alter table tbl_equipment_specifications add max float;
update tbl_equipment_specifications set max=dblmax;
alter table tbl_equipment_specifications drop dblmax;
alter table tbl_equipment_specifications rename column max to dblmax;

insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (1,'Sheets Per Colour','Press Run Overs Rate','125');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (2,'Sheets Per Colour','Press Run Overs Rate','125');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (4,'Sheets Per Colour','Press Run Overs Rate','125');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (25,'Sheets Per Colour','Press Run Overs Rate','125');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (27,'Sheets Per Colour','Press Run Overs Rate','125');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (1,'','Runstyles','Sheet Work,Work & Turn,Work & Tumble');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (2,'','Runstyles','Sheet Work,Work & Turn,Work & Tumble');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (4,'','Runstyles','Sheet Work,Work & Turn,Work & Tumble,Perfecting');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (25,'','Runstyles','Sheet Work,Work & Turn,Work & Tumble');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (27,'','Runstyles','Sheet Work,Work & Turn,Work & Tumble');

insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (1,0,1,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (2,0,1,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (4,0,1,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (25,0,1,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (27,0,1,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (1,2,NULL,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (2,2,NULL,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (4,2,NULL,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (25,2,NULL,'Inches','Default Bleed Size','0.125');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue) values (27,2,NULL,'Inches','Default Bleed Size','0.125');

insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (2,'','Varnish Capable','Y');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (3,'','Varnish Capable','Y');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (4,'','Varnish Capable','Y');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (25,'','Varnish Capable','Y');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (27,'','Varnish Capable','Y');

insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (1,'','Default Colour Proof','EpsonProof');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (2,'','Default Colour Proof','EpsonProof');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (4,'','Default Colour Proof','EpsonProof');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (25,'','Default Colour Proof','EpsonProof');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (27,'','Default Colour Proof','EpsonProof');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (1,'','Default Layout Proof','DigitalDylux');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (2,'','Default Layout Proof','DigitalDylux');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (4,'','Default Layout Proof','DigitalDylux');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (25,'','Default Layout Proof','DigitalDylux');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (27,'','Default Layout Proof','DigitalDylux');

insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (1,'','Double Overs For Covers','N');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (2,'','Double Overs For Covers','N');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (4,'','Double Overs For Covers','N');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (25,'','Double Overs For Covers','N');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (27,'','Double Overs For Covers','N');

update tbl_Equipment set UseInEstimating=true where lngindex=28;
alter table tbl_Equipment add jmf_enabled boolean;
alter table tbl_Equipment add instantgate_enabled boolean;
alter table tbl_Equipment add image text;
alter table tbl_Equipment add cost_center text;
insert into configuration values ('JMFEnabled','Y','yes/no','Whether this installation includes support for JMF data collection.','Integration');
insert into configuration values ('InstantGateEnabled','Y','yes/no','Whether this installation includes support for Heidelberg InstantGate data collection.','Integration');
insert into configuration values ('InstantGateJobFilesLocalPath','/srv/JobFiles','text','The local path on the webserver where InstantGate files are stored.','Integration');
insert into configuration values ('InstantGateJobFilesRemotePath','//Fileserver/JobFiles','text','The network path to the shared area where InstantGate files are stored.','Integration');

/*
delete from tbl_Service_Specifications where strname='txtSignatureQty';
*/
update tbl_service_types set strdetailedurl='bind/stitching.html' where strid='SaddleStitching';
update tbl_service_types set strdetailedurl='bind/stitching.html' where strid='LoopStitching';

alter table tbl_emailcampaign rename to emailcampaigns;

alter table emailcampaigns rename column from_email to email_from;
alter table emailcampaigns add created_on timestamp with time zone;
alter table emailcampaigns add updated_on timestamp with time zone;
alter table emailcampaigns rename column emailtext to email_text;

create SEQUENCE helpdesk_id_seq;
alter table tbl_help_desk rename to helpdesk;
alter table helpdesk rename column lngindex to id;
alter table helpdesk rename column lngcustomerindex to company_id;
alter table helpdesk rename column lnguserindex to user_id;
alter table helpdesk alter column id set default nextval('helpdesk_id_seq');
select setval('helpdesk_id_seq', (select MAX(id) FROM helpdesk));
drop sequence helpdeskindex_seq;

alter table tbl_rma rename column lngcustomerindex to company_id;
alter table tbl_rma rename column lnguserindex to user_id;
alter table tbl_rma rename column lngprojectindex to project_id;
alter table tbl_rma rename column lngorderid to order_id;
alter table tbl_rma rename column lngindex to id;
alter table tbl_rma rename to rma;

insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (15,'','Number of Drills','3');
alter table usergroup rename to usergroups;

update tbl_Service_Prices set lngmax = NULL  where lngserviceindex=32; /* 12pg */
update tbl_Service_Prices set lngmax = NULL  where lngserviceindex=33; /* 16pg */
update tbl_Service_Prices set lngmax = NULL  where lngserviceindex=6701;/* 20pg */
update tbl_Service_Prices set lngmax = NULL  where lngserviceindex=34;/* 24pg */
update tbl_Service_Prices set lngmax = NULL  where lngserviceindex=35;/* 32pg */
update tbl_Service_Prices set lngmax = NULL  where lngserviceindex=30;/* 4pg */
update tbl_Service_Prices set lngmax = NULL  where lngserviceindex=31;/* 8pg */

update tbl_Service_Prices set strunits='Per 1000' where strunits='Per 1000 ';
update tbl_Service_Prices set lngmin=lngmin/2,lngmax=lngmax/2,dblcost=dblCost*2,dblPrice=dblPrice*2 where lngserviceindex IN (select lngindex from tbl_Services where strid LIKE '%ImpressionPerfecting') and lngEquipmentIndex=4;
delete from tbl_Service_prices where lngequipmentindex=28 and lngserviceindex IN (select lngindex from tbl_Services where strid LIKE '%ImpressionPerfecting');


update tbl_equipment set useinestimating=true where strid='Cutter-1';

/* # This one is time consuming so do it last */
update tbl_Projects set type_id = (SELECT lngindex from Project_Types where strid=(SELECT strvalue from tbl_Service_Specifications where lngprojectindex=index and strname='ProjectType' LIMIT 1));
update tbl_Projects set currency_id = (SELECT currencyindex FROM pricelists where index=(select lngpricelist from company where index=companyindex)) WHERE currency_id IS NULL;

update tbl_projectType_Defaults set strfieldname='chk'||strfieldname,strdefaultvalue='Bottom' where strfieldname='BleedBottom' and strdefaultvalue='true';
update tbl_projectType_Defaults set strfieldname='chk'||strfieldname,strdefaultvalue='' where strfieldname='BleedBottom' and strdefaultvalue='false';
update tbl_projectType_Defaults set strfieldname='chk'||strfieldname,strdefaultvalue='Top' where strfieldname='BleedTop' and strdefaultvalue='true';
update tbl_projectType_Defaults set strfieldname='chk'||strfieldname,strdefaultvalue='' where strfieldname='BleedTop' and strdefaultvalue='false';
update tbl_projectType_Defaults set strfieldname='chk'||strfieldname,strdefaultvalue='Left' where strfieldname='BleedLeft' and strdefaultvalue='true';
update tbl_projectType_Defaults set strfieldname='chk'||strfieldname,strdefaultvalue='' where strfieldname='BleedLeft' and strdefaultvalue='false';
update tbl_projectType_Defaults set strfieldname='chk'||strfieldname,strdefaultvalue='Right' where strfieldname='BleedRight' and strdefaultvalue='true';
update tbl_projectType_Defaults set strfieldname='chk'||strfieldname,strdefaultvalue='' where strfieldname='BleedRight' and strdefaultvalue='false';
update tbl_projectType_Defaults set strfieldname='ddm'||strfieldname where strfieldname='BleedSize';

insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT lngindex from tbl_Service_Types where strid='Padding'), 'rdbCardboardBacking', 'Y' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT lngindex from tbl_Service_Types where strid='ShrinkWrap'), 'rdbCardboardBacking', 'Y' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT lngindex from tbl_Service_Types where strid='Bundle'), 'rdbCardboardBacking', 'N' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT lngindex from tbl_Service_Types where strid='AdditionalSignature'), 'chkBleedLeft', 'Left' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT lngindex from tbl_Service_Types where strid='AdditionalSignature'), 'chkBleedRight', 'Right' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT lngindex from tbl_Service_Types where strid='AdditionalSignature'), 'chkBleedTop', 'Top' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT lngindex from tbl_Service_Types where strid='AdditionalSignature'), 'chkBleedBottom', 'Bottom' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT lngindex from tbl_Service_Types where strid='AdditionalSignature'), 'txtCropMarkSpace', '0.0625' );

alter table tbl_trade_references rename to trade_references;
alter table trade_references rename column lngcustomerid to company_id;
alter table trade_references rename column strcompanyname to companyname;
alter table trade_references rename column strcontact to contact;
alter table trade_references rename column strphone to phone;
alter table trade_references rename column strext to ext;
alter table trade_references rename column strfax to fax;
alter table trade_references rename column stremail to email;
alter table trade_references rename column dblcreditlimit to creditlimit;
alter table trade_references rename column lngreferenceid to id;
delete from trade_references where company_id NOT IN (select index from company);
alter table trade_references add foreign key (company_id) references company (index);

alter table tbl_addresses add company_id integer;
update tbl_Addresses set company_id=(select index from company where lngprefshipaddressid=lngindex);
delete from tbl_Addresses where company_id is null;
alter table tbl_Addresses alter company_id set not null;
alter table company drop lngprefshipaddressid;
CREATE SEQUENCE Upload_id_seq;

alter table tbl_Project_Files rename to Project_files;
alter table project_files rename column lngprojectindex to project_id;
alter table project_files rename column strfilename to filename;
alter table project_files rename column strdescription to description;
delete from project_files where project_id NOT IN (select index from tbl_Projects);
alter table project_Files add foreign key (project_id) references tbl_Projects (index);

update tbl_Service_Types set strid='CustomService' where strid='OS';
update tbl_Service_Specifications set strvalue='CustomService' where strname='ServiceType' and strvalue='OS';

insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Brochures'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Brochures'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Letterhead'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Letterhead'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Flyers'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Flyers'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Covers'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Covers'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='ScratchPads'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='ScratchPads'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='ScratchPads'),(select lngindex from tbl_Service_types where strid='Padding'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Posters'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Posters'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Inserts'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Inserts'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Packaging'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Packaging'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Custom'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='Custom'),(select lngindex from tbl_Service_types where strid='Cutting') );
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='PressSheetCombination'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='PressSheetCombination'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='BusinessCards'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='BusinessCards'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='MultiPagePublication'),(select lngindex from tbl_Service_types where strid='Proofs'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='MultiPagePublication'),(select lngindex from tbl_Service_types where strid='Cutting'));
insert into projecttype_requiredservices (projecttype_id,servicetype_id) values ((select lngindex from project_types where strid='MultiPagePublication'),(select lngindex from tbl_Service_types where strid='Folding'));

update company set ysnsupplier='Y' where index=6;

alter table tbl_Service_prices alter lngequipmentindex drop not null;

DELETE FROM tbl_Service_prices where lnglistindex=19;
DELETE FROM tbl_material_prices where lnglistindex=19;
DELETE FROM paper_prices where lnglistindex=19;
DELETE FROM pricelists where index=19;
DELETE FROM tbl_Service_prices where lnglistindex=24;
DELETE FROM tbl_material_prices where lnglistindex=24;
DELETE FROM paper_prices where lnglistindex=24;
DELETE FROM pricelists where index=24;
UPDATE Company set currency_id=2 where strcountry='US';

alter table tbl_credit_app rename column lngindex to id;
alter table tbl_credit_app rename column lngcustomerindex to company_id;
alter table tbl_credit_app rename column lnguserindex to user_id;
alter table tbl_credit_app rename to creditapplications;

insert into tbl_service_types (strid,strname,strcategory,strdetailedurl,ysncreatevisible,ysnviewvisible ) values ('PerfectBound','Perfect Bind','Bindery','bind/perfect.html','Y','Y');
insert into tbl_service_types (strid,strname,strcategory,strdetailedurl,ysncreatevisible,ysnviewvisible ) values ('SpinePaste','Spine Pasting','Bindery','bind/perfect.html','Y','Y');

insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'PerfectBound','5.5 x 8.5 Finished','5.5','8.5','5.5','8.5');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'PerfectBound','7 x 8.5 Finished','7','8.5','7','8.5');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'PerfectBound','8.125 x 10.75 Finished','8.125','10.75','8.125','10.75');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'PerfectBound','8.375 x 10.75 Finished','8.375','10.75','8.375','10.75');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'PerfectBound','8.5 x 11 Finished','8.5','11','8.5','115');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'SpinePaste','5.5 x 8.5 Finished','5.5','8.5','5.5','8.5');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'SpinePaste','7 x 8.5 Finished','7','8.5','7','8.5');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'SpinePaste','8.125 x 10.75 Finished','8.125','10.75','8.125','10.75');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'SpinePaste','8.375 x 10.75 Finished','8.375','10.75','8.375','10.75');
insert into projecttemplate (projecttype_id,type,description,dblfinishedwidth,dblfinishedheight,dblflatwidth,dblflatheight) values ((select lngindex from project_types where strid='MultipagePublication'),'SpinePaste','8.5 x 11 Finished','8.5','11','8.5','115');


insert into tbl_services (strid) values ('Work & TumbleSetup');
insert into tbl_service_Prices (lnglistindex,lngserviceindex,dblcost,dblprice) values (1,(select lngindex from tbl_Services where strid='Work & TumbleSetup'),1,1);

/*
insert into tbl_service_types (strid,strname,strcategory,strdetailedurl,ysncreatevisible,ysnviewvisible,lngsort ) values ('UPS','UPS','Shipping','shipping/UPS.html','Y','Y',200);
*/
insert into tbl_service_types (strid,strname,strcategory,strdetailedurl,ysncreatevisible,ysnviewvisible,lngsort ) values ('CustomerPickUp','Customer Pick Up','Shipping','','Y','Y',200);
update tbl_Service_Types set strdetailedurl='shipping/Shipping.html' where lngindex=23;

alter table Schedule add id SERIAL;
alter table schedule add primary key(id);
alter table Schedule add endtime timestamp with time zone;
alter table Schedule add endtime_locked boolean;
alter table Schedule add starttime_locked boolean;
alter table Schedule add runtime_locked boolean;
alter table Schedule add value	integer;

update paper_prices set strunits='Per 100lbs';
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='GlossVarnish'),'Coverage',NULL,NULL,1000000,'Square Inches Per Kilo',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='MatteVarnish'),'Coverage',NULL,NULL,1000000,'Square Inches Per Kilo',false);

insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='CyanInk'),'Coverage',1,1,1277473,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='CyanInk'),'Coverage',3,3,1277473,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='CyanInk'),'Coverage',2,2,1198454,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='CyanInk'),'Coverage',NULL,NULL,750000,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='CyanInk'),'Weight',NULL,NULL,0.0096,'g',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='MagentaInk'),'Coverage',1,1,1250003,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='MagentaInk'),'Coverage',3,3,1250003,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='MagentaInk'),'Coverage',2,2,1086449,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='MagentaInk'),'Coverage',NULL,NULL,713190,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='YellowInk'),'Coverage',1,1,1174242,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='YellowInk'),'Coverage',3,3,1174242,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='YellowInk'),'Coverage',2,2,1076389,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='YellowInk'),'Coverage',NULL,NULL,740446,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='BlackInk'),'Coverage',1,1,1162500,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='BlackInk'),'Coverage',3,3,1162500,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='BlackInk'),'Coverage',2,2,952869,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='BlackInk'),'Coverage',NULL,NULL,442015,'',false);

insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='PMSInk'),'Coverage',NULL,NULL,442015,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='PMSInk'),'Coverage',1,1,900000,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='PMSInk'),'Coverage',2,2,850000,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='MetallicInk'),'Coverage',NULL,NULL,442015,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='MetallicInk'),'Coverage',1,1,750000,'',false);
insert into Material_specifications (id,material_id,name,min,max,value,units,interpolate) values (nextval('materialspecification_id_seq'),(Select lngindex from tbl_Materials where strid='MetallicInk'),'Coverage',2,2,850000,'',false);
alter table tbl_Service_Prices add id integer;
create sequence serviceprices_id_seq;
alter table tbl_Service_Prices alter id set default nextval('serviceprices_id_seq');
update tbl_Service_Prices set id=nextval('serviceprices_id_seq');
alter table tbl_Service_Prices alter id set not null;

insert into configuration values ('WeightMarkup','5','text','Amount percentage to markup the calculated weight of a product','Miscellaneous');

update tbl_service_prices set strunits='Per M' Where lngserviceindex=(select lngindex from tbl_Services where strid='VarnishInLine');

update tbl_Service_Types set strid='Bundling' where strid='Bundle';
update tbl_Services set strid='Bundling' where strid='Bundle';
update tbl_Services set strid='BundlingMinimum' where strid='BundleMinimum';

\i /etc/apache2/lib/perl/openprint/sql/Product_Categories.sql
\i /etc/apache2/lib/perl/openprint/sql/Products.sql
\i /etc/apache2/lib/perl/openprint/sql/Ordered_Products.sql
\i /etc/apache2/lib/perl/openprint/sql/Upload.sql
\i /etc/apache2/lib/perl/openprint/sql/ProjectType_Categories.sql

alter table orders rename column dateinvoiced to invoiced_on;

alter table tbl_material_prices add id integer;
alter table tbl_material_prices alter id set default nextval(('materialprices_id_seq'::text)::regclass);
create sequence materialprices_id_seq;
update tbl_material_prices set id=nextval(('materialprices_id_seq'::text)::regclass);
alter table tbl_material_prices alter id set not null;

insert into configuration values ('SpecialColourQuantity','8','text','Number of special colours to offer per side','Miscellaneous');

insert into configuration values ('DrillingSizes','0.125~1/8",0.1875~3/16",0.25~1/4",0.3125~5/16",0.375~3/8",0.4375~7/16",0.5~1/2"','text','Options for hole size','Miscellaneous');

