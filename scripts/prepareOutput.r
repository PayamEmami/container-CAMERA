#!/usr/bin/env Rscript
options(stringAsfactors = FALSE, useFancyQuotes = FALSE)

# Taking the command line arguments
args <- commandArgs(trailingOnly = TRUE)

if(length(args)==0)stop("No file has been specified!\n")
require(xcms)
require(CAMERA)
require(intervals)


ppmCal<-function(run,ppm)
{
  return((run*ppm)/1000000)
}
metFragToCamera<-function(metFragSearchResult=NA,cameraObject=NA,ppm=5,MinusTime=5,PlusTime=5)
{
  #metFragSearchResult<-bb
  IDResults<-metFragSearchResult
  #cameraObject<-an
  listofPrecursorsmz<-c()
  listofPrecursorsmz<-IDResults[,"parentMZ"]
  listofPrecursorsrt<-IDResults[,"parentRT"]
  
  CameramzColumnIndex<-which(colnames(cameraObject@groupInfo)=="mz")
  
  MassRun1<-Intervals_full(cbind(listofPrecursorsmz,listofPrecursorsmz))
  
  MassRun2<-Intervals_full(cbind(cameraObject@groupInfo[,CameramzColumnIndex]-
                                   ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm),
                                 cameraObject@groupInfo[,CameramzColumnIndex]+
                                   ppmCal(cameraObject@groupInfo[,CameramzColumnIndex],ppm)))
  
  Mass_iii <- interval_overlap(MassRun1,MassRun2)
  
  CamerartLowColumnIndex<-which(colnames(cameraObject@groupInfo)=="rtmin")
  CamerartHighColumnIndex<-which(colnames(cameraObject@groupInfo)=="rtmax")
  
  TimeRun1<-Intervals_full(cbind(listofPrecursorsrt,listofPrecursorsrt))
  
  TimeRun2<-Intervals_full(cbind(cameraObject@groupInfo[,CamerartLowColumnIndex]-MinusTime,
                                 cameraObject@groupInfo[,CamerartHighColumnIndex]+PlusTime))
  Time_ii <- interval_overlap(TimeRun1,TimeRun2)
  
  imatch = mapply(intersect,Time_ii,Mass_iii)
  listOfMS2Mapped<-list()
  for (i in 1:length(imatch)) {
    for(j in imatch[[i]])
    {
      if(is.null(listOfMS2Mapped[[as.character(j)]]))
      {
        listOfMS2Mapped[[as.character(j)]]<-data.frame(IDResults[i,],stringsAsFactors = F)
      }else
      {
        listOfMS2Mapped[[as.character(j)]]<-
          rbind(listOfMS2Mapped[[as.character(j)]],data.frame(IDResults[i,],stringsAsFactors = F))
      }
      
    }
  }
  return(list(mapped=listOfMS2Mapped))
}


ppmTol<-5
rtTol = 10
higherTheBetter<-T
scoreColumn<-"q.value"
impute<-T
typeColumn<-"type"
selectedType<-"p"
renameCol<-"rename"
rename<-T
onlyReportWithID<-T
combineReplicate<-F
combineReplicateColumn<-"rep"
iflog<-F
for(arg in args)
{
  argCase<-strsplit(x = arg,split = "=")[[1]][1]
  value<-strsplit(x = arg,split = "=")[[1]][2]
  
  if(argCase=="inputcamera")
  {
    inputCamera=as.character(value)
  }
  if(argCase=="inputscores")
  {
    scoreInput=as.character(value)
  }
  if(argCase=="inputpheno")
  {
    phenotypeInfoFile=as.character(value)
  }
  if(argCase=="ppm")
  {
    ppmTol=as.numeric(value)
  }
  if(argCase=="rt")
  {
    rtTol=as.numeric(value)
  }
  if(argCase=="higherTheBetter")
  {
    higherTheBetter=as.logical(value)
  }  
  if(argCase=="scoreColumn")
  {
    scoreColumn=as.character(value)
  }  
  if(argCase=="impute")
  {
    impute=as.logical(value)
  }
  if(argCase=="typeColumn")
  {
    typeColumn=as.character(value)
  }
  if(argCase=="selectedType")
  {
    selectedType=as.character(value)
  }
  if(argCase=="rename")
  {
    rename=as.logical(value)
  }
  if(argCase=="renameCol")
  {
    renameCol=as.character(value)
  }
  if(argCase=="onlyReportWithID")
  {
    onlyReportWithID=as.logical(value)
  }
  if(argCase=="combineReplicate")
  {
    combineReplicate=as.logical(value)
  }
  if(argCase=="combineReplicateColumn")
  {
    combineReplicateColumn=as.character(value)
  }
   if(argCase=="log")
  {
    iflog=as.logical(value)
  }
  if(argCase=="outputPeakTable")
  {
    outputPeakTable=as.character(value)
  }
  if(argCase=="outputVariables")
  {
    outputVariables=as.character(value)
  }  
  if(argCase=="outputMetaData")
  {
    outputMetaData=as.character(value)
  }
  
  
}



