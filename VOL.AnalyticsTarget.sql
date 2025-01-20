


CREATE VIEW VOL.AnalyticsTarget AS
SELECT
--cast (MTH + ' 01 '  + cast(year(s.FUNDGIN_STAT_DT) as varchar(4)) as date) FundingMonth,
CAST(CAST(MONTH(s.mth + '01 1900') AS VARCHAR(2)) + '/01/' + CAST(
        CASE
            WHEN s.mth in ('Nov', 'Dec') THEN '20' + CAST((CAST(RIGHT(s.FISC_YR,2) AS int) - 1) AS varchar)
        ELSE '20' + RIGHT(s.FISC_YR,2)
END AS VARCHAR(4)) AS date) AS [FundingMonth],
s.FUNDGIN_STAT_DT as FundingStatusDate,	
s.CUST_ID as CustomerId,	
s.CUST_NM as CustomerName,	
s.CUST_GEO as CustomerGEO,	
rtrim(c.geo)  as geo,
--SicCode --Dropped
--SicDescription-- Dropped
PF.Country_Name customerCountryName,  --Need to be revisited
c.state CustomerStateName,  --Need to be revisited
s.SCHD_NBR as ScheduleNumber,
--COAAuthorName Dropped
--COADate Dropped
--CutomerPONumber Dropped
s.FUND_AUTHOR_NM as FundingAuthorName,	
s.SCHD_FAM as PrimaryScheduleFAM,	
fam.FAM_QV_display_name FamDisplayName,
s.SEC_SCHD_FAM as SecondaryScheduleFAM,	
--ScheduleFAMPct  Dropped
s.RISK_RATING as RiskRating,	
s.LEASE_BSNS_MDL as LeaseBusinessModel,	
s.DEAL_SRC as DealSource,	
s.LEASE_TERM as LeaseTerm,	
s.BILL_MTHD as BillMethod,	
s.PAY_FREQ as PayFrequency,	
case when s.PAY_FREQ = 'Annually' then 12
when s.PAY_FREQ = 'Monthly' then 1
when s.PAY_FREQ = 'Quarterly' then 3
when s.PAY_FREQ = 'Semi Annua' then 6
End  as PayFrequencyNo,
s.ADVC_ARREAR as AdvanceArrear,	
case when s.APA not in ('Y','N') then 'N' else s.APA end as APA,
s.DFR_PRD as DeferralPeriod,	
s.LEASE_BEG_DT as LeaseBeginDate,	
s.LEASE_BOOKED_DT as LeaseBookedDate,	
s.SCHD_STAT as ScheduleStatus,	
s.SCHD_PROMO as SchedulePromotion,	
s.BSNS_SEG as BusinessSegment,	
s.BSNS_SUB_SEG as BusinessSubSegment,	
s.COMPLIANCY_IND as CompliancyIndicator,	
s.PORTF_ID as PortfolioId,	
s.LEASE_CLASS as LeaseClass,	
--ESNewPursuit Dropped
s.BSNS_UNIT_DESC as BusinessUnitDescription,	
s.PURCH_OPT_MTHD as PurchaseOptionMethod,	
s.RGN as Region,	
--InsuranceFlag Dropped
--InsuranceAmount Dropped
s.TGT_ROE as TargetROE,	
s.ACTL_ROE as ActualROE,
s.CreditApplicationId	CreditApplicationId,
s.DocumentCreationDate DocumentCreationDate,
'Field Missing in Vol_Schd' as AssetTargetROE,
'Field Missing in Vol_Schd' as AssetActualROE,
s.COF as COF,	
s.YLD as Yield,	
s.IRR_WITH_RV as IRRwithRV,	
s.RV_LC_AMT as RVAmountLC,	
s.RV_USD_AMT as RVAmountUSD,	
s.RV_PER as RVPercent,	
s.DEAL_CRNCY_CDE as DealCurrency,	
s.DEAL_CURRENCY_FX_RATE as DealCurrencyFXRate,	
s.INVC_CRNCY_CDE as InvoiceCurrency,	
s.LEASE_FACTR_RATE as LeaseRateFactor,	
s.DCNT_PCT as DiscountPercent,	
s.TOT_DCNT_LC as TotalDiscountLC,	
s.UNIT_PRC_LC as UnitPriceInvoiceLC,	
--UnitPriceInvoiceCurr Canbedropped
s.QTY as Quantity,	
s.TOT_COST as TotalCost,	
s.TOT_COST_LESS_BLIND_DISK_LC as TotalCostLessBlindDiscLC,	
s.US_NET_AMT as USNetAmount,	
s.InvoiceTypeDescription	InvoiceTypeDescription,
s.InvoiceToDealFXRate	InvoiceToDealFXRate,
s.InvoiceCreationDate	InvoiceCreationDate,
s.InvoiceExchangeRate	InvoiceExchangeRate,
s.InvoiceNumber	InvoiceNumber,
s.InvoiceStatus	InvoiceStatus,
s.InvoiceTypeCode	InvoiceTypeCode,
s.RESELLER_ID as ResellerId,	
p.Reseller_Name as ResellerName,
'Field Missing in Partner' as  ResellerVATNumber ,
p.Reseller_Type ResellerType,
p.Reseller_Country ResellerCountry,
p.Partner_City ResellerCity,
p.Partner_State ResellerState,
p.Strategic_Partner	StrategicPartner, -- tobe verified
s.RERNG_PTNR_ID as ReferingPartnerId,	
s.REFRNG_PTNR_NM as ReferingPartnerName,
s.DSTRBR_ID as DistributorID,	
s.DSTRBR_NM as DistributorName,	
s.PTNR_CONN_FLG as PartnerConnectionFlag,	
s.HP_PL 	HPPL,
s.PART_NBR as PartNumber,	
s.PROD_NM as ProductName,	
s.PROD_PRODCR_NM as ProductProducerName,	
s.PROD_LN_NM as ProductLineName,	
s.PROD_DIV_NM as ProductDivisionName,	
s.PROD_FMLY_NM as ProductFamilyName,	
s.PROD_CLASS_TYP_NM as ProductType, -- Tobe verified
s.PROD_TYP_NM as ProductTypeName,	
s.SFWR_HDWR as SoftwareHardware,	
--MDCPOrgId  Can be Dropped
--ServiceProviderMDCPOrgId Can be Dropped
c.ST_ID 	SalesTerritoryId,
c.ST_Name	SalesTerritoryName,
c.TOP_ST_ID ParentSalesTerritoryId, 
c.TOP_ST_Name  	ParentSalesTerritoryName, 
C.HPEFS_Segment 	HPEFSSegmentGPO, --s.HPEFSSegmentGPO changed to Customer from volume as per Nick
s.PC_BSNS_MODE as PCBusinessMode,	
s.FundingStatus FundingStatus,
s.FirstPayment 	FirstPayment,
s.RestOfpayment RestOfpayment,
s.PROJ_NM as ProjectName,	
s.DDQCompletedDate 	DDQCompletedDate,
s.DDQExpiryDate 	DDQExpiryDate,
s.WBS_NUMBER as WBSNumber,	
s.MAX_UPM_PAYMENTS as MAXUPMPayments,
s.FMV_FLG FMVflag,
s.SUB_LEASE_FLG 	Sublease,
s.CHNL_EXCP VolChanelException,
case when len(s.CHNL_EXCP) > 3 then s.CHNL_EXCP else s.RESELLER_ID end 	Channelexceptions,
--S.COMP_ELIG_FLG  AS CompEligible,
--S.ECP_OVRLY  AS	ECPOverlay ,
--S.PDM_PTNR_NM  AS	PDMPartnerName,
--S.ECP_DSTRBR_NM  AS 	ECPDistributorName,
--S.PDM_NM AS  PDMName,
--S.CHNL_OVRLY_NM AS	ChannelOverlayName,
--S.PDM_OVRLY AS 	PDMOverlay,
--S.NOTES_FOR_SLS_COMP  AS 	NotesforSalesComp,
S.E2E_TEAM AS E2ETeam,
s.PLAN_RATE as PlanRate,
s.FISC_YR as FiscalYear,
s.QTR as Quarter,
s.MTH as Month,
case when p.Reseller_type = 'Direct' then 'Direct' else 'Indirect' End
as LocDirectIndirectflag,
Case 
	when upper(SCHD_PROMO) like upper('AaS Greenlake%') then 'Y'
	when upper(SCHD_PROMO) like upper('Aas Flex%') then 'Y'
	Else 'N'
