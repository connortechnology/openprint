UPDATE users set type='A' where email='iconnor@connortechnology.com';
update service_types set name='Aqueous',type='Aqueous',url='spec/Aqueous.html' where name='AQCoating';
UPDATE service_types set url='prep/proofs.html' WHERE url='prep/prep_proo.html';
UPDATE service_types set type='Prepress' WHERE name='TypeSetting';
UPDATE service_types set type='Prepress' WHERE name='FileCorrection';
UPDATE service_types set url='bind/stitching.html' WHERE name='CornerStitching';
UPDATE service_types set url='shipping/Shipping.html' WHERE url='shipping/shipping.html';
UPDATE service_types set url='prin/Signature.html' WHERE url='service/printing.html';
UPDATE service_types set name='Signature', type='Printing'  WHERE name='Printing';
UPDATE service_types set type='Skids'  WHERE type='BulkSkids';
UPDATE service_types set type='Skids'  WHERE type='PlainCartons';
UPDATE service_types set name='Bundling'  WHERE name='Bundle';
UPDATE service_types set url='pack/Bundling.html' WHERE url='pack/pack_bundle.html';
UPDATE service_types set url='bind/Spiral.html' WHERE url='bind/bind_spir.html';
UPDATE service_types set url='bind/cutting.html' WHERE url='bind/bind_cutt.html';
UPDATE service_types set url='bind/Counting.html' WHERE name='Counting';
UPDATE service_types set url='bind/Collating.html' WHERE url='bind/collating.html';
UPDATE service_types set url='bind/drilling.html' WHERE url='bind/bind_dril.html';
UPDATE service_types set url='spec/Embossing.html' WHERE url='spec/embossing.html';
UPDATE service_types set url='bind/Gluing.html' WHERE url='bind/bind_gluing.html';
UPDATE service_types set url='bind/stitching.html' WHERE url='bind/bind_sadd.html';
UPDATE service_types set url='bind/stitching.html' WHERE url='bind/bind_loop.html';
UPDATE service_types set url='bind/Numbering.html' WHERE name='Numbering';
UPDATE service_types set url='bind/Padding.html' WHERE name='Padding';
UPDATE service_types set url='bind/PerfectBound.html',type='PerfectBound' WHERE name='PerfectBinding';
UPDATE service_types set url='bind/RoundCornering.html' WHERE name='RoundCornering';
UPDATE service_types set url='bind/KissCutting.html' WHERE name='KissCutting';
UPDATE service_types set url='spec/FoilStamping.html',type='FoilStamping' WHERE name='FoilStamping';
UPDATE service_types set url='bind/Collating.html' WHERE url='bind/bind_collating.html';
UPDATE service_types set url='pack/pack_by_quantity.html',type='Packaging' WHERE url='pack/pack_shri.html';
UPDATE service_types set url='pack/pack_by_quantity.html',type='Packaging' WHERE url='pack/Bundling.html';
UPDATE service_types set url='spec/UVCoating.html' WHERE name='UVCoating';
UPDATE service_types set description='SCORING' WHERE name='Scoring';
UPDATE service_types set create_visible=true WHERE name='Shipping';
insert into service_types (name,description,url,category_id,create_visible,view_visible,summary_visible,allow_delete, type)
values ('Stripping','STRIPPING','spec/Stripping.html', (SELECT id from servicetype_categories where name='Finishing'),true,true,true,true, 'Stripping');
insert into services (name,description, category_id) values ('Stripping', 'Stripping', (SELECT id from service_categories where name='Bindery'));
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='Stripping'),
  (select id from tbl_equipment where strname='ManualLabourStation-1'),
  0.05,null,0.05,'per lb','Y');
insert into services (name,description, category_id) values ('StrippingMakeReady', 'Stripping Make Ready', (SELECT id from service_categories where name='Bindery'));
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='StrippingMakeReady'),
  (select id from tbl_equipment where strname='ManualLabourStation-1'),
  0.0,null,0.00,'','Y');
insert into service_types (name,description,url,category_id,create_visible,view_visible,summary_visible) values ('Perforating','PERFORATING','bind/perforating.html', (SELECT id from servicetype_categories where name='Finishing'),true,true,true);
insert into service_types (name,description,url,category_id,create_visible,view_visible,summary_visible) values ('CustomerPickUp','Pick Up','shipping/CustomerPickup.html', (SELECT id from servicetype_categories where name='Shipping'),true,true,true);
INSERT INTO tbl_service_defaults (lngservicetypeindex, strfieldname, strdefaultvalue) values ((SELECT id from service_types where name='ShrinkWrap'), 'rdbCardboardBacking','Y');
INSERT INTO tbl_service_defaults (lngservicetypeindex, strfieldname, strdefaultvalue) values ((SELECT id from service_types where name='Bundling'), 'rdbCardboardBacking','N');
INSERT INTO tbl_service_defaults (lngservicetypeindex, strfieldname, strdefaultvalue) values ((SELECT id from service_types where name='Bundling'), 'bands_per_package','1');
INSERT INTO tbl_service_defaults (projecttype_id, lngservicetypeindex, strfieldname, strdefaultvalue) values (
  (SELECT id from project_types where name='PresentationFolders'),
  (SELECT id from service_types where name='Signature'), 'rdbPocketSize','4');
