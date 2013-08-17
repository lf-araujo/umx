# setwd("~/bin/umx/umx")
# devtools::load_all()
# devtools::dev_help("umxStart")
# devtools::document()
# devtools::install()

# =================================
# = Speed  and Efficiency Helpers =
# =================================
#' umxRun
#'
#' umxRun is a version of \code{\link{mxRun}} which can run multiple times by default
#' The main value for umxRun over mxRun is with raw data. It's slightly faster, but 
#' can also calculate the saturated and independence likelihoods necessary for most fit indices.
#'
#' @param model the \code{\link{mxModel}} you wish to run.
#' @param n the maximum number of times you want to run the model trying to get a code green run (defaults to 3)
#' @param calc_SE whether to calculate standard errors 
#' for the summary (they are not very accurate, so if you use \code{\link{mxCI}} you can trun this off)
#' @param calc_sat whether to calculate the saturated and independence models (for raw \code{\link{mxData}} \code{\link{mxModel}}s)
#' @return - \code{\link{mxModel}}
#' @seealso - \code{\link{mxRun}}, \code{\link{umxLabel}}, \code{\link{umxStart}}
#' @references - http://openmx.psyc.virginia.edu/
#' @examples
#'  model = umxRun(model, n = 10)

umxRun <- function(model, n = 3, calc_SE = T, calc_sat = T){
	# TODO: return change in -2LL
	# Optimise for speed
	model = mxOption(model, "Calculate Hessian", "No")
	model = mxOption(model, "Standard Errors", "No")
	# make an initial run
	model = mxRun(model);
	n = (n - 1); tries = 0
	# carry on if we failed
	while(model@output$status[[1]] == 6 && n > 2 ) {
		print(paste("Run", tries+1, "status Red(6): Trying hard...", n, "more times."))
		model <- mxRun(model)
		n <- (n - 1)
		tries = (tries + 1)
	}
	if(tries == 0){ 
		# print("Ran fine first time!")	
	}
	# get the SEs for summary (if requested)
	if(calc_SE){
		# print("Calculating Hessian & SEs")
		model = mxOption(model, "Calculate Hessian", "Yes")
		model = mxOption(model, "Standard Errors", "Yes")
		model = mxRun(model)
	}
	if((class(model$objective)[1] == "MxRAMObjective") & model@data@type =="raw"){
		# If we have a RAM model with raw data, compute the satuated and indpeendence models
		# TODO: Update to omxSaturated() and omxIndependenceModel()
		# message("computing saturated and independence models so you have access to absoute fit indices for this raw-data model")
		model_sat = umxSaturated(model, evaluate = T, verbose = T)
		model@output$IndependenceLikelihood = model_sat$IndependenceLikelihood@output$Minus2LogLikelihood
		model@output$SaturatedLikelihood    = model_sat$SaturatedLikelihood@output$Minus2LogLikelihood
	}
	return(model)
}
# m1 = umxRun(m1); summary(m1)

#' umxRun
#'
#' umxRun is a version of \code{\link{mxRun}} which can run multiple times by default
#' The main value for umxRun over mxRun is with raw data. It's slightly faster, but 
#' can also calculate the saturated and independence likelihoods necessary for most fit indices.
#'
#' @param lastFit The \code{\link{mxModel}} you wish to update and run.
#' @param dropList A list of strings. If not NA, then the labels listed here will be dropped (or set to the value and free state you specify)
#' @param regex = A regular expression. If not NA, then all labels matching this expression will be dropped (or set to the value and free state you specify)
#' @param free Whether to set the parameters whose labels you specify to free or fixed (defaults to FALSE, i.e., fixed)
#' @param freeToStart Whether to only update parameters which are free to start (defaults to NA - i.e, not checked)
#' @param name The name for the new model)
#' @param verbose The name for the new model)
#' @param intervals whether to run confidence intervals (see \code{\link{mxRun}})
#' @return - \code{\link{mxModel}}
#' @seealso - \code{\link{mxRun}}, \code{\link{umxLabel}}, \code{\link{umxStart}}
#' @references - http://openmx.psyc.virginia.edu/
#' @examples
#' fit2 = umxReRun(fit1, regex="Cs", name="AEmodel")
umxReRun <- function(lastFit, dropList = NA, regex = NA, free = F, value = 0, freeToStart = NA, name = NA, verbose = F, intervals = F, newName = "deprecated") {
	# fit2 = umxReRun(fit1, regex="Cs", name="AEip")
	if(newName != "deprecated"){
		message("newName is deprecated in umxReRun: use name=\"", newName, "\" instead")
		name = newName
	}
	if(is.na(name)){
		name = lastFit@name
	}
	if(is.na(regex)) {
		if(any(is.na(dropList))) {
			stop("Both dropList and regex cannot be empty!")
		} else {
			x = mxRun(omxSetParameters(lastFit, labels=dropList, free = free, value = value, name= name), intervals = intervals)
		}
	} else {
		x = mxRun(omxSetParameters(lastFit, labels = umxGetLabels(lastFit, regex= regex, free= freeToStart, verbose= verbose), free = free, value = value, name = name), intervals= intervals)
	}
	return(x)
}