End GreeenLakeFlag,
Case 
	when upper(SCHD_PROMO) = upper('AaS Flex Cap Channel') then '3.0'
	when upper(SCHD_PROMO) like upper('AaS Greenlake%') then 'Std'
	when upper(SCHD_PROMO) like upper('Aas Flex%') then 'Std'
End GreeenLakeType,
Case 
	when upper(SCHD_PROMO) = 'AaS Greenlake for Aruba' then 'GreenLake - Aruba'
	when upper(SCHD_PROMO) like upper('Aas Flex%') then 'GreenLake - PointNext'
	Else ''
End GreeenLakeBU,
case when s.hpfsResellerType like 'SLB%' then 'Y' else 'N' End SLBFlag,
case 
	when (PR.Global_Business_Unit like 'GSB%' OR P.Reseller_type ='GSB') AND C.HPEFS_Segment = 'SMB' then 'SMB GSB'
	When P.Reseller_type ='INDIRECT' AND 
		 (case when s.hpfsResellerType like 'SLB%' then 'Y' else 'N' End) = 'N' and 
		 C.HPEFS_Segment = 'SMB' then 'SMB thru Channel'
	When C.HPEFS_Segment = 'SMB' then 'SMB Direct/OEM'
	ELSE 'Non-SMB'
END as SMBSubsegment,
case When s.ADVC_ARREAR  = 'AR' then 0 else 1 End Adv_Arr,
Case when s.FMV_FLG ='Y' then 'FMV' else 'FL' End FMV,
C.PPT PPTFlag,
case 
	when c.PPT = 'E' then'N'
	When PF.COUNTRY_CODE in ('US', 'USA') and upper(BU.HP_Services_Led_for_Volume_Reporting) = 'DXC' 
						   and upper(s.LEASE_CLASS) ='LEASE LN' then 'N'
	When PF.COUNTRY_CODE in ('US', 'USA') and upper(BU.HP_Services_Led_for_Volume_Reporting) <>  'DIRECT' then 'Y'
	When PF.COUNTRY_CODE in ('US', 'USA') and (upper(BU.HP_Services_Led_for_Volume_Reporting) =  'DIRECT' OR
	BU.HP_Services_Led_for_Volume_Reporting is null) and  c.PPT = 'Y' then 'Y'
	Else 'N'
