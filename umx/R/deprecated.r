# ==============
# = Deprecated =
# ==============

umxTryHard = function(model, n=3, calc_SE=F){ stop("Use umxRun() in place of umxTryHard") }

umxLabels = function(from=NA, to=NA, connect="single", prefix="", suffix="") {stop("please use umxPath in place of umxLabels. To label models or matrices, use umxLabel")}

genEpi_Jiggle = function(matrixIn, mean = 0, sd = .1, dontTouch = 0) {stop("please use umxJiggle in place of genEpi_Jiggle")}

umxPath <- function(from = NA, to = NA, connect = "single", arrows = 1, free = TRUE, values = NA, labels = NA, lbound = NA, ubound = NA, prefix = "", suffix = "",...) {
	stop("replace umxPath with mxPath, and run umxLabel(model) on the model when you are done to add default labels, plus umxStart(model) to add default start values")
	# {$|single,all.pairs,all.bivariate,unique.pairs,unique.bivariate|}
	# Purpose: make mxPaths with informative labels, comments to tim.bates@ed.ac.uk
	# use case
	# umxPath(from = "OriginSES", to = "PaternalSESn")
	# Use case: umxPath("F1", paste("m",1:4,sep="")) # "F1_to_m1" "F1_to_m2" "F1_to_m3" "F1_to_m4"
	# TODO: make this generate the paths as well... i.e., "umxPath()"
	# TODO: handle connection style
	# nb: bivariate length = n-1 recursive 1=0, 2=1, 3=3, 4=7 i.e., 
	if(any(is.na(to)) & (suffix=="var"| suffix=="unique")){
		# handle from only, variance and residuals
		part1  = paste(prefix, from, sep="")
		myLabels = (paste(part1, suffix, sep="_"))
	} else if(any(from == "one")){
		# handle means (from == "one")
		if(!all(from == "one")){
			stop(cat("Error in umxLabels: from was a mix of one and not-one",from))
		} else {
			myLabels = paste(to, "mean", sep="_")
		}
	} else if(connect == "unique.bivariate") {
		if(!all(is.na(to))){
			if(!(from == to)){
				stop("with connect = 'unique.bivariate', to must be blank, or the same as from")
			}
		}
		labels = as.character(combn(from, m = 2, FUN = paste, collapse = "_"))
		return(labels)
	} else {
		fromPart = paste(prefix, from, sep = "")
		toPart   = paste(to  , suffix, sep = "_")
		myLabels = paste(fromPart, toPart, sep = "_to_")
	}
	mxPath(from = from, to = to, connect = connect, arrows = arrows, free = free, values = values, labels = myLabels, lbound = lbound, ubound = ubound)
}