# Parallel helpers to be added here

# ========================================
# = Model building and modifying helpers =
# ========================================

#' umxStart
#'
#' umxStart will set start values for the free parameters in RAM and Matrix \code{\link{mxModels}}, or even mxMatrices.
#' It will try and be smart in guessing these from the values in your data, and the model type.
#'
#' @param obj the RAM or matrix \code{\link{mxModel}}, or \code{\link{mxMatrix}} that you want to set start values for.
#' @param sd optional sd for start values
#' @param n  optional mean for start values
#' @return - \code{\link{mxModel}} with updated start values
#' @export
#' @seealso - \code{\link{umxLabel}}, \code{\link{umxRun}}
#' @references - http://openmx.psyc.virginia.edu/
#' @examples
#' model = umxStart(model)

umxStart <- function(obj = NA, sd = NA, n = 1) {
	if(is.numeric(obj) ) {
		xmuStart_value_list(x = obj, sd = NA, n = 1)
	} else {
		# This is an MxRAM Model: Set sane starting values
		# TODO: Start values in the A matrix...
		# Done: Start values in the S at variance on diag, bit less than cov off diag
		# Done: Start amnifest means in means model
		# TODO: Start latent means?...
		if (!(isS4(obj) && is(obj, "MxModel"))) {
			# TODO: Need to add a check for RAMness
			stop("'obj' must be an mxModel (or a simple number)")
		}
		if (length(obj@submodels) > 0) {
			stop("Cannot yet handle submodels")
		}
		theData = obj@data@observed
		if (is.null(theData)) {
			stop("'model' does not contain any data")
		}
		manifests     = obj@manifestVars
		nVar          = length(manifests)
		if(obj@data@type == "raw"){
			# = Set the means =
			dataMeans   = colMeans(theData[,manifests], na.rm = T)
			freeManifestMeans = (obj@matrices$M@free[1, manifests] == T)
			obj@matrices$M@values[1, manifests][freeManifestMeans] = dataMeans[freeManifestMeans]

			covData     = cov(theData, use = "pairwise.complete.obs")		
		} else {
			covData = theData
		}
		dataVariances = diag(covData)
		# ==========================================================
		# = Fill the free symetrical matrix with good start values =
		# ==========================================================
		# The diagonal is variances
		freePaths = (obj@matrices$S@free[1:nVar, 1:nVar] == TRUE)
		obj@matrices$S@values[1:nVar, 1:nVar][freePaths] = covData[freePaths]
		return(obj)
	}	
}

# ===============
# = RAM Helpers =
# ===============