End PPTFlagAdjusted,
BU.HP_Services_Led_for_Volume_Reporting,
PF.COUNTRY_CODE,
case when 
(case 
	when c.PPT = 'E' then'N'
	When PF.COUNTRY_CODE in ('US', 'USA') and upper(BU.HP_Services_Led_for_Volume_Reporting) = 'DXC' 
						   and upper(s.LEASE_CLASS) ='LEASE LN' then 'N'
	When PF.COUNTRY_CODE in ('US', 'USA') and upper(BU.HP_Services_Led_for_Volume_Reporting) <>  'DIRECT' then 'Y'
	When PF.COUNTRY_CODE in ('US', 'USA') and (upper(BU.HP_Services_Led_for_Volume_Reporting) =  'DIRECT' OR
	BU.HP_Services_Led_for_Volume_Reporting is null) and  c.PPT = 'Y' then 'Y'
	Else 'N'
End) = 'Y' then s.YLD - 1.9 else S.YLD end YieldAdjusted,

(s.YLD - S.COF) as Spread, 

mrgn.Adj_Percentage,
S.COF + (mrgn.Adj_Percentage * 100) CofAdjusted,
s.RV_PER * s.US_NET_AMT RV$,
s.RV_PER * s.TOT_COST_LESS_BLIND_DISK_LC RVLC,

