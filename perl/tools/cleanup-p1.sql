
DELETE from tbl_Service_Specifications where strvalue='';
DELETE from tbl_Service_Specifications where strName='hdnBreakdown';
DELETE from tbl_Service_Specifications where strName='hdnRequestParams';
DELETE from tbl_Service_Specifications where strName='PreviousSpreads';
DELETE from tbl_Service_Specifications where strName='txtBookType';
DELETE from tbl_Service_Specifications where strName='txtSignatureSize';
DELETE from tbl_Service_Specifications where strName='txtSpecificationQuantity';
DELETE from tbl_Service_Specifications where strName='PrintingService';
DELETE from tbl_Service_Specifications where strName='txtNumberOfCuts';
DELETE from tbl_Service_Specifications where strName LIKE 'tmp%';

alter table tbl_Projects drop column ysnboxes;
alter table tbl_Projects drop strprintproduction;
alter table tbl_Projects drop lngpriority;
alter table tbl_Projects drop dtmrequireddate;
alter table tbl_Projects drop dtmshipdate;
alter table tbl_Projects drop intorderedquantity;
alter table tbl_Projects drop strprintingtype;
alter table tbl_Projects drop ysnbindery;
alter table tbl_Projects drop strsessionid;