umxLatent <- function(latent = NA, formedBy = NA, forms = NA, data, endogenous = FALSE, model.name = NA, help = FALSE, labelSuffix = "", verbose = T) {
	# Purpose: make a latent variable formed/or formed by some manifests
	# Use: umxLatent(latent = NA, formedBy = manifestsOrigin, data = df)
	# TODO: delete manifestVariance
	# Check both forms and formedBy are not defined
	if( is.na(formedBy) &&  is.na(forms)) { stop("Error in mxLatent: Must define one of forms or formedBy") }
	if(!is.na(formedBy) && !is.na(forms)) { stop("Error in mxLatent: Only one of forms or formedBy can be set") }
	# ==========================================================
	# = NB: If any vars are ordinal, a call to umxMakeThresholdsMatrices
	# = will fix the mean and variance of ordinal vars to 0 and 1
	# ==========================================================
	# manifests <- names(dataFrame)
	# latents   <- c("G")
	# m1 <- mxModel("m1", type="RAM",
	# 	manifestVars = manifests,
	# 	latentVars   = latents,
	# 	# Factor loadings
	# 	mxLatent("Read", forms = readMeasures),
	# 	mxData(cov(dataFrame), type="cov", numObs=100)
	# )
	# m1= mxRun(m1); summary(m1)

	# Warning("If you use this with a dataframe containing ordinal variables, don't forget to call umxAutoThreshRAMObjective(df)")
	if( nrow(data) == ncol(data)) {
		if(all(data[lower.tri(data)] == t(data)[lower.tri(t(data))])){
			isCov = T
			if(verbose){
				message("treating data as cov")
			}
		} else {
			isCov = F
			if(verbose){
				message("treating data as raw: it's a bit odd that it's square, however")
			}
		}
	} else {
		isCov = F
		if(verbose){
			message("treating data as raw")
		}
	}
	if( any(!is.na(forms)) ) {
		manifests <- forms
	}else{
		manifests <- formedBy
	}
	if(isCov) {
		variances = diag(data[manifests, manifests])
	} else {
		manifestOrdVars = umxIsOrdinalVar(data[,manifests])
		if(any(manifestOrdVars)) {
			means         = rep(0, times = length(manifests))
			variances     = rep(1, times = length(manifests))
			contMeans     = colMeans(data[,manifests[!manifestOrdVars], drop = F], na.rm = T)
			contVariances = diag(cov(data[,manifests[!manifestOrdVars], drop = F], use = "complete"))
			if( any(!is.na(forms)) ) {
				contVariances = contVariances * .1 # hopefully residuals are modest
			}
			means[!manifestOrdVars] = contMeans				
			variances[!manifestOrdVars] = contVariances				
		}else{
			if(verbose){
				message("No ordinal variables")
			}
			means     = colMeans(data[, manifests], na.rm = T)
			variances = diag(cov(data[, manifests], use = "complete"))
		}
	}

	if( any(!is.na(forms)) ) {
		# Handle forms case
		if(!help) {
			# p1 = Residual variance on manifests
			# p2 = Fix latent variance @ 1
			# p3 = Add paths from latent to manifests
			p1 = mxPath(from = manifests, arrows = 2, free = T, values = variances) # umxLabels(manifests, suffix = paste0("unique", labelSuffix))
			if(endogenous){
				# Free latent variance so it can do more than just redirect what comes in
				if(verbose){
					message(paste("latent '", latent, "' is free (treated as a source of variance)", sep=""))
				}
				p2 = mxPath(from=latent, connect="single", arrows=2, free=T, values=.5) # labels=umxLabels(latent, suffix=paste0("var", labelSuffix))
			} else {
				# fix variance at 1 - no inputs
				if(verbose){
					message(paste("latent '", latent, "' has variance fixed @ 1"))
				}
				p2 = mxPath(from=latent, connect="single", arrows=2, free=F, values=1) # labels=umxLabels(latent, suffix=paste0("var", labelSuffix))
			}
			p3 = mxPath(from = latent, to = manifests, connect = "single", free = T, values = variances) # labels = umxLabels(latent, manifests, suffix=paste0("path", labelSuffix))
			if(isCov) {
				# Nothing to do: covariance data don't need means...
				paths = list(p1, p2, p3)
			}else{
				# Add means: fix latent mean @0, and add freely estimated means to manifests
				p4 = mxPath(from = "one", to = latent   , arrows = 1, free = F, values = 0)  # labels=umxLabels("one", latent, suffix = labelSuffix)
				p5 = mxPath(from = "one", to = manifests, arrows = 1, free = T, values = means) # labels=umxLabels("one", manifests, suffix = labelSuffix) 
				paths = list(p1, p2, p3, p4, p5)
			}			
		} else {
			# TODO: display graphVizTextFormed as digraph
			message("Help not implemented: run graphVizTextFormed")
		}
	} else {
		# Handle formedBy case
		if(!help) {
			# Add paths from manifests to the latent
			p1 = mxPath(from = manifests, to = latent, connect = "single", free = T, values = umxStart(.6, n=manifests)) # labels=umxLabels(manifests,latent, suffix=paste0("path", labelSuffix))
			# In general, manifest variance should be left free…
			# TODO If the data were correlations… we can inspect for that, and fix the variance to 1
			p2 = mxPath(from = manifests, connect = "single", arrows = 2, free = T, values = variances) # labels=umxLabels(manifests, suffix=paste0("var", labelSuffix))
			# Allow manifests to intercorrelate
			p3 = mxPath(from = manifests, connect = "unique.bivariate", arrows = 2, free = T, values = umxStart(.3, n = manifests)) #labels = umxLabels(manifests, connect="unique.bivariate", suffix=labelSuffix)
			if(isCov) {
				paths = list(p1, p2, p3)
			}else{
				# Fix latent mean at 0, and freely estimate manifest means
				p4 = mxPath(from="one", to=latent   , free = F, values = 0) # labels = umxLabels("one",latent, suffix=labelSuffix)
				p5 = mxPath(from="one", to=manifests, free = T, values = means) # labels = umxLabels("one",manifests, suffix=labelSuffix)
				paths = list(p1, p2, p3, p4, p5)
			}
		} else {
			# TODO: display graphVizTextForms as digraph
			message("help not implemented: run graphVizTextForms")
		}
	}
	if(!is.na(model.name)) {
		m1 <- mxModel(model.name, type="RAM", manifestVars=manifests, latentVars=latent, paths)
		if(isCov){
			m1 <- mxModel(m1, mxData(cov(df), type="cov", numObs = 100))
			message("\n\nIMPORTANT: you need to see numObs in the mxData() statement\n\n\n")
		} else {
			if(any(manifestOrdVars)){
				m1 <- mxModel(m1, umxThresholdRAMObjective(data, deviationBased = T, droplevels = T, verbose = T))
			} else {
				m1 <- mxModel(m1, mxData(data, type = "raw"))
			}
		}
		return(m1)
	} else {
		return(paths)
	}
	# readMeasures = paste("test", 1:3, sep="")
	# bad usages
	# mxLatent("Read") # no too defined
	# mxLatent("Read", forms=manifestsRead, formedBy=manifestsRead) #both defined
	# m1 = mxLatent("Read", formedBy = manifestsRead, model.name="base"); umxGraph_RAM(m1, std=F, dotFilename="name")
	# m2 = mxLatent("Read", forms = manifestsRead, as.model="base"); 
	# m2 <- mxModel(m2, mxData(cov(df), type="cov", numObs=100))
	# umxGraph_RAM(m2, std=F, dotFilename="name")
	# mxLatent("Read", forms = manifestsRead)
}

umxConnect <- function(x) {
	# TODO handle endogenous	
}