((((S.COF + (mrgn.Adj_Percentage * 100))/100)/(12/(case when s.PAY_FREQ = 'Annually' then 12
when s.PAY_FREQ = 'Monthly' then 1
when s.PAY_FREQ = 'Quarterly' then 3
when s.PAY_FREQ = 'Semi Annua' then 6
End)  ))) AS	Rate,  
s.GEO_CDE,
s.ID,
case when s.LEASE_TERM < 18 then 12 
 when s.LEASE_TERM <  30 then 24
 when s.LEASE_TERM <  42 then 36
 when s.LEASE_TERM <  54 then 48
 when s.LEASE_TERM <  66 then 60
 when s.LEASE_TERM <  78 then 72
 when s.LEASE_TERM <  90 then 84
 when s.LEASE_TERM <  102 then 96
 when s.LEASE_TERM <  114 then 108
 when s.LEASE_TERM >= 114 then 120
 else 0 end Tree_term,
 S.Payment,
 s.pv ,
 s.Volume_Margin as Volume_Margin,
 s.Volume_Margin_Percentage as Volume_Margin_Percentage,
 s.HPFSResellerType as HPFSResellerType, 
 ch.Reseller_Type ChannelResellerType,
 s.Volume_Margin_HPI as VolumeMarginHPI ,  
 s.Volume_Margin_Percentage_HPI as VolumeMarginPctHPI,
 s.Channel_Reseller_ID ChannelResellerID,
 mrgn.adj_key MarginKey,
 P.Esign_Enabled ESignEnabled,
 Case 
	when C.dra = 'Y' and C.Geo = 'AMS' then 'N'
	when c.HPEFS_Segment = 'SMB' AND  bu.sales_Motion = 'Direct selling' and (pr.business_sub_segment ='Graphics Solutions Business' or LEFT(ch.Reseller_type,3)='GSB') THEN  'N'
	when c.HPEFS_Segment = 'SMB' AND  bu.sales_Motion = 'Direct selling' and ch.Reseller_type ='INDIRECT'   THEN  'Y'
	when c.HPEFS_Segment = 'SMB' AND  bu.sales_Motion = 'Direct selling' and ch.Reseller_type <>'INDIRECT'   THEN  'N'
	when c.HPEFS_Segment = 'SMB' THEN  'N'
	when c.HPEFS_Segment = 'Enterprise' AND  bu.sales_Motion = 'Direct selling' and (pr.business_sub_segment ='Graphics Solutions Business' or LEFT(ch.Reseller_type,3)='GSB') THEN  'N'
	when c.HPEFS_Segment = 'Enterprise' AND  bu.sales_Motion = 'Direct selling' and ch.Reseller_type ='INDIRECT'   THEN  'Y'
	when c.HPEFS_Segment = 'Enterprise' AND  bu.sales_Motion = 'Direct selling' and ch.Reseller_type <>'INDIRECT'   THEN  'N'
	when c.HPEFS_Segment = 'Enterprise' THEN  'N'
	when c.HPEFS_Segment = 'Global' then 'N'
End as ChannelFlag,
case when len(c.ST_ID) < 1 then s.cust_nm else  c.ST_Name end CustomerCount,
--IF(PC_Sub_segment='Graphics Solutions Business' OR LEFT(Loc_Reseller_type,3)='GSB', 'GSB', 'Non GSB')     
case when (pr.business_sub_segment ='Graphics Solutions Business' or LEFT(CH.Reseller_type,3)='GSB') then 'GSB'
else 'Non GSB' end AS GSBFlag,
Case 
	when c.HPEFS_Segment = 'SMB' AND  bu.sales_Motion = 'Direct selling' 
	    and (pr.business_sub_segment ='Graphics Solutions Business' or LEFT(CH.Reseller_type,3)='GSB') THEN  'All non-thru'
	when c.HPEFS_Segment = 'SMB' AND  bu.sales_Motion = 'Direct selling' and CH.Reseller_type ='INDIRECT'   THEN  'SMB thru channel'
	when c.HPEFS_Segment = 'SMB' AND  bu.sales_Motion = 'Direct selling' and CH.Reseller_type <>'INDIRECT'   THEN  'All non-thru'
	when c.HPEFS_Segment = 'SMB' THEN  'All non-thru'
	when c.HPEFS_Segment = 'Enterprise' AND  bu.sales_Motion = 'Direct selling' 
	    and (pr.business_sub_segment ='Graphics Solutions Business' or LEFT(CH.Reseller_type,3)='GSB') THEN  'All non-thru'
	when c.HPEFS_Segment = 'Enterprise' AND  bu.sales_Motion = 'Direct selling' and CH.Reseller_type ='INDIRECT'   THEN  'SMB thru channel'
	when c.HPEFS_Segment = 'Enterprise' AND  bu.sales_Motion = 'Direct selling' and CH.Reseller_type <>'INDIRECT'   THEN  'All non-thru'
	when c.HPEFS_Segment = 'Enterprise' THEN  'All non-thru'
	when c.HPEFS_Segment = 'Global' then 'N'
