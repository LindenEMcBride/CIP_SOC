
// This program implements the Kneedle Algorithm by CIP-SOC and by SOC-CIP to generate an empirical crosswalk that augments the NCES crosswalk.

clear 

// Set Working Directory

	*cd 

// NCES crosswalk
	
	copy https://nces.ed.gov/ipeds/cipcode/Files/CIP2020_SOC2018_Crosswalk.xlsx CIP2020_SOC2018_Crosswalk.xlsx
	
	import excel "CIP2020_SOC2018_Crosswalk.xlsx", sheet("CIP-SOC") firstrow
	
	ren CIP2020Code cip
	
	ren SOC2018Code soc 
	
	save nces_crosswalk.dta, replace 

	clear 
	
// replace this fake data with an import of empirical data that includes cip codes (column heading "cip"), soc codes (column heading "soc") and the count of the number of observations sharing a cip and soc (column heading "count"); here I've generated fake data just to demo 
	
	set obs 3000

	gen soc = runiformint(11, 53)
	tostring soc, replace
	gen cip =  runiformint(1, 60)
	tostring cip, replace

	gen count = runiformint(30, 1500)
	
// the above should be replaced with empirical data	

	keep if count > = 30 // only retain CIP-SOC pairs that have 30 or more observations
 
	bys cip: egen totcip = sum(count)  //by CIP  (CIP is denominator, CIP-SOC  path is numerator): of the folks who graduated with this CIP, how many went into a given SOC?

	gen prop_cip = count/totcip

	bys soc: egen totsoc = sum(count)  //by SOC  (SOC is denominator, CIP-SOC path is numerator): of the folks employed in this SOC, how many came from a given CIP?
  
	gen prop_soc = count/totsoc

 
//kneedle algorithm CIP
  
	gsort cip -prop_cip 
	bys cip: gen cumsum_cip = sum(prop_cip)
 
	gen obs = 1
  
	bys cip: egen emp_N_cip = sum(obs)
	bys cip: gen emp_cum_cip =sum(obs)
 
//normalize prop by rank 

	gen prop_norm_cip = emp_cum_cip/emp_N_cip 
  
	bys cip: egen p_max_cip = max(prop_cip)

// distance formula 
	
	gen d_cip = (abs((1 - p_max_cip)*prop_norm_cip - (1- (1/emp_N_cip))*cumsum_cip + 1*(p_max_cip) - 1*(1/emp_N_cip) ))/(sqrt((1 - 1/emp_N_cip)^2 + (1-p_max_cip)^2)) 
 
// find max distance
 
	bys cip: egen maxd_cip = max(d_cip)

// find cutoff
  
	gen cutprop_above_cip = maxd_cip==d_cip
  
	gen th_dk_cip = prop_cip if cutprop_above_cip ==1 

	bys cip: egen threshold_cip = min(th_dk)
  
	gen new_xwlk_fromCIP = prop_cip > =threshold_cip // CIP based selection of crosswalked CIP-SOCS
 
// plot for cip focused elbow plot 

	gsort cip prop_norm_cip 

	local ciplook = "52" // e.g business majors

	br if cip == "`ciplook'"

// to generate the reference line

	sum cumsum_cip if emp_cum_cip ==1 & cip == "`ciplook'"
	local p1 = r(mean)
	sum prop_norm_cip if emp_cum_cip ==1 & cip ==  "`ciplook'"
	local xA = r(mean)
	local slope = (1-`p1') /(1-`xA')
	local intercept = `p1' -`slope'*`xA'
	capture drop ref
	gen ref = `intercept' + `slope'*prop_norm_cip 
 
// elbow plot with reference line
	
    twoway line cumsum_cip prop_norm_cip if cip ==  "`ciplook'", lcolor(dknavy) xscale(range(0 1)) yscale(range(0 1)) ///
    xlabel(0(0.2)1)  ylabel(0(0.2)1) xtitle("Concentration") ytitle("Coverage") legend(off)|| line ref prop_norm_cip if cip ==  "`ciplook'", lcolor(gray) 

// elbow plot with reference line and optimal point 

	sum cumsum_cip if cip ==  "`ciplook'" & cutprop_above_cip ==1
	local opt_y = r(mean)
   
	sum prop_norm_cip if cip ==  "`ciplook'" & cutprop_above_cip ==1

	local opt_x =r(mean)
  
	twoway line cumsum_cip prop_norm_cip if cip ==  "`ciplook'", lcolor(dknavy) xscale(range(0 1)) yscale(range(0 1)) ///
    xlabel(0(0.2)1)  ylabel(0(0.2)1) xtitle("Concentration") ytitle("Coverage") legend(off) || line ref prop_norm_cip if cip ==  "`ciplook'", lcolor(gray) ///
	|| (scatteri `opt_y' `opt_x', mcolor(black) msize(large) msymbol(oh))

 
//kneedle algorithm SOC
   
	gsort soc -prop_soc
	bys soc: gen cumsum_soc = sum(prop_soc)
   
	bys soc: egen emp_N_soc = sum(obs)
	bys soc: gen emp_cum_soc =sum(obs)
 
//normalize prop by rank 
 
	gen prop_norm_soc = emp_cum_soc/emp_N_soc
   
	bys soc: egen p_max_soc = max(prop_soc)
  
// distance formula 

	gen d_soc = (abs((1 - p_max_soc)*prop_norm_soc - (1- (1/emp_N_soc))*cumsum_soc + 1*(p_max_soc) - 1*(1/emp_N_soc) ))/(sqrt((1 - 1/emp_N_soc)^2 + (1-p_max_soc)^2)) 

// find max distance

	bys soc: egen maxd_soc = max(d_soc)
  
	gen cutprop_above_soc = maxd_soc==d_soc
  
	gen th_dk_soc = prop_soc if cutprop_above_soc ==1 

	bys soc: egen threshold_soc = min(th_dk_soc)
  
	gen new_xwlk_fromSOC = prop_soc > =threshold_soc  // SOC based selection of crosswalked CIP-SOCS

	
	keep soc cip new_xwlk_fromCIP new_xwlk_fromSOC
 
 
	merge m:1 cip soc using nces_crosswalk.dta // this is the NCES crosswalk; augment this crosswalk with the empirical crosswalk 

	gen nces_xwlk = _merge==3 | _merge==2
 
	replace new_xwlk_fromCIP = 0 if mi(new_xwlk_fromCIP)
	replace new_xwlk_fromSOC = 0 if mi(new_xwlk_fromSOC)
  
	gen combined_xwlk = (new_xwlk_fromSOC ==1 & new_xwlk_fromCIP==1) | nces_xwlk
 
 
	keep if combined_xwlk==1

	keep soc cip CIP2020Title SOC2018Title
 
	export excel using "augmented_cip_soc_crosswalk.xlsx", replace 
 