umxSingleIndicators <- function(manifests, data, labelSuffix = "", verbose = T){
	# use case
	# mxSingleIndicators(manifests, data)
	if( nrow(data) == ncol(data) & all(data[lower.tri(data)] == t(data)[lower.tri(t(data))]) ) {
		isCov = T
		if(verbose){
			message("treating data as cov")
		}
	} else {
		isCov = F
		if(verbose){
			message("treating data as raw")
		}
	}
	if(isCov){
		variances = diag(data[manifests,manifests])
		# Add variance to the single manfests
		p1 = mxPath(from=manifests, arrows=2, value=variances) # labels = umxLabels(manifests, suffix = paste0("unique", labelSuffix)))
		return(p1)
	} else {
		manifestOrdVars = mxIsOrdinalVar(data[,manifests])
		if(any(manifestOrdVars)){
			means         = rep(0, times=length(manifests))
			variances     = rep(1, times=length(manifests))
			contMeans     = colMeans(data[,manifests[!manifestOrdVars], drop = F], na.rm=T)
			contVariances = diag(cov(data[,manifests[!manifestOrdVars], drop = F], use="complete"))
			means[!manifestOrdVars] = contMeans				
			variances[!manifestOrdVars] = contVariances				
		}else{
			means     = colMeans(data[,manifests], na.rm = T)
			variances = diag(cov(data[,manifests], use = "complete"))
		}
		# Add variance to the single manfests
		p1 = mxPath(from = manifests, arrows = 2, value = variances) # labels = mxLabel(manifests, suffix = paste0("unique", labelSuffix))
		# Add means for the single manfests
		p2 = mxPath(from="one", to=manifests, values=means) # labels = mxLabel("one", manifests, suffix = labelSuffix)
		return(list(p1, p2))
	}
}

umxCheckModel <- function(obj, type = "RAM", hasData = NA) {
	# TODO hasSubmodels = F
	if (!isS4(obj) & is(obj, "MxModel")	) {
		stop("'model' must be an mxModel")
	}
	if (!(class(obj$objective)[1] == "MxRAMObjective" | class(obj$expectation)[1] == "MxExpectationRAM")	) {
		stop("'model' must be an RAMModel")
	}
	if (length(obj@submodels) > 0) {
		stop("Cannot yet handle submodels")
	}
	theData = obj@data@observed
	if (is.null(theData)) {
		stop("'model' does not contain any data")
	}	
}

umxStandardizeModel <- function(model, return="parameters", Amatrix=NA, Smatrix=NA, Mmatrix=NA) {
	# Purpose : standardise a RAM model, usually in order to return a standardized version of the model.
	# Use case: umxStandardizeModel(model, return = "model")
	# note    : Make sure 'return' is a valid option: "parameters", "matrices", or "model"
	if (!(return=="parameters"|return=="matrices"|return=="model"))stop("Invalid 'return' parameter. Do you want do get back parameters, matrices or model?")
	suppliedNames = all(!is.na(c(Amatrix,Smatrix)))
	# if the objective function isn't RAMObjective, you need to supply Amatrix and Smatrix
	if (class(model@objective)[1] !="MxRAMObjective" & !suppliedNames ){
		stop("I need either mxRAMObjective or the names of the A and S matrices.")
	}
	output <- model@output
	# stop if there is no objective function
	if (is.null(output))stop("Provided model has no objective function, and thus no output. I can only standardize models that have been run!")
	# stop if there is no output
	if (length(output)<1)stop("Provided model has no output. I can only standardize models that have been run!")
	# Get the names of the A, S and M matrices 
	if (is.character(Amatrix)){nameA <- Amatrix} else {nameA <- model@objective@A}
	if (is.character(Smatrix)){nameS <- Smatrix} else {nameS <- model@objective@S}
	if (is.character(Mmatrix)){nameM <- Mmatrix} else {nameM <- model@objective@M}
	# Get the A and S matrices, and make an identity matrix
	A <- model[[nameA]]
	S <- model[[nameS]]
	I <- diag(nrow(S@values))
	
	# Calculate the expected covariance matrix
	IA <- solve(I-A@values)
	expCov <- IA %*% S@values %*% t(IA)
	# Return 1/SD to a diagonal matrix
	invSDs <- 1/sqrt(diag(expCov))
	# Give the inverse SDs names, because mxSummary treats column names as characters
	names(invSDs) <- as.character(1:length(invSDs))
	if (!is.null(dimnames(A@values))){names(invSDs) <- as.vector(dimnames(S@values)[[2]])}
	# Put the inverse SDs into a diagonal matrix (might as well recycle my I matrix from above)
	diag(I) <- invSDs
	# Standardize the A, S and M matrices
	#  A paths are value*sd(from)/sd(to) = I %*% A %*% solve(I)
	#  S paths are value/(sd(from*sd(to))) = I %*% S %*% I
	stdA <- I %*% A@values %*% solve(I)
	stdS <- I %*% S@values %*% I
	# Populate the model
	model[[nameA]]@values[,] <- stdA
	model[[nameS]]@values[,] <- stdS
	if (!is.na(nameM)){model[[nameM]]@values[,] <- rep(0, length(invSDs))}
	# Return the model, if asked
	if(return=="model"){
		return(model)
	}else if(return=="matrices"){
		# return the matrices, if asked
		matrices <- list(model[[nameA]], model[[nameS]])
		names(matrices) <- c("A", "S")
		return(matrices)
	}else if(return=="parameters"){
		# return the parameters
		#recalculate summary based on standardised matrices
		p <- summary(model)$parameters
		p <- p[(p[,2]==nameA)|(p[,2]==nameS),]
		## get the rescaling factor
		# this is for the A matrix
		rescale <- invSDs[p$row] * 1/invSDs[p$col]
		# this is for the S matrix
		rescaleS <- invSDs[p$row] * invSDs[p$col]
		# put the A and the S together
		rescale[p$matrix=="S"] <- rescaleS[p$matrix=="S"]
		# rescale
		p[,5] <- p[,5] * rescale
		p[,6] <- p[,6] * rescale
		# rename the columns
		# names(p)[5:6] <- c("Std. Estimate", "Std.Std.Error")
		return(p)		
	}
}