INSERT INTO tbl_service_defaults (projecttype_id, lngservicetypeindex, strfieldname, strdefaultvalue) values (
  (SELECT id from project_types where name='PresentationFolders'),
  (SELECT id from service_types where name='Signature'), 'txtPocketSize','4');
insert into service_types (name,description,url,category_id,create_visible,view_visible,summary_visible,allow_delete)
values ('DTaping','DTAPING','bind/DTaping.html', (SELECT id from servicetype_categories where name='Finishing'),true,true,true,true);

UPDATE service_types set type='Spiral' WHERE type='MetalCoil';

UPDATE service_prices set units='stock calliper - per plate' where service_id=(SELECT id from Services WHERE Name='PressUnitMakeReady') and units is null;
UPDATE tbl_material_prices set strunits='per inch' where lngmaterialindex=(SELECT id from materials WHERE Name='MetalCoil') and strunits IS NULL;
UPDATE tbl_material_prices set strunits='per inch' where lngmaterialindex=(SELECT id from materials WHERE Name='PlasticCoil') and strunits IS NULL;
UPDATE tbl_material_prices set strunits='per inch' where lngmaterialindex=(SELECT id from materials WHERE Name='Cerlox') and strunits IS NULL;

update servicetype_categories set sorting=1 where name='Printing';

UPDATE tbl_equipment_specifications set strname='MakeReady Overs Rate' WHERE strname='Press Unit Setup Overs';


update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=75; /* Colour Key */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=76; /* Colour Laser */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=77; /* Colour Proof */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=97; /* Digital Dylux*/
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=97; /* Double Dylux*/
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=105; /* Dylux COnventional*/
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=115; /* Epson */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=263; /* Folding Dylux */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=133; /* Fuji */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=257; /* HP */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=277; /* Layout */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=184; /* Polaroid */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=204; /* Sherpa */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=309; /* Shpectru */
update services set servicetype_id=(SELECT id from service_types where name='Proofs') where Id=165; /* PDF */

