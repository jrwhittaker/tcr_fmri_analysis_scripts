%
% Code for deriving the novel basis set from ROI time series
%
% Joe Whittaker (2021)

% Main directory
dire='/cubric/data/sapjw12/TCR_BOLD/tcr_fmri';

% Read in ROI time series file
cort_rois=[];
for n=1:10

    pid=sprintf('s%.2d',n);
    fname=sprintf('%s/%s_new/roidump/%s.tcr_cortical_ts.1D',dire,pid,pid);
    tmp=load(fname);
    nvols=size(tmp,1);
    nrois=size(tmp,2);
    y=nan(90,nrois);   
    y(1:nvols,:)=tmp;
    if (isnan(y(end,1)))
        for ii=1:nrois
            x=y(:,ii);
            x(end)=mean(x(1:19));
            x(isnan(x))=[];
            x=interp1([0:59 89],x,0:89,'pchip');
            y(:,ii)=x;
        end
    end
    cort_rois=[cort_rois y]; 
    ROI(:,:,n)=y;
end
ROI=squeeze(mean(ROI,3));

cort_rois_dm=cort_rois-(ones(90,1)*mean(cort_rois(1:20,:)));

% Create low-pass filtered data
time=linspace(0,89,90)';
X=[ones(90,1) linspace(-0.5,0.5,90)'];
for n=1:15
    X=[X cos(2*pi*n*(1/90).*time) sin(2*pi*n*(1/90).*time)];
end
for ii=1:480
    B=regress(cort_rois_dm(:,ii),X);
    cort_rois_lp(:,ii)=X*B;
end

x=linspace(0,69,70);
X=[];

% parameters for double Gamma model
tau=[6:4:26];
sigma=linspace(0.05,0.3,6);

% Create initial basis set
for n=1:size(tau,2)
    X=[X gamma_pdf([tau(n) sigma(n)],x)];
end
matX=zeros(90,size(X,2));
matX(21:90,1:end)=X;
matX=matX./(ones(90,1)*max(matX));

%figure,plot(matX)

for ii=1:480
       
    y=cort_rois_lp(:,ii);
    [B]=regress(y,matX);
    
    minIdx=1; 
    y1=matX(:,minIdx:end)*B(minIdx:end);

    tss=sum((y-mean(y)).^2);
    res=y-y1;
    rss=sum(res.^2);
    
    R2(ii,:)=1-rss/tss;
    fits(:,ii)=y1;
    
end

[~,bestIdx]=sort(R2,'descend');
% Take the top 50% of fits
roiFitMat=fits(:,bestIdx(1:240));

% Loop through different values of k for k-means clustering
for k=[2:80]
    for iter=1:10
        [~,~,sumd]=kmeans(roiFitMat',k);
        SS(k-1,iter)=sum(sumd);
    end
end
ssy=min(SS,[],2);

% Identify the optimal number of clusters
x=2:80;
coefests=lsqcurvefit(@biexponential,[100000 5 10000 10],x',ssy);
ssyf=feval(@biexponential,coefests,x);

nPoints=length(ssyf);
allCoord=[1:nPoints;ssyf]';

firstPoint=allCoord(1,:);
lineVec=allCoord(end,:)-firstPoint;
lineVecN = lineVec / sqrt(sum(lineVec.^2));
vecFromFirst=bsxfun(@minus,allCoord,firstPoint);
scalarProduct=dot(vecFromFirst,repmat(lineVecN,nPoints,1),2);
vecFromFirstParallel=scalarProduct * lineVecN;
vecToLine=vecFromFirst - vecFromFirstParallel;
distToLine=sqrt(sum(vecToLine.^2,2));
[~,maxIdx]=max(distToLine);

ssk=ssy(maxIdx);
ssy(maxIdx)=nan;

% Plot showing optimal cluster
figure,plot(x,ssy),hold on,plot(x(maxIdx),ssk,'k.'),axis('square')

% Do the final clustering
kclusts=x(maxIdx);
clear SS
for iter=1:50
[kIdx(:,iter),~,sumd]=kmeans(roiFitMat(1:60,:)',kclusts);
SS(:,iter)=sum(sumd);
end
[~,minIdx]=min(SS);

roiK=zeros(90,kclusts);
for k=1:kclusts
    tmp=nanmean(roiFitMat(1:90,kIdx(:,minIdx)==k),2);
    roiK(:,k)=tmp;
end

% SVD to get novel basis set
[U,S,~]=svd(roiK);
figure,plot(U(:,1:4));