umxReportCIs <- function(model, addCIs = T, runCIs="if necessary") {
	if(is.na(model)){
		message("umxReportCIs adds mxCI() calls for all free parameters in a model, runs them, and reports a neat summary. A use example is:\n umxReportCIs(model)")
		stop();
	}
	message("### CIs for model ", model@name)
	if(addCIs){
		CIs = names(omxGetParameters(model))
		model = mxRun(mxModel(model, mxCI(CIs)), intervals = T)
	} else if(runCIs == "if necessary" & dim(model@output$confidenceIntervals)[1] < 0){
		model = mxRun(model, intervals = T)		
	}
	model_summary = summary(model)
	model_CIs = round(model_summary$CI, 3)
	model_CI_OK = model@output$confidenceIntervalCodes
	colnames(model_CI_OK) <- c("lbound Code", "ubound Code")
	model_CIs =	cbind(round(model_CIs, 3), model_CI_OK)
	print(model_CIs)
	invisible(model)
}

# ==============================
# = Label and equate functions =
# ==============================

umxLabel <- function(obj, suffix = "", baseName = NA, setfree = F, drop = 0, jiggle = NA, boundDiag = NA, verbose = F) {	
	# Purpose: Label the cells of a matrix, OR the matrices of a RAM model
	# version: 2.0b now that it labels matrices, RAM models, and arbitrary matrix models
	# nb: obj must be either an mxModel or an mxMatrix
	# Use case: m1 = umxLabel(m1)
	# umxLabel(mxMatrix("Full", 3,3, values = 1:9, name = "a"))
	if (is(obj, "MxMatrix") ) { 
		# label an mxMatrix
		xmuLabel_Matrix(obj, baseName, setfree, drop, jiggle, boundDiag, suffix)
	} else if (umxModelIsRAM(obj)) { 
		# label a RAM model
		if(verbose){message("RAM")}
		return(xmuLabel_RAM_Model(obj, suffix))
	} else if (is(obj, "MxModel")) {
		# label a non-RAM matrix model
		return(xmuLabel_MATRIX_Model(obj, suffix))
	} else {
		stop("I can only label OpenMx models and mxMatrix types. You gave me a ", typeof(obj))
	}
}

umxGetLabels <- function(inputTarget, regex = NA, free = NA, verbose = F) {
	# Purpose: a regex-enabled version of omxGetParameters
	# usage e.g.
	# umxGetLabels(model@matrices$as) # all labels of as matrix
	# umxGetLabels(model, regex="as_r_2c_[0-9]", free=T) # get all columns of row 2 or as matrix
	if(class(inputTarget)[1] %in% c("MxRAMModel","MxModel")) {
		topLabels = names(omxGetParameters(inputTarget, indep=FALSE, free=free))
	} else if(is(inputTarget, "MxMatrix")) {
		if(is.na(free)) {
			topLabels = inputTarget@labels
		} else {
			topLabels = inputTarget@labels[inputTarget@free==free]
		}
		}else{
			stop("I am sorry Dave, umxGetLabels needs either a model or a matrix: you offered a ", class(inputTarget)[1])
		}
	theLabels = topLabels[which(!is.na(topLabels))] # exclude NAs
	if( !is.na(regex) ) {
		if(length(grep("[\\.\\*\\[\\(\\+\\|]+", regex) )<1){ # no grep found: add some anchors for safety
			regex = paste("^", regex, "[0-9]*$", sep=""); # anchor to the start of the string
			if(verbose==T){
				cat("note: anchored regex to beginning of string and allowed only numeric follow\n");
			}
		}
		
		theLabels = grep(regex, theLabels, perl = F, value=T) # return more detail
		if(length(theLabels)==0){
			stop("found no matching labels!");
		}
	}
	# TODO Be nice to offer a method to handle submodels
	# model@submodels$aSubmodel@matrices$aMatrix@labels
	# model@submodels$MZ@matrices
	return(theLabels)
}