UPDATE Companies set offers_credit=true where id=102;
UPDATE Companies set ysnsupplier='Y' where id=102;
INSERT INTO Configuration (Name,Value,Description,Type,category) values ('smtp_server','10.0.3.1','Email Server','text','Email Notifications');
INSERT INTO Configuration (Name,Value,Type,Description,category) values ('owner_id','102','Owner','Site Owner','Primary');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('Add_Default_Layout_Proof','Y','yesno','Estimating', 'Whether or not to add a Colour proof to all projects.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('Add_Default_Colour_Proof','Y','yesno','Estimating', 'Whether or not to add a Layout proof to all projects.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('Add_Default_Press_Proof','N','yesno','Estimating', 'Whether or not to add a Press proof to all projects.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('DateFormat','%a %b %e, %Y','text','Miscellaneous', 'Format string for all displayed dates.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('DateTimeFormat','%Y-%m-%d %H:%M','text','Miscellaneous', 'Format string used when displaying timstamps with both a date and a time part.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('SpecialColourQuantity','5','number','Miscellaneous', 'Number of special colours to offer per side');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('UnitPriceRounding','0.001','number','Miscellaneous', 'Value to round unit prices to on projects.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('ProjectMoneyFormat','%.0f.00','text','Miscellaneous', 'Format string used when displaying monetary amounts on projects.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('UnitPriceFormat','%.2f','text','Miscellaneous', 'Format string used when displaying unit prices on projects.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('ProjectPriceRounding','1','number','Miscellaneous', 'Value to round price values to on a project.');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('DefaultPMSCoverage','20','number','Miscellaneous', 'Default Coverage for PMS Ink coverage');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('DefaultInkCoverage','20','number','Miscellaneous', 'Default Coverage for Non PMS Ink coverage');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('DefaultAqueous_GlossCoverage','100','number','Miscellaneous', 'Default Coverage for AQ Gloss');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('DefaultAqueous_SatinCoverage','100','number','Miscellaneous', 'Default Coverage for AQ Satin');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('DefaultAqueous_SoftTouchCoverage','100','number','Miscellaneous', 'Default Coverage for AQ Soft Touch');
INSERT INTO Configuration (Name,Value,Type,category,description) values ('QuoteDisclaimer','Process an Order
At anytime you may process an order for any project or quantity contained in this quote. To process an order from an email, click on
the "Quote ID" located above. After following the link and logging into our web site with your email address and password, click on
the "Process Order" button located near the top right of the "Quote History Details" page and follow the "Order Instructions".
Project Files and Proofs
Default project file format is Adobe PDF (Portable Document Format) unless specified otherwise. To avoid any additional file
preparation charges please read and follow our file preparation instructions carefully. Project files may be uploaded once an order
has been placed by clicking on the "Project Files" button located near the top right of the "Project View Current Project" page.
Credit, Billing and Production Policies
First-time and non-credit account orders may be subject to a production down payment with the balance to be paid in full before the
project leaves our production facilities. Available non-credit account payment options may include Cash, Certified Cheque, Visa,
Mastercard or Bank Draft. Clients requiring credit may apply via our on-line credit application. Terms may be available to clients
upon approved credit.
All CTP quotes must include a digital proof. Production specifications and prices quoted are subject to the viewing of artwork, film or
electronic file. Please verify all project specifications listed in the project docket(s) for accuracy. If project specifications or prices
appear to be questionable please contact us via our helpdesk or call: <a href="tel:9055011296">(905) 501-1296</a> before ordering or preparing reseller
quotations. Quoted prices may be subject to paper price increases, availability, applicable taxes and are valid for 30 days.','text','Disclaimers', 'Text to put at the bottom of a quote');

DROP TABLE IF EXISTS tbl_annual_sales;
INSERT INTO projecttype_categories (id, name) values (2, 'Multi-Sheet Bound Print Projects');
INSERT INTO projecttype_categories (id, name) values (1, 'Single Sheet Flat or Folded Print Projects');
UPDATE project_types set category_id=1 where ysnmultipage=false;
UPDATE project_types set category_id=2 where ysnmultipage=true;
UPDATE project_types set url='' where url='prin/prin_broc.html';
UPDATE project_types set name='ScratchPads',type='ScratchPads' where name='Scratch/WritingPads';

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (120, 'Colour Bar Default', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (120, 'Colour Bar Orientation', 'Width');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (120, 'Orientation', 'Landscape');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (120, 'Default Bleed Size', '0.125','Inches');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (189, 'Stitching Capable', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (189, 'Cutting Capable', 'When Stitching');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (189, 'Drilling Capable', 'When Stitching');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (163, 'Stitching Capable', 'When Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (163, 'Cutting Capable', 'When Stitching');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (163, 'Drilling Capable', 'When Stitching');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (74, 'Collating Capable', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (15, 'Collating Capable', 'Y');


INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (115, 'Cutting Capable', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (115, 'Cutting Time', '10', 'Seconds');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (115, 'Make Ready Time', '60', 'Seconds/Cut');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (115, 'Maximum Lift Depth', '4', 'Inches');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (114, 'Printing Type', 'Sheetfed');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (122, 'Printing Type', 'Sheetfed');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (165, 'Printing Type', 'Sheetfed');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (166, 'Printing Type', 'Sheetfed');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (167, 'Printing Type', 'Sheetfed');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (146, 'Printing Type', 'Sheetfed'); /* PM 5C */
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (112, 'Printing Type', 'Sheetfed');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (73, 'Printing Type', 'Sheetfed');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (48, 'Printing Type', 'Sheetfed');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (120, 'Printing Type', 'Sheetfed');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (146, 'Default Bleed Size', '0.125'); /* PM 5C */

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (146, 'Value', '5'); /* PM 5C */

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (114, 'Runstyles', 'Sheet Work,Work & Turn,Work & Tumble');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (122, 'Runstyles', 'Sheet Work,Work & Turn,Work & Tumble');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (165, 'Runstyles', 'Sheet Work,Work & Turn,Work & Tumble');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (166, 'Runstyles', 'Sheet Work,Work & Turn,Work & Tumble');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (167, 'Runstyles', 'Sheet Work,Work & Turn,Work & Tumble');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (146, 'Runstyles', 'Sheet Work,Work & Turn,Work & Tumble,Perfecting');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (112, 'Runstyles', 'Sheet Work,Work & Turn,Work & Tumble');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (73, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (48, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (120, 'Runstyles', 'Sheet Work,Work & Turn,Work & Tumble');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (107, 'Printing Type', 'Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (106, 'Printing Type', 'Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (108, 'Printing Type', 'Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (187, 'Printing Type', 'Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (168, 'Printing Type', 'Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (191, 'Printing Type', 'Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (81, 'Printing Type', 'Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (164, 'Printing Type', 'Digital');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (107, 'Default Bleed Size', '0.125','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (106, 'Default Bleed Size', '0.125','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (108, 'Default Bleed Size', '0.125','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (187, 'Default Bleed Size', '0.125','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (168, 'Default Bleed Size', '0.125','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (191, 'Default Bleed Size', '0.125','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (81, 'Default Bleed Size', '0.125','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values (164, 'Default Bleed Size', '0.125','Inches');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (107, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (106, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (108, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (187, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (168, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (191, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (81, 'Runstyles', 'Sheet Work');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (164, 'Runstyles', 'Sheet Work');

update tbl_Equipment_specifications set strname='Run Speed' where strname='Press Standard Run Speed';
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (114, 'Overs', 'All');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (107, 'Overs', 'All');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (120, 'Overs', 'All');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (122, 'Overs', 'All');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (146, 'Overs', 'All');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (112, 'Overs', 'All');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (13, 'Type', 'Folder');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values (169, 'Type', 'Folder');


DROP VIEW equipment_specification;
DROP VIEW equipment_type_provides_service;
DROP VIEW equipment_type_provides_service_type;
DROP VIEW equipment_type_service_type;
DROP VIEW mat_inventory;
DROP VIEW project_service_status;
DROP VIEW project_type_service_type_exclusions;

UPDATE materials set category_id =(SELECT id FROM material_categories where name='PlainCartons') where name='LargeCarton';
UPDATE materials set category_id =(SELECT id FROM material_categories where name='PlainCartons') where name='StandardCarton';
UPDATE materials set category_id =(SELECT id FROM material_categories where name='BulkSkids') where name='BulkSkid';

insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='BulkSkid'), 'Width', 36,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='BulkSkid'), 'Height', 24,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='StandardCarton'), 'Height', 9,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='StandardCarton'), 'Width', 12,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='StandardCarton'), 'Depth', 9,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='StandardCarton'), 'Maximum Weight', 30,'lbs');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='LargeCarton'), 'Depth', 9,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='LargeCarton'), 'Width', 12,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='LargeCarton'), 'Height', 18,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='LargeCarton'), 'Maximum Weight', 30,'lbs');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='BusinessCardCarton'), 'Depth', 9,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='BusinessCardCarton'), 'Width', 12,'Inches');
insert into material_specifications (material_id, name, value,units) values ((SELECT id from materials where name='BusinessCardCarton'), 'Height', 18,'Inches');

update projecttemplate set type='Landscape', name='Landscape' where type='CardLandscape';
update projecttemplate set type='Portrait', name='Portrait' where type='CardPortrait';
update projecttemplate set type='2PanelFold', name='2 Panel Fold' where type='Insert2PanelFold';
update projecttemplate set type='2PanelFoldPerf', name='2 Panel Fold Perf' where type='Insert2PanelFoldPerf';
update projecttemplate set type='FolioLip', name='Folio Lip' where type='InsertFolioLip';
update projecttemplate set type='FolioLipPerf', name='Folio Lip Perf' where type='InsertFolioLipPerf';
update projecttemplate set type='Landscape', name='Landscape' where type='BusCardLandscape';
update projecttemplate set type='Landscape Fold', name='Landscape Fold' where type='BusCardLandscapeFold';
update projecttemplate set type='Portrait Fold', name='Portrait Fold' where type='BusCardPortraitFold';
update projecttemplate set type='Portrait', name='Portrait' where type='BusCardPortrait';
update projecttemplate set type='2Panel1Pocket', name='SinglePocket' where type='PresentationFolderStandard1Pocket';
update projecttemplate set type='2Panel2Pocket', name='DoublePocket' where type='PresentationFolderStandard2Pocket';
update projecttemplate set type='Landscape', name='Landscape' where type='PadsLandscape';
update projecttemplate set type='Portrait', name='Portrait' where type='PadsPortrait';
update projecttemplate set type='Square', name='Square' where type='PadsSquare';
update projecttemplate set Type='Landscape', Name='Landscape' where type='PostersLandscape';
update projecttemplate set Type='Portrait', Name='Portrait' where type='PostersPortrait';

insert into material_categories (name) values ('Bundling');

insert into materials (name,description,category_id) values ('Elastic Band','Elastic Band',(SELECT id from material_categories where name='Bundling'));
insert into tbl_material_prices (lnglistindex,lngmaterialindex,lngequipmentindex,lngmin,lngmax,strunits,dblcost,dblmarkup,dblprice,ysndicountable,range_units) values
insert into materials (name,description,category_id) values ('Paper Strips','Paper Strips',(SELECT id from material_categories where name='Bundling'));
insert into materials (name,description,category_id) values ('Cross Banding','Cross Banding',(SELECT id from material_categories where name='Bundling'));

insert into services (name,description, category_id) values ('Varnish Gloss Overall', 'Varnish Gloss Overall', (SELECT id from service_categories where name='Coatings'));
insert into services (name,description, category_id) values ('Varnish Gloss Spot', 'Varnish Gloss Spot', (SELECT id from service_categories where name='Coatings'));
insert into services (name,description, category_id) values ('Varnish Matte Overall', 'Varnish Matte Overall', (SELECT id from service_categories where name='Coatings'));
insert into services (name,description, category_id) values ('Varnish Matte Spot', 'Varnish Matte Spot', (SELECT id from service_categories where name='Coatings'));
/*
insert into services (name,description, category_id) values ('Aqueous Matte', 'Aqueous Matte', (SELECT id from service_categories where name='Coatings'));
insert into services (name,description, category_id) values ('Aqueous Gloss', 'Aqueous Gloss', (SELECT id from service_categories where name='Coatings'));
insert into services (name,description, category_id) values ('Aqueous Silk', 'Aqueous Silk', (SELECT id from service_categories where name='Coatings'));
insert into services (name,description, category_id) values ('Aqueous Soft Touch', 'Aqueous Soft Touch', (SELECT id from service_categories where name='Coatings'));
*/

update services set name='Aqueous', description='Aqueous' where name='AQCoating';
update services set name='AqueousMakeReady' where name='AQCoatingMakeready';
update service_prices set service_id=(SELECT id from services where name='AqueousMakeReady') Where service_id=(SELECT id from services where name='AQCoatingMakeReady');
update service_prices set units='per side' Where service_id=(SELECT id from services where name='Aqueous') and units IS NULL;
update service_prices set units='per side' Where service_id=(SELECT id from services where name='Aqueous') and units ='';

update services set name='AqueousMinimumCharge' where name='AQCoatingMinimumCharge';

insert into material_categories (name) values ('Coatings');
insert into materials (name,description, category_id) values ('Aqueous Matte', 'Aqueous Matte', (SELECT id from material_categories where name='Coatings'));
insert into materials (name,description, category_id) values ('Aqueous Gloss', 'Aqueous Gloss', (SELECT id from material_categories where name='Coatings'));
insert into materials (name,description, category_id) values ('Aqueous Silk', 'Aqueous Silk', (SELECT id from material_categories where name='Coatings'));
insert into materials (name,description, category_id) values ('Aqueous Soft Touch', 'Aqueous Soft Touch', (SELECT id from material_categories where name='Coatings'));
INSERT INTO material_specifications (material_id,name,value,units) values ((SELECT id from materials where name='Aqueous Matte'),'Coverage', '372700','square inches per kg');
INSERT INTO material_specifications (material_id,name,value,units) values ((SELECT id from materials where name='Aqueous Gloss'),'Coverage', '372700','square inches per kg');
INSERT INTO material_specifications (material_id,name,value,units) values ((SELECT id from materials where name='Aqueous Silk'),'Coverage', '372700','square inches per kg');
INSERT INTO material_specifications (material_id,name,value,units) values ((SELECT id from materials where name='Aqueous Soft Touch'),'Coverage', '279525','square inches per kg');

update service_prices set units='per cut' where service_id = (SELECT id from Services where name='CuttingMakeReady');

insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Padding'), 'rdbCardboardBacking', 'Y' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='ShrinkWrap'), 'rdbCardboardBacking', 'Y' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Bundle'), 'rdbCardboardBacking', 'N' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'chkBleedLeft', 'Left' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'chkBleedRight', 'Right' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'chkBleedTop', 'Top' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'chkBleedBottom', 'Bottom' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'txtCropMarkSpace', '0.0625' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'MatchGrain1', 'Y' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'MatchGrain2', 'Y' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'MatchGrain3', 'Y' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'dutch1', 'N' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'dutch2', 'N' );
insert into tbl_service_Defaults (lngservicetypeindex, strfieldname, strdefaultvalue ) values ( (SELECT id from Service_Types where name='Signature'), 'dutch3', 'N' );

alter table papers alter column height type float;
alter table papers alter column width type float;

update projects set order_id=(SELECT min(orderindex) from order_contents where lngprojectindex=projects.id);

update tbl_equipment set servicetype_id=servicetype_id || (SELECT id from service_types where name='Padding') where id=23;
update tbl_equipment set servicetype_id=servicetype_id || (SELECT id from service_types where name='Padding') where id=84;
update tbl_equipment set servicetype_id=servicetype_id || (SELECT id from service_types where name='Padding') where id=86;

update service_prices set units='per pad' where units='pads';

update projecttype_defaults set name='ddmBleedSize' where name='bleed_size';
insert into projecttype_defaults (name,value) values ('chkBleedLeft','Left');
insert into projecttype_defaults (name,value) values ('chkBleedRight','Right');
insert into projecttype_defaults (name,value) values ('chkBleedTop','Top');
insert into projecttype_defaults (name,value) values ('chkBleedBottom','Bottom');
insert into projecttype_defaults (name,value) values ('txtCropMarkSpace','0.0625');

insert into service_types (name,description,type,url,category_id,create_visible,view_visible,summary_visible,allow_delete)
values ('Laminating','LAMINATING','Lamination','spec/Lamination.html', (SELECT id from servicetype_categories where name='Finishing'),true,true,true,true);

insert into tbl_equipment (strid, strname, strdescription,category_id, useinestimating,servicetype_id) values
('TapeMachine','TapeMachine','TapeMachine',array((select id from equipment_categories where name='Finishing')), true, array((SELECT id from service_types WHERE name='DTaping')));
update tbl_equipment set servicetype_id=array_append(servicetype_id, (SELECT id from service_types WHERE name='DTaping')) where strid='ManualLabourStation-1';
update tbl_equipment set servicetype_id=array_append(servicetype_id, (SELECT id from service_types WHERE name='Gluing')) where strid='ManualLabourStation-1';
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='DTaping'),
  (select id from tbl_equipment where strname='TapeMachine'),
  0.01,null,0.01,'per inch','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='DTaping'),
  (select id from tbl_equipment where strname='ManualLabourStation-1'),
  0.01,null,0.01,'per inch','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='DTapingMakeReady'),
  (select id from tbl_equipment where strname='TapeMachine'),
  10,null,10,'','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='DTapingMakeReady'),
  (select id from tbl_equipment where strname='ManualLabourStation-1'),
  10,null,10,'','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='DTapingChargeMinimum'),
  (select id from tbl_equipment where strname='TapeMachine'),
  10,null,10,'','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='DTapingChargeMinimum'),
  (select id from tbl_equipment where strname='ManualLabourStation-1'),
  10,null,10,'','Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='TapeMachine'), 'DTaping Capable', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='ManualLabourStation-1'), 'DTaping Capable', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='TapeMachine'), 'DTapes Per Run', '1');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='ManualLabourStation-1'), 'DTapes Per Run', '1');

insert into tbl_equipment (strid, strname, strdescription,category_id, useinestimating,servicetype_id) values
('Laminator - Matrix','Laminator - Matrix','Laminator - Matrix',array((select id from equipment_categories where name='Finishing')), true, array((SELECT id from service_types WHERE name='Laminating')));
insert into tbl_equipment (strid, strname, strdescription,category_id, useinestimating,servicetype_id) values
('Laminator - Wesco','Laminator - Wesco','Laminator - Wesco',array((select id from equipment_categories where name='Finishing')), true, array((SELECT id from service_types WHERE name='Laminating')));
insert into tbl_equipment (strid, strname, strdescription,category_id, useinestimating,servicetype_id) values
('Laminator - GBC Voyager','Laminator - GBC Voyager','Laminator - GBC Voyager 30"',array((select id from equipment_categories where name='Finishing')), true, array((SELECT id from service_types WHERE name='Laminating')));
insert into services (name, description,category_id,servicetype_id) values 
('Lamination','Lamination',
  (SELECT id from SErvice_categories where name='Finishing'),
  (SELECT id from service_types WHERE name='Laminating')
);
insert into services (name, description,category_id,servicetype_id) values 
('LaminationMakeReady','Lamination Make Ready',
  (SELECT id from SErvice_categories where name='Finishing'),
  (SELECT id from service_types WHERE name='Laminating')
);

INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1, (SELECT id from services where name='Lamination'),(select id from tbl_equipment where strname='Laminator - Matrix'),
  0.01,null,0.01,'per inch','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1, (SELECT id from services where name='LaminationMakeReady'),(select id from tbl_equipment where strname='Laminator - Matrix'),
  50,null,50,'','Y');

INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1, (SELECT id from services where name='Lamination'),(select id from tbl_equipment where strname='Laminator - Wesco'),
  0.01,null,0.01,'per inch','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1, (SELECT id from services where name='LaminationMakeReady'),(select id from tbl_equipment where strname='Laminator - Wesco'),
  50,null,50,'','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1, (SELECT id from services where name='Lamination'),(select id from tbl_equipment where strname='Laminator - GBC Voyager'),
  0.01,null,0.01,'per inch','Y');
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1, (SELECT id from services where name='LaminationMakeReady'),(select id from tbl_equipment where strname='Laminator - GBC Voyager'),
  50,null,50,'','Y');


INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Laminating Capable', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Laminating Sides', 'Single');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Laminating Style', 'Sheet');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Laminate Width', '19.5', 'Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Laminating Count', 'Net Sheets', '');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Laminating Waste', '10', 'Percent');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Maximum Calliper', '0.024','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Minimum Calliper', '0.008','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Maximum Sheet Length', '26','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Maximum Sheet Width', '20','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Matrix'), 'Run Speed', '23760','inches per hour');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Laminating Capable', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Laminating Sides', 'Single');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Laminating Style', 'Sheet');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Laminate Width', '19.5', 'Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Laminating Count', 'Net Sheets', '');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Laminating Waste', '10', 'Percent');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Maximum Calliper', '0.024','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Minimum Calliper', '0.008','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Minimum Sheet Length', '18','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Minimum Sheet Width', '12','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Maximum Sheet Length', '40','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Maximum Sheet Width', '30','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - Wesco'), 'Run Speed', '21000','inches per hour');

INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Laminating Capable', 'Y');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Laminating Sides', 'Single');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Laminating Style', 'Sheet');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyage'), 'Laminate Width', '29.5', 'Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Laminating Count', 'Net Sheets', '');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue,strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Laminating Waste', '10', 'Percent');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Maximum Calliper', '0.018','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Minimum Calliper', '0.008','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Minimum Sheet Length', '12','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Minimum Sheet Width', '12','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Maximum Sheet Length', '40','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Maximum Sheet Width', '30','Inches');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Laminator - GBC Voyager'), 'Run Speed', '72000','inches per hour');
update material_categories set name='Lamination Types' where name='Laminate';
    
update tbl_material_prices set strunits='per square m inches',dblcost=0.15,dblmarkup=30,dbprice=0.195 where strunits='' and lngmaterialindex IN (SELECT id from materials where category_id=(SELECT id from material_categories where name='Lamination Types'));
UPDATE service_prices set max=NULL where Max=500 and range_units='Pads';
update tbl_equipment set servicetype_id = servicetype_id || ((SELECT id from service_types where name='Folding')) where id in (SELECT lngequipmentindex from tbl_equipment_specifications where strname='Folding Capable');
update folds set type='3PanelFold',name='3 Panel Roll Fold' where type='3PanelRollFold';
update folds set type='4PanelFold',name='4 Panel Roll Fold' where type='4PanelRollFold';
update folds set type='5PanelFold',name='5 Panel Roll Fold' where type='5PanelRollFold';
update folds set type='6PanelFold',name='6 Panel Roll Fold' where type='6PanelRollFold';
update folds set stitching=NULL, perfectbind=NULL;

