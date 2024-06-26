#' @title A print method for yatchew_test
#' @name print.yatchew_test
#' @description A customized printed display for yatchew_test output
#' @param x A yatchew_test object
#' @param no_des Suppress the description of the output
#' @param ... Undocumented
#' @returns No return, custom print method for yatchew_test objects.
#' @export
#' @noRd
print.yatchew_test <- function(x, no_des = FALSE, ...) {
    clim <- ncol(x$results)
    setting <- ifelse(isTRUE(x$args$het_robust), "- Heteroskedasticity-robust Test", "- Test under homoskedasticity")
    cit <- ifelse(isTRUE(x$args$het_robust), ", robust version of de Chaisemartin & D'Haultfoeuille (2024)", "")
    type <- ""
    if (length(x$args$D) > 1) {
        type <- "multivariate "
    }

    cat("\n")
    if (isFALSE(no_des)) {
        cat(sprintf(" Yatchew (1997) %stest%s\n", type, cit))
    }
    dis_mat <- matrix(NA, nrow = 1, ncol = clim)
    dis_mat[1, 1:(clim-1)] <- sprintf("%.4f", x$results[1,1:(clim-1)])
    dis_mat[1, clim] <- sprintf("%.0f", x$results[1,clim])
    colnames(dis_mat) <- colnames(x$results)
    rownames(dis_mat) <- rownames(x$results)
    print(noquote(dis_mat), drop = FALSE)
    if (isFALSE(no_des)) {
        cat(sprintf(" H0: %s %s\n", x$null, setting))
    }
    cat("\n")
}

#' @title A summary method for yatchew_test
#' @name summary.yatchew_test
#' @description A customized summary display for yatchew_test output
#' @param object A yatchew_test object
#' @param ... Undocumented
#' @returns No return, custom summary method for yatchew_test objects.
#' @export
#' @noRd
summary.yatchew_test <- function(object, ...) {
    print(object)
}