umxEquate <- function(model, master, slave, free = T, verbose = T, name = NULL) {
	# Purpose: to equate parameters by setting of labels (the slave set) = to the labels in a master set
	# umxEquate(model1, master="am", slave="af", free=T|NA|F")
	if(!(class(model)[1] == "MxModel" | class(model)[1] == "MxRAMModel")){
		message("ERROR in umxEquate: model must be a model, you gave me a ", class(model)[1])
		message("A usage example is umxEquate(model, master=\"a_to_b\", slave=\"a_to_c\", name=\"model2\") # equate paths a->b and a->c, in a new model called \"model2\"")
		stop()
	}
	if(length(grep("[\\^\\.\\*\\[\\(\\+\\|]+", master) )<1){ # no grep found: add some anchors for safety
		master = paste("^", master, "[0-9]*$", sep=""); # anchor to the start of the string
		slave  = paste("^", slave,  "[0-9]*$", sep="");
		if(verbose==T){
			cat("note: anchored regex to beginning of string and allowed only numeric follow\n");
		}
	}
	masterLabels = names(omxGetParameters(model, indep=FALSE, free=free))
	masterLabels = masterLabels[which(!is.na(masterLabels) )]      # exclude NAs
	masterLabels = grep(master, masterLabels, perl = F, value=T)
	# return(masterLabels)
	slaveLabels = names(omxGetParameters(model, indep=F, free=free))
	slaveLabels = slaveLabels[which(!is.na(slaveLabels))] # exclude NAs
	slaveLabels = grep(slave, slaveLabels, perl = F, value=T)
	if( length(slaveLabels) != length(masterLabels)) {
		print(list(masterLabels = masterLabels, slaveLabels = slaveLabels))
		stop("ERROR in umxEquate: master and slave labels not the same length!")
	}
	if( length(slaveLabels)==0 ) {
		legal = names(omxGetParameters(model, indep=FALSE, free=free))
		legal = legal[which(!is.na(legal))]
		message("Labels available in model are: ",legal)
		stop("ERROR in umxEquate: no matching labels found!")
	}
	print(list(masterLabels = masterLabels, slaveLabels = slaveLabels))
	model = omxSetParameters(model = model, labels = slaveLabels, newlabels = masterLabels, name = name)
	model = omxAssignFirstParameters(model, indep = F)
	return(model)
}

#` ## path-oriented helpers
#` ## matrix-oriented helpers

# ===================
# = Ordinal helpers =
# ===================

# umxThresholdRAMObjective can set the means and variance of the latents to 0 & 1, and build an appropriate thresholds matrix
# It uses umxIsOrdinalVar, umxMakeThresholdMatrix as helpers

umxThresholdRAMObjective <- function(df,  deviationBased=T, droplevels = T, verbose=F) {
	# Purpose: add means@0 and variance@1 to each ordinal variable, 
	# Use case: umxThresholdRAMObjective(df)
	# TODO: means = zero & VAR = 1 for ordinal variables
	# (this is a nice place to do it, as we have the df present...)
	if(!any(umxIsOrdinalVar(df))){
		stop("No ordinal variables in dataframe: no need to call umxThresholdRAMObjective")
	} 
	pt1 = mxPath(from = "one", to = umxIsOrdinalVar(df,names = T), connect="single", free=F, values = 0)
	pt2 = mxPath(from = umxIsOrdinalVar(df,names = T), connect = "single", arrows = 2, free = F, values = 1)
	return(list(pt1, pt2, umxMakeThresholdMatrix(df, deviationBased = T, droplevels = T, verbose = F)))
}

umxMakeThresholdMatrix <- function(df, deviationBased=T, droplevels = T, verbose=F) {	
	# Purpose: return a mxRAMObjective(A = "A", S="S", F="F", M="M", thresholds = "thresh"), mxData(df, type="raw")
	# use case:  umxMakeThresholdMatrix(df, verbose = T)
	# note, called by umxThresholdRAMObjective()
	# TODO: Let the user know if there are any levels dropped...
	if(droplevels){
		df = droplevels(df)
	}
	if(deviationBased){
		return(xmuMakeDeviationThresholdsMatrices(df, droplevels, verbose))
	} else {
		return(xmuMakeThresholdsMatrices(df, droplevels, verbose))
	}
}

umxIsOrdinalVar <- function(df, names=F) {
	# Purpose, return which columns are Ordinal
	# use case: isContinuous = !umxIsOrdinalVar(df)
	# nb: can optionally return just the names of these
	nVar = ncol(df);
	# Which are ordered factors?
	factorVariable = rep(F,nVar)
	for(n in 1:nVar) {
		if(is.ordered(df[,n])) {
			factorVariable[n]=T
		}
	}
	if(names){
		return(names(df)[factorVariable])
	} else {
		return(factorVariable)
	}
}

# ==================================
# = Borrowed for tutorial purposes =
# ==================================