update tbl_equipment_specifications set strname='DieCutting Capable' where strname='Die Cutting Capable';

update service_prices set units='per 1000' where units='per 1000 spreads';
update projecttemplate set type='PerfectBound' where type='PerfectBinding';
update projecttemplate set type='Cerlox' where type='PlasticComb';
delete from projecttemplate where type='KnotchBound';

update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='PerfectBound') where id=135;
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Perfect Binder_Sulby_10x14'), 'PerfectBound Capable', 'Y','');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Perfect Binder_Sulby_10x14'), 'Folding Capable', 'When PerfectBound','');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Perfect Binder_Sulby_10x14'), 'Fold Covers Only', 'Y','');

update tbl_equipment set servicetype_id=array_append(servicetype_id, (SELECT id from service_types WHERE name='Folding')) where strid='Perfect Binder_Sulby_10x14';

INSERT INTO service_prices (pricelist_id, service_id,equipment_Id,cost,price,units) values (1, 
  (SELECT id from services where name='Folding'),
  (SELECT id from tbl_equipment where strname='Perfect Binder_Sulby_10x14'),
  0, 0, 'per hour');


UPDATE services set name='PerfectBound' WHERE name='PerfectBinding';
UPDATE services set name='PerfectBoundMakeReady' WHERE name='PerfectBindingMakeReady';
UPDATE Service_Prices SET range_units = 'pockets' WHERE
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Drilling') where id=35;
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Multi Head Drill'), 'Drilling Capable', 'Y','');
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='RoundCornering') where id=26;