load(inputCamera)
cameraObject<-get(varNameForNextStep)
cameraPeakList<-getPeaklist(cameraObject)


phenotypeInfo<-read.csv(file = phenotypeInfoFile,stringsAsFactors = F)
#sepScore<-","
#if(scoreColumn=="q.value")
  sepScore="\t"
metfragRes<-read.table(file = scoreInput,header = T,sep = sepScore,quote="",stringsAsFactors = F,comment.char = "")

mappedToCamera<-metFragToCamera(metFragSearchResult = metfragRes,
                                cameraObject = cameraObject,MinusTime = rtTol,PlusTime = rtTol,ppm = ppmTol)


VariableData<-data.frame(matrix("Unknown",nrow = nrow(cameraPeakList),
                                ncol = (ncol(metfragRes)+1)),stringsAsFactors = F)


colnames(VariableData)<-c("variableMetadata",colnames(metfragRes))

VariableData[,"variableMetadata"]<-paste("variable_",1:nrow(cameraPeakList),sep="")

for(rnName in rownames(cameraPeakList))
{
  if(rnName %in% names(mappedToCamera$mapped))
  {
    tmpId<-mappedToCamera$mapped[[rnName]]
    if(higherTheBetter)
      {
tmpId<-tmpId[which.max(tmpId[,scoreColumn]),]
}else{
tmpId<-tmpId[which.min(tmpId[,scoreColumn]),]
}
      
    VariableData[VariableData[,"variableMetadata"]==paste("variable_",rnName,sep=""),
                 c(2:ncol(VariableData))]<-tmpId
  }
}

if(impute)
{
  
  toBeImputed<-rownames(VariableData[VariableData[,2]=="Unknown",])
  pcgroups<-cameraPeakList[rownames(cameraPeakList)%in%toBeImputed,"pcgroup"]
  
  for(pcgr in pcgroups)
  {
    selectedFeatures<-
      VariableData[,"variableMetadata"]%in%paste("variable_",rownames(cameraPeakList[cameraPeakList[,"pcgroup"]==pcgr,]),sep="") &
      VariableData[,2]!="Unknown"
    
    if(any(selectedFeatures))
    {
      tmpIDs<-VariableData[selectedFeatures,]
      tmpId<-NA
      if(higherTheBetter)
{
tmpId<-tmpIDs[which.max(tmpIDs[,scoreColumn]),]
}else
{
tmpId<-tmpIDs[which.min(tmpIDs[,scoreColumn]),]
}
        
      
      imputedVariables<- paste("variable_",rownames(cameraPeakList[ cameraPeakList[,"pcgroup"]==pcgr,]),sep="")
      
      imputedVariables<- VariableData[,"variableMetadata"]%in%imputedVariables & VariableData[,2]=="Unknown"
      
      VariableData[imputedVariables,c(2:ncol(VariableData))]<-tmpId[,c(2:ncol(tmpId))]
    }
  }
  
}




peakMatrix<-c()
peakMatrixNames<-c()
peakMatrixTMP<-cameraPeakList
technicalReps<-c()