End as MtcEtcFlag,
--PR.Global_Business_Unit
Case When PR.Global_Business_Unit='A&PS' then 'A&PS'
 When PR.Global_Business_Unit='Big Data' then' Big Data'
 When PR.Global_Business_Unit='Commercial Compute'then 'NON-HP'
 When PR.Global_Business_Unit='Commercial Displays, Accy, & 3PO'then 'NON-HP'
 When PR.Global_Business_Unit='Compute Product'then 'Compute'
 When PR.Global_Business_Unit='Compute Services'then 'Services'
 When PR.Global_Business_Unit='Consumer Compute'then 'NON-HP'
 When PR.Global_Business_Unit='GSB Core' then 'NON-HP'
 When PR.Global_Business_Unit='HPE Aruba Product' then 'Aruba'
 When PR.Global_Business_Unit='HPS Printers' then  'NON-HP'
 When PR.Global_Business_Unit='Hyperconverged' then 'Hyperconverged'
 When PR.Global_Business_Unit='MCS' then 'MCS'
 When PR.Global_Business_Unit='Nimble Services' then 'Services'
 When PR.Global_Business_Unit='NON-HP' then 'NON-HP'
 When PR.Global_Business_Unit='OPS Printers' then 'NON-HP'
 When PR.Global_Business_Unit='OPS Scanner/Other' then 'NON-HP'
 When PR.Global_Business_Unit='Other IPG' then 'NON-HP'
 When PR.Global_Business_Unit='Other Specialized Products' then 'Specialized'
 When PR.Global_Business_Unit='Primary Storage' then'Storage'
 When PR.Global_Business_Unit='PS Commercial Services' then 'NON-HP'
 When PR.Global_Business_Unit='PSG Other Consumer' then 'NON-HP'
 When PR.Global_Business_Unit='Specialized Services' then 'Services'
 When PR.Global_Business_Unit='Storage Services' then 'Services'
 When PR.Global_Business_Unit='Traditional Storage'then 'Storage'
else  'Uncategorized' End     AS          GBUCategorized

from
vol.VOL_SCHD s
left outer join 
vol.customer C
on (c.Customer_ID= s.CUST_ID )
left outer join
vol.partner p
on
s.RESELLER_ID = p.Reseller_ID
left outer join 
vol.partner ch
on
s.Channel_Reseller_ID=    ch.Reseller_ID
left outer join 
vol.Product PR
on Pr.HP_PL= s.HP_PL
left outer join vol.portfolio PF
on PF.Portfolio_ID = s.PORTF_ID
left outer join vol.BU_matrix BU
on s.BSNS_UNIT_DESC = BU.GPO_Indicator_Desc
left outer join vol.FAM Fam 
on fam.FAM_GPO_name = s.SCHD_FAM
left outer join vol.Volume_margin_uplift Mrgn 
on mrgn.adj_key = (rtrim(c.GEO) +  
					cast(case when (s.RISK_RATING = '6V' or replace(s.RISK_RATING ,'6V',6) > 6 
						or  s.RISK_RATING is null or s.RISK_RATING = '-') then 6
						else  s.RISK_RATING end as varchar(10)) 
                   +  Case when s.FMV_FLG ='Y' then 'FMV' else 'FL' End
                   + cast(case 
 when s.LEASE_TERM <  18 then 12
 when s.LEASE_TERM <  30 then 24
 when s.LEASE_TERM <  42 then 36
 when s.LEASE_TERM <  54 then 48
 else 60 end as varchar(10)))
 --where s.SCHD_NBR = 'FC5358109694JPN29'