update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Scoring') where id=136;
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Perforating') where id=136;
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='DigiFold Pro'), 'Scoring Capable', 'Y','');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='DigiFold Pro'), 'Perforating Capable', 'Y','');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='DigiFold Pro'), 'Type', 'Folder','');
UPDATE Folds set max_imposition=1 where equipment_id=(SELECT id from tbl_equipment where strname='DigiFold Pro');
UPDATE Folds set max_imposition=2 where equipment_id=(SELECT id from tbl_equipment where strname='Horizon - 28x40 Folder');

update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Scoring') where id=153;
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Perforating') where id=153;
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Digital Folder'), 'Scoring Capable', 'Y','');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Digital Folder'), 'Perforating Capable', 'Y','');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values ((SELECT id from tbl_equipment where strname='Digital Folder'), 'Type', 'Folder','');

update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Scoring') where id=20;
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Perforating') where id=20;
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (20, 'Scoring Capable', 'Y','');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (20, 'Perforating Capable', 'Y','');

/* Brause */
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Embossing') where id=173;
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='FoilStamping') where id=173;
/* Cylinder-21x30 */
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Embossing') where id=20;
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (20, 'Type', 'Cylinder','');
/* Cylinder-21x30 */
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Embossing') where id=172;
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (172, 'Type', 'Cylinder','');
/* Igen NUmber */
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Numbering') where id=164;
/* Platen */
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Numbering') where id=37;
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Scoring') where id=37;
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Embossing') where id=37;
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='FoilStamping') where id=37;
update tbl_equipment set servicetype_id = ARRAY(SELECT id from service_types where name='Perforating') where id=37;
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (37, 'Scoring Capable', 'Y','');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (37, 'Perforating Capable', 'Y','');
update service_prices set units='per m' where units='per 1000 sheets' and service_id=(SELECT id from services where name='Perforating');
INSERT INTO tbl_equipment_specifications (lngequipmentindex,strname,strvalue, strunits) values (37, 'Type', 'Platen','');

