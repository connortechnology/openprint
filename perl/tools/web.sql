

insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (28,'','Default Colour Proof','EpsonProof');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (28,'','Default Layout Proof','DigitalDylux');
insert into tbl_equipment_specifications (lngequipmentindex,strunits,strname,strvalue) values (28,'','Double Overs For Covers','Y');
update tbl_Equipment set UseInEstimating=true where lngindex=28;

insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x1-4PageSignatureFoldMaximumImposition','2','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x1-4PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x1-4PageSignatureFoldMinimumWidth','10.236','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','1x1-4PageSignatureFoldRunSpeed','35000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,70,70,'gsm','1x1-4PageSignatureFoldRunSpeed','50000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','1x1-4PageSignatureFoldRunSpeed','50000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x1-4PageSignatureFoldSpineOrientation','Horizontal','false');

insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x1-6PageSignatureFoldMaximumImposition','2','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x1-6PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x1-6PageSignatureFoldMinimumWidth','10.236','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','1x1-6PageSignatureFoldRunSpeed','30000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,70,70,'gsm','1x1-6PageSignatureFoldRunSpeed','42500','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','1x1-6PageSignatureFoldRunSpeed','42500','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x1-6PageSignatureFoldSpineOrientation','Horizontal','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x2-8PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x2-8PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x2-8PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','1x2-8PageSignatureFoldRunSpeed','35000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,70,70,'gsm','1x2-8PageSignatureFoldRunSpeed','50000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','1x2-8PageSignatureFoldRunSpeed','50000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x2-8PageSignatureFoldSpineOrientation','Vertical','false');

insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x3-12PageSignatureFoldBinding','PerfectBound','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x3-12PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','1x3-12PageSignatureFoldRunSpeed','30000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,70,70,'gsm','1x3-12PageSignatureFoldRunSpeed','42500','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,115,115,'gsm','1x3-12PageSignatureFoldRunSpeed','42500','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x3-12PageSignatureFoldSpineOrientation','Vertical','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x4-16PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','1x4-16PageSignatureFoldRunSpeed','40000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,52.5,52.5,'gsm','1x4-16PageSignatureFoldRunSpeed','60000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,90,90,'gsm','1x4-16PageSignatureFoldRunSpeed','60000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,110,110,'gsm','1x4-16PageSignatureFoldRunSpeed','50000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x4-16PageSignatureFoldSpineOrientation','Vertical','false');

insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'2x1-8PageSignatureFoldMaximumImposition','2','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','2x1-8PageSignatureFoldRunSpeed','37000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,50,50,'gsm','2x1-8PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','2x1-8PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,110,110,'gsm','1x4-16PageSignatureFoldRunSpeed','50000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'1x4-16PageSignatureFoldSpineOrientation','Horizontal','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'2x2-16PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','2x2-16PageSignatureFoldRunSpeed','37000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,57.5,57.5,'gsm','2x2-16PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,100,100,'gsm','2x2-16PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','2x2-16PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'2x2-16PageSignatureFoldSpineOrientation','','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'2x3-24PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,50,50,'gsm','2x3-24PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,70,70,'gsm','2x3-24PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,100,100,'gsm','2x3-24PageSignatureFoldRunSpeed','40000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'2x3-24PageSignatureFoldSpineOrientation','Vertical','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'3x1-12PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','3x1-12PageSignatureFoldRunSpeed','37000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,50,50,'gsm','3x1-12PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','3x1-12PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'3x1-12PageSignatureFoldSpineOrientation','Horizontal','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'3x2-24PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','3x2-24PageSignatureFoldRunSpeed','40000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,54,54,'gsm','3x2-24PageSignatureFoldRunSpeed','60000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,90,90,'gsm','3x2-24PageSignatureFoldRunSpeed','60000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,110,110,'gsm','3x2-24PageSignatureFoldRunSpeed','50000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'3x2-24PageSignatureFoldSpineOrientation','Horizontal','false');

insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'4x2-32PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','4x2-32PageSignatureFoldRunSpeed','40000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,50,50,'gsm','4x2-32PageSignatureFoldRunSpeed','54000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,70,70,'gsm','4x2-32PageSignatureFoldRunSpeed','54000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,110,110,'gsm','4x2-32PageSignatureFoldRunSpeed','30000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'4x2-32PageSignatureFoldSpineOrientation','Horizontal','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'5x1-20PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','5x1-20PageSignatureFoldRunSpeed','37000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,57,57,'gsm','5x1-20PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,100,100,'gsm','5x1-20PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','5x1-20PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'5x1-20PageSignatureFoldSpineOrientation','Horizontal','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'6x1-24PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','6x1-24PageSignatureFoldRunSpeed','37000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,57,57,'gsm','6x1-24PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,100,100,'gsm','6x1-24PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','6x1-24PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'6x1-24PageSignatureFoldSpineOrientation','Horizontal','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'7x1-28PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','7x1-28PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,57,57,'gsm','7x1-28PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,100,100,'gsm','7x1-28PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','7x1-28PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'7x1-28PageSignatureFoldSpineOrientation','Horizontal','false');


insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'8x1-32PageSignatureFoldMaximumImposition','1','false');
/*
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMaximumWidth','18.996','false');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,'Inches','1x3-12PageSignatureFoldMinimumWidth','10.236','false');
*/
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,40,40,'gsm','8x1-32PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,57,57,'gsm','8x1-32PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,100,100,'gsm','8x1-32PageSignatureFoldRunSpeed','65000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,120,120,'gsm','8x1-32PageSignatureFoldRunSpeed','45000','true');
insert into tbl_equipment_specifications (lngequipmentindex,dblmin,dblmax,strunits,strname,strvalue,interpolate) values (28,NULL,NULL,NULL,'8x1-32PageSignatureFoldSpineOrientation','Horizontal','false');


update tbl_equipment_specifications set interpolate=true where lngequipmentindex=28 and strname='Press Run Overs';
update tbl_equipment_specifications set value='1000000' where lngequipmentindex=28 and strname='Maximum Plate Impressions';