summaryACEFit <- function(fit, accuracy = 2, dotFilename = NA, returnStd = F, extended = F, showRg = F, showStd = T, parentModel = NA, CIs = F, zero.print = ".") {
	# Purpose: summarise a Cholesky model, as returned by makeACE_2Group
	# use case: summaryACEFit(fit, dotFilename=NA);
	# summaryACEFit(safeFit, dotFilename = "name", showStd = T)
	# stdFit = summaryACEFit(fit, accuracy=2, dotFilename="name", returnStd=F, extended=F, showRg=T, showStd=T,parentModel=NA, CIs=T);
	if(length(fit)>1){ # call self recursively
		for(thisFit in fit) {
			message("Output for Model: ",thisFit@name)
			summaryACEFit(thisFit, accuracy=accuracy, dotFilename=dotFilename, returnStd=returnStd, extended=extended, showRg=showRg, showStd=showStd, parentModel=NA, CIs=CIs)
		}
	} else {
		if(!class(parentModel)=="logical"){
			message("Comparison of fit")
			print(mxCompare(parentModel, fit))
		}
		logLikelihood = mxEval(objective, fit); 
		message("-2 \u00d7 log(Likelihood)") # ×
		print(logLikelihood[1,1]);
		selDVs = dimnames(fit$top.mzCov)[[1]]
		# genEpi_TableFitStatistics(fit, extended=extended)
		nVar <- length(selDVs)/2;
		# Calculate standardised variance components
		a  <- mxEval(top.a, fit); # Path coefficients
		c  <- mxEval(top.c, fit);
		e  <- mxEval(top.e, fit);
		A  <- mxEval(top.A, fit); # Variances
		C  <- mxEval(top.C, fit);
		E  <- mxEval(top.E, fit);
		Vtot = A+C+E;             # Total variance
		I  <- diag(nVar); # nVar Identity matrix
		SD <- solve(sqrt(I*Vtot)) # Inverse of diagonal matrix of standard deviations  (same as "(\sqrt(I.Vtot))~"
	
		# Standardized _path_ coefficients ready to be stacked together
		a_std <- SD %*% a; # Standardized path coefficients
		c_std <- SD %*% c;
		e_std <- SD %*% e;
		if(showStd){
			message("Standardized solution")
			aClean = a_std
			cClean = c_std
			eClean = e_std
		} else {
			message("Raw solution")
			aClean = a
			cClean = c
			eClean = e
		}
		aClean[upper.tri(aClean)]=NA
		cClean[upper.tri(cClean)]=NA
		eClean[upper.tri(eClean)]=NA
		Estimates = data.frame(cbind(aClean,cClean,eClean), row.names=selDVs[1:nVar]);
		names(Estimates) = paste(rep(c("a", "c", "e"), each = nVar), rep(1:nVar), sep = "");
		print.dataframe(Estimates, digits = accuracy, zero.print = ".") # this function is created in genEpi.lib
		if(extended==TRUE) {
			message("Unstandardized path coefficients")
			aClean = a
			cClean = c
			eClean = e
			aClean[upper.tri(aClean)]=NA
			cClean[upper.tri(cClean)]=NA
			eClean[upper.tri(eClean)]=NA
			unStandardizedEstimates = data.frame(cbind(aClean,cClean,eClean), row.names=selDVs[1:nVar]);
			names(unStandardizedEstimates) = paste(rep(c("a", "c", "e"), each=nVar), rep(1:nVar), sep="");
			print.dataframe(unStandardizedEstimates, digits=accuracy, zero.print = ".")
		}

		# Pre & post multiply covariance matrix by inverse of standard deviations
		if(showRg) {
			message("Genetic correlations")
			NAmatrix <- matrix(NA, nVar, nVar);
			rA = tryCatch(solve(sqrt(I*A)) %*% A %*% solve(sqrt(I*A)), error=function(err) return(NAmatrix)); # genetic correlations
			rC = tryCatch(solve(sqrt(I*C)) %*% C %*% solve(sqrt(I*C)), error=function(err) return(NAmatrix)); # shared environmental correlations
			rE = tryCatch(solve(sqrt(I*E)) %*% E %*% solve(sqrt(I*E)), error=function(err) return(NAmatrix)); # Unique environmental correlations
			rAClean = rA
			rCClean = rC
			rEClean = rE
			rAClean[upper.tri(rAClean)]=NA
			rCClean[upper.tri(rCClean)]=NA
			rEClean[upper.tri(rEClean)]=NA
			genetic_correlations  = data.frame(cbind(rAClean, rCClean, rEClean), row.names=selDVs[1:nVar] );
			names(genetic_correlations)<-selDVs[1:nVar]
		 	# Make a nice-ish table
			names(genetic_correlations)= paste(rep(c("rA", "rC", "rE"), each=nVar), rep(1:nVar), sep="");
			print.dataframe(genetic_correlations, digits=accuracy, zero.print = ".")
		}
		stdFit = fit
		if(CIs) {
			# TODO Need to refactor this into some function calls...
			if(all(dim(fit@output$confidenceIntervals) == c(0,2))){
				message("You requested me to print out CIs, but there are none - perhaps you’d like to add 'addStd = T' to your makeACE_2Group() call?")
			} else {
				message("Computing CI-based diagram!")
				# get the lower and uppper CIs as a dataframe
				CIlist = data.frame(fit@output$confidenceIntervals)
				# Drop rows fixed to zero
				CIlist = CIlist[(CIlist$lbound!=0 & CIlist$ubound!=0),]

				# These can be names ("top.a_std[1,1]") or labels ("a11")
				# imxEvalByName finds them both
				outList = c();
				for(aName in row.names(CIlist)) {
					outList <- append(outList, imxEvalByName(aName,fit))
				}
				# Add estimates into the CIlist
				CIlist$estimate = outList
				# reorder to match summary
				CIlist <- CIlist[,c("lbound","estimate", "ubound")] 
				CIlist$fullName = row.names(CIlist)
				# Initialise empty matrices for the standardized results
				rows = dim(fit@submodels$top@matrices$a@labels)[1]
				cols = dim(fit@submodels$top@matrices$a@labels)[2]
				a_std = c_std = e_std= matrix(NA, rows, cols)

				# iterate over each CI
				labelList = imxGenerateLabels(fit)			
				rowCount = dim(CIlist)[1]

				for(n in 1:rowCount) { # n=1
					thisName = row.names(CIlist)[n] # thisName = "a11"
					if(!hasSquareBrackets(thisName)) {
						# upregulate to a bracket name
						nameParts = labelList[which(row.names(labelList)==thisName),]
						CIlist$fullName[n] = paste(nameParts$model, ".", nameParts$matrix, "[", nameParts$row, ",", nameParts$col, "]", sep="")
					}
					fullName = CIlist$fullName[n]

					thisMatrixName = sub(".*\\.([^\\.]*)\\[.*", replacement = "\\1", x = fullName) # .matrix[
					thisMatrixRow  = as.numeric(sub(".*\\[(.*),(.*)\\]", replacement = "\\1", x = fullName))
					thisMatrixCol  = as.numeric(sub(".*\\[(.*),(.*)\\]", replacement = "\\2", x = fullName))
					CIparts = round(CIlist[n, c("estimate", "lbound", "ubound")], 2)
					thisString = paste(CIparts[1], " (",CIparts[2], ":",CIparts[3], ")", sep="")
					# print(list(CIlist,labelList,rowCount,fullName,thisMatrixName))

					if(grepl("^a", thisMatrixName)) {
						a_std[thisMatrixRow, thisMatrixCol] = thisString
					} else if(grepl("^c", thisMatrixName)){
						c_std[thisMatrixRow, thisMatrixCol] = thisString
					} else if(grepl("^e", thisMatrixName)){
						e_std[thisMatrixRow, thisMatrixCol] = thisString
					} else{
						stop(paste("illegal matrix name: must begin with a, c, or e. You sent: ", thisMatrixName))
					}
				}
				print(a_std)
				print(c_std)
				print(e_std)
			}
		} #use CIs
		stdFit@submodels$top@matrices$a@values = a_std
		stdFit@submodels$top@matrices$c@values = c_std
		stdFit@submodels$top@matrices$e@values = e_std
		if(!is.na(dotFilename)) {
			message("making dot file")
			if(showStd){
				graphViz_Cholesky(stdFit, selDVs, dotFilename)
			}else{
				graphViz_Cholesky(fit, selDVs, dotFilename)
			}
		}
		if(returnStd) {
			return(stdFit)
		}

		# MZc = mxEval(MZ.expCov,  fit);
		# DZc = mxEval(DZ.expCov,  fit);
		# M   = mxEval(MZ.expMean, fit);
	}
}

