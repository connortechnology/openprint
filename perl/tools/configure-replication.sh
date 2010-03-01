#!/bin/bash
# $Id: configure-replication.sh,v 1.1.2.4 2008-03-06 18:49:03 cbbrowne Exp $

# Global defaults
CLUSTER=${CLUSTER:-"slonytest"}
NUMNODES=${NUMNODES:-"2"}

# Defaults - origin node
DB1=${DB1:-${PGDATABASE:-"slonytest"}}
HOST1=${HOST1:-`hostname`}
USER1=${USER1:-${PGUSER:-"slony"}}
PORT1=${PORT1:-${PGPORT:-"5432"}}

# Defaults - node 2
DB2=${DB2:-${PGDATABASE:-"slonytest"}}
HOST2=${HOST2:-"backup.example.info"}
USER2=${USER2:-${PGUSER:-"slony"}}
PORT2=${PORT2:-${PGPORT:-"5432"}}

# Defaults - node 3
DB3=${DB3:-${PGDATABASE:-"slonytest"}}
HOST3=${HOST3:-"backup3.example.info"}
USER3=${USER3:-${PGUSER:-"slony"}}
PORT3=${PORT3:-${PGPORT:-"5432"}}

# Defaults - node 4
DB4=${DB4:-${PGDATABASE:-"slonytest"}}
HOST4=${HOST4:-"backup4.example.info"}
USER4=${USER4:-${PGUSER:-"slony"}}
PORT4=${PORT4:-${PGPORT:-"5432"}}

# Defaults - node 5
DB5=${DB5:-${PGDATABASE:-"slonytest"}}
HOST5=${HOST5:-"backup5.example.info"}
USER5=${USER5:-${PGUSER:-"slony"}}
PORT5=${PORT5:-${PGPORT:-"5432"}}

store_path()
{

echo "include <${PREAMBLE}>;" > $mktmp/store_paths.slonik
  i=1
  while : ; do
    eval db=\$DB${i}
    eval host=\$HOST${i}
    eval user=\$USER${i}
    eval port=\$PORT${i}

    if [ -n "${db}" -a "${host}" -a "${user}" -a "${port}" ]; then
      j=1
      while : ; do
        if [ ${i} -ne ${j} ]; then
          eval bdb=\$DB${j}
          eval bhost=\$HOST${j}
          eval buser=\$USER${j}
          eval bport=\$PORT${j}
          if [ -n "${bdb}" -a "${bhost}" -a "${buser}" -a "${bport}" ]; then
            echo "STORE PATH (SERVER=${i}, CLIENT=${j}, CONNINFO='dbname=${db} host=${host} user=${user} port=${port}');" >> $mktmp/store_paths.slonik
          else
            echo "STORE PATH (SERVER=${i}, CLIENT=${j}, CONNINFO='dbname=${db} host=${host} user=${user} port=${port}');" >> $mktmp/store_paths.slonik
          fi
        fi
        if [ ${j} -ge ${NUMNODES} ]; then
          break;
        else
          j=$((${j} + 1))
        fi
      done
      if [ ${i} -ge ${NUMNODES} ]; then
        break;
      else
        i=$((${i} +1))
      fi
    else
      echo "no DB"
    fi
  done
}

mktmp=`mktemp -d -t slonytest-temp.XXXXXX`
if [ $MY_MKTEMP_IS_DECREPIT ] ; then
       mktmp=`mktemp -d /tmp/slonytest-temp.XXXXXX`
fi

PREAMBLE=${mktmp}/preamble.slonik

echo "cluster name=${CLUSTER};" > $PREAMBLE

alias=1

while : ; do
  eval db=\$DB${alias}
  eval host=\$HOST${alias}
  eval user=\$USER${alias}
  eval port=\$PORT${alias}

  if [ -n "${db}" -a "${host}" -a "${user}" -a "${port}" ]; then
    conninfo="dbname=${db} host=${host} user=${user} port=${port}"
    echo "NODE ${alias} ADMIN CONNINFO = '${conninfo}';" >> $PREAMBLE
    if [ ${alias} -ge ${NUMNODES} ]; then
      break;
    else
      alias=`expr ${alias} + 1`
    fi   
  else
    break;
  fi
