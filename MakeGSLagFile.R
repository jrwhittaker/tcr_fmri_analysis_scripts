#!/cubric/software/r.versions/3.2.3/bin/Rscript --slave

# Collect arguments
args<-commandArgs(TRUE)

# Default setting when no arguments passed
if (length(args) < 2) {
args <- c("--help")
}

# Help section
if ("--help" %in% args) {
cat("
R script for making lag file from global signal:

Arguements:
--input	 = path input global signal file
--prefix = output prefix /path/prefix
\n\n")
q(save="no")
}

## Parse arguements (of the form --arg=value)
parseArgs<-function(x) strsplit(sub("^--","",x),"=")
argsDf<-as.data.frame(do.call("rbind",parseArgs(args)))
argsList<-as.list(as.character(argsDf$V2))
names(argsList)<-argsDf$V1

maxlag<-10
gs<-as.matrix(read.table(argsList$input))
nt<-length(gs)

# Make lag matrix
lagmat<-matrix(,(nt-(2*maxlag)),(2*maxlag+1))

for (n in 1:(2*maxlag+1))
{
  startIdx<-n
  endIdx<-nt-(2*maxlag)+(n-1)
  lagmat[,n]<-gs[startIdx:endIdx]
}

cat("\nWriting global signal lag matrix\n")
write(t(lagmat),file=paste(argsList$prefix,"gs_lagmatrix.1D",sep="."),ncolumns=(2*maxlag+1),sep=" ")