UPDATE service_prices set units='per form' where units='per signature';
UPDATE Services set name='SignatureImpositionMakeReady' where name='ImpositionMakeReady';
UPDATE service_prices set units='total' WHERE service_id=(SELECT id from services where name='PressMakeReady') and units='';
UPDATE service_prices set service_id=(SELECT id from services where name='PressUnitMakeReady') WHERE service_id=(SELECT id from services where name='PressMakeReady');
DELETE FROM Services where name='PressMakeReady';
UPDATE Services set name='PerfectingImpression1/1' where name='1-1ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression2/1' where name='2-1ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression2/2' where name='2-2ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression3/1' where name='3-1ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression3/2' where name='3-2ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression3/3' where name='3-3ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression4/1' where name='4-1ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression4/2' where name='4-2ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression4/3' where name='4-3ColourImpressionPerfecting';
UPDATE Services set name='PerfectingImpression4/4' where name='4-4ColourImpressionPerfecting';



insert into services (name, description,category_id,servicetype_id) values 
('Folding','Folding',
  (SELECT id from SErvice_categories where name='Bindery'),
  (SELECT id from service_types WHERE name='Folding')
);
insert into services (name, description,category_id,servicetype_id) values 
('FoldingMakeReady','Folding Make Ready',
  (SELECT id from SErvice_categories where name='Bindery'),
  (SELECT id from service_types WHERE name='Folding')
);
INSERT into service_prices (pricelist_id,service_id,equipment_id,cost,markup,price,units,discountable) values
(1,
  (SELECT id from services where name='FoldingMakeReady'),
  (select id from tbl_equipment where strname='DigiFold Pro'),
  10,100,20,'','Y');

UPDATE Services set name='3PanelZFold' where name='3PanelAccordianFold';
UPDATE Services set name='4PanelZFold' where name='4PanelAccordianFold';
UPDATE Services set name='3PanelZFoldMakeReady' where name='3PanelAccordianFoldMakeReady';
UPDATE Services set name='4PanelZFoldMakeReady' where name='4PanelAccordianFoldMakeReady';

INSERT INTO material_categories (name) values ('Printing');

INSERT INTO Materials (name, description,category_id) values ('CyanInk','Cyan Ink', (SELECT id from Material_categories where name='Printing'));
INSERT INTO Materials (name, description,category_id) values ('MagentaInk','Magenta Ink', (SELECT id from Material_categories where name='Printing'));
INSERT INTO Materials (name, description,category_id) values ('YellowInk','Yellow Ink', (SELECT id from Material_categories where name='Printing'));
INSERT INTO Materials (name, description,category_id) values ('BlackInk','Black Ink', (SELECT id from Material_categories where name='Printing'));
insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='CyanInk'), 'Coverage', 920000, 1,1, 'square inches per kg');
insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='CyanInk'), 'Coverage', 862500, 2,2, 'square inches per kg');
insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='CyanInk'), 'Coverage', 920000, 3,3, 'square inches per kg');
insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='CyanInk'), 'Coverage', 715555, 4,5, 'square inches per kg');

insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='CyanInk'), 'Coverage', 920000, 1,1, 'square inches per kg');
insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='CyanInk'), 'Coverage', 862500, 2,2, 'square inches per kg');
insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='CyanInk'), 'Coverage', 920000, 3,3, 'square inches per kg');
insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='CyanInk'), 'Coverage', 715555, 4,5, 'square inches per kg');
insert into material_specifications (material_id, name, value,min,max, units) values ((SELECT id from materials where name='BlackInk'), 'Coverage', 920000, 1,1, 'square inches per kg');

delete from projecttemplate where type='KnotchBound';
UPDATE tbl_equipment set deleted=true where strid='DigiFold Pro01-136';
update paper_prices set strunits='per 100lbs' where strunits='100 lbs';

update papers set score_required=true where calliper > 0.008;
update service_prices set units='per m' where units ilike '%Per%' AND service_id=(SELECT id from services where name='Scoring');

delete from tbl_equipment_specifications where strname='Non-Parallel Perforating / Scoring';
delete from tbl_equipment_specifications where strname='Parallel Perforating / Scoring';
delete from service_prices where service_id=(SELECT id from services where name='ScorePerforationMinimumCharge');
delete from services where name='ScorePerforationMinimumCharge';
UPDATE tbl_Equipment_specifications set strname='Maximum Image Length' WHERE strname='Maximum Image Area Length';
UPDATE tbl_Equipment_specifications set strname='Maximum Image Width' WHERE strname='Maximum Image Area Width';
UPDATE tbl_Equipment_specifications set strvalue = strvalue::float * 100 WHERE strname='Press Run Overs' and strvalue::float < 1;
Update services set name='DieCuttingRuleBendingComplex' where name='DieCutRuleBendingComplex';
Update services set name='DieCuttingRuleBendingSimple' where name='DieCutRuleBendingSimple';
Update services set name='DieCuttingRuleBendingAverage' where name='DieCutRuleBendingAverage';
Update services set name='KissCuttingRuleBendingComplex' where name='KissCutRuleBendingComplex';
Update services set name='KissCuttingRuleBendingSimple' where name='KissCutRuleBendingSimple';
Update services set name='KissCuttingRuleBendingAverage' where name='KissCutRuleBendingAverage';
UPDATE service_prices set range_units='impressions' WHERE range_units='Per 1000 Impressions' and service_id IN (SELECT id from services where name LIKE 'DieCutting%');
update services set servicetype_id=(SELECT id from service_types where name='KissCutting') where name like 'KissCutt%';

UPDATE services set lngsortorder = 3151 where name='DieCuttingSimpleMakeReady';
UPDATE services set lngsortorder = 3152 where name='DieCuttingAverageMakeReady';
UPDATE services set lngsortorder = 3153 where name='DieCuttingComplexMakeReady';
UPDATE services set lngsortorder = 3154 where name='DieCuttingSimple';
UPDATE services set lngsortorder = 3155 where name='DieCuttingAverage';
UPDATE services set lngsortorder = 3156 where name='DieCuttingComplex';
UPDATE services set lngsortorder = 3157 where name='DieCuttingRuleBendingSimple';
UPDATE services set lngsortorder = 3158 where name='DieCuttingRuleBendingAverage';
UPDATE services set lngsortorder = 3159 where name='DieCuttingRuleBendingComplex';
UPDATE services set lngsortorder = 3160 where name='HoleClearing';
UPDATE services set lngsortorder = 3161 where name='DieCuttingMinimumCharge';
UPDATE services set lngsortorder = 3162 where name='KissCuttingSimpleMakeReady';
UPDATE services set lngsortorder = 3163 where name='KissCuttingAverageMakeReady';
UPDATE services set lngsortorder = 3164 where name='KissCuttingComplexMakeReady';
UPDATE services set lngsortorder = 3165 where name='KissCuttingSimple';
UPDATE services set lngsortorder = 3166 where name='KissCuttingAverage';
UPDATE services set lngsortorder = 3167 where name='KissCuttingComplex';
UPDATE services set lngsortorder = 3168 where name='KissCuttingRuleBendingSimple';
UPDATE services set lngsortorder = 3169 where name='KissCuttingRuleBendingAverage';
UPDATE services set lngsortorder = 3170 where name='KissCuttingRuleBendingComplex';
UPDATE services set lngsortorder = 3172 where name='KissCuttingMinimumCharge';

UPDATE services set lngsortorder = 3173 where name='ScoringMakeReady';
UPDATE services set lngsortorder = 3174 where name='Scoring';
UPDATE services set lngsortorder = 3175 where name='ScoringMinimumCharge';

update service_prices set units='per m' where service_id=(SELECT id from services where name='EmbossingSimple');
update service_prices set units='per m' where service_id=(SELECT id from services where name='EmbossingAverage');
update service_prices set units='per m' where service_id=(SELECT id from services where name='EmbossingComplex');