done

# The following schema is based on that of IntelligentQuote

ALTTABLES1="
annualsales assistants car blacklist cip3_ppf; companies_in_marketing_categories bindery_schedule currency_conversions configuration creditapplications complaints emailtemplates database_info detail_levels company_credit currencies emailcampaign_log equipment_shifts employeenumbers helpdesk public.inventorycheck log inks inventorycheckentries labels manifest_content_types label_data log_actions labeltypes material_specifications manifestcontents marketing_categories ordered_products materials material_categories manufacturers order_statuses order_contents order_log paper_recommendations paper_inventory paper_allocations public.paper_prices papers paperweights par papercolours paperqualities paperfinishes papernames product_prices par_reasons par_areas project_log products productionfeedback project_files product_categories payments pressactivities project_statuses purchaseorder_contents projecttemplate purchaseorders projecttype_requiredservices public.purchaseorder_logs purchaseorder_notifications quote_log project_types purchaseorder_contenttypes rfidscannerhistory rfidtagtypes rfidtagactions rfidtaghistory rma shifts service_categories services service_types sessions schedule skid_verifications survey_question_categories survey_responses taxes skid_contents skids survey_question_available_answers public.tbl_addresses stockpurposes survey_answers tbl_projecttype_defaults tbl_equipment_specifications tbl_material_prices tbl_quote_users_by tbl_project_pdfs tbl_quote_details tbl_equipment tbl_project_contents tbl_service_prices tbl_reports tbl_service_defaults tbl_ship_via public.trade_references uploads tbl_warehouse user_notifications user_purchaseorder_limits tbl_quote_users_for user_types tbl_service_specifications user_notification_types users_in_usergroups manifests public.projecttype_categories emailcampaign_sent users_in_marketing_categories car_reasons rfidscanners orders tbl_quotes pricelists usergroups rfidtags company surveys emailcampaigns survey_questions inventorychecks paper_purchase_orders locations car_areas users tbl_projects
"

for t in `echo $ALTTABLES1`; do
  ALTTABLES="$ALTTABLES public.${t}"
done
  
ALTSEQUENCES1="
address_index_seq
 assistants_id_seq
 car_areas_id_seq
 car_id_seq
 car_reasons_id_seq
 cip3_ppf_id_seq
 companyindex_seq
 complaints_id_seq
 contentsserviceindex_seq
 currencyindex_seq
 database_info_version_seq
 detail_levels_id_seq
 docketnumber_seq
 emailcampaign_id_seq
 emailtemplates_id_seq
 equipment_index_seq
 equipment_shifts_id_seq
 equipmentspecification_seq
 helpdesk_id_seq
 inks_id_seq
 inventorycheck_id_seq
 labels_id_seq
 labeltypes_id_seq
 lngbannerindex_seq
 lngcreditappindex_seq
 lngprojectindex_seq
 lngshipviaindex_seq
 lngstateid_seq
 lngwarehouseid_seq
 location_id_seq
 log_actions_id_seq
 log_id_seq
 manifest_content_types_id_seq
 manifestcontents_id_seq
 manufacturers_id_seq
 materialcategoriesindex_seq
 marketing_category_index_seq
 materialspecification_id_seq
 materialindex_seq
