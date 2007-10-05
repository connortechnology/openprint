
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('Folding','Folding', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Bindery' ) );
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('Padding','Padding', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Bindery' ));
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('BulkSkid','Bulk Skids', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Packing' ));
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('Bundle','Bundle', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Packing' ));
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('AdditionalSignature','Signature', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Printing' ));
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('Proofs','Proofs', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Prepress' ));
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('Perforating','Perforating/Scoring', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Bindery' ));
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('DieCutting','DieCutting', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Bindery' ));
insert into tbl_Services (strID, strName, lngCategoryIndex ) values ('Shipping','Shipping', (SELECT lngIndex FROM tbl_Service_Categories WHERE strName='Shipping' ));

  UPDATE tbl_Services set strUrl='prep/prep_scan.html', lngSortOrder= 50 WHERE strID='Scanning';
  UPDATE tbl_Services set strUrl='prep/prep_film.html', lngSortOrder= 51 WHERE strID='Film';
  UPDATE tbl_Services set strUrl='prep/prep_proo.html', lngSortOrder= 52 WHERE strID='Proofs';
  UPDATE tbl_Services set strUrl='prep/prep_file_conversion.html', lngSortOrder= 53 WHERE strID='FileConversion';
  UPDATE tbl_Services set strUrl='prep/prep_file_correction.html', lngSortOrder= 54 WHERE strID='FileCorrection';
  UPDATE tbl_Services set strUrl='prep/prep_type_setting.html', lngSortOrder= 55 WHERE strID='TypeSetting';
  UPDATE tbl_Services set strUrl='prep/prep_copy_dot.html', lngSortOrder= 56 WHERE strID='CopyDot';
  UPDATE tbl_Services set strUrl='prep/prep_stri.html', lngSortOrder= 57 WHERE strID='FilmStripping';
  UPDATE tbl_Services set strUrl='prep/prep_phot.html', lngSortOrder= 58 WHERE strID='PhotoRetouching';
  UPDATE tbl_Services set strUrl='prep/prep_extra_burn.html', lngSortOrder= 59 WHERE strID='ExtraBurn';
  UPDATE tbl_Services set strUrl='prep/prep_colo.html', lngSortOrder= 60 WHERE strID='ColourCorrection';
  UPDATE tbl_Services set strUrl='prep/prep_plac.html', lngSortOrder= 61 WHERE strID='PhotoPlacement';
  UPDATE tbl_Services set strUrl='prep/prep_cd_burning.html', lngSortOrder= 62 WHERE strID='CDBurning';
  UPDATE tbl_Services set strUrl='prep/prep_phtg.html', lngSortOrder= 63 WHERE strID='Photography';
  UPDATE tbl_services set strUrl='prep/prep_graphic_design.html', lngSortOrder= 64 WHERE strId='GraphicDesign';
  
  UPDATE tbl_Services set strUrl='bind/bind_perf.html', lngSortOrder= 21 WHERE strID='Perforating';
  UPDATE tbl_Services set strUrl='bind/bind_perf.html', lngSortOrder= 21 WHERE strID='Perforating/Scoring';
  UPDATE tbl_Services set strUrl='bind/bind_cutt.html', lngSortOrder= 22 WHERE strID='Cutting';
  UPDATE tbl_Services set strUrl='bind/bind_fold.html', lngSortOrder= 23 WHERE strID='Folding';
  UPDATE tbl_Services set strUrl='bind/bind_sadd.html', lngSortOrder= 24 WHERE strID='SaddleStitching';
  UPDATE tbl_Services set strUrl='bind/bind_loop.html', lngSortOrder= 25 WHERE strID='LoopStitching';
  UPDATE tbl_Services set strUrl='bind/bind_collating.html', lngSortOrder= 26 WHERE strID='Collating';
  UPDATE tbl_Services set strUrl='bind/bind_spiral.html', lngSortOrder= 27 WHERE strID='Spiral';
  UPDATE tbl_Services set strUrl='bind/bind_perfect_bound.html', lngSortOrder= 28 WHERE strID='PerfectBound';
  UPDATE tbl_Services set strUrl='bind/bind_padd.html', lngSortOrder= 29 WHERE strID='Padding';
  UPDATE tbl_Services set strUrl='bind/bind_gluing.html', lngSortOrder= 30 WHERE strID='Gluing';
  UPDATE tbl_Services set strUrl='bind/bind_dril.html', lngSortOrder= 31 WHERE strID='Drilling';
  UPDATE tbl_Services set strUrl='bind/die_cutting.html', lngSortOrder= 32 WHERE strID='DieCutting';
  UPDATE tbl_Services set strUrl='bind/bind_numb.html', lngSortOrder= 33 WHERE strID='Numbering';


  UPDATE tbl_Services set strUrl='spec/spec_embossing.html', lngSortOrder= 40 WHERE strID='Embossing';
  UPDATE tbl_Services set strUrl='spec/spec_foil_stamping.html', lngSortOrder= 41 WHERE strID='FoilStamping';
  UPDATE tbl_Services set strUrl='spec/spec_uv_coating.html', lngSortOrder= 42 WHERE strID='UVCoating';

  UPDATE tbl_Services set strUrl='pack/pack_bundle.html', lngSortOrder= 70 WHERE strID='Bundle';
  UPDATE tbl_Services set strUrl='pack/pack_kraf.html', lngSortOrder= 71 WHERE strID='KraftWrap';
  UPDATE tbl_Services set strUrl='pack/pack_shri.html',lngSortOrder= 72 WHERE strID='ShrinkWrap';
  UPDATE tbl_Services set strUrl='pack/pack_carton.html', lngSortOrder= 73 WHERE strID='PlainCartons';
  UPDATE tbl_Services set strUrl='pack/pack_by_weight.html', lngSortOrder= 74 WHERE strID='BulkSkid';

  UPDATE tbl_Services set strUrl='shipping/shipping.html', lngSortOrder= 80 WHERE strID='Shipping';
  UPDATE tbl_Services set strUrl='prin/multipage/prin_multipage_signatures.html', lngSortOrder= 10 WHERE strID='AdditionalSignature';