# ===========
# = Utility =
# ===========

umxJiggle <- function(matrixIn, mean = 0, sd = .1, dontTouch = 0) {
	mask      = (matrixIn != dontTouch);
	newValues = mask;
	matrixIn[mask==TRUE] = matrixIn[mask==TRUE] + rnorm(length(mask[mask==TRUE]), mean=mean, sd=sd);
	return (matrixIn);
}

umxModelIsRAM <- function(obj) {
	# test is model is RAM
	# umxModelIsRAM(obj)
	isModel = isS4(obj) & is(obj, "MxModel")
	if(!isModel){
		return(F)
	}
	oldRAM_check = class(obj$objective) == "MxRAMObjective"
	# TODO: get working on both the old and new objective model...
	# newRAM_check = (class(obj$objective)[1] == "MxRAMObjective"))
	if(oldRAM_check) {
		return(T)
	} else {
		return(F)			
	}
}

umxIsMxModel <- function(obj) {
	isS4(obj) & is(obj, "MxModel")	
}

umxIsRAMmodel <- function(obj) {
	(class(obj$objective)[1] == "MxRAMObjective" | class(obj$expectation)[1] == "MxExpectationRAM")	
}

xmuStart_value_list <- function(x = 1, sd = NA, n = 1) {
	# Purpose: Create startvalues for OpenMx paths
	# use cases
	# umxStart(1) # 1 value, varying around 1, with sd of .1
	# umxStart(1, n=letters) # length(letters) start values, with mean 1 and sd .1
	# umxStart(100, 15)  # 1 start, with mean 100 and sd 15
	# TODO: handle connection style
	# nb: bivariate length = n-1 recursive 1=0, 2=1, 3=3, 4=7 i.e., 
	if(is.na(sd)){
		sd = x/6.6
	}
	if(length(n)>1){
		n = length(n)
	}
	return(rnorm(n=n, mean=x, sd=sd))
}