materialprices_id_seq
 order_status_id_seq
 orderedproduct_id_seq
 paper_allocation_id_seq
 paper_discount_index_seq
 paper_id_seq
 paperinventory_id_seq
 paper_prices_id_seq
 papercolour_id_seq
 paperfinish_id_seq
 paperlist_index_seq
 papername_id_seq
 paperquality_id_seq
 paperpurchaseorderindex_seq
 paperweight_id_seq
 par_areas_id_seq
 par_id_seq
 par_reasons_id_seq
 payments_index_seq
 press_schedule_seq
 price_list_id_seq
 product_category_id_seq
 product_id_seq
 product_prices_id_seq
 productionfeedback_id_seq
 project_files_id_seq
 project_log_id_seq
 project_statuses_id_seq
 project_templateindex
 projecttemplate_id_seq
 projecttype_categories_id_seq
 projecttypeindex
 purchaseorder_contents_id_seq
 purchaseorder_logs_id_seq
 purchaseorder_contenttypes_id_seq
 purchaseorders_id_seq
 quotelog_id_seq
 quotes_id_seq
 reports_index_seq
 rfidscannerhistory_id_seq
 rfidtagtypes_id_seq
 rfidscanners_id_seq
 rfidtagactions_id_seq
 rfidtaghistory_id_seq
 rma_index_seq
 schedule_id_seq
 servicecategoriesindex_seq
 serviceindex_seq
 serviceprices_id_seq
 servicetypeindex
 shifts_id_seq
 skid_contents_id_seq
 skid_id_seq
 skid_verifications_id_seq
 survey_question_available_answers_id_seq
 stockpurposes_id_seq
 survey_answer_id_seq
 survey_id_seq
 survey_question_category_id_seq
 survey_question_id_seq
 taxes_id_seq
 tbl_customer_shipto_lngshipid_s
 tbl_paper_lngindex_seq
 tbl_service_defaults_lngid_seq
 upload_id_seq
 user_notification_types_id_seq
 usergroup_id_seq
 users_index_seq
 company_credit_id_seq
 bindery_schedule_id_seq
 companies_in_marketing_categories_id_seq
 currency_conversions_id_seq
 emailcampaign_log_id_seq
 inventorycheckentries_id_seq
 label_data_id_seq
 order_contents_id_seq
 tbl_project_pdfs_id_seq
 order_log_id_seq
 paper_recommendations_id_seq
 tbl_projecttype_defaults_id_seq
 pressactivities_id_seq
 projecttype_requiredservices_id_seq
purchaseorder_notifications_id_seq
 tbl_quote_users_for_id_seq
 survey_responses_id_seq
 tbl_quote_users_by_id_seq
 tbl_quote_details_id_seq
 tbl_project_contents_id_seq
 annualsales_id_seq
 user_notifications_id_seq
 tbl_service_specifications_id_seq
 emailcampaign_sent_id_seq
"

for s in `echo $ALTSEQUENCES1`; do
  ALTSEQUENCES="$ALTSEQUENCES public.${s}"
done

TABLES=${TABLES:-${ALTTABLES}}
SEQUENCES=${SEQUENCES:-${ALTSEQUENCES}}

SETUPSET=${mktmp}/create_set.slonik

echo "include <${PREAMBLE}>;" > $SETUPSET
echo "create set (id=1, origin=1, comment='${CLUSTER} Tables and Sequences');" >> $SETUPSET

tnum=1

for table in `echo $TABLES`; do
    echo "set add table (id=${tnum}, set id=1, origin=1, fully qualified name='${table}', comment='${CLUSTER} table ${table}');" >> $SETUPSET
    tnum=`expr ${tnum} + 1`
done

snum=1
for seq in `echo $SEQUENCES`; do
    echo "set add sequence (id=${snum}, set id=1, origin=1, fully qualified name='${seq}', comment='${CLUSTER} sequence ${seq}');" >> $SETUPSET    
    snum=`expr ${snum} + 1`
done

NODEINIT=$mktmp/create_nodes.slonik
echo "include <${PREAMBLE}>;" > $NODEINIT
echo "init cluster (id=1, comment='${CLUSTER} node 1');" >> $NODEINIT

node=2
while : ; do
    SUBFILE=$mktmp/subscribe_set_${node}.slonik
    echo "include <${PREAMBLE}>;" > $SUBFILE
    echo "store node (id=${node}, comment='${CLUSTER} subscriber node ${node}');" >> $NODEINIT
    echo "subscribe set (id=1, provider=1, receiver=${node}, forward=yes);" >> $SUBFILE
    if [ ${node} -ge ${NUMNODES} ]; then
      break;
    else
      node=`expr ${node} + 1`
    fi   
done

store_path

echo "
$0 has generated Slony-I slonik scripts to initialize replication for SlonyTest.

Cluster name: ${CLUSTER}
Number of nodes: ${NUMNODES}
Scripts are in ${mktmp}
=====================
"
ls -l $mktmp

echo "
=====================
Be sure to verify that the contents of $PREAMBLE very carefully, as
the configuration there is used widely in the other scripts.
=====================
====================="
