cap program drop yatchew_test
program define yatchew_test, eclass
syntax varlist(min = 2 numeric) [if] [, het_robust path_graph]

local var_base = strtrim("`varlist'")
local var_count = length("`var_base'") - length(subinstr("`var_base'", " ", "", .))

if "`path_graph'" != "" & `var_count' != 2 {
    noi di as err "The path_graph option can only be specified with 2 treatment variables."
    exit
}

qui {
preserve
if "`if'" != "" {
    keep `if'
}

tokenize `varlist'
gen Y_XX = `1'

local D_base = substr("`var_base'", strpos("`var_base'", " ") + 1, .)
local D_base "`D_base' "
local D_vars_XX ""
forv j = 1/`var_count' {
    local varn = substr("`D_base'", 1, strpos("`D_base'", " ")-1)
    gen D_`j'_XX = `varn' 
    local D_vars_XX "`D_vars_XX' D_`j'_XX"
    local D_base = substr("`D_base'", strpos("`D_base'", " ")+1, .)
}

keep if !missing(Y_XX)
foreach v in `D_vars_XX' {
    drop if missing(`v')
}

if `var_count' == 1 {
    sort `D_vars_XX' Y_XX
    gen sort_id_XX = _n
}
else {
    local D_vars_norm_XX ""
    foreach v in `D_vars_XX' {
        sum `v'
        gen `v'_norm = (`v' - r(min)) / (r(max) - r(min))
        local D_vars_norm_XX "`D_vars_norm_XX' `v'_norm"
    }

    gen sort_id_temp_XX = 0
    local nbins = ceil(log10(`=_N')) * 2

    local p_vars ""
    foreach v in `D_vars_norm_XX' {
        pctile p_`v'_XX = `v', n(`nbins')
        gen P_`v'_XX = 1
        forv j = 1/`nbins' {
            replace P_`v'_XX = P_`v'_XX + 1 if `v' > p_`v'_XX[`j']
        }
        local p_vars "`p_vars' P_`v'_XX"
        drop p_`v'_XX
    }

    foreach v in `D_vars_norm_XX' {
        if ("`loop_var'" != "") {
            replace P_`v'_XX = `nbins' - P_`v'_XX + 1 if mod(P_`loop_var'_XX, 2) == 0
        }
        local loop_var "`v'"
    }

    gen og_rown = _n
    egen q_groups_XX = group(`p_vars')
    gen rown_temp = _n
    drop `p_vars'

    sort q_groups_XX rown_temp

    drop rown_temp
    gen rown = _n
    sum q_groups_XX
    local ncells = r(max)
    forv i = 1/`ncells' {
        sum rown if q_groups_XX == `i'
        local start = r(min)
        local stop = r(max)
        plugin call msort sort_id_temp_XX `D_vars_norm_XX' in `start'/`stop'
    }
    sort q_groups_XX sort_id_temp_XX
    gen sort_id_XX = _n

    if "`path_graph'" != "" {
        sort sort_id_XX
        local y_1 = D_1_XX_norm[1]
        local x_1 = D_2_XX_norm[1]
        local y_N = D_1_XX_norm[`=_N']
        local x_N = D_2_XX_norm[`=_N']
        line `D_vars_norm_XX', lc(black%100) || ///
        scatteri `y_1' `x_1', mc(green) || ///
        scatteri `y_N' `x_N', mc(red) || ///
        , title("Shortest Path between each obs.") subtitle("Euclidean Distance") note("First node in green, last node in red.") leg(off)
    }

    drop q_groups_XX sort_id_temp_XX rown `D_vars_norm_XX'
}

// Variance of residuals from linear regression
reg Y_XX `D_vars_XX'
predict e_lin_XX, res
sum e_lin_XX
local var_lin = r(Var)

// Variance of residuals from nonparametric model
sort sort_id_XX
gen e_diff_XX = Y_XX[_n] - Y_XX[_n-1]
gen e_diff_sq_XX = e_diff_XX^2
sum e_diff_sq_XX
local var_diff = 0.5 * r(mean)

local sigma = ustrunescape("\u03c3")
local squared = ustrunescape("\u00b2")
if "`het_robust'" == "" {
    // Hypothesis test under homoskedasticity
    local T_test = sqrt(`=_N') * ((`var_lin'/`var_diff') - 1)
} 
else {
    // Hypothesis test under heteroskedasticity
    local num = sqrt(`=_N') * (`var_lin' -`var_diff')
    sort sort_id_XX
    gen e_lin_sq_XX = (e_lin[_n] * e_lin[_n-1])^2
    sum e_lin_sq_XX
    local denom = r(mean)
    local T_test = `num'/sqrt(`denom')
}

matrix define results = J(1, 5, .)
matrix results[1,1] = `var_lin'
matrix results[1,2] = `var_diff'
matrix results[1,3] = `T_test'
matrix results[1,4] = 1 - normal(`T_test')
matrix results[1,5] = `=_N'

if "`het_robust'" == "" {
    matrix colnames results = "`sigma'`squared'_lin" "`sigma'`squared'_diff" "T" "p-value" "N"
    local setting = "- Test under homoskedasticity"
    local addon ""
}
else {
    matrix colnames results = "`sigma'`squared'_lin" "`sigma'`squared'_diff" "T_hr" "p-value" "N"
    local setting = "- Heteroskedasticity-robust Test"
    local addon ", robust version of de Chaisemartin & D'Haultfoeuille (2024)"
}
}

noi di as text ""
noi di as text "Yatchew (1997) test`addon'"
noisily matlist results, names(c)
noi di as text ""
noi di as text "H0: E[Y|D] linear in D `setting'"

eret clear
ereturn matrix results = results

restore
end

cap program drop msort
program msort, plugin