phenotypeInfo<-phenotypeInfo[phenotypeInfo[,typeColumn]==selectedType,]
for(i in 1:nrow(cameraObject@xcmsSet@phenoData))
{
  index<-which(phenotypeInfo==rownames(cameraObject@xcmsSet@phenoData)[i],arr.ind = T)[1]
  if(!is.na(index))
  {
    peakMatrix<-cbind(peakMatrix, peakMatrixTMP[,rownames(cameraObject@xcmsSet@phenoData)[i]])
    if(rename)
    {
      
      peakMatrixNames<-c(peakMatrixNames,phenotypeInfo[index,renameCol])
    }else
    {
      peakMatrixNames<-c(peakMatrixNames,phenotypeInfo[index,1])
      #peakMatrixNames<-c(peakMatrixNames,rownames(cameraObject@xcmsSet@phenoData)[i])
    }
    if(combineReplicate)
    {
      technicalReps<-c(technicalReps,phenotypeInfo[index,combineReplicateColumn])
    }
    
  }
}



peakMatrix<-data.frame(peakMatrix)
colnames(peakMatrix)<-peakMatrixNames


sampleMetaData<-c()
phenotypeInfo<-phenotypeInfo[,!grepl(pattern = "step_",x = colnames(phenotypeInfo),fixed=T)]
if(rename)
{
  
  sampleMetaData<-phenotypeInfo[,c(renameCol,colnames(phenotypeInfo)[colnames(phenotypeInfo)!=renameCol])]
}else
{
  sampleMetaData<-phenotypeInfo
  
}
colnames(sampleMetaData)[1]<-"sampleMetadata"

technicalReps<-technicalReps[match(sampleMetaData[,1],colnames(peakMatrix))]
peakMatrix<-peakMatrix[,match(sampleMetaData[,1],colnames(peakMatrix))]
peakMatrixNames<-colnames(peakMatrix)
if(combineReplicate)
{
  newpheno<-c()
  newNames<-c()
  combinedPeakMatrix<-c()
  techs<-unique(technicalReps)
  for(x in techs)
  {
    if(ncol(data.frame(peakMatrix[,technicalReps==x]))>1)
    {
      
      dataTMP<-apply(data.frame(peakMatrix[,technicalReps==x]),MARGIN = 1,FUN = median,na.rm=T)
      newNames<-c(newNames,as.character(unique(peakMatrixNames[technicalReps==x]))[1])
      newpheno<-rbind(newpheno,sampleMetaData[sampleMetaData[,combineReplicateColumn]==x,][1,])
      combinedPeakMatrix<-cbind(combinedPeakMatrix,dataTMP)
    }else
    {
      dataTMP<-peakMatrix[,technicalReps==x]
      newNames<-c(newNames,as.character(unique(peakMatrixNames[technicalReps==x]))[1])
      newpheno<-rbind(newpheno,sampleMetaData[sampleMetaData[,combineReplicateColumn]==x,][1,])
      combinedPeakMatrix<-cbind(combinedPeakMatrix,dataTMP)
    }
  }
  
  peakMatrix<-  combinedPeakMatrix
  peakMatrixNames<-newNames
  sampleMetaData<-newpheno[,colnames(newpheno)!=combineReplicateColumn]
}


peakMatrix<-data.frame(peakMatrix)
colnames(peakMatrix)<-peakMatrixNames


if(!onlyReportWithID)
{
  peakMatrix<-peakMatrix[VariableData[,2]!="Unknown",]
  VariableData<-VariableData[VariableData[,2]!="Unknown",]
}
if(iflog)
{
peakMatrix<-log2(peakMatrix)
}
peakMatrix<-cbind.data.frame(dataMatrix=VariableData[,"variableMetadata"],peakMatrix,stringsAsFactors = F)
VariableData<-sapply(VariableData, gsub, pattern="\'|#", replacement="")
VariableData<-VariableData[apply(is.na(peakMatrix),1,sum)!=(ncol(peakMatrix)-1),]
peakMatrix<-peakMatrix[apply(is.na(peakMatrix),1,sum)!=(ncol(peakMatrix)-1),]
#peakMatrix[VariableData[,2]!="Unknown",1]<-VariableData[VariableData[,2]!="Unknown","Identifier"]
#VariableData[VariableData[,2]!="Unknown",1]<-VariableData[VariableData[,2]!="Unknown","Identifier"]

write.table(x = peakMatrix,file = outputPeakTable,
            row.names = F,quote = F,sep = "\t")
write.table(x = VariableData,file = outputVariables,
            row.names = F,quote = F,sep = "\t")

write.table(x = sampleMetaData,file = outputMetaData,
            row.names = F,quote = F,sep = "\t")

